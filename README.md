# Duck Keyboard

Una aplicacion de broma que reproduce sonidos de pato de manera aleatoria sin repetirse al presionar cualquier tecla del teclado.

## Caracteristicas
- Creada 100% en Rust.
- Audio pre-decodificado en RAM para velocidad maxima.
- Cada tecla dispara un sonido de pato en paralelo.
- Ejecutable unico, portable y auto-contenido (los MP3 estan embebidos en el binario).

## Instalacion (Fedora/RHEL)
```bash
sudo dnf install ./duck-keyboard-0.1.0-1.x86_64.rpm
```
Eso es todo. Al instalar el paquete:
1. Se agrega tu usuario al grupo `input` (necesario para capturar teclas).
2. Se crea un archivo de autostart en tu sesion.
3. Se lanza el daemon inmediatamente.

**Despues de instalar, cierra sesion y vuelve a entrar** para que el grupo `input` tome efecto completo.

## Desinstalacion
```bash
sudo dnf remove duck-keyboard
```
El paquete mata todos los procesos de pato automaticamente al desinstalarse.

## Uso manual (sin paquete)
```bash
cargo build --release
./target/release/duck-keyboard install   # Instala, configura y arranca
./target/release/duck-keyboard uninstall # Detiene todo y limpia
./target/release/duck-keyboard daemon    # Ejecuta en primer plano (debug)
```

## Compilar paquetes
```bash
./build_all.sh
# Genera .rpm, .deb y .tar.gz en releases/
```

## Requisitos
- Grupo `input` (el instalador lo configura automaticamente).
- Sesion grafica con X11 o XWayland (Fedora usa XWayland por defecto).
- Servidor de audio PulseAudio o PipeWire (incluidos en Fedora).
