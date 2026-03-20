#!/bin/bash
# Post-install: configurar autostart y agregar al grupo input
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null)}"
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    REAL_HOME=$(eval echo "~$REAL_USER")
    # Agregar al grupo input para que rdev pueda leer /dev/input
    usermod -aG input "$REAL_USER" 2>/dev/null || true
    # Crear autostart
    AUTOSTART_DIR="$REAL_HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_DIR/duck-keyboard.desktop" << EOF
[Desktop Entry]
Type=Application
Exec=/usr/bin/duck-keyboard daemon
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Duck Keyboard
EOF
    chown "$REAL_USER:$REAL_USER" "$AUTOSTART_DIR/duck-keyboard.desktop"
    # Intentar arrancar ahora como el usuario real
    su - "$REAL_USER" -c "nohup /usr/bin/duck-keyboard daemon &>/dev/null &" 2>/dev/null || true
fi
exit 0
