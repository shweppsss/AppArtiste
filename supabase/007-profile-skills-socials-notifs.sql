-- =============================================================================
-- ADD profile Phase 2A fields — skills (text[]), social_links (jsonb),
-- notifications_prefs (jsonb)
-- =============================================================================
-- À exécuter dans Supabase Dashboard → SQL Editor → New query → Run
--
-- Contexte : la page "Mon profil" Phase 2A (PR #32 — feat/profile-phase-2a)
-- écrit ces colonnes via sb.from('profiles').update({ skills, social_links,
-- notifications_prefs }). Sans la migration, les writes échouent silencieusement
-- (try/catch côté JS) — la page marche, mais les valeurs ne persistent pas
-- cross-device.
--
-- Idempotent : ré-exécutable sans erreur grâce à `IF NOT EXISTS`.
-- =============================================================================

alter table public.profiles
  add column if not exists skills text[] default '{}'::text[],
  add column if not exists social_links jsonb default '{}'::jsonb,
  add column if not exists notifications_prefs jsonb default '{
    "releases": true,
    "deadlines": true,
    "mentions": false,
    "weeklyDigest": false
  }'::jsonb;

-- Verification
-- select column_name, data_type, column_default
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'profiles'
--   and column_name in ('skills','social_links','notifications_prefs')
-- order by column_name;
