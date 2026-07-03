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
    # Android forbids hard links; older tarballs contained hard-linked build junk.
    # Tolerate tar's exit status and verify the essentials instead.
    tar -xzf klonkt-node.tar.gz 2>/dev/null || true
    rm -f klonkt-node.tar.gz
    if [ ! -f klonkt-node/package.json ] || [ ! -f klonkt-node/node_modules/better-sqlite3/build/Release/better_sqlite3.node ]; then
        echo "CRITISCHE FOUT: download onvolledig. Probeer opnieuw: bash ~/.klonkt-start.sh"
        exit 1
    fi
    echo "Voorgebouwde Klonkt geinstalleerd - geen compilatie nodig."
else
    echo "CRITISCHE FOUT: kan de voorgebouwde Klonkt niet downloaden."
    echo "Controleer je internetverbinding en probeer opnieuw: bash ~/.klonkt-start.sh"
    exit 1
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
