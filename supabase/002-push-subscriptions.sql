-- =============================================================================
-- NONAME × DEGZZY — Push notifications : table push_subscriptions
-- =============================================================================
-- Pourquoi une table dédiée plutôt qu'une colonne push_token dans team_members ?
--   • Un user a souvent plusieurs devices (iPhone + MacBook + iPad).
--   • Chaque device génère sa propre subscription (endpoint unique).
--   • Si on stockait dans team_members.push_token, on écraserait à chaque nouveau device.
--   • Avec une table dédiée, chaque device a sa row, le fan-out push couvre tous les devices.
-- =============================================================================

create table if not exists public.push_subscriptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  endpoint   text not null,                            -- URL unique du service de push (FCM, APNs, Mozilla, etc.)
  p256dh     text not null,                            -- clé publique ECDH (chiffrement)
  auth_key   text not null,                            -- secret d'auth (chiffrement)
  user_agent text,                                     -- pour debug ("iPhone Safari iOS 17.4")
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Anti-duplicate : un même device ne s'inscrit qu'une fois par user
  unique (user_id, endpoint)
);

create index if not exists push_subscriptions_user_id_idx on public.push_subscriptions (user_id);


-- =============================================================================
-- RLS — chaque user gère uniquement SES subscriptions
-- =============================================================================
alter table public.push_subscriptions enable row level security;

drop policy if exists "push_subs_select_own" on public.push_subscriptions;
drop policy if exists "push_subs_insert_own" on public.push_subscriptions;
drop policy if exists "push_subs_update_own" on public.push_subscriptions;
drop policy if exists "push_subs_delete_own" on public.push_subscriptions;

create policy "push_subs_select_own"
  on public.push_subscriptions for select
  to authenticated using (auth.uid() = user_id);
create policy "push_subs_insert_own"
  on public.push_subscriptions for insert
  to authenticated with check (auth.uid() = user_id);
create policy "push_subs_update_own"
  on public.push_subscriptions for update
  to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "push_subs_delete_own"
  on public.push_subscriptions for delete
  to authenticated using (auth.uid() = user_id);

-- Note : l'Edge Function `send-push` utilise la service_role key, qui bypass RLS.
-- Elle peut donc lire toutes les subscriptions pour fan-out.


-- =============================================================================
-- (Optionnel) Cleanup : supprimer les subscriptions expirées
-- =============================================================================
-- Quand Web Push retourne 410 Gone, on supprime la sub côté Edge Function.
-- Tu peux aussi planifier un cron pour nettoyer les subs inactives > 90 jours :
-- delete from public.push_subscriptions where updated_at < now() - interval '90 days';
