#!/usr/bin/env bash

# Klonkt setup for Termux (v5)
# Prebuilt-first: downloads a ready-made klonkt-node WITH node_modules
# (better-sqlite3 already compiled for aarch64 in CI), so the phone never
# needs python/build-essential or a slow on-device compile.

echo "=== 1/3 Pakketten installeren ==="
yes | pkg update >/dev/null 2>&1 || true
pkg install -y nodejs-lts ffmpeg cloudflared

echo "=== 2/3 Klonkt downloaden (voorgebouwd) ==="
pkill node 2>/dev/null || true
cd "$HOME"
chmod -R u+rw klonkt-node 2>/dev/null || true

if curl -fL --retry 3 -o klonkt-node.tar.gz "https://github.com/roboburr/klonkt-android/releases/download/termux-latest/klonkt-node-arm64.tar.gz"; then
    rm -rf klonkt-node
    tar -xzf klonkt-node.tar.gz
    rm -f klonkt-node.tar.gz
    echo "Voorgebouwde Klonkt geinstalleerd - geen compilatie nodig."
else
    echo "Prebuilt download mislukt - terugvallen op broncode + lokaal bouwen (duurt langer)..."
    pkg install -y python build-essential git unzip
    rm -rf klonkt-node
    mkdir -p klonkt-node
    if ! curl -fL -o klonkt-node.zip "https://raw.githubusercontent.com/roboburr/klonkt-android/main/app/src/main/assets/klonkt-node.zip"; then
        echo "CRITISCHE FOUT: kan Klonkt niet downloaden. Controleer je internetverbinding."
        exit 1
    fi
    unzip -q -o klonkt-node.zip -d klonkt-node
    rm -f klonkt-node.zip
    cd klonkt-node
    # node-gyp on termux looks for an android_ndk_path variable that doesn't exist
    export GYP_DEFINES="android_ndk_path=''"
    npm install --no-audit --no-fund
    cd "$HOME"
fi

echo "=== 3/4 klonkt-token commando installeren ==="
cat << 'EOF' > "$PREFIX/bin/klonkt-token"
#!/data/data/com.termux/files/usr/bin/bash
# Set/clear the Cloudflare named-tunnel token for a fixed own domain.
if [ -z "$1" ]; then
    echo "Gebruik:  klonkt-token <token>     (plak de eyJ...-string uit Cloudflare Zero Trust)"
    echo "          klonkt-token clear       (terug naar tijdelijke trycloudflare-URL)"
    exit 1
fi
if [ "$1" = "clear" ]; then
    rm -f ~/.klonkt-tunnel-token
    echo "Token gewist. Herstart de app voor een trycloudflare-URL."
    exit 0
fi
printf '%s' "$1" > ~/.klonkt-tunnel-token
echo "Token opgeslagen. Herstart de app (of draai: bash ~/.klonkt-start.sh)."
EOF
chmod +x "$PREFIX/bin/klonkt-token"

echo "=== 4/4 Autostart bij telefoon-herstart (Termux:Boot) ==="
mkdir -p ~/.termux/boot
cat << 'EOF' > ~/.termux/boot/start-klonkt.sh
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
[ -f ~/.klonkt-start.sh ] && bash ~/.klonkt-start.sh
EOF
chmod +x ~/.termux/boot/start-klonkt.sh

echo "=== Setup voltooid! Klonkt wordt gestart... ==="
