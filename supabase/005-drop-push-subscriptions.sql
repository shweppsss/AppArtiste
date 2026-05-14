-- =============================================================================
-- DROP push_subscriptions table — push notification subsystem removed
-- =============================================================================
-- À exécuter dans Supabase Dashboard → SQL Editor → New query → Run
--
-- Contexte : le système de push notifications reposait sur un Database Webhook
-- qui devait fire sur chaque INSERT dans la table `notifications`. Mais le
-- frontend stocke tout dans `workspace.state` (JSONB) et n'INSERT jamais dans
-- `notifications` → le webhook ne fire jamais → send-push edge function
-- jamais invoquée. Tout le subsystem était dead code.
--
-- Cette migration :
--   1. Drop la table push_subscriptions (et ses policies)
--   2. À faire MANUELLEMENT après : supprimer l'Edge Function send-push depuis
--      Supabase Dashboard → Edge Functions → send-push → Delete
--   3. À faire MANUELLEMENT après : supprimer le Database Webhook s'il existe,
--      depuis Database → Webhooks
--
-- Idempotent : peut être ré-exécuté.
-- =============================================================================

-- Policies sont automatiquement supprimées avec DROP TABLE CASCADE
drop table if exists public.push_subscriptions cascade;

-- Vérification
-- select count(*) from pg_tables where tablename = 'push_subscriptions';
-- → doit retourner 0
