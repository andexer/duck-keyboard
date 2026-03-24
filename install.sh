#!/bin/sh
set -eu

APP_NAME="duck-keyboard"
REPO_URL="https://github.com/andexer/duck-keyboard"
RAW_BASE="https://raw.githubusercontent.com/andexer/duck-keyboard/main"
RELEASE_BASE="$REPO_URL/releases/latest/download"
SOURCE_TARBALL="$REPO_URL/archive/refs/heads/main.tar.gz"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

run_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "Necesitas root para instalar $APP_NAME y no se encontró sudo." >&2
        exit 1
    fi
}

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Falta el comando requerido: $1" >&2
        exit 1
    fi
}

download_to() {
    need_cmd curl
    curl -fsSL "$1" -o "$2"
}

install_deb() {
    pkg="$TMPDIR/$APP_NAME-amd64.deb"
    download_to "$RELEASE_BASE/$APP_NAME-amd64.deb" "$pkg"
    if command -v apt-get >/dev/null 2>&1; then
        run_root apt-get install -y "$pkg"
    else
        run_root dpkg -i "$pkg"
    fi
}

install_rpm() {
    pkg="$TMPDIR/$APP_NAME-x86_64.rpm"
    download_to "$RELEASE_BASE/$APP_NAME-x86_64.rpm" "$pkg"
    if command -v dnf >/dev/null 2>&1; then
        run_root dnf install -y "$pkg"
    else
        run_root rpm -Uvh "$pkg"
    fi
}

install_arch_package() {
    pkg="$TMPDIR/$APP_NAME-x86_64.pkg.tar.zst"
    download_to "$RELEASE_BASE/$APP_NAME-x86_64.pkg.tar.zst" "$pkg"
    run_root pacman -U --noconfirm "$pkg"
}

install_build_deps() {
    if command -v apt-get >/dev/null 2>&1; then
        run_root apt-get update
        run_root apt-get install -y build-essential cargo pkg-config libasound2-dev libx11-dev libxtst-dev libxi-dev
        return
    fi

    if command -v dnf >/dev/null 2>&1; then
        run_root dnf install -y cargo gcc alsa-lib-devel libX11-devel libXtst-devel libXi-devel
        return
    fi

    if command -v pacman >/dev/null 2>&1; then
        run_root pacman -S --needed --noconfirm base-devel cargo alsa-lib libx11 libxtst libxi
        return
    fi

    echo "No pude detectar un gestor de paquetes compatible para instalar dependencias de compilación." >&2
    exit 1
}

fallback_source_install() {
    src_tar="$TMPDIR/$APP_NAME-source.tar.gz"
    src_dir="$TMPDIR/src"
    helper="$TMPDIR/system-setup.sh"

    echo "No encontré un paquete nativo listo. Haré instalación desde código fuente."
    install_build_deps
    download_to "$SOURCE_TARBALL" "$src_tar"
    mkdir -p "$src_dir"
    tar -xzf "$src_tar" -C "$src_dir" --strip-components=1

    need_cmd cargo
    cargo build --release --locked --manifest-path "$src_dir/Cargo.toml"

    run_root install -Dm755 "$src_dir/target/release/$APP_NAME" "/usr/local/bin/$APP_NAME"
    download_to "$RAW_BASE/packaging/system-setup.sh" "$helper"
    chmod +x "$helper"
    run_root "$helper" post-install "/usr/local/bin/$APP_NAME" write-autostart
}

main() {
    arch="$(uname -m)"
    if [ "$arch" != "x86_64" ]; then
        echo "Solo x86_64 está soportado por ahora. Arquitectura detectada: $arch" >&2
        exit 1
    fi

    if command -v pacman >/dev/null 2>&1; then
        if install_arch_package; then
            return
        fi
    fi

    if command -v apt-get >/dev/null 2>&1 || command -v dpkg >/dev/null 2>&1; then
        if install_deb; then
            return
        fi
    fi

    if command -v dnf >/dev/null 2>&1 || command -v rpm >/dev/null 2>&1; then
        if install_rpm; then
            return
        fi
    fi

    fallback_source_install
}

main "$@"
