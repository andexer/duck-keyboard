#!/bin/sh
set -eu

ACTION="${1:-}"
BINARY_PATH="${2:-/usr/bin/duck-keyboard}"
AUTOSTART_MODE="${3:-package}"
AUTOSTART_FILE="/etc/xdg/autostart/duck-keyboard.desktop"

log() {
    printf '%s\n' "$1"
}

user_in_input_group() {
    id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "input"
}

ensure_input_group() {
    if ! getent group input >/dev/null 2>&1 && command -v groupadd >/dev/null 2>&1; then
        groupadd --system input >/dev/null 2>&1 || true
    fi
}

detect_real_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
        printf '%s\n' "$SUDO_USER"
        return 0
    fi

    if [ -n "${PKEXEC_UID:-}" ]; then
        id -nu "$PKEXEC_UID" 2>/dev/null && return 0
    fi

    if command -v logname >/dev/null 2>&1; then
        user_name="$(logname 2>/dev/null || true)"
        if [ -n "$user_name" ] && [ "$user_name" != "root" ]; then
            printf '%s\n' "$user_name"
            return 0
        fi
    fi

    if [ -e /dev/console ]; then
        user_name="$(stat -c %U /dev/console 2>/dev/null || true)"
        if [ -n "$user_name" ] && [ "$user_name" != "root" ] && [ "$user_name" != "UNKNOWN" ]; then
            printf '%s\n' "$user_name"
            return 0
        fi
    fi

    if command -v loginctl >/dev/null 2>&1; then
        user_name="$(loginctl list-users --no-legend 2>/dev/null | awk '$2 != "root" { print $2; exit }')"
        if [ -n "$user_name" ]; then
            printf '%s\n' "$user_name"
            return 0
        fi
    fi

    user_name="$(awk -F: '$3 >= 1000 && $1 != "nobody" && $7 !~ /(nologin|false)$/ { print $1; exit }' /etc/passwd)"
    if [ -n "$user_name" ]; then
        printf '%s\n' "$user_name"
        return 0
    fi

    return 1
}

user_home_dir() {
    getent passwd "$1" | cut -d: -f6
}

session_pid_for_user() {
    user_name="$1"
    if ! command -v pgrep >/dev/null 2>&1; then
        return 1
    fi

    pid="$(pgrep -u "$user_name" -f 'gnome-session|plasmashell|startplasma|xfce4-session|cinnamon-session|mate-session|lxqt-session|Xwayland|Xorg' 2>/dev/null | tail -n 1 || true)"
    if [ -n "$pid" ]; then
        printf '%s\n' "$pid"
        return 0
    fi

    return 1
}

read_env_value() {
    pid="$1"
    key="$2"
    tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n "s/^${key}=//p" | head -n 1
}

write_system_autostart() {
    mkdir -p "$(dirname "$AUTOSTART_FILE")"
    cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Exec=$BINARY_PATH daemon
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Duck Keyboard
Comment=Reproduce sonidos de pato al presionar cualquier tecla
EOF
}

remove_system_autostart() {
    rm -f "$AUTOSTART_FILE"
}

stop_running_daemons() {
    if command -v pkill >/dev/null 2>&1; then
        pkill -f 'duck-keyboard daemon' 2>/dev/null || true
    fi

    if command -v killall >/dev/null 2>&1; then
        killall duck-keyboard 2>/dev/null || true
    fi
}

start_for_user() {
    user_name="$1"
    binary_path="$2"
    pid="$(session_pid_for_user "$user_name" || true)"
    if [ -z "$pid" ]; then
        return 1
    fi

    home_dir="$(user_home_dir "$user_name")"
    uid="$(id -u "$user_name")"
    display="$(read_env_value "$pid" DISPLAY)"
    wayland_display="$(read_env_value "$pid" WAYLAND_DISPLAY)"
    dbus_address="$(read_env_value "$pid" DBUS_SESSION_BUS_ADDRESS)"
    xauthority="$(read_env_value "$pid" XAUTHORITY)"
    runtime_dir="$(read_env_value "$pid" XDG_RUNTIME_DIR)"

    if [ -z "$runtime_dir" ] && [ -d "/run/user/$uid" ]; then
        runtime_dir="/run/user/$uid"
    fi

    if [ -z "$display" ] && [ -z "$wayland_display" ]; then
        return 1
    fi

    stop_running_daemons

    runuser -u "$user_name" -- env \
        HOME="$home_dir" \
        USER="$user_name" \
        LOGNAME="$user_name" \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        DISPLAY="$display" \
        WAYLAND_DISPLAY="$wayland_display" \
        DBUS_SESSION_BUS_ADDRESS="$dbus_address" \
        XAUTHORITY="$xauthority" \
        XDG_RUNTIME_DIR="$runtime_dir" \
        "$binary_path" daemon >/dev/null 2>&1 &
}

post_install() {
    user_name=""
    if [ "$AUTOSTART_MODE" = "write-autostart" ]; then
        write_system_autostart
    fi

    ensure_input_group
    user_name="$(detect_real_user || true)"
    if [ -z "$user_name" ]; then
        log "Duck Keyboard fue instalado. No pude detectar el usuario de escritorio para agregarlo al grupo input."
        log "Si no responde al teclado, agrega tu usuario manualmente con: sudo usermod -aG input <tu_usuario>"
        return 0
    fi

    had_input_group="yes"
    if ! user_in_input_group "$user_name"; then
        had_input_group="no"
        usermod -aG input "$user_name" 2>/dev/null || true
    fi

    if start_for_user "$user_name" "$BINARY_PATH"; then
        log "Duck Keyboard quedó instalado y se intentó iniciar en la sesión de $user_name."
    else
        log "Duck Keyboard quedó instalado y arrancará automáticamente al iniciar sesión."
    fi

    if [ "$had_input_group" = "no" ]; then
        log "Tu usuario fue agregado al grupo input. Si el teclado no responde de inmediato, cierra sesión y vuelve a entrar."
    fi
}

pre_remove() {
    stop_running_daemons
    if [ "$AUTOSTART_MODE" = "write-autostart" ]; then
        remove_system_autostart
    fi
}

case "$ACTION" in
    post-install)
        post_install
        ;;
    pre-remove)
        pre_remove
        ;;
    *)
        echo "Uso: $0 {post-install|pre-remove} [ruta_binario] [write-autostart]" >&2
        exit 1
        ;;
esac
