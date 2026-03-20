#!/bin/sh
set -e

echo "Descargando duck-keyboard..."
# Asumiendo que hostearás el .tar.gz en github releases. A modo de ejemplo:
# curl -L -o duck-keyboard.tar.gz "https://github.com/andexer/duck-keyboard/releases/latest/download/duck-keyboard.linux-amd64.tar.gz"
# Por ahora instalamos el que compilemos localmente o asumimos que ya está compilado si se corre desde el source.

if [ ! -f "target/release/duck-keyboard" ]; then
    echo "Compilando proyecto..."
    cargo build --release
fi

echo "Instalando binario..."
sudo install -m 755 target/release/duck-keyboard /usr/local/bin/duck-keyboard

echo "Instalando servicio systemd..."
sudo cp duck-keyboard.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable duck-keyboard
sudo systemctl restart duck-keyboard

echo "¡Instalado con éxito! El teclado de pato está al acecho..."
