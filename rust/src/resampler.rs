use anyhow::Result;
use rubato::{
    audioadapter_buffers::direct::SequentialSliceOfVecs, calculate_cutoff, Async, FixedAsync,
    Resampler as RubatoResampler, SincInterpolationParameters, SincInterpolationType,
    WindowFunction,
};

const CHUNK_FRAMES: usize = 1024;

pub struct Resampler {
    inner: Async<f32>,
    channels: usize,
    in_buf: Vec<Vec<f32>>,
    chunk: Vec<Vec<f32>>,
    out_planar: Vec<Vec<f32>>,
    #[allow(dead_code)]
    source_rate: usize,
    #[allow(dead_code)]
    target_rate: usize,
}

impl Resampler {
    pub fn matches(&self, source_rate: u32, target_rate: u32, channels: u32) -> bool {
        self.source_rate == source_rate as usize
            && self.target_rate == target_rate as usize
            && self.channels == channels as usize
    }

    pub fn new(source_rate: u32, target_rate: u32, channels: u32) -> Result<Self> {
        const SINC_LEN: usize = 256;
        let params = SincInterpolationParameters {
            sinc_len: SINC_LEN,
            f_cutoff: calculate_cutoff(SINC_LEN, WindowFunction::BlackmanHarris2),
            interpolation: SincInterpolationType::Cubic,
            oversampling_factor: 256,
            window: WindowFunction::BlackmanHarris2,
        };
        let ch = channels as usize;
        let inner = Async::<f32>::new_sinc(
            target_rate as f64 / source_rate as f64,
            1.1,
            &params,
            CHUNK_FRAMES,
            ch,
            FixedAsync::Input,
        )?;

        Ok(Self {
            inner,
            channels: ch,
            in_buf: vec![Vec::with_capacity(CHUNK_FRAMES * 2); ch],
            chunk: vec![vec![0.0; CHUNK_FRAMES]; ch],
            out_planar: vec![Vec::new(); ch],
            source_rate: source_rate as usize,
            target_rate: target_rate as usize,
        })
    }

    pub fn process_into(&mut self, input: &[f32], out: &mut Vec<f32>) -> Result<()> {
        out.clear();
        let in_frames = input.len() / self.channels;
        for f in 0..in_frames {
            for ch in 0..self.channels {
                self.in_buf[ch].push(input[f * self.channels + ch]);
            }
        }

        while self.in_buf[0].len() >= CHUNK_FRAMES {
            for ch in 0..self.channels {
                self.chunk[ch].clear();
                self.chunk[ch].extend(self.in_buf[ch].drain(..CHUNK_FRAMES));
            }

            let input_adapter =
                SequentialSliceOfVecs::new(&self.chunk, self.channels, CHUNK_FRAMES)
                    .map_err(|e| anyhow::anyhow!("resampler input adapter: {e:?}"))?;

            let out_frames = self.inner.output_frames_next();
            for ch in &mut self.out_planar {
                ch.resize(out_frames, 0.0);
            }
            let mut output_adapter =
                SequentialSliceOfVecs::new_mut(&mut self.out_planar, self.channels, out_frames)
                    .map_err(|e| anyhow::anyhow!("resampler output adapter: {e:?}"))?;

            self.inner
                .process_into_buffer(&input_adapter, &mut output_adapter, None)?;

            out.reserve(out_frames * self.channels);
            for f in 0..out_frames {
                for ch in 0..self.channels {
                    out.push(self.out_planar[ch][f]);
                }
            }
        }
        Ok(())
    }

    pub fn flush_into(&mut self, out: &mut Vec<f32>) -> Result<()> {
        out.clear();
        if self.in_buf[0].is_empty() {
            return Ok(());
        }

        let leftover = self.in_buf[0].len();
        for ch in 0..self.channels {
            self.chunk[ch].clear();
            self.chunk[ch].extend(self.in_buf[ch].drain(..));
            self.chunk[ch].resize(CHUNK_FRAMES, 0.0);
        }

        let input_adapter = SequentialSliceOfVecs::new(&self.chunk, self.channels, CHUNK_FRAMES)
            .map_err(|e| anyhow::anyhow!("resampler flush input adapter: {e:?}"))?;

        let out_frames = self.inner.output_frames_next();
        for ch in &mut self.out_planar {
            ch.resize(out_frames, 0.0);
        }
        let mut output_adapter =
            SequentialSliceOfVecs::new_mut(&mut self.out_planar, self.channels, out_frames)
                .map_err(|e| anyhow::anyhow!("resampler flush output adapter: {e:?}"))?;

        self.inner
            .process_into_buffer(&input_adapter, &mut output_adapter, None)?;

        let keep_frames = ((out_frames as f64 * leftover as f64 / CHUNK_FRAMES as f64).round()
            as usize)
            .min(out_frames);
        out.reserve(keep_frames * self.channels);
        for f in 0..keep_frames {
            for ch in 0..self.channels {
                out.push(self.out_planar[ch][f]);
            }
        }
        Ok(())
    }

    pub fn reset(&mut self) {
        for ch in &mut self.in_buf {
            ch.clear();
        }
        self.inner.reset();
    }
}
