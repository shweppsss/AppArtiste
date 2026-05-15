-- =============================================================================
-- ADD user_badges table — earned-achievement records (Phase 2B-2, PR #37
-- — feat/badges-system).
-- =============================================================================
-- À exécuter dans Supabase Dashboard → SQL Editor → New query → Run
--
-- Une rangée par (user, badge). Le catalogue de badges est défini côté frontend
-- dans BADGES_CATALOG (data-driven) — la DB ne stocke que la liste de ceux
-- effectivement gagnés. Cela permet d'ajouter de nouveaux badges sans toucher
-- au schéma.
--
-- RLS :
--   SELECT — tous les users authentifiés (badges sont publics côté team)
--   INSERT — seulement pour ses propres badges (auth.uid() = user_id)
-- =============================================================================

create table if not exists public.user_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id text not null,
  earned_at timestamptz not null default now(),
  unique (user_id, badge_id)
);

create index if not exists user_badges_user_idx
  on public.user_badges (user_id, earned_at desc);

alter table public.user_badges enable row level security;

drop policy if exists "user_badges read all authenticated" on public.user_badges;
create policy "user_badges read all authenticated"
  on public.user_badges
  for select
  to authenticated
  using (true);

drop policy if exists "user_badges insert own" on public.user_badges;
create policy "user_badges insert own"
  on public.user_badges
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Verification
-- select user_id, badge_id, earned_at from public.user_badges order by earned_at desc limit 20;
