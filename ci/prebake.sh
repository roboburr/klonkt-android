#!/data/data/com.termux/files/usr/bin/bash
# Runs INSIDE termux/termux-docker:aarch64 (via QEMU in CI).
# Produces:
#   /repo/klonkt-node-arm64.tar.gz  - klonkt-node WITH node_modules (release fallback)
#   /repo/klonkt-bundle.tar.gz      - the OFFLINE bundle shipped inside the APK:
#                                     debs/ (nodejs-lts+ffmpeg+cloudflared incl. full
#                                     dependency closure) + klonkt-node/
# so a fresh phone installs everything without downloading a single byte.
set -e

yes | pkg update >/dev/null 2>&1 || true

# 1) Download the FULL dependency closure BEFORE installing anything, so the
#    apt archive cache holds every .deb a fresh phone needs.
apt-get install --download-only -y nodejs-lts ffmpeg cloudflared
mkdir -p /repo/bundle/debs
# apt's archive dir varies in termux-docker - just find every downloaded .deb
find /data/data/com.termux -name "*.deb" -exec cp {} /repo/bundle/debs/ \;
DEBS=$(ls /repo/bundle/debs/ | wc -l)
echo "collected $DEBS debs"
[ "$DEBS" -gt 10 ] || { echo "ERROR: deb closure missing"; exit 1; }

# 2) Build klonkt-node with node_modules (compilers only exist here, never on phones)
pkg install -y nodejs-lts python build-essential git
cp -r /repo/klonkt-node-src "$HOME/klonkt-node"
cd "$HOME/klonkt-node"
# node-gyp on termux looks for an android_ndk_path variable that doesn't exist
export GYP_DEFINES="android_ndk_path=''"
npm install --no-audit --no-fund
node -e 'require("better-sqlite3"); console.log("better-sqlite3 loads OK on aarch64 termux, node " + process.version)'

# 3) Assemble both artifacts
tar -czf /repo/klonkt-node-arm64.tar.gz -C "$HOME" klonkt-node
cp -r "$HOME/klonkt-node" /repo/bundle/klonkt-node
tar -czf /repo/klonkt-bundle.tar.gz -C /repo/bundle debs klonkt-node
echo "bundle: $(du -h /repo/klonkt-bundle.tar.gz | cut -f1)  node-tar: $(du -h /repo/klonkt-node-arm64.tar.gz | cut -f1)"
