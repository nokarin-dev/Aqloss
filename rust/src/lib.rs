pub mod api;
pub mod audio_engine;
pub mod decoder;
pub mod discord_rpc;
pub mod eq;
mod frb_generated;
pub mod logger;
pub mod metadata;
pub mod output;
pub mod resampler;

use flutter_rust_bridge::frb;

#[cfg(target_os = "android")]
#[no_mangle]
pub unsafe extern "C" fn Java_xyz_nokarin_aqloss_MainActivity_initAudioContext(
    mut env: jni::JNIEnv,
    _class: jni::objects::JClass,
    ctx: jni::objects::JObject,
) {
    let vm = env.get_java_vm().expect("initAudioContext: get_java_vm");
    let ctx_global = env
        .new_global_ref(ctx)
        .expect("initAudioContext: new_global_ref");
    ndk_context::initialize_android_context(
        vm.get_java_vm_pointer().cast(),
        ctx_global.as_raw().cast(),
    );
    std::mem::forget(ctx_global);
}

#[frb(dart_metadata = ("freezed"))]
pub struct TrackInfo {
    pub path: String,
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub track_number: Option<u32>,
    pub duration_secs: f64,
    pub sample_rate: u32,
    pub bit_depth: Option<u32>,
    pub channels: u32,
    pub format: String,
    pub file_size_bytes: u64,
    pub replay_gain_track: Option<f64>,
    pub replay_gain_album: Option<f64>,
}

pub struct PlaybackPosition {
    pub position_secs: f64,
    pub duration_secs: f64,
    pub sample_rate: u32,
    pub bit_depth: u32,
}
