-- =============================================================================
-- ADD profile extra fields — bio, phone, specialty, avatar_path, activity_visibility
-- =============================================================================
-- À exécuter dans Supabase Dashboard → SQL Editor → New query → Run
--
-- Contexte : la page "Mon profil" (PR #31 — feat/user-profile-page) écrit
-- ces colonnes via sb.from('profiles').update({ ... }). Sans la migration
-- les writes échouent silencieusement (try/catch côté JS) — la page marche,
-- mais les valeurs ne persistent pas cross-device.
--
-- Idempotent : ré-exécutable sans erreur grâce à `IF NOT EXISTS`.
-- =============================================================================

alter table public.profiles
  add column if not exists bio text,
  add column if not exists phone text,
  add column if not exists specialty text,
  add column if not exists avatar_path text,
  add column if not exists activity_visibility text default 'team';

-- Verification
-- select column_name, data_type, column_default
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'profiles'
--   and column_name in ('bio','phone','specialty','avatar_path','activity_visibility')
-- order by column_name;
