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

# Pin the canonical Termux mirror. The default mirror-rotation sometimes lands on
# a stale mirror that 404s on packages the fresh index references (build failed
# on termux.niranjan.co missing vulkan-loader/libtiff/etc). One in-sync mirror
# for both `apt update` and the downloads avoids that.
echo "deb https://packages.termux.dev/apt/termux-main stable main" > "$PREFIX/etc/apt/sources.list"

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
mkdir -p $HOME/kboot
(PORT=3555 HOST=127.0.0.1 DATABASE_PATH=$HOME/kboot/t.sqlite MEDIA_PATH=$HOME/kboot/media AUDIO_PATH=$HOME/kboot/audio \
  timeout 60 node src/server.js > $HOME/kboot/boot.log 2>&1 || true)
if grep -q "3555" $HOME/kboot/boot.log; then
  echo "server boot smoke test OK"
else
  echo "ERROR: server failed to boot:"; cat $HOME/kboot/boot.log; exit 1
fi

# 4) Strip gyp's hard-linked build intermediates (obj.target/*, *.a): Android
#    forbids hard links, so extracting them on a phone fails - and they're
#    build junk anyway (only build/Release/*.node is used at runtime).
find node_modules -type d -name obj.target -prune -exec rm -rf {} + 2>/dev/null || true
find node_modules -name "*.a" -delete 2>/dev/null || true

# 5) Assemble both artifacts (hard-dereference as belt-and-braces) + guard
tar --hard-dereference -czf /repo/klonkt-node-arm64.tar.gz -C "$HOME" klonkt-node
if tar -tvf /repo/klonkt-node-arm64.tar.gz | grep -q " link to "; then
  echo "ERROR: tarball still contains hard links"; exit 1
fi
cp -r "$HOME/klonkt-node" /repo/bundle/klonkt-node
tar --hard-dereference -czf /repo/klonkt-bundle.tar.gz -C /repo/bundle debs klonkt-node
echo "bundle: $(du -h /repo/klonkt-bundle.tar.gz | cut -f1)  node-tar: $(du -h /repo/klonkt-node-arm64.tar.gz | cut -f1)"
