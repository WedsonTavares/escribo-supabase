-- Dados de exemplo para testes do fluxo completo
-- Substitua os UUIDs conforme necessário para corresponder ao seu ambiente

-- 1. Inserir cliente (vinculado a um user_id do auth.users)
INSERT INTO public.customers (id, user_id, name, email, phone, address)
VALUES ('11111111-1111-1111-1111-111111111111', '88e0cb44-a069-4a24-ae3c-6b9944f4d442', 'Cliente Teste', 'cliente@teste.com', '11999999999', 'Rua Exemplo, 123');

-- 2. Inserir produtos
INSERT INTO public.products (id, name, description, price_cents, stock_quantity, is_active)
VALUES
  ('33333333-3333-3333-3333-333333333333', 'Produto A', 'Descrição do Produto A', 1500, 10, true),
  ('44444444-4444-4444-4444-444444444444', 'Produto B', 'Descrição do Produto B', 2500, 5, true);

-- 3. Criar pedido
INSERT INTO public.orders (id, customer_id, status)
VALUES ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'pending');

-- 4. Adicionar itens ao pedido
INSERT INTO public.order_items (id, order_id, product_id, quantity, price_cents)
VALUES
  ('66666666-6666-6666-6666-666666666666', '55555555-5555-5555-5555-555555555555', '33333333-3333-3333-3333-333333333333', 2, 1500),
  ('77777777-7777-7777-7777-777777777777', '55555555-5555-5555-5555-555555555555', '44444444-4444-4444-4444-444444444444', 1, 2500);

-- 5. Verificar views
-- SELECT * FROM v_order_summary;
-- SELECT * FROM v_product_inventory;
-- SELECT * FROM v_customer_orders;

-- Observação: Para testar RLS, execute as queries autenticado como o usuário de user_id '22222222-2222-2222-2222-222222222222'.
-- Para testar triggers, altere itens do pedido e veja o campo total_cents do pedido ser atualizado automaticamente.

-- Para testar as Edge Functions, utilize os exemplos abaixo:
-- Envio de e-mail de confirmação:
-- POST https://ggkhlujobdizoegatxhv.supabase.co/functions/v1/sendOrderConfirmation
-- Body: { "orderId": "55555555-5555-5555-5555-555555555555" }

-- Exportação de pedidos em CSV:
-- POST https://ggkhlujobdizoegatxhv.supabase.co/functions/v1/exportOrderCsv
-- Body: { "customerId": "11111111-1111-1111-1111-111111111111" }