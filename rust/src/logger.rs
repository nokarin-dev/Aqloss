use std::{
    fs::{self, File, OpenOptions},
    io::Write,
    path::{Path, PathBuf},
    sync::{Mutex, OnceLock},
    time::{SystemTime, UNIX_EPOCH},
};

// Log level
#[derive(Clone, Copy)]
pub enum Level {
    Debug,
    Info,
    Warn,
    Error,
}

impl Level {
    fn label(self) -> &'static str {
        match self {
            Level::Debug => "DEBUG",
            Level::Info => "INFO",
            Level::Warn => "WARN",
            Level::Error => "ERROR",
        }
    }
}

// Internal state
struct Logger {
    audio: Mutex<File>,
    output: Mutex<File>,
    discord: Mutex<File>,
}

static LOG_PATH: OnceLock<PathBuf> = OnceLock::new();
static LOGGER: OnceLock<Logger> = OnceLock::new();

// Log directory
fn log_dir() -> PathBuf {
    LOG_PATH
        .get()
        .cloned()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("logs/backend")
}

fn open_log(dir: &Path, name: &str) -> File {
    let path = dir.join(name);
    OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&path)
        .unwrap_or_else(|_| {
            // last resort
            let fallback = PathBuf::from("/tmp").join(name);
            OpenOptions::new()
                .write(true)
                .create(true)
                .truncate(true)
                .open(fallback)
                .expect("cannot open any log file")
        })
}

pub fn set_path(path: String) {
    let _ = LOG_PATH.set(PathBuf::from(path));
}

// Initialises the logger
pub fn init() {
    if LOGGER.get().is_some() {
        return;
    }

    let dir = log_dir();
    let _ = fs::create_dir_all(&dir);

    let logger = Logger {
        audio: Mutex::new(open_log(&dir, "audio.log")),
        output: Mutex::new(open_log(&dir, "output.log")),
        discord: Mutex::new(open_log(&dir, "discord_rpc.log")),
    };

    let sep = format!(
        "\n──────────────────────────────────────────────────────\n\
         [{}] SESSION START\n\
         ──────────────────────────────────────────────────────\n",
        timestamp()
    );
    for file in [&logger.audio, &logger.discord] {
        if let Ok(mut f) = file.lock() {
            let _ = f.write_all(sep.as_bytes());
        }
    }

    let _ = LOGGER.set(logger);
}

// Timestamp
fn timestamp() -> String {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    let secs = now.as_secs();
    let millis = now.subsec_millis();

    let jd = (secs / 86400) as i64 + 2440588;
    let p = jd + 68569;
    let q = 4 * p / 146097;
    let r = p - (146097 * q + 3) / 4;
    let s = 4000 * (r + 1) / 1461001;
    let t = r - 1461 * s / 4 + 31;
    let u = 80 * t / 2447;
    let day = t - 2447 * u / 80;
    let v = u / 11;
    let month = u + 2 - 12 * v;
    let year = 100 * (q - 49) + s + v;

    let time_of_day = secs % 86400;
    let hh = time_of_day / 3600;
    let mm = (time_of_day % 3600) / 60;
    let ss = time_of_day % 60;

    format!(
        "{:04}-{:02}-{:02} {:02}:{:02}:{:02}.{:03}",
        year, month, day, hh, mm, ss, millis
    )
}

// Core write
enum Target {
    Audio,
    Output,
    Discord,
}

fn write(target: Target, level: Level, msg: &str) {
    if LOGGER.get().is_none() {
        init();
    }
    let Some(logger) = LOGGER.get() else { return };

    let line = format!(
        "[{}] [{}] [{}] {}\n",
        timestamp(),
        "BACKEND",
        level.label(),
        msg
    );
    eprint!("{}", line);

    let file = match target {
        Target::Audio => &logger.audio,
        Target::Output => &logger.output,
        Target::Discord => &logger.discord,
    };

    if let Ok(mut f) = file.lock() {
        let _ = f.write_all(line.as_bytes());
        let _ = f.flush();
    }
}

// Public API

// audio
pub fn debug_audio(msg: impl AsRef<str>) {
    write(Target::Audio, Level::Debug, msg.as_ref());
}
pub fn info_audio(msg: impl AsRef<str>) {
    write(Target::Audio, Level::Info, msg.as_ref());
}
pub fn warn_audio(msg: impl AsRef<str>) {
    write(Target::Audio, Level::Warn, msg.as_ref());
}
pub fn error_audio(msg: impl AsRef<str>) {
    write(Target::Audio, Level::Error, msg.as_ref());
}

// Convenience
#[macro_export]
macro_rules! log_audio {
    ($lvl:ident, $($arg:tt)*) => { $crate::logger::$lvl(format!($($arg)*)); }
}
#[macro_export]
macro_rules! debug_audio { ($($arg:tt)*) => { $crate::log_audio!(debug_audio, $($arg)*) }; }
#[macro_export]
macro_rules! info_audio  { ($($arg:tt)*) => { $crate::log_audio!(info_audio,  $($arg)*) }; }
#[macro_export]
macro_rules! warn_audio  { ($($arg:tt)*) => { $crate::log_audio!(warn_audio,  $($arg)*) }; }
#[macro_export]
macro_rules! error_audio { ($($arg:tt)*) => { $crate::log_audio!(error_audio, $($arg)*) }; }

// discord_rpc
pub fn debug_discord(msg: impl AsRef<str>) {
    write(Target::Discord, Level::Debug, msg.as_ref());
}
pub fn info_discord(msg: impl AsRef<str>) {
    write(Target::Discord, Level::Info, msg.as_ref());
}
pub fn warn_discord(msg: impl AsRef<str>) {
    write(Target::Discord, Level::Warn, msg.as_ref());
}
pub fn error_discord(msg: impl AsRef<str>) {
    write(Target::Discord, Level::Error, msg.as_ref());
}

#[macro_export]
macro_rules! debug_discord { ($($arg:tt)*) => { $crate::logger::debug_discord(format!($($arg)*)) }; }
#[macro_export]
macro_rules! info_discord  { ($($arg:tt)*) => { $crate::logger::info_discord(format!($($arg)*)) }; }
#[macro_export]
macro_rules! warn_discord  { ($($arg:tt)*) => { $crate::logger::warn_discord(format!($($arg)*)) }; }
#[macro_export]
macro_rules! error_discord { ($($arg:tt)*) => { $crate::logger::error_discord(format!($($arg)*)) }; }

// output
pub fn debug_output(msg: impl AsRef<str>) {
    write(Target::Output, Level::Debug, msg.as_ref());
}
pub fn info_output(msg: impl AsRef<str>) {
    write(Target::Output, Level::Info, msg.as_ref());
}
pub fn warn_output(msg: impl AsRef<str>) {
    write(Target::Output, Level::Warn, msg.as_ref());
}
pub fn error_output(msg: impl AsRef<str>) {
    write(Target::Output, Level::Error, msg.as_ref());
}

#[macro_export]
macro_rules! debug_output { ($($arg:tt)*) => { $crate::logger::debug_output(format!($($arg)*)) }; }
#[macro_export]
macro_rules! info_output  { ($($arg:tt)*) => { $crate::logger::info_output(format!($($arg)*)) }; }
#[macro_export]
macro_rules! warn_output  { ($($arg:tt)*) => { $crate::logger::warn_output(format!($($arg)*)) }; }
#[macro_export]
macro_rules! error_output { ($($arg:tt)*) => { $crate::logger::error_output(format!($($arg)*)) }; }
