-- ============================================================
-- SCHEMA GL Negócios / Método G3 — Blog + Auth + Roles
-- Rode este arquivo inteiro no SQL Editor do Supabase.
-- ============================================================

-- Extensão para gerar uuids (o Supabase já vem com ela na maioria dos projetos)
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- PROFILES — um perfil por usuário autenticado, com o papel dele
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'user', -- 'admin' ou 'user'
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- função auxiliar (security definer) para checar se o usuário logado é admin
-- sem cair em recursão de RLS
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create policy "profiles: user reads own" on public.profiles
  for select using (auth.uid() = id);

create policy "profiles: admin reads all" on public.profiles
  for select to authenticated using (public.is_admin());

create policy "profiles: admin updates roles" on public.profiles
  for update to authenticated using (public.is_admin());

-- cria o profile automaticamente quando um usuário se cadastra
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    'user'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ------------------------------------------------------------
-- CATEGORIES — categorias do blog
-- ------------------------------------------------------------
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  created_at timestamptz not null default now()
);

alter table public.categories enable row level security;

create policy "categories: public read" on public.categories
  for select using (true);

create policy "categories: admin write" on public.categories
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- POSTS — artigos do blog
-- ------------------------------------------------------------
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text unique not null,
  content text not null default '',
  cover_image_url text,
  category text,               -- nome livre (compatível com o painel atual)
  category_id uuid references public.categories(id), -- opcional, se quiser vincular à tabela categories
  meta_title text,
  meta_description text,
  status text not null default 'draft', -- 'draft' ou 'published'
  author_id uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz
);

alter table public.posts enable row level security;

create policy "posts: public read published" on public.posts
  for select using (status = 'published');

create policy "posts: admin read all" on public.posts
  for select to authenticated using (public.is_admin());

create policy "posts: admin insert" on public.posts
  for insert to authenticated with check (public.is_admin());

create policy "posts: admin update" on public.posts
  for update to authenticated using (public.is_admin());

create policy "posts: admin delete" on public.posts
  for delete to authenticated using (public.is_admin());

-- ------------------------------------------------------------
-- UPLOADS — histórico de imagens enviadas (Storage)
-- ------------------------------------------------------------
create table if not exists public.uploads (
  id uuid primary key default gen_random_uuid(),
  path text not null,
  url text not null,
  uploaded_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.uploads enable row level security;

create policy "uploads: admin all" on public.uploads
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- STORAGE BUCKET — crie manualmente em Storage > New bucket:
--   nome: blog-images   |   marcar como Public bucket
-- Depois rode as policies abaixo no SQL Editor:
-- ------------------------------------------------------------
create policy "blog-images: public read"
  on storage.objects for select
  using (bucket_id = 'blog-images');

create policy "blog-images: admin upload"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'blog-images' and public.is_admin());

create policy "blog-images: admin delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'blog-images' and public.is_admin());

-- ------------------------------------------------------------
-- CRIAR O PRIMEIRO ADMINISTRADOR
-- 1. Cadastre-se normalmente pela página /Login.dc.html (aba "Cadastrar").
-- 2. Depois rode este UPDATE trocando o e-mail:
-- ------------------------------------------------------------
-- update public.profiles set role = 'admin' where email = 'seu-email@exemplo.com';
