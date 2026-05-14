# Noname × Degzzy — Workspace R.I.C.H

Web-app interne de management d'album pour le projet **R.I.C.H** de Degzzy.
Sortie prévue : **vendredi 11 septembre 2026**.

Développée par [Noname Agency](https://noname.agency) (Genève) — direction Chouaib Serir.

**Live** : [deggzyteam.netlify.app](https://deggzyteam.netlify.app)
**Mirror GitHub Pages** : [shweppsss.github.io/AppArtiste](https://shweppsss.github.io/AppArtiste/)

---

## Stack

- **Frontend** : HTML / CSS / JavaScript vanilla — single-file `index.html` (~9000 lignes)
- **Backend** : Supabase (PostgreSQL + Realtime + Auth)
- **Hébergement** : Netlify
- **PWA** : Service Worker `sw.js` + manifest pour installation iOS / Android (offline caching)

Pas de build step, pas de framework, pas de node_modules. Le déploiement est aussi simple que glisser le contenu du dossier sur Netlify.

## Structure du dépôt

```
.
├── index.html               # L'app complète — tout est dedans
├── manifest.json            # PWA manifest
├── sw.js                    # Service Worker (cache offline + push handler)
├── _headers                 # Cache policy Netlify
├── netlify.toml             # Config auto-deploy
├── icon-*.png               # Icônes PWA (à générer via realfavicongenerator.net)
├── og-image.png             # Image partage social
├── supabase/
│   ├── 001-relational-schema.sql   # Schéma tables + triggers + RLS
│   ├── 002-push-subscriptions.sql  # Table push_subscriptions + RLS
│   └── functions/send-push/
│       └── index.ts                # Edge Function — envoie les pushes
├── docs/
│   └── RECAP.md             # Historique des phases + conventions du projet
├── .gitignore
└── README.md                # Ce fichier
```

## Démarrage local

Pas d'install. Ouvre `index.html` dans le navigateur, ou sers le dossier via un serveur statique :

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
2. SQL Editor → exécuter `supabase/004-workspace-table.sql` (la table principale) + `supabase/003-storage-policies.sql` (RLS sur les 5 buckets : audio, covers, inspirations, clips, capsules).
3. Storage → créer les 5 buckets (`audio`, `covers`, `inspirations`, `clips`, `capsules`) en mode **privé**.
4. Authentication → Providers → Email → activer "Confirm email" pour la prod.
5. Authentication → URL Configuration → restreindre Redirect URLs aux domaines de déploiement.
6. Récupérer URL projet + anon key (Settings → API) → remplacer dans `index.html`.

## Déploiement Netlify

Deux options possibles.

### Option 1 — Drag & drop (simple)

1. Zip le dossier (sans `.git/`).
2. Aller sur [app.netlify.com/drop](https://app.netlify.com/drop).
3. Glisser le dossier → c'est en ligne en 30 secondes.

### Option 2 — Auto-deploy depuis GitHub (recommandé pour le travail à plusieurs)

1. Sur Netlify → "Add new site" → "Import an existing project" → connecter le repo GitHub.
2. Build settings : **Build command** = (vide), **Publish directory** = `.` (la racine du repo).
3. Chaque push sur `main` déclenche un re-deploy automatique. Les PR génèrent des deploy previews.

Le fichier `netlify.toml` à la racine du repo encode déjà cette config.

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
# Reviewer relit → merge → Netlify redéploie main
```

Conseils pratiques :

- **Test local avant push** : ouvre `index.html` dans le navigateur, vérifie que tu n'as rien cassé.
- **Commit petits et fréquents** : un commit = une intention claire. Plus facile à reviewer et à revert.
- **Ne pas commit de secrets** : la `anon key` Supabase est OK (publique par design), mais jamais coller la `service_role key` dans le repo.

## Historique des phases

Voir `docs/RECAP.md` pour l'historique détaillé des 8+ phases de développement, les conventions design (tokens, typographie, motion), et la carte des fonctions JS principales avec leurs numéros de lignes.

## Roadmap (ouverte)

- [ ] Migration JSONB monolithe → tables relationnelles (SQL en place, JS à câbler)
- [ ] Refactor des 60+ `onclick` inline en event delegation
- [ ] Light mode (tokens définis, variants à coder)
- [ ] Refonte pages restantes : Budget, KPI, Plan, Assets

## Licence

Propriétaire — © Noname Agency. Tous droits réservés. Code privé non destiné à redistribution.
# (auto-pull test marker)
# (auto-pull test 2 - 16:46:14)
# (test 3 - 16:49:56)
