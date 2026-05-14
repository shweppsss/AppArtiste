#!/bin/bash
# Configure le workflow auto-push + auto-pull avec notif macOS pour ce dépôt.
# À lancer une fois après avoir cloné le dépôt :
#   bash scripts/setup-auto-sync.sh
#
# Ce que ça met en place :
#   1. Hook post-commit -> push auto à chaque commit
#   2. Script de watch  -> vérifie origin/main toutes les 60s, pull auto si possible, notif macOS
#   3. LaunchAgent      -> lance le watch en arrière-plan
#
# Pré-requis : macOS, git, gh (GitHub CLI) authentifié, accès collaborateur Write au dépôt.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WATCH_DIR="$HOME/Library/Application Support/AppArtisteWatch"
WATCH_SCRIPT="$WATCH_DIR/check.sh"

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ gh (GitHub CLI) n'est pas installé. Lance : brew install gh && gh auth login"
  exit 1
fi

GH_LOGIN=$(gh api user --jq '.login' 2>/dev/null || echo "")
if [ -z "$GH_LOGIN" ]; then
  echo "❌ gh n'est pas authentifié. Lance : gh auth login"
  exit 1
fi

PLIST="$HOME/Library/LaunchAgents/com.${GH_LOGIN}.appartiste-watch.plist"

echo "→ Installation pour l'utilisateur GitHub : $GH_LOGIN"
echo "→ Dépôt local : $REPO_ROOT"
echo ""

# === 1. Identité Git (si pas déjà configurée) ===
if [ -z "$(git config --global user.email)" ]; then
  GH_ID=$(gh api user --jq '.id')
  git config --global user.name "$GH_LOGIN"
  git config --global user.email "${GH_ID}+${GH_LOGIN}@users.noreply.github.com"
  echo "✅ Identité Git configurée : $GH_LOGIN <${GH_ID}+${GH_LOGIN}@users.noreply.github.com>"
else
  echo "↪ Identité Git déjà configurée ($(git config --global user.email)) — on garde"
fi

# === 2. Hook post-commit (push auto) ===
HOOK="$REPO_ROOT/.git/hooks/post-commit"
cat > "$HOOK" <<'POST_COMMIT_EOF'
#!/bin/sh
branch=$(git rev-parse --abbrev-ref HEAD)
echo ""
echo "→ Push automatique vers origin/$branch..."
if git push origin "$branch"; then
  echo "✅ Push réussi"
else
  echo "❌ Push échoué — fais 'git pull' puis 'git push' manuellement"
fi
POST_COMMIT_EOF
chmod +x "$HOOK"
echo "✅ Hook post-commit installé : $HOOK"

# === 3. Script de watch ===
mkdir -p "$WATCH_DIR"
cat > "$WATCH_SCRIPT" <<WATCH_EOF
#!/bin/bash
# Auto-généré par scripts/setup-auto-sync.sh — ne pas éditer à la main.
REPO="$REPO_ROOT"
STATE_FILE="\$REPO/.git/last-notified-commit"

cd "\$REPO" || exit 0
git fetch origin main --quiet 2>/dev/null || exit 0

BEHIND=\$(git rev-list --count main..origin/main 2>/dev/null)
[ -z "\$BEHIND" ] && exit 0
[ "\$BEHIND" = "0" ] && exit 0

REMOTE_SHA=\$(git rev-parse origin/main)
LAST_NOTIFIED=""
[ -f "\$STATE_FILE" ] && LAST_NOTIFIED=\$(cat "\$STATE_FILE")
[ "\$REMOTE_SHA" = "\$LAST_NOTIFIED" ] && exit 0

MSG=\$(git log -1 --format='%s' origin/main | tr -d '"')
AUTHOR=\$(git log -1 --format='%an' origin/main | tr -d '"')

CURRENT_BRANCH=\$(git rev-parse --abbrev-ref HEAD)
PULL_OK=0
if [ "\$CURRENT_BRANCH" = "main" ]; then
  git pull --ff-only origin main >/dev/null 2>&1
  PULL_OK=\$?
fi

if [ "\$CURRENT_BRANCH" != "main" ]; then
  TITLE="AppArtiste — nouveau commit (pas pull : branche \$CURRENT_BRANCH)"
  SUBTITLE="par \$AUTHOR — \$BEHIND en attente"
elif [ \$PULL_OK -eq 0 ]; then
  TITLE="AppArtiste — \$BEHIND commit(s) récupéré(s) ✅"
  SUBTITLE="par \$AUTHOR"
else
  TITLE="AppArtiste — pull échoué ⚠️"
  SUBTITLE="modifs locales en cours — pull à la main"
fi

osascript -e "display notification \"\$MSG\" with title \"\$TITLE\" subtitle \"\$SUBTITLE\" sound name \"Glass\""
echo "\$REMOTE_SHA" > "\$STATE_FILE"
WATCH_EOF
chmod +x "$WATCH_SCRIPT"
echo "✅ Script de watch installé : $WATCH_SCRIPT"

# === 4. LaunchAgent macOS ===
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.${GH_LOGIN}.appartiste-watch</string>
    <key>ProgramArguments</key>
    <array>
        <string>${WATCH_SCRIPT}</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${WATCH_DIR}/out.log</string>
    <key>StandardErrorPath</key>
    <string>${WATCH_DIR}/err.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
PLIST_EOF
echo "✅ LaunchAgent écrit : $PLIST"

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "✅ LaunchAgent chargé"

echo ""
echo "🎉 Tout est en place !"
echo ""
echo "→ Test : 'git commit --allow-empty -m \"test\"' dans le dépôt — push doit partir auto"
echo "→ Si tu ne vois pas les notifs : Réglages Système → Notifications → autoriser Script Editor"
echo "→ Logs du watch : tail -f \"$WATCH_DIR/err.log\""
echo "→ Pour arrêter : launchctl unload \"$PLIST\""
