-- =============================================================================
-- STORAGE POLICIES — Permissions sur les buckets audio / covers / inspirations
-- =============================================================================
-- À exécuter dans Supabase Dashboard → SQL Editor → New query → Run
-- Prérequis : avoir créé les 3 buckets `audio`, `covers`, `inspirations`
--             dans Storage AVANT de lancer ce script.
-- Idempotent : peut être ré-exécuté sans casser l'existant.
-- =============================================================================

-- Active RLS sur storage.objects (normalement déjà actif sur Supabase)
alter table storage.objects enable row level security;

-- Helper : supprime les policies existantes pour éviter les doublons
do $$
declare r record;
begin
  for r in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'app_storage_%'
  loop
    execute format('drop policy if exists %I on storage.objects', r.policyname);
  end loop;
end $$;

-- =============================================================================
-- BUCKET : audio  (WAV, MP3, FLAC, etc.)
-- =============================================================================
create policy "app_storage_audio_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'audio');

create policy "app_storage_audio_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'audio');

create policy "app_storage_audio_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'audio')
  with check (bucket_id = 'audio');

create policy "app_storage_audio_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'audio');

-- =============================================================================
-- BUCKET : covers  (images de couverture des morceaux)
-- =============================================================================
create policy "app_storage_covers_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'covers');

create policy "app_storage_covers_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'covers');

create policy "app_storage_covers_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'covers')
  with check (bucket_id = 'covers');

create policy "app_storage_covers_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'covers');

-- =============================================================================
-- BUCKET : inspirations  (mood board)
-- =============================================================================
create policy "app_storage_inspirations_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'inspirations');

create policy "app_storage_inspirations_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'inspirations');

create policy "app_storage_inspirations_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'inspirations')
  with check (bucket_id = 'inspirations');

create policy "app_storage_inspirations_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'inspirations');

-- =============================================================================
-- Vérification
-- =============================================================================
-- Pour vérifier que les policies sont bien en place, lance ensuite :
--   select policyname, tablename from pg_policies
--   where schemaname = 'storage' and policyname like 'app_storage_%';
-- =============================================================================
