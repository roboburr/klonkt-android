#!/data/data/com.termux/files/usr/bin/bash
# Runs INSIDE termux/termux-docker:aarch64 (via QEMU in CI).
# Builds klonkt-node WITH node_modules (better-sqlite3 compiled here), so
# phones never need python/build-essential or an on-device gyp compile.
set -e

yes | pkg update >/dev/null 2>&1 || true
pkg install -y nodejs-lts python build-essential git

cp -r /repo/klonkt-node-src "$HOME/klonkt-node"
cd "$HOME/klonkt-node"

# node-gyp on termux looks for an android_ndk_path variable that doesn't exist
export GYP_DEFINES="android_ndk_path=''"
npm install --no-audit --no-fund

# Sanity: the one native module must actually load on aarch64 termux
node -e 'require("better-sqlite3"); console.log("better-sqlite3 loads OK on aarch64 termux, node " + process.version)'

tar -czf /repo/klonkt-node-arm64.tar.gz -C "$HOME" klonkt-node
echo "prebake done: $(du -h /repo/klonkt-node-arm64.tar.gz | cut -f1)"
