# Duck Keyboard

Una aplicacion de broma que reproduce sonidos de pato de manera aleatoria sin repetirse al presionar cualquier tecla del teclado.

## Caracteristicas
- Creada 100% en Rust.
- Audio pre-decodificado en RAM para velocidad maxima.
- Cada tecla dispara un sonido de pato en paralelo.
- Ejecutable unico, portable y auto-contenido (los MP3 estan embebidos en el binario).
- Los paquetes configuran autostart global al instalarse.
- Incluye instalador y desinstalador por `curl`.

## Instalacion rapida
Instalacion automatica desde el repositorio:
```bash
curl -fsSL https://raw.githubusercontent.com/andexer/duck-keyboard/main/install.sh | sh
```

Desinstalacion automatica:
```bash
curl -fsSL https://raw.githubusercontent.com/andexer/duck-keyboard/main/uninstall.sh | sh
```

El instalador detecta tu distro, intenta usar el paquete nativo (`.deb`, `.rpm` o `.pkg.tar.zst`)
y, si no lo encuentra, hace fallback a compilacion desde codigo fuente.

## Instalacion por paquete
### Debian/Ubuntu (.deb)
```bash
sudo apt install ./duck-keyboard-amd64.deb
```

### Fedora/RHEL (.rpm)
```bash
sudo dnf install ./duck-keyboard-x86_64.rpm
```

### Arch/Manjaro (.pkg.tar.zst)
```bash
sudo pacman -U ./duck-keyboard-x86_64.pkg.tar.zst
```

Con Pamac:
```bash
pamac install ./duck-keyboard-x86_64.pkg.tar.zst
```

Con Yay:
```bash
yay -U ./duck-keyboard-x86_64.pkg.tar.zst
```

## Que hace la instalacion
Los paquetes y el instalador automatico intentan:
1. Instalar el binario en el sistema.
2. Crear autostart global en `/etc/xdg/autostart/`.
3. Detectar tu usuario de escritorio y agregarlo al grupo `input`.
4. Intentar arrancar el daemon inmediatamente.

Si tu usuario acaba de ser agregado al grupo `input`, puede que necesites cerrar sesion y volver a entrar
para que la captura global del teclado funcione por completo.

## Desinstalacion
En Debian/Ubuntu:
```bash
sudo apt remove duck-keyboard
```

En Fedora/RHEL:
```bash
sudo dnf remove duck-keyboard
```

En Arch/Manjaro:
```bash
sudo pacman -Rns duck-keyboard
```

## Uso manual (sin paquete)
```bash
cargo build --release --locked
./target/release/duck-keyboard install   # Modo local por usuario
./target/release/duck-keyboard uninstall # Limpia modo local por usuario
./target/release/duck-keyboard daemon    # Ejecuta en primer plano (debug)
```

## Compilar paquetes
```bash
./build_all.sh
# Genera .deb, .rpm, .pkg.tar.zst y .tar.gz en releases/
```

## Requisitos
- Grupo `input` o una sesion donde `rdev` pueda capturar teclas globales.
- Sesion grafica con X11 o XWayland.
- Servidor de audio PulseAudio, PipeWire o ALSA compatible.
