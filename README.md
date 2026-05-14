# Noname × Degzzy — Workspace R.I.C.H

Web-app interne de management d'album pour le projet **R.I.C.H** de Degzzy.
Sortie prévue : **vendredi 11 septembre 2026**.

Développée par [Noname Agency](https://noname.agency) (Genève) — direction Chouaib Serir.

**Live** : [shweppsss.github.io/AppArtiste](https://shweppsss.github.io/AppArtiste/)

---

## Stack

- **Frontend** : HTML / CSS / JavaScript vanilla — single-file `index.html` (~9900 lignes)
- **Backend** : Supabase Pro (PostgreSQL + Realtime + Auth + Storage)
- **Hébergement** : GitHub Pages (auto-deploy sur push `main`)
- **PWA** : Service Worker `sw.js` + manifest pour installation iOS / Android (offline caching)

Pas de build step, pas de framework, pas de node_modules. Chaque push sur `main` déclenche un déploiement automatique de GitHub Pages.

## Structure du dépôt

```
.
├── index.html               # L'app complète — tout est dedans
├── manifest.json            # PWA manifest (paths relatifs)
├── sw.js                    # Service Worker (offline cache)
├── icon-*.png               # Icônes PWA (à générer via realfavicongenerator.net)
├── og-image.png             # Image partage social
├── supabase/
│   ├── 001-relational-schema.sql        # Schéma tables relationnelles (dormant — l'app utilise workspace.state JSON)
│   ├── 002-push-subscriptions.sql       # (legacy, table à drop via 005)
│   ├── 003-storage-policies.sql         # RLS policies pour les 5 buckets storage
│   ├── 004-profile-alias.sql            # Ajout colonne alias sur profiles
│   ├── 004-workspace-table.sql          # Table workspace (state JSON)
│   └── 005-drop-push-subscriptions.sql  # Drop push system (push retiré)
├── scripts/
│   └── setup-auto-sync.sh   # Hook git local pour auto-push
├── docs/
│   └── RECAP.md             # Historique des phases + conventions design
├── .gitignore
└── README.md                # Ce fichier
```

## Démarrage local

Pas d'install. Sers le dossier via un serveur statique :

```bash
# Option 1 — Python
python3 -m http.server 8080

# Option 2 — Node
npx serve .

# Option 3 — VSCode
# Extension "Live Server" → clic droit sur index.html → "Open with Live Server"
```

Puis ouvre `http://localhost:8080`.

> Note : le Service Worker exige HTTPS ou `localhost`. Ouvrir le fichier en `file://` désactive les fonctions PWA.

## Configuration Supabase

L'app pointe vers un projet Supabase existant. Les credentials (`URL` + `anon key`) sont hardcodés dans `index.html`. La `anon key` est volontairement publique — la sécurité repose entièrement sur les RLS policies définies dans les fichiers SQL.

Pour repartir de zéro avec un nouveau projet Supabase :

1. Créer un projet sur [supabase.com](https://supabase.com).
2. **Storage** → créer les 5 buckets (`audio`, `covers`, `inspirations`, `clips`, `capsules`) en mode **privé**.
3. **SQL Editor** → exécuter dans l'ordre :
   - `supabase/004-workspace-table.sql` (table principale)
   - `supabase/004-profile-alias.sql` (alias support)
   - `supabase/005-drop-push-subscriptions.sql` (clean push legacy)
4. **Storage → bucket → Policies** (UI, pas SQL — le SQL Editor n'a pas les droits owner) → créer une policy par bucket : "For full customization" → toutes les ops (SELECT/INSERT/UPDATE/DELETE) → role `authenticated` → expression `bucket_id = '<nom>'`.
5. **Authentication → Sign In / Up → Email** → activer "Confirm email" pour la prod.
6. **Authentication → URL Configuration** → restreindre Redirect URLs au domaine GitHub Pages (`https://<user>.github.io/AppArtiste/**`).
7. **Settings → API** → récupérer URL projet + anon key → remplacer `SUPABASE_DEFAULTS` dans `index.html`.

## Déploiement GitHub Pages

Configuré dans **Settings → Pages → Source : Deploy from a branch → main → / (root)**. Build type = `legacy` (pas de workflow).

Chaque push sur `main` déclenche un build automatique en ~60s. État visible dans **Actions → pages-build-deployment**.

### Service Worker cache

À chaque release, bumper `CACHE_VERSION` dans `sw.js` (format `noname-YYYYMMDD-N`) pour invalider l'ancien cache offline.

## Workflow collaboratif

Branche `main` = production. Personne ne push directement dessus.

```bash
# Pour ajouter une feature
git checkout -b feature/nom-clair
# ... modifs ...
git add .
git commit -m "Description claire en français OK"
git push -u origin feature/nom-clair
# Puis créer une Pull Request sur GitHub
# Reviewer relit → merge → GitHub Pages redéploie main
```

Conseils pratiques :

- **Test local avant push** : sers `index.html` via serveur local (pas `file://`), vérifie que tu n'as rien cassé.
- **Commit petits et fréquents** : un commit = une intention claire. Plus facile à reviewer et à revert.
- **Ne pas commit de secrets** : la `anon key` Supabase est OK (publique par design), mais jamais coller la `service_role key` dans le repo.

## Historique des phases

Voir `docs/RECAP.md` pour l'historique détaillé des phases de développement, les conventions design (tokens, typographie, motion), et la carte des fonctions JS principales avec leurs numéros de lignes.

## Roadmap (ouverte)

- [ ] Migration JSONB monolithe → tables relationnelles (SQL en place, JS à câbler)
- [ ] Refactor des 60+ `onclick` inline en event delegation
- [ ] Light mode (tokens définis, variants à coder)
- [ ] Refonte pages restantes : Budget, KPI, Plan, Assets

## Licence

Propriétaire — © Noname Agency. Tous droits réservés. Code privé non destiné à redistribution.
