-- =============================================================================
-- STORAGE POLICIES — Permissions sur les buckets audio / covers / inspirations / clips / capsules
-- =============================================================================
-- À exécuter dans Supabase Dashboard → SQL Editor → New query → Run
-- Prérequis : avoir créé les 5 buckets `audio`, `covers`, `inspirations`,
--             `clips`, `capsules` dans Storage AVANT de lancer ce script.
-- Idempotent : peut être ré-exécuté sans casser l'existant.
-- =============================================================================

-- Note : RLS est déjà actif par défaut sur storage.objects sur Supabase.
-- On NE peut PAS faire `alter table storage.objects` depuis le SQL Editor
-- (la table appartient à supabase_storage_admin, on aurait ERROR 42501).
-- On se contente de drop+create les policies, ce qui est autorisé.

-- Cleanup : drop les policies créées par ce script si elles existent déjà
drop policy if exists "app_storage_audio_select"        on storage.objects;
drop policy if exists "app_storage_audio_insert"        on storage.objects;
drop policy if exists "app_storage_audio_update"        on storage.objects;
drop policy if exists "app_storage_audio_delete"        on storage.objects;
drop policy if exists "app_storage_covers_select"       on storage.objects;
drop policy if exists "app_storage_covers_insert"       on storage.objects;
drop policy if exists "app_storage_covers_update"       on storage.objects;
drop policy if exists "app_storage_covers_delete"       on storage.objects;
drop policy if exists "app_storage_inspirations_select" on storage.objects;
drop policy if exists "app_storage_inspirations_insert" on storage.objects;
drop policy if exists "app_storage_inspirations_update" on storage.objects;
drop policy if exists "app_storage_inspirations_delete" on storage.objects;
drop policy if exists "app_storage_clips_select"        on storage.objects;
drop policy if exists "app_storage_clips_insert"        on storage.objects;
drop policy if exists "app_storage_clips_update"        on storage.objects;
drop policy if exists "app_storage_clips_delete"        on storage.objects;
drop policy if exists "app_storage_capsules_select"     on storage.objects;
drop policy if exists "app_storage_capsules_insert"     on storage.objects;
drop policy if exists "app_storage_capsules_update"     on storage.objects;
drop policy if exists "app_storage_capsules_delete"     on storage.objects;

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
-- BUCKET : clips  (vidéos courtes — TikTok, Reels, teasers)
-- =============================================================================
create policy "app_storage_clips_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'clips');

create policy "app_storage_clips_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'clips');

create policy "app_storage_clips_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'clips')
  with check (bucket_id = 'clips');

create policy "app_storage_clips_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'clips');

-- =============================================================================
-- BUCKET : capsules  (formats long — interviews, BTS, documentaires)
-- =============================================================================
create policy "app_storage_capsules_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'capsules');

create policy "app_storage_capsules_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'capsules');

create policy "app_storage_capsules_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'capsules')
  with check (bucket_id = 'capsules');

create policy "app_storage_capsules_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'capsules');

-- =============================================================================
-- Vérification
-- =============================================================================
-- Pour vérifier que les policies sont bien en place, lance ensuite :
--   select policyname, tablename from pg_policies
--   where schemaname = 'storage' and policyname like 'app_storage_%';
-- =============================================================================
