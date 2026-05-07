use biquad::{Biquad, Coefficients, DirectForm1, Hertz, ToHertz, Type};

pub const EQ_BANDS: [f32; 10] = [
    31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
];
const MAX_GAIN_DB: f32 = 12.0;
const BANDWIDTH_OCT: f32 = 1.0;

pub struct Equalizer {
    filters: Vec<Vec<DirectForm1<f32>>>,
    gains_db: [f32; 10],
    sample_rate: u32,
    channels: usize,
    enabled: bool,
}

impl Equalizer {
    pub fn new(sample_rate: u32, channels: usize) -> Self {
        let gains_db = [0.0f32; 10];
        let filters = Self::build_filters(sample_rate, channels, &gains_db);
        Self {
            filters,
            gains_db,
            sample_rate,
            channels,
            enabled: false,
        }
    }

    fn build_filters(
        sample_rate: u32,
        channels: usize,
        gains_db: &[f32; 10],
    ) -> Vec<Vec<DirectForm1<f32>>> {
        let fs = (sample_rate as f32).hz();
        EQ_BANDS
            .iter()
            .enumerate()
            .map(|(i, &fc)| {
                let gain_db = gains_db[i].clamp(-MAX_GAIN_DB, MAX_GAIN_DB);
                let f0 = fc.hz();
                let q = bandwidth_to_q(BANDWIDTH_OCT);
                let coeffs = peaking_eq_coeffs(fs, f0, q, gain_db).unwrap_or_else(|_| {
                    Coefficients::from_params(Type::BandPass, fs, f0, q).unwrap()
                });
                (0..channels).map(|_| DirectForm1::new(coeffs)).collect()
            })
            .collect()
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
        self.filters = Self::build_filters(sample_rate, channels, &self.gains_db);
    }

    fn retune_band(&mut self, band: usize) {
        let fs = (self.sample_rate as f32).hz();
        let f0 = EQ_BANDS[band].hz();
        let q = bandwidth_to_q(BANDWIDTH_OCT);
        let gain_db = self.gains_db[band];
        let coeffs = peaking_eq_coeffs(fs, f0, q, gain_db)
            .unwrap_or_else(|_| Coefficients::from_params(Type::BandPass, fs, f0, q).unwrap());
        for ch in &mut self.filters[band] {
            *ch = DirectForm1::new(coeffs);
        }
    }

    pub fn process_interleaved(&mut self, samples: &mut [f32]) {
        if !self.enabled {
            return;
        }
        let ch = self.channels;
        for frame_start in (0..samples.len()).step_by(ch) {
            for c in 0..ch {
                let s = samples[frame_start + c];
                let mut out = s;
                for band in &mut self.filters {
                    out = band[c].run(out);
                }
                samples[frame_start + c] = out;
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

fn bandwidth_to_q(bw_oct: f32) -> f32 {
    let bw = bw_oct as f64;
    let q = (2.0_f64.powf(bw)).sqrt() / (2.0_f64.powf(bw) - 1.0);
    q as f32
}

fn peaking_eq_coeffs(
    fs: Hertz<f32>,
    f0: Hertz<f32>,
    q: f32,
    gain_db: f32,
) -> Result<Coefficients<f32>, biquad::Errors> {
    if gain_db.abs() < 0.01 {
        return Coefficients::from_params(Type::PeakingEQ(0.01), fs, f0, q);
    }
    Coefficients::from_params(Type::PeakingEQ(gain_db), fs, f0, q)
}
