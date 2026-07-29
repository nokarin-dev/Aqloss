use biquad::{Biquad, Coefficients, DirectForm2Transposed, Hertz, ToHertz, Type};

pub const EQ_BANDS: [f32; 10] = [
    31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
];
const MAX_GAIN_DB: f32 = 12.0;
const BANDWIDTH_OCT: f64 = 1.0;
const FLAT_THRESHOLD_DB: f32 = 0.05;

pub struct Equalizer {
    filters: Vec<Vec<DirectForm2Transposed<f64>>>,
    active: [bool; 10],
    gains_db: [f32; 10],
    sample_rate: u32,
    channels: usize,
    enabled: bool,
}

impl Equalizer {
    pub fn new(sample_rate: u32, channels: usize) -> Self {
        let mut eq = Self {
            filters: Vec::new(),
            active: [false; 10],
            gains_db: [0.0; 10],
            sample_rate,
            channels,
            enabled: false,
        };
        eq.rebuild_all();
        eq
    }

    pub fn set_enabled(&mut self, enabled: bool) {
        self.enabled = enabled;
    }

    pub fn set_gain(&mut self, band: usize, gain_db: f32) {
        if band >= 10 {
            return;
        }
        self.gains_db[band] = gain_db.clamp(-MAX_GAIN_DB, MAX_GAIN_DB);
        self.retune_band(band);
    }

    pub fn set_all_gains(&mut self, gains: &[f32]) {
        for (i, &g) in gains.iter().enumerate().take(10) {
            self.gains_db[i] = g.clamp(-MAX_GAIN_DB, MAX_GAIN_DB);
            self.retune_band(i);
        }
    }

    pub fn reset_sample_rate(&mut self, sample_rate: u32, channels: usize) {
        self.sample_rate = sample_rate;
        self.channels = channels;
        self.rebuild_all();
    }

    fn rebuild_all(&mut self) {
        self.filters = (0..10)
            .map(|_| {
                let identity = Coefficients::<f64> {
                    a1: 0.0,
                    a2: 0.0,
                    b0: 1.0,
                    b1: 0.0,
                    b2: 0.0,
                };
                (0..self.channels)
                    .map(|_| DirectForm2Transposed::new(identity))
                    .collect()
            })
            .collect();
        for band in 0..10 {
            self.retune_band(band);
        }
    }

    fn retune_band(&mut self, band: usize) {
        let gain_db = self.gains_db[band];
        if gain_db.abs() < FLAT_THRESHOLD_DB {
            self.active[band] = false;
            return;
        }
        match peaking_coeffs(self.sample_rate, EQ_BANDS[band], gain_db) {
            Some(coeffs) => {
                for ch in &mut self.filters[band] {
                    *ch = DirectForm2Transposed::new(coeffs);
                }
                self.active[band] = true;
            }
            None => {
                self.active[band] = false;
            }
        }
    }

    pub fn process_interleaved(&mut self, samples: &mut [f32]) {
        if !self.enabled || !self.active.iter().any(|&a| a) {
            return;
        }
        let ch = self.channels;
        if ch == 0 {
            return;
        }
        for frame in samples.chunks_exact_mut(ch) {
            for c in 0..ch {
                let mut s = frame[c] as f64;
                for (band, filters) in self.filters.iter_mut().enumerate() {
                    if self.active[band] {
                        s = filters[c].run(s);
                    }
                }
                frame[c] = s as f32;
            }
        }
    }

    pub fn gains_db(&self) -> &[f32; 10] {
        &self.gains_db
    }
    pub fn is_enabled(&self) -> bool {
        self.enabled
    }
}

fn peaking_coeffs(sample_rate: u32, fc: f32, gain_db: f32) -> Option<Coefficients<f64>> {
    if (fc as f64) >= sample_rate as f64 / 2.0 {
        return None;
    }
    let fs: Hertz<f64> = (sample_rate as f64).hz();
    let f0: Hertz<f64> = (fc as f64).hz();
    let q = bandwidth_to_q(BANDWIDTH_OCT);
    Coefficients::<f64>::from_params(Type::PeakingEQ(gain_db as f64), fs, f0, q).ok()
}

fn bandwidth_to_q(bw_oct: f64) -> f64 {
    (2.0_f64.powf(bw_oct)).sqrt() / (2.0_f64.powf(bw_oct) - 1.0)
}
