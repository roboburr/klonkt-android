#!/usr/bin/env bash

# Setup Script voor Klonkt-Node in Termux op Android

echo "=== 1. Termux Pakketten Updaten & Installeren ==="
pkg update && pkg upgrade -y
pkg install -y nodejs-lts python build-essential git openssh termux-api

echo "=== 2. Toegang voor Externe Apps (zoals de Klonkt App) Inschakelen ==="
mkdir -p ~/.termux
if ! grep -q "allow-external-apps" ~/.termux/termux.properties; then
    echo "allow-external-apps = true" >> ~/.termux/termux.properties
fi
termux-reload-settings

echo "=== 3. Klonkt Node.js Bestanden Ophalen ==="
# Check if offline installation folder exists
if [ -d "/storage/emulated/0/Download/klonkt-node" ]; then
    echo "Offline installatiebestanden gevonden in Download map!"
    echo "Kopiëren van bestanden naar ~/klonkt-node..."
    rm -rf ~/klonkt-node
    cp -r /storage/emulated/0/Download/klonkt-node ~/
    rm -f ~/klonkt-node/setup-termux-klonkt.sh
else
    echo "Geen offline bestanden gevonden. We gaan clonen van je VPS..."
    rm -rf ~/klonkt-node
    git clone roboburr@91.98.142.161:/home/roboburr/apps/klonkt-demo ~/klonkt-node
fi

echo "=== 4. SSH-sleutel controleren of genereren ==="
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "Geen SSH-sleutel gevonden. Nieuwe sleutel genereren..."
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    echo "Nieuwe SSH-sleutel gegenereerd!"
fi
echo "Je publieke SSH-sleutel is:"
cat ~/.ssh/id_ed25519.pub
echo "------------------------------------------------"
echo "TIP: Voeg de bovenstaande sleutel toe aan je VPS/GitHub als je git clone wilt gebruiken."

echo "=== 5. Automatische start bij opstarten telefoon (Termux:Boot) ==="
mkdir -p ~/.termux/boot
cat << 'EOF' > ~/.termux/boot/start-klonkt.sh
#!/data/data/com.termux/files/usr/bin/sh
# Schakel wake lock in om te voorkomen dat Android de server slaapt
termux-wake-lock
cd ~/klonkt-node
npm run start &
ssh -R 80:localhost:3020 a.pinggy.io
EOF
chmod +x ~/.termux/boot/start-klonkt.sh
echo "Termux:Boot startscript aangemaakt in ~/.termux/boot/start-klonkt.sh"

echo "=== 6. Node Modules Installeren (dit compileert SQLite voor Android) ==="
cd ~/klonkt-node
npm install

echo "=== Setup Voltooid! ==="
echo "Je kunt nu de Klonkt APK openen op je telefoon."
echo "Zorg ervoor dat Termux open staat in de achtergrond."
