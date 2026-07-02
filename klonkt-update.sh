#!/data/data/com.termux/files/usr/bin/bash
# Klonkt phone updater. Run on the phone as: klonkt-update
# Fetches the latest prebuilt klonkt-node from the release, keeps your data
# (storage/ = database + uploads, and .env), swaps the code and restarts.
set -e
cd "$HOME"

echo "[Klonkt] Nieuwste versie downloaden..."
curl -fL --retry 3 -o klonkt-upd.tar.gz "https://github.com/roboburr/klonkt-android/releases/download/termux-latest/klonkt-node-arm64.tar.gz"
rm -rf klonkt-upd && mkdir klonkt-upd
# Android forbids hard links; gyp's build intermediates in the tarball are
# hard-linked junk (obj.target/*, *.a) and make tar exit non-zero even though
# everything that matters extracted fine. Tolerate that, then hard-verify the
# essentials below.
tar -xzf klonkt-upd.tar.gz -C klonkt-upd 2>/dev/null || true
rm -f klonkt-upd.tar.gz
if [ ! -f klonkt-upd/klonkt-node/package.json ] || [ ! -f klonkt-upd/klonkt-node/src/server.js ] \
   || [ ! -f klonkt-upd/klonkt-node/node_modules/better-sqlite3/build/Release/better_sqlite3.node ]; then
    echo "[Klonkt] Download onvolledig - update afgebroken (niets veranderd)."
    exit 1
fi

echo "[Klonkt] Server stoppen..."
chmod -R u+rwX klonkt-node klonkt-node.prev 2>/dev/null || true
pkill node 2>/dev/null || true
pkill cloudflared 2>/dev/null || true
sleep 1

echo "[Klonkt] Data behouden (storage + .env)..."
rm -rf klonkt-upd/klonkt-node/storage
[ -d klonkt-node/storage ] && cp -a klonkt-node/storage klonkt-upd/klonkt-node/storage
[ -f klonkt-node/.env ] && cp -a klonkt-node/.env klonkt-upd/klonkt-node/.env

# Previous version (incl. a copy of the data) stays as rollback until the next update.
rm -rf klonkt-node.prev
mv klonkt-node klonkt-node.prev
mv klonkt-upd/klonkt-node klonkt-node
rmdir klonkt-upd 2>/dev/null || true

NEWV=$(node -e "console.log(require('$HOME/klonkt-node/package.json').version)" 2>/dev/null || echo "?")
echo "[Klonkt] Bijgewerkt naar versie $NEWV. Herstarten..."
exec bash "$HOME/.klonkt-start.sh"
