#!/bin/bash
set -e

echo "Iniciando proceso de empaquetado y subida múltiple..."
mkdir -p releases
rm -f releases/duck-keyboard-amd64.deb
rm -f releases/duck-keyboard-x86_64.rpm
rm -f releases/duck-keyboard-x86_64.pkg.tar.zst
rm -f releases/duck-keyboard-linux-amd64.tar.gz
rm -f releases/duck-keyboard-windows-amd64.exe
rm -f releases/duck-keyboard_*.deb
rm -f releases/duck-keyboard-*.rpm

echo "1. Construyendo binario nativo (Linux x86_64)..."
cargo build --release --locked
tar -czf releases/duck-keyboard-linux-amd64.tar.gz -C target/release duck-keyboard
echo "-> Creado duck-keyboard-linux-amd64.tar.gz en releases/"

echo "2. Instalando cargo-deb (si no está instalado)..."
if ! command -v cargo-deb &> /dev/null; then
    cargo install cargo-deb
fi
echo "Empaquetando .deb..."
cargo deb --output releases/duck-keyboard-amd64.deb
echo "-> Creado paquete .deb en releases/duck-keyboard-amd64.deb"

echo "3. Instalando cargo-generate-rpm (si no está instalado)..."
if ! command -v cargo-generate-rpm &> /dev/null; then
    cargo install cargo-generate-rpm
fi
echo "Empaquetando .rpm..."
strip -s target/release/duck-keyboard
cargo generate-rpm -o releases/duck-keyboard-x86_64.rpm
echo "-> Creado paquete .rpm en releases/duck-keyboard-x86_64.rpm"

echo "4. Empaquetando .pkg.tar.zst para Arch/Manjaro si makepkg está disponible..."
if command -v makepkg &> /dev/null; then
    rm -f ./*.pkg.tar.zst
    makepkg -sf --noconfirm
    arch_pkg=$(find . -maxdepth 1 -type f -name 'duck-keyboard-*.pkg.tar.zst' | head -n 1)
    if [ -n "$arch_pkg" ]; then
        cp "$arch_pkg" releases/duck-keyboard-x86_64.pkg.tar.zst
        echo "-> Creado paquete Arch en releases/duck-keyboard-x86_64.pkg.tar.zst"
    else
        echo "ADVERTENCIA: makepkg terminó, pero no se encontró el paquete generado."
    fi
else
    echo "ADVERTENCIA: No se encontró 'makepkg'. Omite el paquete Arch."
fi

echo "5. Revisando compatibilidad para compilación cruzada hacia Windows (.exe)..."
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
