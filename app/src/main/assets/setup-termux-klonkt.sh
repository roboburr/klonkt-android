#!/usr/bin/env bash

# Setup Script voor Klonkt-Node in Termux op Android

echo "=== 1. Termux Pakketten Updaten & Installeren ==="
pkg update && pkg upgrade -y
pkg install -y nodejs-lts python build-essential git openssh termux-api unzip

echo "=== 2. Toegang voor Externe Apps (zoals de Klonkt App) Inschakelen ==="
mkdir -p ~/.termux
if ! grep -q "allow-external-apps" ~/.termux/termux.properties; then
    echo "allow-external-apps = true" >> ~/.termux/termux.properties
fi
termux-reload-settings

echo "=== 3. Klonkt Node.js Bestanden Ophalen ==="
echo "Bestanden worden gedownload van de Klonkt app..."
rm -rf ~/klonkt-node
mkdir -p ~/klonkt-node

# Download zip file directly from the running Klonkt app's local HTTP server
if curl -f -s "http://127.0.0.1:3021/klonkt-node.zip" -o ~/klonkt-node.zip; then
    echo "Bestanden succesvol gedownload via lokale app. Uitpakken..."
    unzip -q -o ~/klonkt-node.zip -d ~/klonkt-node
    rm ~/klonkt-node.zip
else
    echo "Fout bij lokaal downloaden (Klonkt staat niet open of is op de achtergrond afgesloten)."
    echo "We vallen terug op de officiële GitHub release..."
    if curl -f -L -s "https://github.com/roboburr/klonkt-android/releases/latest/download/klonkt-node.zip" -o ~/klonkt-node.zip; then
        echo "GitHub fallback succesvol! Uitpakken..."
        unzip -q -o ~/klonkt-node.zip -d ~/klonkt-node
        rm ~/klonkt-node.zip
    else
        echo "CRITISCHE FOUT: Kan ook niet van GitHub downloaden. Controleer je internetverbinding."
        exit 1
    fi
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
# Fix voor node-gyp (better-sqlite3) op Termux die zoekt naar een missende android_ndk_path variabele
export GYP_DEFINES="android_ndk_path=''"

cd ~/klonkt-node
npm install

echo "=== Setup Voltooid! ==="
echo "Je kunt nu de Klonkt APK openen op je telefoon."
echo "Zorg ervoor dat Termux open staat in de achtergrond."
