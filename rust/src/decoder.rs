use anyhow::{anyhow, Result};
use std::{fs::File, sync::OnceLock};
use symphonia::core::{
    codecs::{
        audio::{AudioDecoder as SymphDecoder, AudioDecoderOptions},
        registry::CodecRegistry,
        CodecParameters,
    },
    errors::Error as SymphError,
    formats::{probe::Hint, FormatOptions, FormatReader, SeekMode, SeekTo, TrackType},
    io::MediaSourceStream,
    meta::MetadataOptions,
    units::Time,
};
use symphonia_adapter_libopus::OpusDecoder;

pub struct Decoder {
    format: Box<dyn FormatReader>,
    decoder: Box<dyn SymphDecoder>,
    track_id: u32,
    sample_rate: u32,
    channels: u32,
    bit_depth: u32,
    duration_secs: f64,
    position_secs: f64,
    logged_layout: bool,
}

impl Decoder {
    pub fn open(path: &str, gapless: bool) -> Result<Self> {
        let file = File::open(path)?;
        let mss = MediaSourceStream::new(Box::new(file), Default::default());

        let mut hint = Hint::new();
        if let Some(ext) = std::path::Path::new(path)
            .extension()
            .and_then(|e| e.to_str())
        {
            hint.with_extension(ext);
        }

        let format = symphonia::default::get_probe().probe(
            &hint,
            mss,
            FormatOptions::default(),
            MetadataOptions::default(),
        )?;

        let track = format
            .default_track(TrackType::Audio)
            .ok_or_else(|| anyhow!("No default audio track found"))?;

        let track_id = track.id;

        let CodecParameters::Audio(params) = track
            .codec_params
            .as_ref()
            .ok_or_else(|| anyhow!("No codec parameters"))?
        else {
            return Err(anyhow!("Track is not an audio track"));
        };

        let sample_rate = params.sample_rate.unwrap_or(44100);
        let channels = params
            .channels
            .as_ref()
            .map(|c| c.count() as u32)
            .unwrap_or(2);
        let bit_depth = params.bits_per_sample.unwrap_or(16);

        let n_frames = track.num_frames.unwrap_or(0);
        let duration_secs = if sample_rate > 0 {
            n_frames as f64 / sample_rate as f64
        } else {
            0.0
        };

        let mut dec_opts = AudioDecoderOptions::default();
        dec_opts.gapless = gapless;

        static CODEC_REGISTRY: OnceLock<CodecRegistry> = OnceLock::new();

        let codec_registry = CODEC_REGISTRY.get_or_init(|| {
            let mut registry = CodecRegistry::new();
            symphonia::default::register_enabled_codecs(&mut registry);
            registry.register_audio_decoder::<OpusDecoder>();
            registry
        });
        let decoder = codec_registry.make_audio_decoder(&params, &dec_opts)?;

        Ok(Self {
            format,
            decoder,
            track_id,
            sample_rate,
            channels,
            bit_depth,
            duration_secs,
            position_secs: 0.0,
            logged_layout: false,
        })
    }

    pub fn next_packet_into(&mut self, buf: &mut Vec<f32>) -> Result<bool> {
        loop {
            let packet = match self.format.next_packet() {
                Ok(Some(p)) => p,
                Ok(None) => return Ok(false),
                Err(SymphError::IoError(e)) if e.kind() == std::io::ErrorKind::UnexpectedEof => {
                    return Ok(false)
                }
                Err(SymphError::ResetRequired) => {
                    self.decoder.reset();
                    continue;
                }
                Err(e) => return Err(e.into()),
            };

            if packet.track_id != self.track_id {
                continue;
            }

            let decoded = match self.decoder.decode(&packet) {
                Ok(d) => d,
                Err(SymphError::DecodeError(_)) => continue,
                Err(e) => return Err(e.into()),
            };

            let spec = decoded.spec();
            let decoded_frames = decoded.frames();
            if decoded_frames == 0 {
                continue;
            }

            buf.clear();
            decoded.copy_to_vec_interleaved(buf);

            let spec_ch = spec.channels().count().max(1);
            let pcm_ch = (buf.len() / decoded_frames).max(1);
            let ch = if buf.len() == decoded_frames * spec_ch {
                spec_ch as u32
            } else {
                pcm_ch as u32
            };
            buf.truncate(decoded_frames * ch as usize);
            let rate = spec.rate().max(1);

            if (ch != self.channels || rate != self.sample_rate) && !self.logged_layout {
                self.logged_layout = true;
                crate::logger::warn_audio(format!(
                    "packet layout {}Hz {}ch ({} frames, {} samples) differs from stream {}Hz {}ch spec_ch={spec_ch}",
                    rate,
                    ch,
                    decoded_frames,
                    buf.len(),
                    self.sample_rate,
                    self.channels
                ));
            }
            self.sample_rate = rate;
            self.channels = ch;
            self.position_secs += decoded_frames as f64 / rate as f64;
            return Ok(true);
        }
    }

    pub fn seek(&mut self, position_secs: f64) -> Result<()> {
        let time = Time::try_from_secs_f64(position_secs.max(0.0))
            .ok_or_else(|| anyhow!("invalid seek target: {position_secs}"))?;
        self.format.seek(
            SeekMode::Accurate,
            SeekTo::Time {
                time,
                track_id: Some(self.track_id),
            },
        )?;
        self.decoder.reset();
        self.position_secs = position_secs;
        Ok(())
    }

    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }
    pub fn channels(&self) -> u32 {
        self.channels
    }
    pub fn bit_depth(&self) -> u32 {
        self.bit_depth
    }
    pub fn duration_secs(&self) -> f64 {
        self.duration_secs
    }
    pub fn position_secs(&self) -> f64 {
        self.position_secs
    }
}
