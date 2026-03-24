#!/bin/sh
set -eu

APP_NAME="duck-keyboard"
RAW_BASE="https://raw.githubusercontent.com/andexer/duck-keyboard/main"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

run_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "Necesitas root para desinstalar $APP_NAME y no se encontró sudo." >&2
        exit 1
    fi
}

download_to() {
    curl -fsSL "$1" -o "$2"
}

remove_deb() {
    if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W -f='${Status}' "$APP_NAME" 2>/dev/null | grep -q "install ok installed"; then
        if command -v apt-get >/dev/null 2>&1; then
            run_root apt-get remove -y "$APP_NAME"
        else
            run_root dpkg -r "$APP_NAME"
        fi
        return 0
    fi
    return 1
}

remove_rpm() {
    if command -v rpm >/dev/null 2>&1 && rpm -q "$APP_NAME" >/dev/null 2>&1; then
        if command -v dnf >/dev/null 2>&1; then
            run_root dnf remove -y "$APP_NAME"
        else
            run_root rpm -e "$APP_NAME"
        fi
        return 0
    fi
    return 1
}

remove_arch() {
    if command -v pacman >/dev/null 2>&1 && pacman -Q "$APP_NAME" >/dev/null 2>&1; then
        run_root pacman -Rns --noconfirm "$APP_NAME"
        return 0
    fi
    return 1
}

remove_local_install() {
    helper="$TMPDIR/system-setup.sh"
    download_to "$RAW_BASE/packaging/system-setup.sh" "$helper"
    chmod +x "$helper"

    if [ -x "/usr/local/bin/$APP_NAME" ]; then
        run_root "$helper" pre-remove "/usr/local/bin/$APP_NAME" write-autostart
        run_root rm -f "/usr/local/bin/$APP_NAME"
        echo "$APP_NAME fue removido de /usr/local/bin."
        return 0
    fi

    return 1
}

main() {
    if remove_arch || remove_deb || remove_rpm || remove_local_install; then
        return
    fi

    echo "No encontré una instalación conocida de $APP_NAME." >&2
    exit 1
}

main "$@"
