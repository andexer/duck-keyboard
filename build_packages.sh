#!/bin/sh
set -e

echo "Compilando binario de release..."
cargo build --release --locked

echo "Generando tar.gz..."
tar -czf duck-keyboard-linux-amd64.tar.gz -C target/release duck-keyboard
echo "Creado duck-keyboard-linux-amd64.tar.gz"

echo "Para empaquetado completo multiplataforma usa './build_all.sh'."
