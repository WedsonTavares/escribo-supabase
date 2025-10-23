# Documento Interno — Ambiente de Desenvolvimento

## Versões usadas
- Node.js: v22.x  
- npm: v10.x  
- Deno: v2.x  
- Docker: 28.x  
- Supabase CLI: (usando via `npx supabase` ou instalado globalmente)

## Comandos principais do CLI
- `npx supabase --version` — verifica a versão da CLI  
- `npx supabase init` — inicializa projeto local (opcional)  
- `npx supabase link --project-ref <projeto_ref>` — vincula ao projeto remoto  
- `npx supabase db push` — aplica migrations no banco remoto  
- `npx supabase functions deploy <nome_função>` — deploy de Edge Function  
- `npx supabase start` — inicia stack local com Docker (se estiver usando)

### Autenticação da CLI (Access Token)
Para executar `link`, `db push` e `functions deploy`, é necessário um Access Token da CLI:

1. No painel do Supabase → Account Settings → Access Tokens → Generate New Token.  
2. Faça login na CLI:  
  `npx supabase login --token <SEU_ACCESS_TOKEN>`
3. Opcional: exporte a variável de ambiente para não precisar informar sempre:  
  `export SUPABASE_ACCESS_TOKEN=<SEU_ACCESS_TOKEN>`

## Procedimento de migração & deploy
1. Execute `npx supabase link --project-ref <seu_ref>`  
2. Execute `npx supabase db push` para aplicar schema  
3. Verifique no dashboard do Supabase que tabelas, views, RLS estão criadas  
4. Implemente/adicione funções no diretório `supabase/functions/`  
5. Execute `npx supabase functions deploy sendOrderConfirmation`  
6. Execute `npx supabase functions deploy exportOrderCsv`

### Segredos (variáveis de ambiente das Functions)
As Edge Functions usam variáveis de ambiente definidas como segredos do projeto:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `MAIL_API_URL` (opcional)
- `MAIL_API_KEY` (opcional)

Defina com a CLI (ex.: lendo do `.env`):

`npx supabase secrets set SUPABASE_URL=$SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY MAIL_API_URL=$MAIL_API_URL MAIL_API_KEY=$MAIL_API_KEY`

## Testes de verificação rápida
- Inserir cliente, produto, pedido + itens → ver se `total_cents` atualiza  
- Ler view `v_order_summary` ou `v_product_inventory`  
- Chamar endpoint da função de e-mail com `{ "orderId": <id> }`  
- Chamar endpoint da função de CSV com `{ "customerId": "<uuid>" }`  
- Verificar que usuário diferente **não** acessa dados de outro cliente (RLS)

## Notas de segurança
- A chave `SUPABASE_SERVICE_ROLE_KEY` **não** deve estar em arquivos versionados  
- RLS ativado em tabelas `customers`, `orders`, `order_items`, `products`  
- Índices criados para colunas de filtro (customer_id, order_id, is_active) para desempenho  
  :contentReference[oaicite:2]{index=2}

### Tipos de credenciais
- `Publishable Key (sbp_...)`: uso em frontend; não funciona para deploy da CLI.  
- `Anon Key`: JWT de acesso anônimo; uso em frontend autenticado.  
- `Service Role Key`: JWT com privilégios elevados; uso apenas em backend/Edge Functions.  
- `Access Token (CLI)`: token da conta para autenticar a CLI (login/link/deploy).  

## Nota de segurança rápida

- As chaves sensíveis (especialmente `SUPABASE_SERVICE_ROLE_KEY`) não devem ser comitadas no repositório.
- Se quaisquer chaves foram acidentalmente expostas (por exemplo, `.env` comitado), gere novas chaves no Dashboard e revogue as antigas o quanto antes.
- As Edge Functions devem ler segredos do ambiente de execução configurado no Dashboard (Settings → Functions → Secrets) ou via `npx supabase secrets set` quando possível. Observe que a CLI pode recusar variáveis cujo nome comece com `SUPABASE_` por proteção; neste caso use o Dashboard.
- Para testes locais, use `.env.local` e `.env.example`. Nunca inclua `.env.local` no controle de versão.

Próximo passo recomendado antes de PR/entrega:
- Verifique que `.env` não está no repositório (git status) e que `.env.example` contém apenas placeholders.
- Documente quais chaves devem ser criadas no Dashboard para o deploy (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, MAIL_API_URL, MAIL_API_KEY).



