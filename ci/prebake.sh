#!/data/data/com.termux/files/usr/bin/bash
# Runs INSIDE termux/termux-docker:aarch64 (via QEMU in CI).
# The workflow provides /repo/klonkt-node-src = a fresh clone of
# roboburr/klonkt @ the STABLE branch (the same channel self-hosters run).
#
# Produces:
#   /repo/klonkt-node-arm64.tar.gz  - klonkt-node WITH node_modules (release asset,
#                                     what `klonkt-update` on phones downloads)
#   /repo/klonkt-bundle.tar.gz      - the OFFLINE bundle shipped inside the APK:
#                                     debs/ (nodejs-lts+ffmpeg+cloudflared incl. full
#                                     dependency closure) + klonkt-node/
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
rm -rf .git .beads .github

# Android adaptation: no source patch needed. ffmpeg-static's npm binary is
# glibc-linux and can't run on Android/bionic, so drop the dependency and stub
# the module to Termux's system ffmpeg (installed from the repo above). Klonkt
# imports `ffmpeg-static` for its PATH only, so a one-line stub is exact.
npm pkg delete dependencies.ffmpeg-static

# node-gyp on termux looks for an android_ndk_path variable that doesn't exist
export GYP_DEFINES="android_ndk_path=''"
npm install --no-audit --no-fund

mkdir -p node_modules/ffmpeg-static
printf '%s\n' "module.exports = '/data/data/com.termux/files/usr/bin/ffmpeg';" > node_modules/ffmpeg-static/index.js
printf '%s\n' '{"name":"ffmpeg-static","version":"0.0.0-termux","main":"index.js"}' > node_modules/ffmpeg-static/package.json

# 3) Sanity: the native module loads, the ffmpeg stub resolves, and the server BOOTS.
node -e 'require("better-sqlite3"); console.log("better-sqlite3 loads OK, node " + process.version)'
node -e 'import("ffmpeg-static").then(m => { if (!m.default.includes("usr/bin/ffmpeg")) process.exit(1); console.log("ffmpeg stub:", m.default); })'
mkdir -p /tmp/klonkt-boot
(PORT=3555 HOST=127.0.0.1 DATABASE_PATH=/tmp/klonkt-boot/t.sqlite MEDIA_PATH=/tmp/klonkt-boot/media AUDIO_PATH=/tmp/klonkt-boot/audio \
  timeout 60 node src/server.js > /tmp/klonkt-boot/boot.log 2>&1 || true)
if grep -q "3555" /tmp/klonkt-boot/boot.log; then
  echo "server boot smoke test OK"
else
  echo "ERROR: server failed to boot:"; cat /tmp/klonkt-boot/boot.log; exit 1
fi

# 4) Assemble both artifacts
tar -czf /repo/klonkt-node-arm64.tar.gz -C "$HOME" klonkt-node
cp -r "$HOME/klonkt-node" /repo/bundle/klonkt-node
tar -czf /repo/klonkt-bundle.tar.gz -C /repo/bundle debs klonkt-node
echo "bundle: $(du -h /repo/klonkt-bundle.tar.gz | cut -f1)  node-tar: $(du -h /repo/klonkt-node-arm64.tar.gz | cut -f1)"
