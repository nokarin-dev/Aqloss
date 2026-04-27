use anyhow::Result;
use rubato::{
    audioadapter_buffers::direct::SequentialSliceOfVecs, Async, FixedAsync,
    Resampler as RubatoResampler, SincInterpolationParameters, SincInterpolationType,
    WindowFunction,
};

const CHUNK_FRAMES: usize = 1024;

#[allow(dead_code)]
pub struct Resampler {
    inner: Async<f32>,
    channels: usize,
    in_buf: Vec<Vec<f32>>,
    source_rate: usize,
    target_rate: usize,
}

impl Resampler {
    pub fn new(source_rate: u32, target_rate: u32, channels: u32) -> Result<Self> {
        let params = SincInterpolationParameters {
            sinc_len: 64,
            f_cutoff: 0.95,
            interpolation: SincInterpolationType::Linear,
            oversampling_factor: 128,
            window: WindowFunction::BlackmanHarris2,
        };

        let inner = Async::<f32>::new_sinc(
            target_rate as f64 / source_rate as f64,
            1.1,
            &params,
            CHUNK_FRAMES,
            channels as usize,
            FixedAsync::Input,
        )?;

        Ok(Self {
            inner,
            channels: channels as usize,
            in_buf: vec![Vec::with_capacity(CHUNK_FRAMES * 2); channels as usize],
            source_rate: source_rate as usize,
            target_rate: target_rate as usize,
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
            let chunk: Vec<Vec<f32>> = self
                .in_buf
                .iter_mut()
                .map(|ch| ch.drain(..CHUNK_FRAMES).collect())
                .collect();

            let input_adapter = SequentialSliceOfVecs::new(&chunk, self.channels, CHUNK_FRAMES)
                .map_err(|e| anyhow::anyhow!("resampler input adapter: {e:?}"))?;

            let out_frames = self.inner.output_frames_next();
            let mut out_buf = vec![vec![0f32; out_frames]; self.channels];
            let mut output_adapter =
                SequentialSliceOfVecs::new_mut(&mut out_buf, self.channels, out_frames)
                    .map_err(|e| anyhow::anyhow!("resampler output adapter: {e:?}"))?;

            self.inner
                .process_into_buffer(&input_adapter, &mut output_adapter, None)?;

            out_interleaved.reserve(out_frames * self.channels);
            for f in 0..out_frames {
                for ch in 0..self.channels {
                    out_interleaved.push(out_buf[ch][f]);
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

        let input_adapter = SequentialSliceOfVecs::new(&chunk, self.channels, CHUNK_FRAMES)
            .map_err(|e| anyhow::anyhow!("resampler flush input adapter: {e:?}"))?;

        let out_frames = self.inner.output_frames_next();
        let mut out_buf = vec![vec![0f32; out_frames]; self.channels];
        let mut output_adapter =
            SequentialSliceOfVecs::new_mut(&mut out_buf, self.channels, out_frames)
                .map_err(|e| anyhow::anyhow!("resampler flush output adapter: {e:?}"))?;

        self.inner
            .process_into_buffer(&input_adapter, &mut output_adapter, None)?;

        let ratio = leftover as f64 / CHUNK_FRAMES as f64;
        let keep_frames = (out_frames as f64 * ratio).round() as usize;

        let mut out = Vec::with_capacity(keep_frames * self.channels);
        for f in 0..keep_frames.min(out_frames) {
            for ch in 0..self.channels {
                out.push(out_buf[ch][f]);
            }
        }
        Ok(out)
    }

    pub fn reset(&mut self) {
        for ch in &mut self.in_buf {
            ch.clear();
        }
        self.inner.reset();
    }
}
