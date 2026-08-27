use ringbuf::HeapProd;
use std::sync::{Arc, Mutex};

pub type SharedProducer = Arc<Mutex<HeapProd<f32>>>;

pub const RING_MS: usize = 200;
pub const RING_EXTRA: usize = 1024;

pub fn ring_cap(sample_rate: u32, channels: u32) -> usize {
    (sample_rate as usize * channels as usize * RING_MS) / 1000 + RING_EXTRA
}
