-- Ajoute un champ alias (pseudo perso) au profil utilisateur.
-- Lance ce script dans le SQL Editor de Supabase une seule fois.

alter table public.profiles add column if not exists alias text;
