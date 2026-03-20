use anyhow::Result;
use clap::{Parser, Subcommand};
use daemonize::Daemonize;
use rand::Rng;
use rdev::{listen, Event, EventType};
use rodio::{Decoder, OutputStream, OutputStreamHandle, Sink};
use rust_embed::RustEmbed;
use std::fs::File;
use std::io::Cursor;
use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::process::Command;

#[derive(RustEmbed)]
#[folder = "assets/"]
struct Assets;

struct AppState {
    stream_handle: OutputStreamHandle,
    last_played: AtomicUsize,
}

lazy_static::lazy_static! {
    static ref APP_STATE: Arc<Mutex<Option<AppState>>> = Arc::new(Mutex::new(None));
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

fn init_audio() -> Result<()> {
    let (stream, stream_handle) = OutputStream::try_default()?;
    Box::leak(Box::new(stream));

    let state = AppState {
        stream_handle,
        last_played: AtomicUsize::new(99),
    };
    *APP_STATE.lock().unwrap() = Some(state);
    Ok(())
}

fn play_random_duck() {
    let state_lock = APP_STATE.lock().unwrap();
    if let Some(state) = state_lock.as_ref() {
        let mut rng = rand::rng();
        let last = state.last_played.load(Ordering::Relaxed);
        let mut next;
        loop {
            next = rng.random_range(1..=4);
            if next != last {
                break;
            }
        }
        state.last_played.store(next, Ordering::Relaxed);

        let filename = format!("audio/effect-duck-{}.mp3", next);
        if let Some(asset) = Assets::get(&filename) {
            let cursor = Cursor::new(asset.data.into_owned());
            if let Ok(source) = Decoder::new_mp3(cursor) {
                if let Ok(sink) = Sink::try_new(&state.stream_handle) {
                    sink.append(source);
                    sink.detach();
                }
            }
        }
    }
}

fn callback(event: Event) {
    if let EventType::KeyPress(_) = event.event_type {
        play_random_duck();
    }
}

#[cfg(unix)]
fn drop_privileges() -> Result<()> {
    unsafe {
        libc::setuid(65534);
        libc::setgid(65534);
    }
    Ok(())
}

#[cfg(not(unix))]
fn drop_privileges() -> Result<()> {
    Ok(())
}

fn install() -> Result<()> {
    println!("Instalando Duck Keyboard...");
    let status = Command::new("sh")
        .arg("./install.sh")
        .status()?;

    if status.success() {
        println!("Instalado correctamente.");
    } else {
        println!("Error al instalar.");
    }
    Ok(())
}

fn uninstall() -> Result<()> {
    println!("Desinstalando Duck Keyboard...");
    let status = Command::new("sh")
        .arg("./uninstall.sh")
        .status()?;

    if status.success() {
        println!("Desinstalado correctamente.");
    } else {
        println!("Error al desinstalar.");
    }
    Ok(())
}

fn run_daemon() -> Result<()> {
    let user = std::env::var("USER").unwrap_or_else(|_| "nobody".to_string());
    let log_path = format!("/tmp/duck-{}.log", user);
    let err_path = format!("/tmp/duck-{}.err", user);
    let pid_path = format!("/tmp/duck-{}.pid", user);

    let stdout = File::create(&log_path).unwrap();
    let stderr = File::create(&err_path).unwrap();

    #[cfg(unix)]
    let daemonize = Daemonize::new()
        .pid_file(&pid_path)
        .chown_pid_file(true)
        .working_directory("/tmp")
        .stdout(stdout)
        .stderr(stderr);

    #[cfg(unix)]
    match daemonize.start() {
        Ok(_) => {
            println!("Proceso demonio iniciado en segundo plano.");
        }
        Err(e) => eprintln!("Error al iniciar demonio: {}", e),
    }

    // drop_privileges interfiere si se necesita acceso global a teclado en algunas distribuciones de Linux,
    // pero si se requiere por politica de seguridad, se intenta llamar:
    let _ = drop_privileges();

    init_audio()?;

    if let Err(error) = listen(callback) {
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
