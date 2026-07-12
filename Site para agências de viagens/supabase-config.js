// ============================================================
// CONFIGURAÇÃO DO SUPABASE — preencha depois de criar o projeto
// ============================================================
// 1. Crie um projeto grátis em https://supabase.com
// 2. Vá em Settings > API e copie "Project URL" e "anon public key"
// 3. Cole os valores abaixo
// 4. Siga o arquivo SETUP-BLOG-ADMIN.md para criar a tabela, o bucket
//    de imagens e o usuário admin.
// ============================================================

export const SUPABASE_URL = "https://xdqxhhktridnaqjmqvug.supabase.co";
export const SUPABASE_ANON_KEY = "sb_publishable_0ATuhtFh8cxlHF_N0xhpQQ_5jjixk3J";

export const SUPABASE_CONFIGURED =
  SUPABASE_URL.startsWith("http") && SUPABASE_ANON_KEY.length > 20;

let _client = null;

export async function getSupabase() {
  if (_client) return _client;
  const mod = await import("https://esm.sh/@supabase/supabase-js@2");
  _client = mod.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true },
  });
  return _client;
}

export async function getProfile(supabase, userId) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export function slugify(text) {
  return (text || "")
    .toString()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}
