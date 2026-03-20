use anyhow::Result;
use clap::{Parser, Subcommand};
use rand::Rng;
use rdev::{listen, EventType};
use rodio::{Decoder, OutputStream, OutputStreamHandle, Sink, Source};
use rust_embed::RustEmbed;
use std::io::Cursor;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
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

/// Estado compartido entre hilos. Solo contiene datos inmutables (buffers)
/// y un contador atomico, asi que no necesita Mutex para la reproduccion.
struct AppState {
    stream_handle: OutputStreamHandle,
    last_played: AtomicUsize,
    sounds: Vec<PreloadedSound>,
}

// El estado es seguro entre hilos porque OutputStreamHandle es Send+Sync,
// los buffers son inmutables, y last_played es atomico.
unsafe impl Sync for AppState {}
unsafe impl Send for AppState {}

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

fn init_audio() -> Result<Arc<AppState>> {
    let (stream, stream_handle) = OutputStream::try_default()?;
    // Mantener el stream vivo para siempre
    Box::leak(Box::new(stream));

    let mut sounds = Vec::new();
    for i in 1..=4 {
        let filename = format!("audio/effect-duck-{}.mp3", i);
        if let Some(asset) = Assets::get(&filename) {
            let cursor = Cursor::new(asset.data.into_owned());
            if let Ok(source) = Decoder::new_mp3(cursor) {
                let channels = source.channels();
                let sample_rate = source.sample_rate();
                let samples: Vec<i16> = source.into_iter().collect();
                sounds.push(PreloadedSound { channels, sample_rate, samples });
            }
        }
    }

    let state = Arc::new(AppState {
        stream_handle,
        last_played: AtomicUsize::new(99),
        sounds,
    });
    Ok(state)
}

/// Reproduce un pato aleatorio (no repite el ultimo) de forma instantanea.
/// Cada llamada crea un Sink independiente que se ejecuta en paralelo,
/// permitiendo que multiples sonidos suenen simultaneamente.
fn play_random_duck(state: &AppState) {
    if state.sounds.is_empty() {
        return;
    }

    let mut rng = rand::thread_rng();
    let last = state.last_played.load(Ordering::Relaxed);
    let mut next;
    loop {
        next = rng.gen_range(1..=4usize);
        if next != last {
            break;
        }
    }
    state.last_played.store(next, Ordering::Relaxed);

    let idx = next - 1;
    if idx < state.sounds.len() {
        let sound = &state.sounds[idx];
        let buffer = rodio::buffer::SamplesBuffer::new(
            sound.channels,
            sound.sample_rate,
            sound.samples.clone(),
        );
        if let Ok(sink) = Sink::try_new(&state.stream_handle) {
            sink.append(buffer);
            sink.detach();
        }
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
    let _ = Command::new("pkill").arg("-f").arg("duck-keyboard daemon").status();
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
    let _ = Command::new("pkill").arg("-f").arg("duck-keyboard daemon").status();
    // Segundo intento por si acaso
    let _ = Command::new("killall").arg("duck-keyboard").status();

    println!("Desinstalado correctamente. El pato ha muerto.");
    Ok(())
}

fn run_daemon() -> Result<()> {

    let state = match init_audio() {
        Ok(s) => s,
        Err(e) => {
            eprintln!("No se pudo inicializar el sistema de audio: {:?}", e);
            return Err(e);
        }
    };

    // Cada tecla dispara un hilo efimero que reproduce el sonido.
    // Esto garantiza que CADA tecla suene, sin importar la velocidad,
    // porque los hilos corren en paralelo y no se esperan entre si.
    if let Err(error) = listen(move |event| {
        if let EventType::KeyPress(_) = event.event_type {
            let state_ref = Arc::clone(&state);
            thread::spawn(move || {
                play_random_duck(&state_ref);
            });
        }
    }) {
        eprintln!("Error al escuchar teclado: {:?}", error);
    }

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
