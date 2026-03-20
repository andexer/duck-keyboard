#!/bin/bash
# Pre-uninstall: matar daemon y limpiar autostart
pkill -f "duck-keyboard daemon" 2>/dev/null || true
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null)}"
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    REAL_HOME=$(eval echo "~$REAL_USER")
    rm -f "$REAL_HOME/.config/autostart/duck-keyboard.desktop"
fi
# Tambien limpiar para todos los usuarios por si acaso
rm -f /home/*/.config/autostart/duck-keyboard.desktop 2>/dev/null
killall duck-keyboard 2>/dev/null || true
exit 0
