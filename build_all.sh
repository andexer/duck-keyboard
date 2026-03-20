#!/bin/bash
set -e

echo "Iniciando proceso de empaquetado y subida múltiple..."
mkdir -p releases

echo "1. Construyendo binario nativo (Linux x86_64)..."
cargo build --release
tar -czf releases/duck-keyboard-linux-amd64.tar.gz -C target/release duck-keyboard
echo "-> Creado duck-keyboard-linux-amd64.tar.gz en releases/"

echo "2. Instalando cargo-deb (si no está instalado)..."
if ! command -v cargo-deb &> /dev/null; then
    cargo install cargo-deb
fi
echo "Empaquetando .deb..."
cargo deb
cp target/debian/*.deb releases/ || true
echo "-> Creado paquete .deb en releases/"

echo "3. Instalando cargo-generate-rpm (si no está instalado)..."
if ! command -v cargo-generate-rpm &> /dev/null; then
    cargo install cargo-generate-rpm
fi
echo "Empaquetando .rpm..."
strip -s target/release/duck-keyboard
cargo generate-rpm -o releases/
echo "-> Creado paquete .rpm en releases/"

echo "4. Revisando compatibilidad para compilación cruzada hacia Windows (.exe)..."
if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
    echo "Compilador Windows detectado. Empaquetando .exe..."
    rustup target add x86_64-pc-windows-gnu
    cargo build --release --target x86_64-pc-windows-gnu
    cp target/x86_64-pc-windows-gnu/release/duck-keyboard.exe releases/duck-keyboard-windows-amd64.exe
    echo "-> Creado paquete Windows (.exe) en releases/"
else
    echo "ADVERTENCIA: No se encontró 'x86_64-w64-mingw32-gcc'. Omita Windows .exe."
    echo "Puedes instalarlo en Fedora ejecutando: sudo dnf install mingw64-gcc"
fi

echo "============================================="
echo "COMPILACIÓN FINALIZADA"
echo "Todos tus paquetes disponibles están en la carpeta 'releases/' listos para ser testeados."
ls -lh releases/
