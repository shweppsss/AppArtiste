-- =============================================================================
-- NONAME × DEGZZY — Migration vers architecture relationnelle v1
-- =============================================================================
-- Cible : Supabase (PostgreSQL 15+)
-- Mode d'emploi : copier-coller intégralement dans le SQL Editor Supabase
--                 (Dashboard → SQL Editor → New query → Run).
-- Idempotent : peut être ré-exécuté sans casser l'existant (IF NOT EXISTS partout).
--
-- Ce script crée :
--   • 5 tables métier (tracks, todos, events, inspirations, team_members)
--   • 1 table notifications + son type enum
--   • Audit fields automatiques (created_by, updated_by, created_at, updated_at)
--   • RLS activée + policies (workspace partagé, notifs privées)
--   • Triggers de notification automatique (insert event, todo urgent, todo done, etc.)
--   • Activation realtime sur chaque table
--
-- À NOTER :
--   • La table `profiles` est supposée déjà exister (créée lors du setup Supabase
--     initial). Si non, voir le bloc "PRÉREQUIS" plus bas.
--   • Multi-workspace : ce script gère UN seul workspace implicite. Pour passer
--     multi-projet plus tard : ajouter une table `workspaces` + colonne
--     `workspace_id` sur chaque table métier + filtrer RLS dessus.
-- =============================================================================


-- =============================================================================
-- 0. EXTENSIONS
-- =============================================================================
create extension if not exists "pgcrypto";  -- pour gen_random_uuid()


-- =============================================================================
-- 1. PRÉREQUIS — table `profiles`
-- =============================================================================
-- Si `profiles` n'existe pas encore (improbable d'après le récap projet), le bloc
-- ci-dessous la crée. Sinon il ne fait rien.
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  name        text,
  role        text,
  avatar_url  text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Si la table profiles existait déjà sans ces colonnes (cas typique après setup
-- Supabase initial), les ajoute proprement sans casser l'existant.
alter table public.profiles add column if not exists is_active  boolean not null default true;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists email      text;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_authed" on public.profiles;
create policy "profiles_select_authed"
  on public.profiles for select
  to authenticated using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
  on public.profiles for insert
  to authenticated with check (auth.uid() = id);


-- =============================================================================
-- 2. FONCTIONS UTILITAIRES
-- =============================================================================

-- 2.1 Audit fields — alimente created_by / updated_by / created_at / updated_at
--     automatiquement et empêche le client de les usurper.
create or replace function public.tg_set_audit_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    -- auth.uid() peut être null si appelé par service_role (jobs serveur)
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.updated_by := coalesce(auth.uid(), new.updated_by);
    new.created_at := coalesce(new.created_at, now());
    new.updated_at := now();
  elsif tg_op = 'UPDATE' then
    -- updated_by = qui édite. created_by/created_at restent figés.
    new.updated_by := coalesce(auth.uid(), new.updated_by);
    new.updated_at := now();
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;


-- 2.2 — notify_other_users est défini plus bas (section 9.5), APRÈS la création
--      du type `notification_type` et de la table `notifications` dont il dépend.
--      PostgreSQL valide les types de paramètres à la création de la fonction,
--      donc l'ordre compte.


-- =============================================================================
-- 3. TABLE : tracks
-- =============================================================================
create table if not exists public.tracks (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  release_date  date,
  status        text not null default 'projet',  -- 'projet', 'single', 'archived'
  bpm           text,
  duration      text,
  feat          text,
  notes         text,
  cover_url     text,   -- pour fichiers lourds : Supabase Storage + URL ici
  audio_url     text,
  position      int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid references auth.users(id) on delete set null,
  updated_by    uuid references auth.users(id) on delete set null
);

drop trigger if exists tg_tracks_audit on public.tracks;
create trigger tg_tracks_audit
  before insert or update on public.tracks
  for each row execute function public.tg_set_audit_fields();

create index if not exists tracks_release_date_idx on public.tracks (release_date);
create index if not exists tracks_status_idx       on public.tracks (status);
create index if not exists tracks_position_idx     on public.tracks (position);


-- =============================================================================
-- 4. TABLE : todos
-- =============================================================================
create table if not exists public.todos (
  id            uuid primary key default gen_random_uuid(),
  text          text not null,
  category      text,                       -- 'Pre-Launch', 'Rollout', 'Pivot', etc.
  urgent        boolean not null default false,
  done          boolean not null default false,
  due           date,
  assignee_id   uuid references auth.users(id) on delete set null,
  notes         text,
  position      int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid references auth.users(id) on delete set null,
  updated_by    uuid references auth.users(id) on delete set null
);

drop trigger if exists tg_todos_audit on public.todos;
create trigger tg_todos_audit
  before insert or update on public.todos
  for each row execute function public.tg_set_audit_fields();

create index if not exists todos_done_idx     on public.todos (done);
create index if not exists todos_urgent_idx   on public.todos (urgent);
create index if not exists todos_due_idx      on public.todos (due);
create index if not exists todos_category_idx on public.todos (category);
create index if not exists todos_assignee_idx on public.todos (assignee_id);


-- =============================================================================
-- 5. TABLE : events
-- =============================================================================
create table if not exists public.events (
  id                uuid primary key default gen_random_uuid(),
  title             text not null,
  event_date        date not null,
  event_time        time,
  type              text not null default 'meeting',  -- 'meeting', 'shoot', 'release', 'tiktok', 'milestone', etc.
  location          text,
  attendees         text,  -- texte libre "Degzzy, Michael, chouaib" (compat archi actuelle)
  notes             text,
  related_track_id  uuid references public.tracks(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid references auth.users(id) on delete set null,
  updated_by        uuid references auth.users(id) on delete set null
);

drop trigger if exists tg_events_audit on public.events;
create trigger tg_events_audit
  before insert or update on public.events
  for each row execute function public.tg_set_audit_fields();

create index if not exists events_date_idx          on public.events (event_date);
create index if not exists events_type_idx          on public.events (type);
create index if not exists events_related_track_idx on public.events (related_track_id);


-- =============================================================================
-- 6. TABLE : inspirations (moodboard Milanote)
-- =============================================================================
create table if not exists public.inspirations (
  id           uuid primary key default gen_random_uuid(),
  media_type   text not null,  -- 'image', 'video', 'embed', 'link', 'note'
  media_url    text,
  media_embed  text,           -- iframe HTML pour YouTube/Spotify/SoundCloud
  provider     text,           -- 'youtube', 'spotify', 'tiktok', 'soundcloud', 'image'
  title        text,
  caption      text,
  source_url   text,
  position     int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  created_by   uuid references auth.users(id) on delete set null,
  updated_by   uuid references auth.users(id) on delete set null
);

drop trigger if exists tg_inspirations_audit on public.inspirations;
create trigger tg_inspirations_audit
  before insert or update on public.inspirations
  for each row execute function public.tg_set_audit_fields();

create index if not exists inspirations_media_type_idx on public.inspirations (media_type);
create index if not exists inspirations_provider_idx   on public.inspirations (provider);


-- =============================================================================
-- 7. TABLE : team_members
-- =============================================================================
-- Stocke les membres de l'équipe (y compris ceux qui n'ont pas de compte app
-- — réalisateur extérieur, photographe freelance, etc.). user_id optionnel
-- pour lier à auth.users si la personne a un compte.
create table if not exists public.team_members (
  id          uuid primary key default gen_random_uuid(),
  role        text not null,           -- 'Direction & Stratégie', 'Artiste', etc.
  name        text not null,
  note        text,
  user_id     uuid references auth.users(id) on delete set null,
  email       text,
  avatar_url  text,
  position    int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid references auth.users(id) on delete set null,
  updated_by  uuid references auth.users(id) on delete set null
);

drop trigger if exists tg_team_members_audit on public.team_members;
create trigger tg_team_members_audit
  before insert or update on public.team_members
  for each row execute function public.tg_set_audit_fields();

create index if not exists team_members_user_id_idx  on public.team_members (user_id);
create index if not exists team_members_position_idx on public.team_members (position);


-- =============================================================================
-- 8. TYPE ENUM : notification_type
-- =============================================================================
do $$
begin
  if not exists (select 1 from pg_type where typname = 'notification_type') then
    create type public.notification_type as enum (
      'event_added',
      'event_updated',
      'event_deleted',
      'todo_added',
      'todo_urgent',
      'todo_completed',
      'todo_assigned',
      'inspiration_added',
      'track_added',
      'track_released',
      'team_changed',
      'mention',
      'system'
    );
  end if;
end$$;


-- =============================================================================
-- 9. TABLE : notifications (per-user feed)
-- =============================================================================
create table if not exists public.notifications (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,  -- destinataire
  actor_id     uuid references auth.users(id) on delete set null,           -- qui a déclenché
  type         public.notification_type not null,
  message      text not null,
  link_table   text,   -- 'events', 'todos', 'tracks', 'inspirations', 'team_members'
  link_id      uuid,   -- id de l'item lié (pas de FK : polymorphe)
  is_read      boolean not null default false,
  created_at   timestamptz not null default now(),
  read_at      timestamptz
);

create index if not exists notifications_user_unread_idx  on public.notifications (user_id, is_read);
create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index if not exists notifications_link_idx         on public.notifications (link_table, link_id);


-- 9.5 — Notification fan-out helper
-- Doit être créée APRÈS le type notification_type et la table notifications.
-- Insère une notif pour chaque profile actif sauf l'actor (SECURITY DEFINER pour
-- contourner la RLS de notifications — seul ce chemin contrôlé peut insérer).
create or replace function public.notify_other_users(
  p_actor_id     uuid,
  p_type         public.notification_type,
  p_message      text,
  p_link_table   text default null,
  p_link_id      uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, actor_id, type, message, link_table, link_id)
  select p.id, p_actor_id, p_type, p_message, p_link_table, p_link_id
  from public.profiles p
  where p.is_active = true
    and p.id <> coalesce(p_actor_id, '00000000-0000-0000-0000-000000000000'::uuid);
end;
$$;


-- =============================================================================
-- 10. RLS — activer + policies
-- =============================================================================
-- Modèle simple : workspace partagé.
--   • SELECT/INSERT/UPDATE/DELETE : tout user authentifié sur les tables métier.
--   • Notifications : chaque user voit/manipule UNIQUEMENT les siennes.
--   • INSERT notifications : non exposé au client (seuls les triggers serveur insèrent).

alter table public.tracks         enable row level security;
alter table public.todos          enable row level security;
alter table public.events         enable row level security;
alter table public.inspirations   enable row level security;
alter table public.team_members   enable row level security;
alter table public.notifications  enable row level security;

-- Drop puis recreate pour idempotence
drop policy if exists "tracks_select"  on public.tracks;
drop policy if exists "tracks_insert"  on public.tracks;
drop policy if exists "tracks_update"  on public.tracks;
drop policy if exists "tracks_delete"  on public.tracks;
create policy "tracks_select" on public.tracks for select to authenticated using (true);
create policy "tracks_insert" on public.tracks for insert to authenticated with check (true);
create policy "tracks_update" on public.tracks for update to authenticated using (true) with check (true);
create policy "tracks_delete" on public.tracks for delete to authenticated using (true);

drop policy if exists "todos_select"   on public.todos;
drop policy if exists "todos_insert"   on public.todos;
drop policy if exists "todos_update"   on public.todos;
drop policy if exists "todos_delete"   on public.todos;
create policy "todos_select" on public.todos for select to authenticated using (true);
create policy "todos_insert" on public.todos for insert to authenticated with check (true);
create policy "todos_update" on public.todos for update to authenticated using (true) with check (true);
create policy "todos_delete" on public.todos for delete to authenticated using (true);

drop policy if exists "events_select"  on public.events;
drop policy if exists "events_insert"  on public.events;
drop policy if exists "events_update"  on public.events;
drop policy if exists "events_delete"  on public.events;
create policy "events_select" on public.events for select to authenticated using (true);
create policy "events_insert" on public.events for insert to authenticated with check (true);
create policy "events_update" on public.events for update to authenticated using (true) with check (true);
create policy "events_delete" on public.events for delete to authenticated using (true);

drop policy if exists "inspirations_select" on public.inspirations;
drop policy if exists "inspirations_insert" on public.inspirations;
drop policy if exists "inspirations_update" on public.inspirations;
drop policy if exists "inspirations_delete" on public.inspirations;
create policy "inspirations_select" on public.inspirations for select to authenticated using (true);
create policy "inspirations_insert" on public.inspirations for insert to authenticated with check (true);
create policy "inspirations_update" on public.inspirations for update to authenticated using (true) with check (true);
create policy "inspirations_delete" on public.inspirations for delete to authenticated using (true);

drop policy if exists "team_members_select" on public.team_members;
drop policy if exists "team_members_insert" on public.team_members;
drop policy if exists "team_members_update" on public.team_members;
drop policy if exists "team_members_delete" on public.team_members;
create policy "team_members_select" on public.team_members for select to authenticated using (true);
create policy "team_members_insert" on public.team_members for insert to authenticated with check (true);
create policy "team_members_update" on public.team_members for update to authenticated using (true) with check (true);
create policy "team_members_delete" on public.team_members for delete to authenticated using (true);

-- Notifications : privées, pas d'INSERT client
drop policy if exists "notifications_select_own" on public.notifications;
drop policy if exists "notifications_update_own" on public.notifications;
drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_select_own"
  on public.notifications for select
  to authenticated using (auth.uid() = user_id);
create policy "notifications_update_own"
  on public.notifications for update
  to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "notifications_delete_own"
  on public.notifications for delete
  to authenticated using (auth.uid() = user_id);
-- (Pas de policy INSERT : seuls les triggers SECURITY DEFINER insèrent.)


-- =============================================================================
-- 11. TRIGGERS DE NOTIFICATION AUTOMATIQUE
-- =============================================================================

-- 11.1 — event ajouté
create or replace function public.trg_notify_event_added()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
begin
  select coalesce(name, 'Quelqu''un') into actor_name
    from public.profiles where id = new.created_by;
  perform public.notify_other_users(
    new.created_by,
    'event_added',
    coalesce(actor_name, 'Quelqu''un') || ' a ajouté un événement : ' || new.title,
    'events',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists trg_events_notify_added on public.events;
create trigger trg_events_notify_added
  after insert on public.events
  for each row execute function public.trg_notify_event_added();


-- 11.2 — todo ajouté (urgent = type spécifique)
create or replace function public.trg_notify_todo_added()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
  notif_type public.notification_type;
  notif_msg  text;
begin
  select coalesce(name, 'Quelqu''un') into actor_name
    from public.profiles where id = new.created_by;
  if new.urgent then
    notif_type := 'todo_urgent';
    notif_msg  := coalesce(actor_name, 'Quelqu''un') || ' a ajouté une tâche URGENTE : ' || new.text;
  else
    notif_type := 'todo_added';
    notif_msg  := coalesce(actor_name, 'Quelqu''un') || ' a ajouté une tâche : ' || new.text;
  end if;
  perform public.notify_other_users(new.created_by, notif_type, notif_msg, 'todos', new.id);
  return new;
end;
$$;

drop trigger if exists trg_todos_notify_added on public.todos;
create trigger trg_todos_notify_added
  after insert on public.todos
  for each row execute function public.trg_notify_todo_added();


-- 11.3 — todo complété (transition done false → true)
create or replace function public.trg_notify_todo_completed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
begin
  if old.done = false and new.done = true then
    select coalesce(name, 'Quelqu''un') into actor_name
      from public.profiles where id = new.updated_by;
    perform public.notify_other_users(
      new.updated_by,
      'todo_completed',
      coalesce(actor_name, 'Quelqu''un') || ' a terminé : ' || new.text,
      'todos',
      new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_todos_notify_completed on public.todos;
create trigger trg_todos_notify_completed
  after update of done on public.todos
  for each row execute function public.trg_notify_todo_completed();


-- 11.4 — todo assigné (transition assignee_id changée vers non-null)
create or replace function public.trg_notify_todo_assigned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
begin
  if new.assignee_id is not null
     and (old.assignee_id is null or old.assignee_id <> new.assignee_id)
     and new.assignee_id <> coalesce(new.updated_by, '00000000-0000-0000-0000-000000000000'::uuid) then
    select coalesce(name, 'Quelqu''un') into actor_name
      from public.profiles where id = new.updated_by;
    -- Notif ciblée (pas de fan-out) : insertion directe pour l'assignee
    insert into public.notifications (user_id, actor_id, type, message, link_table, link_id)
    values (
      new.assignee_id,
      new.updated_by,
      'todo_assigned',
      coalesce(actor_name, 'Quelqu''un') || ' t''a assigné : ' || new.text,
      'todos',
      new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_todos_notify_assigned on public.todos;
create trigger trg_todos_notify_assigned
  after insert or update of assignee_id on public.todos
  for each row execute function public.trg_notify_todo_assigned();


-- 11.5 — inspiration ajoutée
create or replace function public.trg_notify_inspiration_added()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
  preview    text;
begin
  select coalesce(name, 'Quelqu''un') into actor_name
    from public.profiles where id = new.created_by;
  preview := coalesce(new.title, new.caption, new.provider, new.media_type, 'lien');
  perform public.notify_other_users(
    new.created_by,
    'inspiration_added',
    coalesce(actor_name, 'Quelqu''un') || ' a ajouté une inspiration : ' || preview,
    'inspirations',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists trg_inspirations_notify_added on public.inspirations;
create trigger trg_inspirations_notify_added
  after insert on public.inspirations
  for each row execute function public.trg_notify_inspiration_added();


-- 11.6 — track ajouté
create or replace function public.trg_notify_track_added()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
begin
  select coalesce(name, 'Quelqu''un') into actor_name
    from public.profiles where id = new.created_by;
  perform public.notify_other_users(
    new.created_by,
    'track_added',
    coalesce(actor_name, 'Quelqu''un') || ' a ajouté le morceau : ' || new.name,
    'tracks',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists trg_tracks_notify_added on public.tracks;
create trigger trg_tracks_notify_added
  after insert on public.tracks
  for each row execute function public.trg_notify_track_added();


-- =============================================================================
-- 12. REALTIME — exposer les tables aux subscriptions postgres_changes
-- =============================================================================
-- Sans cette étape, les `.on('postgres_changes', ...)` côté client ne recevront
-- rien. Wrap dans un DO block pour être idempotent (les re-runs ne plantent pas
-- si la table est déjà dans la publication).
do $$
declare
  tbls text[] := array['tracks','todos','events','inspirations','team_members','notifications'];
  t text;
begin
  foreach t in array tbls loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then
      null;  -- déjà dans la publication, on continue
    end;
  end loop;
end$$;


-- =============================================================================
-- 13. SANITY CHECK — à exécuter après le run pour valider
-- =============================================================================
-- Décommente et lance pour vérifier que tout est OK :
--
-- select tablename from pg_tables where schemaname = 'public'
--   order by tablename;
-- -- Attendu : events, inspirations, notifications, profiles, team_members, todos, tracks
--
-- select tablename from pg_publication_tables where pubname = 'supabase_realtime'
--   order by tablename;
-- -- Attendu : les 6 tables ci-dessus listées
--
-- select trigger_name, event_object_table from information_schema.triggers
--   where trigger_schema = 'public' order by event_object_table, trigger_name;
-- -- Attendu : tg_*_audit pour chaque table + trg_*_notify_* pour les actions notifiables


-- =============================================================================
-- ROLLBACK (en cas de souci — à exécuter manuellement, NE FAIT PAS PARTIE du run)
-- =============================================================================
-- Pour tout supprimer et repartir à zéro, exécute le bloc suivant (commente/uncommente) :
--
-- drop table if exists public.notifications cascade;
-- drop table if exists public.team_members  cascade;
-- drop table if exists public.inspirations  cascade;
-- drop table if exists public.events        cascade;
-- drop table if exists public.todos         cascade;
-- drop table if exists public.tracks        cascade;
-- drop type  if exists public.notification_type;
-- drop function if exists public.notify_other_users(uuid, notification_type, text, text, uuid);
-- drop function if exists public.tg_set_audit_fields();
-- drop function if exists public.trg_notify_event_added();
-- drop function if exists public.trg_notify_todo_added();
-- drop function if exists public.trg_notify_todo_completed();
-- drop function if exists public.trg_notify_todo_assigned();
-- drop function if exists public.trg_notify_inspiration_added();
-- drop function if exists public.trg_notify_track_added();
-- ⚠ Ne pas drop la table `profiles` si elle existait déjà avant ce script.


-- =============================================================================
-- FIN
-- =============================================================================
