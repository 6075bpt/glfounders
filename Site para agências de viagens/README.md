# GL Negócios / Método G3 — Site + Blog + Área de Membros

Site institucional (landing page de alta conversão) com blog e área de
membros, usando **Supabase** como backend (autenticação, banco Postgres e
storage de imagens).

## Importante: este projeto é HTML estático, não Next.js

Os arquivos aqui são páginas estáticas (`.dc.html`) que rodam 100% no
navegador — não há servidor Node nem build step. Isso significa:

- **Sem servidor:** não existe *middleware* de servidor de verdade. A proteção
  de rota acontece em duas camadas, que juntas são equivalentes em segurança:
  1. **No cliente:** cada página protegida (`Dashboard.dc.html`, `Admin.dc.html`)
     verifica a sessão do Supabase ao carregar e redireciona/bloqueia quem não
     está logado ou não tem o papel certo.
  2. **No banco (a proteção real):** todas as tabelas têm **Row Level Security
     (RLS)** — mesmo que alguém manipule o JavaScript do navegador, o Postgres
     recusa qualquer leitura/escrita que a política não permitir. Isso é o que
     de fato impede acesso não autorizado, com ou sem servidor.
- **Variáveis de ambiente:** como não há build do Next.js para "injetar"
  `NEXT_PUBLIC_...` em tempo de compilação, as credenciais do Supabase vivem em
  `supabase-config.js` (arquivo próprio do projeto, não versionado como
  segredo real — é a *anon public key*, feita para ser exposta no navegador).
  Os nomes abaixo seguem a convenção pedida, para o caso de você migrar este
  projeto para Next.js no futuro:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`

## 1. Criar o projeto no Supabase

1. Acesse [supabase.com](https://supabase.com) → **New project**.
2. Em **Settings → API**, copie:
   - **Project URL**
   - **anon public key**

## 2. Rodar o schema do banco

1. Abra **SQL Editor** no Supabase.
2. Copie todo o conteúdo de `supabase-schema.sql` deste projeto e execute.
   Isso cria:
   - `profiles` (usuário + papel `admin`/`user`, criado automaticamente no cadastro)
   - `categories` (categorias do blog)
   - `posts` (artigos: título, slug, conteúdo, capa, categoria, SEO, status)
   - `uploads` (histórico de imagens enviadas)
   - Função `is_admin()` e todas as políticas de RLS
   - Policies do bucket de imagens

## 3. Criar o bucket de imagens

1. **Storage → New bucket** → nome `blog-images` → marque **Public bucket**.
2. As policies de leitura/upload/exclusão já foram criadas pelo script SQL.

## 4. Conectar o projeto

Edite `supabase-config.js` e cole os dois valores do passo 1:

```js
export const SUPABASE_URL = "https://xxxxx.supabase.co";
export const SUPABASE_ANON_KEY = "eyJhbGciOi...";
```

## 5. Criar o primeiro administrador

1. Acesse `/Login.dc.html` → aba **Cadastrar** → crie sua conta normalmente.
2. No Supabase, vá em **SQL Editor** e rode (trocando o e-mail):
   ```sql
   update public.profiles set role = 'admin' where email = 'seu-email@exemplo.com';
   ```
3. Pronto — esse usuário agora enxerga o link "Abrir painel administrativo"
   no `/Dashboard.dc.html` e tem acesso liberado em `/Admin.dc.html`.
   Qualquer outro cadastro novo entra como `user` (área de membros comum).

## Páginas do projeto

| Página | Rota | Acesso |
|---|---|---|
| Landing page | `GL Metodo G3.dc.html` | pública |
| Blog (lista) | `Blog.dc.html` | pública (só posts `published`) |
| Artigo | `BlogPost.dc.html?slug=...` | pública |
| Login / Cadastro / Recuperar senha | `Login.dc.html` | pública |
| Nova senha (link do e-mail) | `ResetPassword.dc.html` | pública, exige token válido |
| Dashboard do usuário | `Dashboard.dc.html` | autenticado |
| Painel administrativo do blog | `Admin.dc.html` | autenticado + `role = 'admin'` |

## Deploy no Vercel

Este projeto já foi importado/publicado como site estático. Para reimportar
manualmente:

1. Suba a pasta do projeto (ou use a integração já configurada).
2. Nenhuma variável de ambiente precisa ser configurada no painel do Vercel —
   as credenciais já estão em `supabase-config.js` (chave pública, protegida
   por RLS, é seguro que fique no bundle do cliente).
3. Depois de configurar `supabase-config.js`, `supabase-schema.sql` e o bucket
   `blog-images`, o site fica 100% funcional em produção.

## Estrutura de dados

- **profiles**: `id, email, full_name, role, created_at`
- **categories**: `id, name, slug, created_at`
- **posts**: `id, title, slug, content, cover_image_url, category, category_id,
  meta_title, meta_description, status, author_id, created_at, updated_at,
  published_at`
- **uploads**: `id, path, url, uploaded_by, created_at`

## Segurança (RLS resumido)

- Qualquer pessoa pode **ler** posts com `status = 'published'` e todas as
  `categories`.
- Só usuários com `profiles.role = 'admin'` podem criar, editar, apagar e
  publicar posts, gerenciar categorias e subir/apagar imagens no bucket
  `blog-images`.
- Cada usuário só lê o próprio `profile`; admins leem todos.
