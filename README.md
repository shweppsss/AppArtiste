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
- **PWA** : Service Worker `sw.js` + manifest pour installation iOS / Android
- **Notifications push** : Web Push Protocol + VAPID, via Supabase Edge Function

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
2. SQL Editor → exécuter `supabase/001-relational-schema.sql` puis `supabase/002-push-subscriptions.sql`.
3. Authentication → Providers → Email → désactiver "Confirm email" pour simplifier le flow d'invitation.
4. Authentication → URL Configuration → ajouter `https://<ton-domaine>/**` dans Redirect URLs.
5. Récupérer URL projet + anon key (Settings → API) → remplacer dans `index.html`.

## Notifications push (déploiement)

Voir `supabase/functions/send-push/index.ts` pour les détails. Étapes résumées :

```bash
# 1. Générer les clés VAPID
npx web-push generate-vapid-keys

# 2. Coller la clé publique dans index.html (cherche VAPID_PUBLIC_KEY)
# 3. Déployer l'Edge Function
npm install -g supabase
supabase login
supabase link --project-ref <project-id>
supabase secrets set \
  VAPID_PUBLIC_KEY='...' \
  VAPID_PRIVATE_KEY='...' \
  VAPID_SUBJECT='mailto:chouaib.serir.pro@gmail.com'
supabase functions deploy send-push --no-verify-jwt

# 4. Dashboard Supabase → Database → Webhooks → Create
#    Table: notifications, Event: Insert
#    URL: https://<project-id>.supabase.co/functions/v1/send-push
```

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
- **Ne pas commit de secrets** : la `anon key` Supabase est OK (publique par design), mais jamais coller la `service_role key` ou les clés VAPID privées dans le repo. Elles vivent dans les secrets Supabase / Netlify env vars.

## Historique des phases

Voir `docs/RECAP.md` pour l'historique détaillé des 8+ phases de développement, les conventions design (tokens, typographie, motion), et la carte des fonctions JS principales avec leurs numéros de lignes.

## Roadmap (ouverte)

- [ ] Migration JSONB monolithe → tables relationnelles (SQL en place, JS à câbler)
- [ ] Cloche + Inbox UI consommant la table `notifications`
- [ ] Refactor des 60+ `onclick` inline en event delegation
- [ ] Light mode (tokens définis, variants à coder)
- [ ] Refonte pages restantes : Budget, KPI, Plan, Assets

## Licence

Propriétaire — © Noname Agency. Tous droits réservés. Code privé non destiné à redistribution.
# (auto-pull test marker)
# (auto-pull test 2 - 16:46:14)
# (test 3 - 16:49:56)
