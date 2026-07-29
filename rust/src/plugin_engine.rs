use std::{
    collections::HashMap,
    fs,
    path::{Path, PathBuf},
    sync::Mutex,
};

use anyhow::{anyhow, Result};
use mlua::prelude::*;
use serde::{Deserialize, Serialize};
use ureq::{self, http::StatusCode};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PluginPermission {
    Network,
    Filesystem,
    LibraryWrite,
}

fn default_type() -> String {
    "lua".to_string()
}

fn default_min_version() -> String {
    "1.0.0".to_string()
}

fn parse_version_triplet(s: &str) -> Option<(u64, u64, u64)> {
    let mut parts = s.split('.');
    let major = parts.next()?.parse().ok()?;
    let minor = parts.next().and_then(|p| p.parse().ok()).unwrap_or(0);
    let patch = parts.next().and_then(|p| p.parse().ok()).unwrap_or(0);
    Some((major, minor, patch))
}

fn version_at_least(host: &str, min: &str) -> bool {
    match (parse_version_triplet(host), parse_version_triplet(min)) {
        (Some(h), Some(m)) => h >= m,
        _ => true,
    }
}

// Manifest
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub author: String,
    pub description: Option<String>,
    #[serde(default = "default_min_version", rename = "min_aqloss_version")]
    pub min_aqloss_version: String,
    pub entry: Option<String>,
    #[serde(default = "default_type", rename = "type")]
    pub plugin_type: String,
    #[serde(default)]
    pub permissions: Vec<PluginPermission>,
}

impl PluginManifest {
    fn has(&self, perm: PluginPermission) -> bool {
        self.permissions.contains(&perm)
    }
}

// Events
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum PluginEvent {
    TrackStart {
        title: String,
        artist: String,
        album: Option<String>,
        duration_secs: f64,
        path: String,
    },
    TrackStop {
        title: Option<String>,
        artist: Option<String>,
    },
    PlayPause {
        is_playing: bool,
        position_secs: f64,
    },
    PositionUpdate {
        position_secs: f64,
        duration_secs: f64,
        progress: f64,
    },
    TrackComplete {
        title: String,
        artist: String,
        duration_secs: f64,
        path: String,
    },
    LibraryScanStart,
    LibraryScanComplete {
        total: u32,
    },
    TrackLoved {
        title: String,
        artist: String,
        loved: bool,
    },
    AppForeground,
}

impl PluginEvent {
    fn hook_name(&self) -> &'static str {
        match self {
            Self::TrackStart { .. } => "on_track_start",
            Self::TrackStop { .. } => "on_track_stop",
            Self::PlayPause { .. } => "on_play_pause",
            Self::PositionUpdate { .. } => "on_position_update",
            Self::TrackComplete { .. } => "on_track_complete",
            Self::LibraryScanStart => "on_library_scan_start",
            Self::LibraryScanComplete { .. } => "on_library_scan_complete",
            Self::TrackLoved { .. } => "on_track_loved",
            Self::AppForeground => "on_app_foreground",
        }
    }
}

// Per-plugin Lua instance
struct PluginInstance {
    lua: Lua,
    manifest: PluginManifest,
    dir: PathBuf,
    enabled: bool,
}

impl PluginInstance {
    fn new(manifest: PluginManifest, dir: &Path) -> Result<Self> {
        let lua = Lua::new_with(
            LuaStdLib::TABLE | LuaStdLib::STRING | LuaStdLib::MATH,
            LuaOptions::default(),
        )?;

        let inst = Self {
            lua,
            manifest,
            dir: dir.to_path_buf(),
            enabled: true,
        };
        inst.setup_api()?;
        inst.load_entry(dir)?;
        Ok(inst)
    }

    fn setup_api(&self) -> Result<()> {
        let lua = &self.lua;
        let api = lua.create_table()?;
        let network_ok = self.manifest.has(PluginPermission::Network);
        let fs_ok = self.manifest.has(PluginPermission::Filesystem);
        let plugin_dir = self.dir.clone();

        api.set(
            "log",
            lua.create_function(|_, msg: String| {
                crate::logger::info_plugin(format!("[plugin] {msg}"));
                Ok(())
            })?,
        )?;

        api.set(
            "log_warn",
            lua.create_function(|_, msg: String| {
                crate::logger::warn_plugin(format!("[plugin] {msg}"));
                Ok(())
            })?,
        )?;

        api.set(
            "json_encode",
            lua.create_function(|lua_ctx, val: LuaValue| {
                let json = lua_to_json(lua_ctx, &val)
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))?;
                let s = serde_json::to_string(&json)
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))?;
                Ok(s)
            })?,
        )?;

        api.set(
            "json_decode",
            lua.create_function(|lua_ctx, s: String| {
                let val: serde_json::Value =
                    serde_json::from_str(&s).map_err(|e| LuaError::RuntimeError(e.to_string()))?;
                json_to_lua(lua_ctx, &val).map_err(|e| LuaError::RuntimeError(e.to_string()))
            })?,
        )?;

        api.set(
            "http_post",
            lua.create_function(move |_, (url, headers, body): (String, LuaTable, String)| {
                if !network_ok {
                    return Err(LuaError::RuntimeError(
                        "http_post: missing 'network' permission in plugin.json".into(),
                    ));
                }
                let mut req = ureq::post(&url);
                for pair in headers.pairs::<String, String>() {
                    match pair {
                        Ok((k, v)) => req = req.header(&k, &v),
                        Err(_) => continue,
                    }
                }

                match req.send(body) {
                    Ok(resp) => Ok(resp.status() < StatusCode::from_u16(400).unwrap()),
                    Err(e) => {
                        crate::logger::warn_plugin(format!("[plugin http_post] {e}"));
                        Ok(false)
                    }
                }
            })?,
        )?;

        api.set(
            "http_get",
            lua.create_function(move |_, url: String| {
                if !network_ok {
                    return Err(LuaError::RuntimeError(
                        "http_get: missing 'network' permission in plugin.json".into(),
                    ));
                }
                match ureq::get(&url).call() {
                    Ok(mut resp) => {
                        let body = resp.body_mut().read_to_string().unwrap_or_default();
                        Ok(Some(body))
                    }
                    Err(e) => {
                        crate::logger::warn_plugin(format!("[plugin http_get] {e}"));
                        Ok(None)
                    }
                }
            })?,
        )?;

        let read_dir = plugin_dir.clone();
        api.set(
            "read_file",
            lua.create_function(move |_, rel_path: String| {
                if !fs_ok {
                    return Err(LuaError::RuntimeError(
                        "read_file: missing 'filesystem' permission in plugin.json".into(),
                    ));
                }
                let target = read_dir.join(&rel_path);
                let resolved = target
                    .canonicalize()
                    .map_err(|e| LuaError::RuntimeError(format!("read_file: {e}")))?;
                let root = read_dir
                    .canonicalize()
                    .map_err(|e| LuaError::RuntimeError(format!("read_file: {e}")))?;
                if !resolved.starts_with(&root) {
                    return Err(LuaError::RuntimeError(
                        "read_file: path escapes plugin directory".into(),
                    ));
                }
                fs::read_to_string(&resolved)
                    .map_err(|e| LuaError::RuntimeError(format!("read_file: {e}")))
            })?,
        )?;

        api.set("version", env!("CARGO_PKG_VERSION"))?;

        lua.globals().set("aqloss", api)?;
        Ok(())
    }

    fn load_entry(&self, dir: &Path) -> Result<()> {
        let entry = self.manifest.entry.as_deref().unwrap_or("main.lua");
        let path = dir.join(entry);
        let src = fs::read_to_string(&path)
            .map_err(|e| anyhow!("cannot read {}: {e}", path.display()))?;
        self.lua.load(&src).set_name(entry).exec()?;
        Ok(())
    }

    fn call_hook(&self, hook: &str, event_json: &serde_json::Value) -> Result<()> {
        let globals = self.lua.globals();
        let func: Option<LuaFunction> = globals.get(hook)?;
        if let Some(f) = func {
            let mut payload = event_json.clone();
            if let serde_json::Value::Object(ref mut map) = payload {
                map.remove("event");
            }
            let arg = json_to_lua(&self.lua, &payload)?;
            f.call::<()>(arg)?;
        }
        Ok(())
    }
}

fn json_to_lua<'lua>(lua: &'lua Lua, val: &serde_json::Value) -> Result<LuaValue> {
    Ok(match val {
        serde_json::Value::Null => LuaValue::Nil,
        serde_json::Value::Bool(b) => LuaValue::Boolean(*b),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                LuaValue::Integer(i)
            } else {
                LuaValue::Number(n.as_f64().unwrap_or(0.0))
            }
        }
        serde_json::Value::String(s) => LuaValue::String(lua.create_string(s)?),
        serde_json::Value::Array(arr) => {
            let t = lua.create_table()?;
            for (i, v) in arr.iter().enumerate() {
                t.set(i + 1, json_to_lua(lua, v)?)?;
            }
            LuaValue::Table(t)
        }
        serde_json::Value::Object(map) => {
            let t = lua.create_table()?;
            for (k, v) in map {
                t.set(k.as_str(), json_to_lua(lua, v)?)?;
            }
            LuaValue::Table(t)
        }
    })
}

fn lua_to_json(lua: &Lua, val: &LuaValue) -> Result<serde_json::Value> {
    Ok(match val {
        LuaValue::Nil => serde_json::Value::Null,
        LuaValue::Boolean(b) => serde_json::Value::Bool(*b),
        LuaValue::Integer(i) => serde_json::Value::Number((*i).into()),
        LuaValue::Number(f) => serde_json::json!(*f),
        LuaValue::String(s) => serde_json::Value::String(s.to_str()?.to_string()),
        LuaValue::Table(t) => {
            let len = t.raw_len();
            if len > 0 {
                let mut arr = Vec::with_capacity(len);
                for i in 1..=len {
                    let v: LuaValue = t.raw_get(i)?;
                    arr.push(lua_to_json(lua, &v)?);
                }
                serde_json::Value::Array(arr)
            } else {
                let mut map = serde_json::Map::new();
                for pair in t.clone().pairs::<String, LuaValue>() {
                    let (k, v) = pair?;
                    map.insert(k, lua_to_json(lua, &v)?);
                }
                serde_json::Value::Object(map)
            }
        }
        _ => serde_json::Value::Null,
    })
}

// Engine
pub struct LuaPluginEngine {
    order: Vec<String>,
    plugins: HashMap<String, PluginInstance>,
}

impl LuaPluginEngine {
    pub fn new() -> Self {
        Self {
            order: Vec::new(),
            plugins: HashMap::new(),
        }
    }

    pub fn load_plugin(&mut self, dir: &Path) -> Result<String> {
        let raw = fs::read_to_string(dir.join("plugin.json"))
            .map_err(|_| anyhow!("plugin.json not found in {}", dir.display()))?;
        let manifest: PluginManifest =
            serde_json::from_str(&raw).map_err(|e| anyhow!("plugin.json parse: {e}"))?;

        let host_version = env!("CARGO_PKG_VERSION");
        if !version_at_least(host_version, &manifest.min_aqloss_version) {
            return Err(anyhow!(
                "plugin {} requires Aqloss {} or newer (running {host_version})",
                manifest.id,
                manifest.min_aqloss_version
            ));
        }

        let id = manifest.id.clone();
        if self.plugins.contains_key(&id) {
            return Err(anyhow!("{id} already loaded"));
        }

        let inst = PluginInstance::new(manifest, dir)?;
        if let Err(e) = inst.call_hook("on_load", &serde_json::Value::Null) {
            crate::logger::warn_plugin(format!("[plugins/{id}] on_load: {e}"));
        }

        self.order.push(id.clone());
        self.plugins.insert(id.clone(), inst);
        crate::logger::info_plugin(format!("loaded: {id}"));
        Ok(id)
    }

    pub fn unload_plugin(&mut self, id: &str) {
        if let Some(p) = self.plugins.get(id) {
            if let Err(e) = p.call_hook("on_unload", &serde_json::Value::Null) {
                crate::logger::warn_plugin(format!("[plugins/{id}] on_unload: {e}"));
            }
        }
        self.plugins.remove(id);
        self.order.retain(|x| x != id);
    }

    pub fn set_enabled(&mut self, id: &str, enabled: bool) {
        if let Some(p) = self.plugins.get_mut(id) {
            p.enabled = enabled;
        }
    }

    pub fn is_enabled(&self, id: &str) -> bool {
        self.plugins.get(id).map(|p| p.enabled).unwrap_or(false)
    }

    pub fn loaded_ids(&self) -> Vec<String> {
        self.order.clone()
    }

    pub fn manifest(&self, id: &str) -> Option<PluginManifest> {
        self.plugins.get(id).map(|p| p.manifest.clone())
    }

    pub fn dispatch(&self, event: &PluginEvent) {
        let hook = event.hook_name();
        let json = match serde_json::to_value(event) {
            Ok(v) => v,
            Err(e) => {
                crate::logger::warn_plugin(format!("[plugins] serialize event: {e}"));
                return;
            }
        };

        for id in &self.order {
            let inst = match self.plugins.get(id) {
                Some(p) if p.enabled => p,
                _ => continue,
            };
            if let Err(e) = inst.call_hook(hook, &json) {
                crate::logger::warn_plugin(format!("[plugins/{id}] {hook}: {e}"));
            }
        }
    }
}

// Global singleton
static ENGINE: Mutex<Option<LuaPluginEngine>> = Mutex::new(None);

pub fn engine_init() {
    let mut lock = ENGINE.lock().unwrap();
    if lock.is_none() {
        *lock = Some(LuaPluginEngine::new());
    }
}

pub fn with_engine<F, R>(f: F) -> Result<R>
where
    F: FnOnce(&mut LuaPluginEngine) -> R,
{
    let mut g = ENGINE.lock().unwrap();
    match g.as_mut() {
        Some(e) => Ok(f(e)),
        None => Err(anyhow!("plugin engine not initialized")),
    }
}

pub fn with_engine_read<F, R>(f: F) -> Option<R>
where
    F: FnOnce(&LuaPluginEngine) -> R,
{
    let g = ENGINE.lock().unwrap();
    g.as_ref().map(f)
}
