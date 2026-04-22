use anyhow::Result;
use rubato::{FftFixedIn, Resampler as RubatoResampler};

const CHUNK_FRAMES: usize = 1024;

pub struct Resampler {
    inner: FftFixedIn<f32>,
    channels: usize,
    in_buf: Vec<Vec<f32>>,
}

impl Resampler {
    pub fn new(source_rate: u32, target_rate: u32, channels: u32) -> Result<Self> {
        let inner = FftFixedIn::<f32>::new(
            source_rate as usize,
            target_rate as usize,
            CHUNK_FRAMES,
            2,
            channels as usize,
        )?;
        Ok(Self {
            inner,
            channels: channels as usize,
            in_buf: vec![Vec::new(); channels as usize],
        })
    }

    pub fn process(&mut self, input: &[f32]) -> Result<Vec<f32>> {
        let in_frames = input.len() / self.channels;
        for f in 0..in_frames {
            for ch in 0..self.channels {
                self.in_buf[ch].push(input[f * self.channels + ch]);
            }
        }

        let mut out_interleaved = Vec::new();

        while self.in_buf[0].len() >= CHUNK_FRAMES {
            // Drain exactly CHUNK_FRAMES from each channel buffer
            let chunk: Vec<Vec<f32>> = self
                .in_buf
                .iter_mut()
                .map(|ch| ch.drain(..CHUNK_FRAMES).collect())
                .collect();

            let processed = self.inner.process(&chunk, None)?;
            let out_frames = processed[0].len();

            out_interleaved.reserve(out_frames * self.channels);
            for f in 0..out_frames {
                for ch in 0..self.channels {
                    out_interleaved.push(processed[ch][f]);
                }
            }
        }

        Ok(out_interleaved)
    }

    pub fn flush(&mut self) -> Result<Vec<f32>> {
        if self.in_buf[0].is_empty() {
            return Ok(Vec::new());
        }

        let leftover = self.in_buf[0].len();
        for ch in &mut self.in_buf {
            ch.resize(CHUNK_FRAMES, 0.0);
        }

        let chunk: Vec<Vec<f32>> = self
            .in_buf
            .iter_mut()
            .map(|ch| ch.drain(..).collect())
            .collect();
        let processed = self.inner.process(&chunk, None)?;

        let ratio = leftover as f64 / CHUNK_FRAMES as f64;
        let keep_frames = (processed[0].len() as f64 * ratio).round() as usize;

        let mut out = Vec::with_capacity(keep_frames * self.channels);
        for f in 0..keep_frames.min(processed[0].len()) {
            for ch in 0..self.channels {
                out.push(processed[ch][f]);
            }
        }
        Ok(out)
    }

    pub fn reset(&mut self) {
        for ch in &mut self.in_buf {
            ch.clear();
        }
    }
}
