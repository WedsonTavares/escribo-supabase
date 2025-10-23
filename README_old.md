# Backend E-commerce com Supabase

## Visão geral
Este projeto implementa o backend de um sistema e-commerce com foco em segurança, eficiência e clareza.  
As principais funcionalidades: tabelas para clientes, produtos, pedidos; Row-Level Security (RLS); funções automáticas; views para consulta eficiente; Edge Functions para envio de e-mail de confirmação e exportação de CSV.

## Tecnologias e versões
- PostgreSQL (via Supabase)  
- Supabase CLI (usado via `npx supabase`)  
- Edge Functions com Deno (v2.x)  
- Node.js (v22.x) & npm (v10.x) para ambiente local  
- Docker (v28.x) para stack local, se necessário  

## Instalação e configuração
1. Clone o repositório:  
   ```bash
   git clone git@github.com:WedsonTavares/escribo-supabase.git
   cd escribo-supabase

