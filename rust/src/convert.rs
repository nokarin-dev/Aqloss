#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PcmKind {
    F32,
    S16,
    S24In32,
    S32,
}

impl PcmKind {
    pub fn bytes_per_sample(self) -> usize {
        match self {
            Self::F32 | Self::S24In32 | Self::S32 => 4,
            Self::S16 => 2,
        }
    }

    pub fn bits(self) -> u32 {
        match self {
            Self::F32 | Self::S32 => 32,
            Self::S24In32 => 24,
            Self::S16 => 16,
        }
    }
}

pub struct Rng(u32);

impl Rng {
    pub fn new() -> Self {
        Self(0xA341_316C)
    }

    fn next_unit(&mut self) -> f32 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 17;
        self.0 ^= self.0 << 5;
        (self.0 as f32) / (u32::MAX as f32)
    }

    fn tpdf(&mut self) -> f32 {
        self.next_unit() + self.next_unit() - 1.0
    }
}

pub fn quantize(src: &[f32], dst: &mut [u8], kind: PcmKind, rng: &mut Rng) {
    let n = src.len();
    match kind {
        PcmKind::F32 => {
            let out = unsafe { std::slice::from_raw_parts_mut(dst.as_mut_ptr() as *mut f32, n) };
            out[..n].copy_from_slice(src);
        }
        PcmKind::S16 => {
            let out = unsafe { std::slice::from_raw_parts_mut(dst.as_mut_ptr() as *mut i16, n) };
            let scale = 32767.0;
            for i in 0..n {
                let d = rng.tpdf();
                let v = (src[i] * scale + d).round();
                out[i] = v.clamp(-32768.0, 32767.0) as i16;
            }
        }
        PcmKind::S24In32 => {
            let out = unsafe { std::slice::from_raw_parts_mut(dst.as_mut_ptr() as *mut i32, n) };
            let scale = 8_388_607.0;
            for i in 0..n {
                let v = (src[i] * scale).round().clamp(-8_388_608.0, 8_388_607.0) as i32;
                out[i] = v << 8;
            }
        }
        PcmKind::S32 => {
            let out = unsafe { std::slice::from_raw_parts_mut(dst.as_mut_ptr() as *mut i32, n) };
            let scale = 2_147_483_647.0;
            for i in 0..n {
                let v = (src[i] as f64 * scale as f64).round();
                out[i] = v.clamp(i32::MIN as f64, i32::MAX as f64) as i32;
            }
        }
    }
}

pub fn apply_gain(
    samples: &mut [f32],
    target: f32,
    smooth: &mut f32,
    replay_gain: f32,
    soft: bool,
    ramp: f32,
) {
    for s in samples {
        let diff = target - *smooth;
        if diff.abs() > ramp {
            *smooth += diff.signum() * ramp;
        } else {
            *smooth = target;
        }
        let gained = *s * *smooth * replay_gain;
        *s = if soft {
            soft_clip(gained)
        } else {
            gained.clamp(-1.0, 1.0)
        };
    }
}

#[inline(always)]
pub fn soft_clip(x: f32) -> f32 {
    if x >= 3.0 {
        return 1.0;
    }
    if x <= -3.0 {
        return -1.0;
    }
    let x2 = x * x;
    x * (27.0 + x2) / (27.0 + 9.0 * x2)
}

pub fn adapt_channels_into(input: &[f32], src: u32, dst: u32, out: &mut Vec<f32>) {
    out.clear();
    if input.is_empty() {
        return;
    }
    let dst = dst.max(1);
    let src = if src == 0 || input.len() % src as usize != 0 {
        if input.len() % dst as usize == 0 {
            dst
        } else if input.len() % 2 == 0 {
            2
        } else {
            1
        }
    } else {
        src
    };
    if src == dst {
        out.extend_from_slice(input);
        return;
    }
    let src = src as usize;
    let dst = dst as usize;
    match (src, dst) {
        (1, d) => {
            out.reserve(input.len() * d);
            for &s in input {
                for _ in 0..d {
                    out.push(s);
                }
            }
        }
        (2, 1) => {
            out.reserve(input.len() / 2);
            for c in input.chunks_exact(2) {
                out.push((c[0] + c[1]) * std::f32::consts::FRAC_1_SQRT_2);
            }
        }
        (2, d) => {
            let frames = input.len() / 2;
            out.resize(frames * d, 0.0);
            for (f, chunk) in input.chunks_exact(2).enumerate() {
                out[f * d] = chunk[0];
                if d > 1 {
                    out[f * d + 1] = chunk[1];
                }
            }
        }
        (s, 2) if s > 2 => {
            out.reserve((input.len() / s) * 2);
            for frame in input.chunks_exact(s) {
                let l = frame.iter().step_by(2).sum::<f32>() / (s as f32 / 2.0);
                let r = frame.iter().skip(1).step_by(2).sum::<f32>() / (s as f32 / 2.0);
                out.push(l);
                out.push(r);
            }
        }
        (s, d) if s > 2 && d > 2 => {
            let frames = input.len() / s;
            out.resize(frames * d, 0.0);
            let copy = s.min(d);
            for f in 0..frames {
                out[f * d..f * d + copy].copy_from_slice(&input[f * s..f * s + copy]);
            }
        }
        _ => out.extend_from_slice(input),
    }
}

pub fn playback_dst_rate(out_sr: u32, speed: f32, exclusive: bool) -> u32 {
    let out_sr = out_sr.max(1);
    if exclusive {
        return out_sr;
    }
    let speed = (speed as f64).clamp(0.5, 2.0);
    if (speed - 1.0).abs() < 0.001 {
        return out_sr;
    }
    ((out_sr as f64) / speed).round().clamp(1.0, 384_000.0) as u32
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dst_rate_follows_speed_except_exclusive() {
        assert_eq!(playback_dst_rate(44100, 1.0, false), 44100);
        assert_eq!(playback_dst_rate(44100, 2.0, false), 22050);
        assert_eq!(playback_dst_rate(44100, 0.5, false), 88200);
        assert_eq!(playback_dst_rate(48000, 1.25, false), 38400);
        assert_eq!(playback_dst_rate(44100, 2.0, true), 44100);
    }
}
