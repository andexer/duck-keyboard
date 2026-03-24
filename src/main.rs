use anyhow::{Result, anyhow, ensure};
use clap::{Parser, Subcommand};
use rand::Rng;
use rdev::{EventType, listen};
use rodio::{Decoder, OutputStream, OutputStreamHandle, Sink, Source};
use rust_embed::RustEmbed;
use std::cell::RefCell;
use std::io::Cursor;
use std::process::Command;

#[derive(RustEmbed)]
#[folder = "assets/"]
struct Assets;

/// Audio pre-decodificado en memoria RAM para cero latencia.
struct PreloadedSound {
    channels: u16,
    sample_rate: u32,
    samples: Vec<i16>,
}

/// El stream vive en el mismo hilo que `listen`, asi evitamos `unsafe`
/// y tambien evitamos crear un hilo efimero por cada tecla.
struct AppState {
    _stream: OutputStream,
    stream_handle: OutputStreamHandle,
    last_played: Option<usize>,
    sounds: Vec<PreloadedSound>,
}

#[derive(Parser)]
#[command(version, about = "Duck Keyboard Prank", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    Install,
    Uninstall,
    #[command(hide = true)]
    Daemon,
}

fn init_audio() -> Result<AppState> {
    let (stream, stream_handle) = OutputStream::try_default()?;

    let mut sounds = Vec::new();
    for i in 1..=4 {
        let filename = format!("audio/effect-duck-{}.mp3", i);
        if let Some(asset) = Assets::get(&filename) {
            let cursor = Cursor::new(asset.data.into_owned());
            if let Ok(source) = Decoder::new_mp3(cursor) {
                let channels = source.channels();
                let sample_rate = source.sample_rate();
                let samples: Vec<i16> = source.into_iter().collect();
                sounds.push(PreloadedSound {
                    channels,
                    sample_rate,
                    samples,
                });
            }
        }
    }

    ensure!(
        !sounds.is_empty(),
        "No se encontraron sonidos de pato embebidos en el binario."
    );

    Ok(AppState {
        _stream: stream,
        stream_handle,
        last_played: None,
        sounds,
    })
}

fn choose_next_sound_index(sound_count: usize, last_played: Option<usize>) -> Option<usize> {
    if sound_count == 0 {
        return None;
    }

    if sound_count == 1 {
        return Some(0);
    }

    let mut rng = rand::thread_rng();
    let mut next = rng.gen_range(0..sound_count);

    if Some(next) == last_played {
        next = (next + 1 + rng.gen_range(0..(sound_count - 1))) % sound_count;
    }

    Some(next)
}

/// Reproduce un pato aleatorio sin repetir el ultimo si hay varias opciones.
/// Cada evento crea su propio `Sink`, pero sin lanzar hilos nuevos.
fn play_random_duck(state: &mut AppState) {
    let Some(idx) = choose_next_sound_index(state.sounds.len(), state.last_played) else {
        return;
    };

    state.last_played = Some(idx);

    let sound = &state.sounds[idx];
    let buffer =
        rodio::buffer::SamplesBuffer::new(sound.channels, sound.sample_rate, sound.samples.clone());

    if let Ok(sink) = Sink::try_new(&state.stream_handle) {
        sink.append(buffer);
        sink.detach();
    }
}

fn install() -> Result<()> {
    println!("Instalando Duck Keyboard...");

    // Verificar que el usuario tenga acceso a /dev/input (grupo input)
    let user = std::env::var("USER").unwrap_or_default();
    let groups_output = Command::new("groups").output();
    let in_input_group = groups_output
        .map(|o| String::from_utf8_lossy(&o.stdout).contains("input"))
        .unwrap_or(false);

    if !in_input_group {
        println!("NOTA: Tu usuario no esta en el grupo 'input'.");
        println!("Esto es necesario para capturar las teclas del teclado.");
        let _ = Command::new("sudo")
            .args(["usermod", "-aG", "input", &user])
            .status();
        println!("Se agrego '{}' al grupo 'input'.", user);
        println!("IMPORTANTE: Debes cerrar sesion y volver a entrar para que tome efecto.");
    }

    let home = std::env::var("HOME").unwrap_or_default();
    if home.is_empty() {
        anyhow::bail!("No se pudo ubicar el directorio HOME.");
    }
    let autostart_dir = format!("{}/.config/autostart", home);
    std::fs::create_dir_all(&autostart_dir)?;
    let desktop_file = format!("{}/duck-keyboard.desktop", autostart_dir);
    let current_exe = std::env::current_exe()?;
    let desktop_content = format!(
        "[Desktop Entry]\n\
         Type=Application\n\
         Exec={} daemon\n\
         Hidden=false\n\
         NoDisplay=false\n\
         X-GNOME-Autostart-enabled=true\n\
         Name=Duck Keyboard\n",
        current_exe.display()
    );
    std::fs::write(&desktop_file, desktop_content)?;

    // Matar instancias previas antes de lanzar una nueva
    let _ = Command::new("pkill")
        .arg("-f")
        .arg("duck-keyboard daemon")
        .status();
    Command::new(current_exe).arg("daemon").spawn()?;

    println!("Instalado. El pato esta corriendo en background.");
    if !in_input_group {
        println!("Recuerda: cierra sesion y vuelve a entrar para que funcione al 100%.");
    }
    Ok(())
}

fn uninstall() -> Result<()> {
    println!("Desinstalando Duck Keyboard...");
    let home = std::env::var("HOME").unwrap_or_default();
    if !home.is_empty() {
        let desktop_file = format!("{}/.config/autostart/duck-keyboard.desktop", home);
        let _ = std::fs::remove_file(&desktop_file);
    }

    // Matar TODOS los procesos de duck-keyboard daemon
    let _ = Command::new("pkill")
        .arg("-f")
        .arg("duck-keyboard daemon")
        .status();
    // Segundo intento por si acaso
    let _ = Command::new("killall").arg("duck-keyboard").status();

    println!("Desinstalado correctamente. El pato ha muerto.");
    Ok(())
}

fn run_daemon() -> Result<()> {
    let state = RefCell::new(init_audio().map_err(|e| {
        eprintln!("No se pudo inicializar el sistema de audio: {:?}", e);
        e
    })?);

    // El callback trabaja en el mismo hilo del listener. `Sink::detach()`
    // deja el audio sonando en background, asi que no hace falta un hilo
    // nuevo por cada pulsacion.
    listen(move |event| {
        if let EventType::KeyPress(_) = event.event_type
            && let Ok(mut audio_state) = state.try_borrow_mut()
        {
            play_random_duck(&mut audio_state);
        }
    })
    .map_err(|error| anyhow!("Error al escuchar teclado: {:?}", error))?;

    Ok(())
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Some(Commands::Install) => install()?,
        Some(Commands::Uninstall) => uninstall()?,
        Some(Commands::Daemon) => run_daemon()?,
        None => run_daemon()?,
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::choose_next_sound_index;

    #[test]
    fn choose_next_sound_index_returns_none_when_empty() {
        assert_eq!(choose_next_sound_index(0, None), None);
    }

    #[test]
    fn choose_next_sound_index_handles_single_sound() {
        assert_eq!(choose_next_sound_index(1, None), Some(0));
        assert_eq!(choose_next_sound_index(1, Some(0)), Some(0));
    }

    #[test]
    fn choose_next_sound_index_avoids_immediate_repeats() {
        for last in 0..4 {
            let next = choose_next_sound_index(4, Some(last));
            assert!(next.is_some());
            assert_ne!(next, Some(last));
        }
    }
}
