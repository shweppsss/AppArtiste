-- =============================================================================
-- ADD activity_log table — real audit feed for the profile "Activité récente"
-- section (Phase 2B-1, PR #34 — feat/profile-phase-2b1).
-- =============================================================================
-- À exécuter dans Supabase Dashboard → SQL Editor → New query → Run
--
-- Contexte : la section "Activité récente" du profil dérivait jusque-là ses
-- entrées du state local (todos terminées + events créés). Elle ne voyait
-- donc que le périmètre que le user avait déjà chargé. Cette table devient
-- la source de vérité — toute action significative y est journalisée.
--
-- Schéma volontairement maigre :
--   user_id       qui a fait l'action
--   kind          'todo_done' | 'todo_created' | 'event_created' | 'event_updated' | 'profile_updated'
--   subject_id    id du todo / event affecté (texte, pour rester souple)
--   subject_title snapshot du titre au moment de l'action — résilient si l'objet est supprimé après
--   metadata      jsonb libre pour contexte additionnel (priority, type d'event, etc.)
--   created_at    horodatage
--
-- RLS : tous les users authentifiés peuvent lire (audit d'équipe transparent).
-- INSERT : seulement pour son propre user_id.
-- =============================================================================

create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  subject_id text,
  subject_title text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Index for the common query: latest N entries for a given user.
create index if not exists activity_log_user_created_at_idx
  on public.activity_log (user_id, created_at desc);

-- Index for team-wide feeds (future Phase 2B-2 dashboard widget).
create index if not exists activity_log_created_at_idx
  on public.activity_log (created_at desc);

alter table public.activity_log enable row level security;

-- Policies — drop-and-recreate pattern so this migration stays idempotent.
drop policy if exists "activity_log read all authenticated" on public.activity_log;
create policy "activity_log read all authenticated"
  on public.activity_log
  for select
  to authenticated
  using (true);

drop policy if exists "activity_log insert own" on public.activity_log;
create policy "activity_log insert own"
  on public.activity_log
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Verification
-- select kind, count(*) from public.activity_log group by 1 order by 2 desc;
