#!/usr/bin/env bash

# Setup Script voor Klonkt-Node in Termux op Android

echo "=== 1. Termux Pakketten Updaten & Installeren ==="
pkg update && pkg upgrade -y
pkg install -y nodejs-lts python build-essential git openssh

echo "=== 2. Toegang voor Externe Apps (zoals de Klonkt App) Inschakelen ==="
mkdir -p ~/.termux
# Zorg dat de optie uniek wordt toegevoegd
if ! grep -q "allow-external-apps" ~/.termux/termux.properties; then
    echo "allow-external-apps = true" >> ~/.termux/termux.properties
fi
termux-reload-settings

echo "=== 3. Klonkt Node.js Bestanden Ophalen ==="
echo "We gaan de Klonkt-bestanden van je VPS clonen naar ~/klonkt-node..."
mkdir -p ~/klonkt-node
git clone roboburr@91.98.142.161:/home/roboburr/apps/klonkt-demo ~/klonkt-node

echo "=== 4. Node Modules Installeren (dit compileert SQLite voor Android) ==="
cd ~/klonkt-node
npm install

echo "=== Setup Voltooid! ==="
echo "Je kunt nu de Klonkt APK installeren en openen op je telefoon."
echo "Zorg er wel voor dat je je SSH-sleutel (id_ed25519) ook in Termux hebt staan (~/.ssh/id_ed25519) zodat de Pinggy tunnel en git clone werken."
