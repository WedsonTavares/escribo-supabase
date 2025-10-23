# Backend E-commerce com Supabase

## Visão Geral
Este projeto implementa o backend de um sistema e-commerce utilizando Supabase com foco em segurança, eficiência e clareza. As principais funcionalidades incluem:

- **Tabelas relacionais**: customers, products, orders, order_items
- **Row-Level Security (RLS)**: Políticas de segurança para acesso restrito aos dados
- **Funções automáticas**: Triggers para cálculo de totais e atualização de timestamps
- **Views otimizadas**: Consultas eficientes para relatórios e dashboards
- **Edge Functions**: Automação para envio de e-mails e exportação de dados
- **Validações**: Controle de estoque e validação de dados

## Tecnologias e Versões
- **PostgreSQL** (via Supabase Cloud)
- **Supabase CLI** v2.x (usado via `npx supabase`)
- **Edge Functions** com Deno v2.x
- **Node.js** v22.x & npm v10.x para ambiente local
- **TypeScript** para Edge Functions

## Instalação e Configuração

### 1. Clone o repositório
```bash
git clone git@github.com:WedsonTavares/escribo-supabase.git
cd escribo-supabase
```

### 2. Instalar dependências
```bash
npm install
```

### 3. Configurar variáveis de ambiente
1. Copie o arquivo `.env` e configure com os valores do seu projeto Supabase:
```bash
cp .env .env.local
```

2. No dashboard do Supabase, obtenha:
   - **SUPABASE_URL**: URL do projeto (https://ggkhlujobdizoegatxhv.supabase.co)
   - **SUPABASE_SERVICE_ROLE_KEY**: Chave de serviço (Settings → API)
   - **SUPABASE_ANON_KEY**: Chave anônima (Settings → API)

### 4. Autenticar com Supabase CLI
```bash
# Gere um Access Token
npx supabase login 

  -**Isso abre o navegador para você entrar na sua conta do Supabase e autoriza a CLI.
  -**Se o navegador não abrir, a CLI mostra uma URL para você copiar/colar.

```

### 5. Vincular projeto local ao remoto
```bash
npx supabase link --project-ref ggkhlujobdizoegatxhv
```

### 6. Aplicar migrations (criar schema)
```bash
npx supabase db push
```

### 7. Deploy das Edge Functions
```bash
# Defina os segredos das funções (lê do seu .env atual)
npx supabase secrets set \
  SUPABASE_URL=$SUPABASE_URL \
  SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY \
  MAIL_API_URL=$MAIL_API_URL \
  MAIL_API_KEY=$MAIL_API_KEY

npx supabase functions deploy sendOrderConfirmation
npx supabase functions deploy exportOrderCsv
```

Nota: se a CLI exibir mensagens como "Env name cannot start with SUPABASE_", defina os segredos pelo Dashboard (Settings → Functions → Secrets) e publique novamente.

### Segurança de chaves e arquivos

- Não versione nem envie para repositórios públicos o arquivo `.env` com chaves reais.
- Se o arquivo `.env` já foi comitado, remova-o e rode a rotação das chaves no dashboard (veja instruções abaixo).
- Preferência: defina segredos das Edge Functions no Dashboard (Settings → API → Secrets) ou use `npx supabase secrets set` com nomes que não comecem por `SUPABASE_` (a CLI bloqueia algumas varáveis por segurança).

Se precisar remover o `.env` já comitado e limpar do histórico do git (faça com cuidado):

```bash
# remove from git and keep local
git rm --cached .env
echo ".env" >> .gitignore
git commit -m "chore: remove .env from repo and ignore"

# to wipe from history (optional, destructive) - replace with your own caution message
# git filter-branch --force --index-filter "git rm --cached --ignore-unmatch .env" --prune-empty --tag-name-filter cat -- --all
```


## Estrutura do Banco de Dados

### Tabelas Principais
- **customers**: Dados dos clientes (vinculados a auth.users)
- **products**: Catálogo de produtos com controle de estoque
- **orders**: Pedidos com status e totais calculados automaticamente
- **order_items**: Itens dos pedidos com validação de estoque

### Views Disponíveis
- **v_order_summary**: Resumo dos pedidos com dados do cliente
- **v_product_inventory**: Inventário com vendas totalizadas
- **v_customer_orders**: Pedidos completos por cliente com itens

### Funcionalidades Automáticas
- **Cálculo de totais**: Trigger atualiza `total_cents` automaticamente
- **Timestamps**: `updated_at` atualizado em modificações
- **Validação de estoque**: Impede venda de produtos sem estoque
- **RLS**: Segurança por linha garantindo acesso apenas aos próprios dados

## API das Edge Functions

### 1. Envio de E-mail de Confirmação
**Endpoint**: `https://ggkhlujobdizoegatxhv.supabase.co/functions/v1/sendOrderConfirmation`

**Método**: POST
```json
{
  "orderId": "uuid-do-pedido"
}
```

**Resposta**:
```json
{
  "success": true,
  "message": "Order confirmation email sent successfully",
  "orderId": "uuid-do-pedido",
  "emailSent": true
}
```

Exemplo (curl) com autorização:

```bash
curl -X POST \
  'https://ggkhlujobdizoegatxhv.supabase.co/functions/v1/sendOrderConfirmation' \
  -H 'Authorization: Bearer <SEU_JWT_ANON_OU_DE_USUÁRIO>' \
  -H 'Content-Type: application/json' \
  -d '{"orderId":"55555555-5555-5555-5555-555555555555"}'
```

### 2. Exportação de Pedidos em CSV
**Endpoint**: `https://ggkhlujobdizoegatxhv.supabase.co/functions/v1/exportOrderCsv`

**Método**: POST
```json
{
  "customerId": "uuid-do-cliente",
  "startDate": "2024-01-01", 
  "endDate": "2024-12-31"     
}
```

**Resposta**: Arquivo CSV com os pedidos do cliente

Exemplo (curl) com autorização:

```bash
curl -X POST \
  'https://ggkhlujobdizoegatxhv.supabase.co/functions/v1/exportOrderCsv' \
  -H 'Authorization: Bearer <SEU_JWT_ANON_OU_DE_USUÁRIO>' \
  -H 'Content-Type: application/json' \
  -d '{"customerId":"11111111-1111-1111-1111-111111111111"}'
```

### Autorização
As funções exigem o cabeçalho `Authorization: Bearer <JWT>` (pode ser o `anon` para testes). Sem ele, a resposta será 401 (Missing authorization header). Em produção, prefira JWTs de usuários autenticados.

## Testes e Desenvolvimento

### Fluxo de Teste Completo
1. **Criar cliente** (vinculado a um user_id do auth.users)
2. **Inserir produtos** com estoque disponível
3. **Criar pedido** e adicionar itens
4. **Verificar cálculo automático** do total
5. **Testar envio de e-mail** via Edge Function
6. **Testar exportação CSV** com filtros de data
7. **Validar RLS** - usuários só acessam próprios dados

### Comandos Úteis
```bash
# Verificar status do projeto
npx supabase status

# Reset do banco local (se estiver usando stack local)
npx supabase db reset

# Logs das Edge Functions
npx supabase functions serve --debug

# Verificar diferenças no schema
npx supabase db diff
```

## Segurança (RLS)
### Tipos de chaves e tokens
- `sbp_...` (Publishable): uso em frontend. Não serve para deploy CLI.  
- `Anon Key`: JWT anônimo para clientes.  
- `Service Role Key`: JWT privilegiado para backend/Edge Functions.  
- `Access Token (CLI)`: autentica a CLI para `link`, `db push`, `functions deploy`.  


O sistema implementa Row-Level Security com as seguintes políticas:

- **Customers**: Usuários só acessam seus próprios dados
- **Orders**: Apenas pedidos do próprio cliente são visíveis
- **Order Items**: Restrito aos itens dos pedidos do usuário
- **Products**: Todos podem ver produtos ativos (leitura pública)

## Performance

Índices criados para otimização:
- `customers(user_id, email)`
- `products(is_active)`
- `orders(customer_id, status)`
- `order_items(order_id, product_id)`

## Integração com IA (Próximos Passos)

### Funcionalidades Planejadas
- **Recomendações de produtos**: ML baseado no histórico de compras
- **Análise de sentimento**: Avaliação automática de reviews
- **Otimização de estoque**: Previsão de demanda com IA
- **Chatbot inteligente**: Suporte ao cliente automatizado
- **Detecção de fraudes**: Análise de padrões suspeitos

### Implementação Sugerida
```typescript
// Exemplo de Edge Function para recomendações
const { data } = await supabase
  .from('v_customer_orders')
  .select('*')
  .eq('customer_id', customerId)

const recommendations = await openai.chat.completions.create({
  model: "gpt-4",
  messages: [{
    role: "user",
    content: `Baseado no histórico: ${JSON.stringify(data)}, recomende produtos similares`
  }]
})
```

## Licença
MIT License - Desenvolvido para teste técnico Escribo

## Contato
**Desenvolvedor**: Wedson Tavares  
**Email**: [seu-email]  
**GitHub**: https://github.com/WedsonTavares/escribo-supabase