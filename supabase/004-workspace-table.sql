-- =============================================================================
-- WORKSPACE — Table de synchronisation du state global (JSONB)
-- =============================================================================
-- À coller dans Supabase Dashboard → SQL Editor → New query → Run
-- Idempotent : peut être ré-exécuté sans casser l'existant.
-- =============================================================================

create table if not exists public.workspace (
  id          text primary key,
  state       jsonb,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references auth.users(id) on delete set null
);

alter table public.workspace enable row level security;

-- Workspace partagé : tout utilisateur authentifié peut lire et écrire.
drop policy if exists "workspace_select_authenticated" on public.workspace;
create policy "workspace_select_authenticated" on public.workspace
  for select to authenticated using (true);

drop policy if exists "workspace_modify_authenticated" on public.workspace;
create policy "workspace_modify_authenticated" on public.workspace
  for all to authenticated using (true) with check (true);

-- Realtime — pour que les autres clients reçoivent les changements en direct.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'workspace'
  ) then
    alter publication supabase_realtime add table public.workspace;
  end if;
end $$;
