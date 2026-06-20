pub struct StereoEnhancer {
    sample_rate: u32,
    pub width: f32,
    pub haas_ms: f32,
    delay_buf: Vec<f32>,
    delay_write: usize,
    delay_samples: usize,
    shelf_x1: [f32; 2],
    shelf_x2: [f32; 2],
    shelf_y1: [f32; 2],
    shelf_y2: [f32; 2],
    shelf_b: [f32; 3],
    shelf_a: [f32; 2],
}

impl StereoEnhancer {
    pub fn new(sample_rate: u32) -> Self {
        let (b, a) = shelf_coeffs(sample_rate, 6000.0, 2.5);
        Self {
            sample_rate,
            width: 1.0,
            haas_ms: 0.0,
            delay_buf: vec![0.0; 4096],
            delay_write: 0,
            delay_samples: 0,
            shelf_x1: [0.0; 2],
            shelf_x2: [0.0; 2],
            shelf_y1: [0.0; 2],
            shelf_y2: [0.0; 2],
            shelf_b: b,
            shelf_a: a,
        }
    }

    pub fn reset_sample_rate(&mut self, sample_rate: u32) {
        self.sample_rate = sample_rate;
        let (b, a) = shelf_coeffs(sample_rate, 6000.0, 2.5);
        self.shelf_b = b;
        self.shelf_a = a;
        self.clear_state();
        self.rebuild_delay();
    }

    pub fn set_width(&mut self, width: f32) {
        self.width = width.clamp(0.0, 2.0);
    }

    pub fn set_haas_ms(&mut self, ms: f32) {
        self.haas_ms = ms.clamp(0.0, 25.0);
        self.rebuild_delay();
    }

    // Process interleaved stereo
    pub fn process(&mut self, samples: &mut [f32], channels: usize) {
        if channels != 2 || self.is_bypass() {
            return;
        }

        let width = self.width;
        // Side gain
        let side_gain = width;
        let mid_gain: f32 = 1.0;

        for frame in samples.chunks_exact_mut(2) {
            let l = frame[0];
            let r = frame[1];

            // M/S encode
            let mid = (l + r) * 0.5;
            let side = (l - r) * 0.5;

            // Width
            let mid_out = mid * mid_gain;
            let mut side_out = side * side_gain;

            // High-shelf on Side
            if (width - 1.0).abs() > 0.01 {
                side_out = self.shelf_run(side_out);
            }

            // M/S decode
            let l_out = mid_out + side_out;
            let r_out = mid_out - side_out;

            // Haas delay on right channel
            let r_delayed = if self.delay_samples > 0 {
                let read = (self.delay_write + self.delay_buf.len() - self.delay_samples)
                    % self.delay_buf.len();
                let out = self.delay_buf[read];
                self.delay_buf[self.delay_write] = r_out;
                self.delay_write = (self.delay_write + 1) % self.delay_buf.len();
                out
            } else {
                r_out
            };

            frame[0] = l_out;
            frame[1] = r_delayed;
        }
    }

    fn is_bypass(&self) -> bool {
        (self.width - 1.0).abs() < 1e-4 && self.delay_samples == 0
    }

    fn shelf_run(&mut self, x: f32) -> f32 {
        // Single biquad
        let y = self.shelf_b[0] * x
            + self.shelf_b[1] * self.shelf_x1[0]
            + self.shelf_b[2] * self.shelf_x2[0]
            - self.shelf_a[0] * self.shelf_y1[0]
            - self.shelf_a[1] * self.shelf_y2[0];
        self.shelf_x2[0] = self.shelf_x1[0];
        self.shelf_x1[0] = x;
        self.shelf_y2[0] = self.shelf_y1[0];
        self.shelf_y1[0] = y;
        y
    }

    fn rebuild_delay(&mut self) {
        self.delay_samples = ((self.haas_ms / 1000.0) * self.sample_rate as f32).round() as usize;
        let cap = (self.delay_samples + 256).max(4096);
        if self.delay_buf.len() < cap {
            self.delay_buf.resize(cap, 0.0);
        }
    }

    pub fn clear_state(&mut self) {
        self.shelf_x1 = [0.0; 2];
        self.shelf_x2 = [0.0; 2];
        self.shelf_y1 = [0.0; 2];
        self.shelf_y2 = [0.0; 2];
        self.delay_buf.fill(0.0);
        self.delay_write = 0;
    }
}

/// High-shelf biquad coefficients
fn shelf_coeffs(sample_rate: u32, fc: f32, gain_db: f32) -> ([f32; 3], [f32; 2]) {
    let a = 10.0_f32.powf(gain_db / 40.0);
    let w0 = 2.0 * std::f32::consts::PI * fc / sample_rate as f32;
    let cos_w0 = w0.cos();
    let sin_w0 = w0.sin();
    let alpha = sin_w0 / 2.0 * ((a + 1.0 / a) * (1.0 / 1.0 - 1.0) + 2.0).sqrt();

    let b0 = a * ((a + 1.0) + (a - 1.0) * cos_w0 + 2.0 * a.sqrt() * alpha);
    let b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cos_w0);
    let b2 = a * ((a + 1.0) + (a - 1.0) * cos_w0 - 2.0 * a.sqrt() * alpha);
    let a0 = (a + 1.0) - (a - 1.0) * cos_w0 + 2.0 * a.sqrt() * alpha;
    let a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cos_w0);
    let a2 = (a + 1.0) - (a - 1.0) * cos_w0 - 2.0 * a.sqrt() * alpha;

    ([b0 / a0, b1 / a0, b2 / a0], [a1 / a0, a2 / a0])
}
