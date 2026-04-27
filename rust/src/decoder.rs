use anyhow::{anyhow, Result};
use std::fs::File;
use symphonia::core::{
    audio::SampleBuffer,
    codecs::{Decoder as SymphDecoder, DecoderOptions},
    errors::Error as SymphError,
    formats::{FormatOptions, FormatReader, SeekMode, SeekTo},
    io::MediaSourceStream,
    meta::MetadataOptions,
    probe::Hint,
    units::Time,
};

pub struct Decoder {
    format: Box<dyn FormatReader>,
    decoder: Box<dyn SymphDecoder>,
    track_id: u32,
    sample_rate: u32,
    channels: u32,
    bit_depth: u32,
    duration_secs: f64,
    position_secs: f64,
}

impl Decoder {
    pub fn open(path: &str) -> Result<Self> {
        let file = File::open(path)?;
        let mss = MediaSourceStream::new(Box::new(file), Default::default());

        let mut hint = Hint::new();
        if let Some(ext) = std::path::Path::new(path)
            .extension()
            .and_then(|e| e.to_str())
        {
            hint.with_extension(ext);
        }

        let probed = symphonia::default::get_probe().format(
            &hint,
            mss,
            &FormatOptions {
                enable_gapless: true,
                ..Default::default()
            },
            &MetadataOptions::default(),
        )?;

        let format = probed.format;
        let track = format
            .default_track()
            .ok_or_else(|| anyhow!("No default audio track found"))?;

        let track_id = track.id;
        let params = &track.codec_params;
        let sample_rate = params.sample_rate.unwrap_or(44100);
        let channels = params.channels.map(|c| c.count() as u32).unwrap_or(2);
        let bit_depth = params.bits_per_sample.unwrap_or(16);
        let n_frames = params.n_frames.unwrap_or(0);
        let duration_secs = if sample_rate > 0 {
            n_frames as f64 / sample_rate as f64
        } else {
            0.0
        };

        let decoder = symphonia::default::get_codecs().make(params, &DecoderOptions::default())?;

        Ok(Self {
            format,
            decoder,
            track_id,
            sample_rate,
            channels,
            bit_depth,
            duration_secs,
            position_secs: 0.0,
        })
    }

    /// Decode and return the next packet as interleaved f32 samples.
    /// Returns `Ok(None)` when the stream is exhausted.
    pub fn next_packet(&mut self) -> Result<Option<Vec<f32>>> {
        loop {
            let packet = match self.format.next_packet() {
                Ok(p) => p,
                Err(SymphError::IoError(e)) if e.kind() == std::io::ErrorKind::UnexpectedEof => {
                    return Ok(None);
                }
                Err(SymphError::ResetRequired) => {
                    self.decoder.reset();
                    continue;
                }
                Err(_) => return Ok(None),
            };

            // Skip packets that belong to other tracks (e.g. cover art)
            if packet.track_id() != self.track_id {
                continue;
            }

            let decoded = match self.decoder.decode(&packet) {
                Ok(d) => d,
                Err(SymphError::DecodeError(_)) => continue, // skip bad frame
                Err(e) => return Err(e.into()),
            };

            let spec = *decoded.spec();
            let mut buf = SampleBuffer::<f32>::new(decoded.capacity() as u64, spec);
            buf.copy_interleaved_ref(decoded);

            // Update position from packet timestamp
            self.position_secs = packet.ts() as f64 / self.sample_rate as f64;

            return Ok(Some(buf.samples().to_vec()));
        }
    }

    pub fn seek(&mut self, position_secs: f64) -> Result<()> {
        let time = Time::from(position_secs);
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
