#!/bin/sh

echo "Deteniendo servicio..."
sudo systemctl stop duck-keyboard || true
sudo systemctl disable duck-keyboard || true
sudo rm -f /etc/systemd/system/duck-keyboard.service
sudo systemctl daemon-reload

echo "Eliminando binario..."
sudo rm -f /usr/local/bin/duck-keyboard

echo "Duck Keyboard desinstalado exitosamente."
