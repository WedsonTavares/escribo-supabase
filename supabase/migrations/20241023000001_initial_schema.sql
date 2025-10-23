-- Criação do schema inicial para e-commerce
-- Tabelas: customers, products, orders, order_items
-- RLS policies, triggers, views e índices

-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- gera UUID v4 para chaves primárias

-- Tabela de clientes
-- Tabela de clientes: vincula com auth.users via user_id
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de produtos
-- Catálogo de produtos com controle de estoque
CREATE TABLE IF NOT EXISTS public.products (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price_cents INTEGER NOT NULL CHECK (price_cents > 0),
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de pedidos
-- Pedido do cliente. total_cents é calculado por trigger
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
    total_cents INTEGER DEFAULT 0 CHECK (total_cents >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de itens do pedido
-- Itens do pedido. price_cents é o preço no momento da compra
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price_cents INTEGER NOT NULL CHECK (price_cents > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_customers_user_id ON public.customers(user_id);
CREATE INDEX IF NOT EXISTS idx_customers_email ON public.customers(email);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON public.products(is_active);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON public.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON public.order_items(product_id);

-- Trigger para atualizar updated_at automaticamente
-- Função utilitária: atualiza coluna updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON public.customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Função para calcular total do pedido
-- Função: recalcula o total de um pedido a partir dos itens
CREATE OR REPLACE FUNCTION calculate_order_total(order_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
    total INTEGER;
BEGIN
    SELECT COALESCE(SUM(quantity * price_cents), 0)
    INTO total
    FROM public.order_items
    WHERE order_id = order_uuid;
    
    UPDATE public.orders
    SET total_cents = total, updated_at = NOW()
    WHERE id = order_uuid;
    
    RETURN total;
END;
$$ LANGUAGE plpgsql;

-- Trigger para calcular total automaticamente quando itens são modificados
-- Trigger: dispara recálculo do total após mutações em order_items
CREATE OR REPLACE FUNCTION trigger_calculate_order_total()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM calculate_order_total(OLD.order_id);
        RETURN OLD;
    ELSE
        PERFORM calculate_order_total(NEW.order_id);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_order_total_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.order_items
    FOR EACH ROW EXECUTE FUNCTION trigger_calculate_order_total();

-- Views para consultas eficientes
-- View: resumo agregando quantidades e itens por pedido
CREATE OR REPLACE VIEW v_order_summary AS
SELECT 
    o.id as order_id,
    o.status,
    o.total_cents,
    o.created_at as order_date,
    c.name as customer_name,
    c.email as customer_email,
    COUNT(oi.id) as total_items,
    SUM(oi.quantity) as total_quantity
FROM public.orders o
JOIN public.customers c ON o.customer_id = c.id
LEFT JOIN public.order_items oi ON o.id = oi.order_id
GROUP BY o.id, o.status, o.total_cents, o.created_at, c.name, c.email;

-- View: inventário com total vendido (exclui cancelados)
CREATE OR REPLACE VIEW v_product_inventory AS
SELECT 
    p.id as product_id,
    p.name,
    p.price_cents,
    p.stock_quantity,
    p.is_active,
    COALESCE(SUM(oi.quantity), 0) as total_sold
FROM public.products p
LEFT JOIN public.order_items oi ON p.id = oi.product_id
LEFT JOIN public.orders o ON oi.order_id = o.id
WHERE o.status NOT IN ('cancelled') OR o.status IS NULL
GROUP BY p.id, p.name, p.price_cents, p.stock_quantity, p.is_active;

-- View: pedidos por cliente com items em array JSON
CREATE OR REPLACE VIEW v_customer_orders AS
SELECT 
    c.id as customer_id,
    c.name as customer_name,
    c.email,
    o.id as order_id,
    o.status,
    o.total_cents,
    o.created_at as order_date,
    array_agg(
        json_build_object(
            'product_name', p.name,
            'quantity', oi.quantity,
            'price_cents', oi.price_cents
        )
    ) as items
FROM public.customers c
JOIN public.orders o ON c.id = o.customer_id
JOIN public.order_items oi ON o.id = oi.order_id
JOIN public.products p ON oi.product_id = p.id
GROUP BY c.id, c.name, c.email, o.id, o.status, o.total_cents, o.created_at;

-- Habilitação do RLS
-- Habilita RLS (políticas abaixo)
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para customers
CREATE POLICY "Customers can view own data" ON public.customers
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Customers can update own data" ON public.customers
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own customer data" ON public.customers
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Políticas RLS para products (todos podem ver produtos ativos)
CREATE POLICY "Anyone can view active products" ON public.products
    FOR SELECT USING (is_active = true);

-- Políticas RLS para orders
CREATE POLICY "Customers can view own orders" ON public.orders
    FOR SELECT USING (
        customer_id IN (
            SELECT id FROM public.customers WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Customers can create own orders" ON public.orders
    FOR INSERT WITH CHECK (
        customer_id IN (
            SELECT id FROM public.customers WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Customers can update own orders" ON public.orders
    FOR UPDATE USING (
        customer_id IN (
            SELECT id FROM public.customers WHERE user_id = auth.uid()
        )
    );

-- Políticas RLS para order_items
CREATE POLICY "Customers can view own order items" ON public.order_items
    FOR SELECT USING (
        order_id IN (
            SELECT o.id FROM public.orders o
            JOIN public.customers c ON o.customer_id = c.id
            WHERE c.user_id = auth.uid()
        )
    );

CREATE POLICY "Customers can create own order items" ON public.order_items
    FOR INSERT WITH CHECK (
        order_id IN (
            SELECT o.id FROM public.orders o
            JOIN public.customers c ON o.customer_id = c.id
            WHERE c.user_id = auth.uid()
        )
    );

CREATE POLICY "Customers can update own order items" ON public.order_items
    FOR UPDATE USING (
        order_id IN (
            SELECT o.id FROM public.orders o
            JOIN public.customers c ON o.customer_id = c.id
            WHERE c.user_id = auth.uid()
        )
    );

CREATE POLICY "Customers can delete own order items" ON public.order_items
    FOR DELETE USING (
        order_id IN (
            SELECT o.id FROM public.orders o
            JOIN public.customers c ON o.customer_id = c.id
            WHERE c.user_id = auth.uid()
        )
    );

-- Função para validar estoque antes de criar item do pedido
CREATE OR REPLACE FUNCTION validate_stock_availability()
RETURNS TRIGGER AS $$
DECLARE
    current_stock INTEGER;
    product_active BOOLEAN;
BEGIN
    SELECT stock_quantity, is_active
    INTO current_stock, product_active
    FROM public.products
    WHERE id = NEW.product_id;
    
    IF NOT product_active THEN
        RAISE EXCEPTION 'Product is not active';
    END IF;
    
    IF current_stock < NEW.quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %', current_stock, NEW.quantity;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_stock_trigger
    BEFORE INSERT ON public.order_items
    FOR EACH ROW EXECUTE FUNCTION validate_stock_availability();