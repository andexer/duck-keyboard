# Duck Keyboard

Una aplicacion de broma que reproduce sonidos de pato de manera aleatoria sin repetirse al presionar cualquier tecla en el teclado.

## Caracteristicas
- Creada 100% en Rust.
- Utiliza escuchas globales de teclado.
- Embebe audios directamente en el binario sin depender de archivos externos.
- Genera ejecutables multiplataforma.
- Reduccion de privilegios por politica de seguridad en UNIX.

## Instalacion manual (Linux)
Se puede utilizar el instalador o construir directamente a traves de los administradores de paquetes si configuras tu sistema localmente.

### Uso
Para ejecutar como demonio por defecto:
```bash
./duck-keyboard daemon
```

Otras tareas validas:
```bash
./duck-keyboard install
./duck-keyboard uninstall
./duck-keyboard --version
./duck-keyboard --help
```

### Seguridad
Esta es una aplicacion de broma disenyada bajo el conocimiento seguro. Siempre puedes desinstalarla mediante las instrucciones. 
Los binarios se ejecutan como usuario "nobody" despues de arrancar.
