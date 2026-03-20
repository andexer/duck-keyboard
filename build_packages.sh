#!/bin/sh
set -e

echo "Compilando binario de release..."
cargo build --release

echo "Generando tar.gz..."
tar -czf duck-keyboard-linux-amd64.tar.gz -C target/release duck-keyboard
echo "Creado duck-keyboard-linux-amd64.tar.gz"

echo "Revisa Cargo.toml para construir .deb o .rpm vía 'cargo deb' o 'cargo rpm'."
echo "Para Windows: cargo build --release --target x86_64-pc-windows-gnu (requiere mingw-w64)"
