// i64 decode path for subframes wider than 32 bits (stereo side channel).

use std::cmp;
use std::num::Wrapping;

use symphonia_core::errors::{decode_error, unsupported_error, Result};
use symphonia_core::io::ReadBitsLtr;
use symphonia_core::util::bits::sign_extend_leq64_to_i64;

use super::rice_signed_to_i32;

#[derive(Debug)]
enum SubFrameType {
    Constant,
    Verbatim,
    FixedLinear(u32),
    Linear(u32),
}

#[inline(always)]
pub fn clamp_i64_to_i32(v: i64) -> i32 {
    v.clamp(i32::MIN as i64, i32::MAX as i64) as i32
}

pub fn decorrelate_left_side_scratch(left: &mut [i64], side_enc: &mut [i64]) {
    for (l, s) in left.iter_mut().zip(side_enc.iter_mut()) {
        *s = l.wrapping_sub(*s);
    }
}

pub fn decorrelate_mid_side_scratch(mid: &mut [i64], side_enc: &mut [i64]) {
    for i in 0..mid.len() {
        let m = mid[i];
        let s = side_enc[i];
        let mid2 = (m << 1) | (s & 1);
        mid[i] = mid2.wrapping_add(s) >> 1;
        side_enc[i] = mid2.wrapping_sub(s) >> 1;
    }
}

pub fn decorrelate_right_side_scratch(right: &[i64], side_enc: &mut [i64]) {
    for (s, &r) in side_enc.iter_mut().zip(right) {
        *s = s.wrapping_add(r);
    }
}

pub fn decorrelate_left_side_wide(left: &[i32], side_enc: &[i64], side_out: &mut [i32]) {
    for ((out, &l), &se) in side_out.iter_mut().zip(left).zip(side_enc) {
        *out = clamp_i64_to_i32(l as i64 - se);
    }
}

pub fn decorrelate_mid_side_wide(mid: &mut [i32], side_enc: &[i64], side_out: &mut [i32]) {
    for i in 0..mid.len() {
        let m = mid[i] as i64;
        let s = side_enc[i];
        let mid2 = (m << 1) | (s & 1);
        mid[i] = clamp_i64_to_i32(mid2.wrapping_add(s) >> 1);
        side_out[i] = clamp_i64_to_i32(mid2.wrapping_sub(s) >> 1);
    }
}

pub fn decorrelate_right_side_wide(right: &[i32], side_enc: &[i64], side_out: &mut [i32]) {
    for ((out, &r), &se) in side_out.iter_mut().zip(right).zip(side_enc) {
        *out = clamp_i64_to_i32(se + r as i64);
    }
}

pub fn read_subframe_wide<B: ReadBitsLtr>(
    bs: &mut B,
    frame_bps: u32,
    buf: &mut [i64],
) -> Result<()> {
    if bs.read_bool()? {
        return decode_error("flac: subframe padding is not 0");
    }

    let subframe_type_enc = bs.read_bits_leq32(6)?;

    let subframe_type = match subframe_type_enc {
        0x00 => SubFrameType::Constant,
        0x01 => SubFrameType::Verbatim,
        0x08..=0x0f => {
            let order = subframe_type_enc & 0x07;
            if order > 4 {
                return decode_error("flac: fixed predictor orders of greater than 4 are invalid");
            }
            SubFrameType::FixedLinear(order)
        }
        0x20..=0x3f => SubFrameType::Linear((subframe_type_enc & 0x1f) + 1),
        _ => return decode_error("flac: subframe type set to reserved value"),
    };

    let dropped_bps = if bs.read_bool()? {
        bs.read_unary_zeros()? + 1
    } else {
        0
    };
    if dropped_bps > frame_bps {
        return decode_error("flac: dropped bits per sample is greater than the frame bits per sample");
    }

    let bps = frame_bps - dropped_bps;

    match subframe_type {
        SubFrameType::Constant => decode_constant_wide(bs, bps, buf)?,
        SubFrameType::Verbatim => decode_verbatim_wide(bs, bps, buf)?,
        SubFrameType::FixedLinear(order) => decode_fixed_linear_wide(bs, bps, order, buf)?,
        SubFrameType::Linear(order) => decode_linear_wide(bs, bps, order, buf)?,
    };

    samples_shl_wide(dropped_bps, buf);
    Ok(())
}

#[inline(always)]
fn samples_shl_wide(shift: u32, buf: &mut [i64]) {
    if shift > 0 {
        for sample in buf.iter_mut() {
            *sample = sample.wrapping_shl(shift);
        }
    }
}

fn decode_constant_wide<B: ReadBitsLtr>(bs: &mut B, bps: u32, buf: &mut [i64]) -> Result<()> {
    let const_sample = sign_extend_leq64_to_i64(bs.read_bits_leq64(bps)?, bps);
    for sample in buf.iter_mut() {
        *sample = const_sample;
    }
    Ok(())
}

fn decode_verbatim_wide<B: ReadBitsLtr>(bs: &mut B, bps: u32, buf: &mut [i64]) -> Result<()> {
    for sample in buf.iter_mut() {
        *sample = sign_extend_leq64_to_i64(bs.read_bits_leq64(bps)?, bps);
    }
    Ok(())
}

fn decode_fixed_linear_wide<B: ReadBitsLtr>(
    bs: &mut B,
    bps: u32,
    order: u32,
    buf: &mut [i64],
) -> Result<()> {
    if order as usize > buf.len() {
        return decode_error("flac: fixed predictor order is greater than the block size");
    }

    decode_verbatim_wide(bs, bps, &mut buf[..order as usize])?;
    decode_residual_wide(bs, order, buf)?;
    fixed_predict_wide(order, buf);
    Ok(())
}

fn flac_log2(v: u32) -> u32 {
    if v == 0 {
        0
    } else {
        32 - (v - 1).leading_zeros()
    }
}

fn needs_high_precision_lpc(bps: u32, coeff_prec: u32, order: u32, coeff_shift: i64) -> bool {
    i64::from(bps) + i64::from(coeff_prec) + i64::from(flac_log2(order)) - coeff_shift > 32
}

fn lpc_restore_wide<const N: usize>(
    order: usize,
    coeffs: &[i32; N],
    coeff_shift: i64,
    residual: &[i64],
    samples: &mut [i64],
) {
    for i in order..samples.len() {
        let predicted = coeffs[N - order..N]
            .iter()
            .zip(&samples[i - order..i])
            .map(|(&c, &s)| i128::from(c) * i128::from(s))
            .sum::<i128>();
        samples[i] = residual[i].wrapping_add((predicted >> coeff_shift) as i64);
    }
}

fn decode_linear_wide<B: ReadBitsLtr>(
    bs: &mut B,
    bps: u32,
    order: u32,
    buf: &mut [i64],
) -> Result<()> {
    if order as usize > buf.len() {
        return decode_error("flac: predictor order is greater than the block size");
    }

    decode_verbatim_wide(bs, bps, &mut buf[0..order as usize])?;

    let qlp_precision = bs.read_bits_leq32(4)? + 1;
    if qlp_precision > 15 {
        return decode_error("flac: qlp precision set to reserved value");
    }

    let qlp_coeff_shift =
        sign_extend_leq64_to_i64(bs.read_bits_leq64(5)?, 5);

    if qlp_coeff_shift >= 0 {
        let mut qlp_coeffs = [0i32; 32];
        for c in qlp_coeffs.iter_mut().rev().take(order as usize) {
            *c = sign_extend_leq64_to_i64(bs.read_bits_leq64(qlp_precision)?, qlp_precision) as i32;
        }

        let use_restore = needs_high_precision_lpc(bps, qlp_precision, order, qlp_coeff_shift);

        #[inline(always)]
        fn lpc<const N: usize>(
            order: u32,
            coeffs: &[i32; 32],
            coeff_shift: i64,
            buf: &mut [i64],
        ) {
            let coeffs_n = (&coeffs[32 - N..32]).try_into().unwrap();
            lpc_predict_wide::<N>(order as usize, coeffs_n, coeff_shift as u32, buf);
        }

        #[inline(always)]
        fn restore<const N: usize>(
            order: u32,
            coeffs: &[i32; 32],
            coeff_shift: i64,
            residual: &[i64],
            buf: &mut [i64],
        ) {
            let coeffs_n = (&coeffs[32 - N..32]).try_into().unwrap();
            lpc_restore_wide::<N>(order as usize, coeffs_n, coeff_shift, residual, buf);
        }

        if use_restore {
            let mut residual = vec![0i64; buf.len()];
            decode_residual_wide(bs, order, &mut residual)?;
            match order {
                0..=4 => restore::<4>(order, &qlp_coeffs, qlp_coeff_shift, &residual, buf),
                5..=6 => restore::<6>(order, &qlp_coeffs, qlp_coeff_shift, &residual, buf),
                7..=8 => restore::<8>(order, &qlp_coeffs, qlp_coeff_shift, &residual, buf),
                9..=10 => restore::<10>(order, &qlp_coeffs, qlp_coeff_shift, &residual, buf),
                11..=12 => restore::<12>(order, &qlp_coeffs, qlp_coeff_shift, &residual, buf),
                _ => restore::<32>(order, &qlp_coeffs, qlp_coeff_shift, &residual, buf),
            };
        } else {
            decode_residual_wide(bs, order, buf)?;
            match order {
                0..=4 => lpc::<4>(order, &qlp_coeffs, qlp_coeff_shift, buf),
                5..=6 => lpc::<6>(order, &qlp_coeffs, qlp_coeff_shift, buf),
                7..=8 => lpc::<8>(order, &qlp_coeffs, qlp_coeff_shift, buf),
                9..=10 => lpc::<10>(order, &qlp_coeffs, qlp_coeff_shift, buf),
                11..=12 => lpc::<12>(order, &qlp_coeffs, qlp_coeff_shift, buf),
                _ => lpc::<32>(order, &qlp_coeffs, qlp_coeff_shift, buf),
            };
        }
    } else {
        return unsupported_error("flac: lpc shifts less than 0 are not supported");
    }

    Ok(())
}

fn decode_residual_wide<B: ReadBitsLtr>(
    bs: &mut B,
    n_prelude_samples: u32,
    buf: &mut [i64],
) -> Result<()> {
    let method_enc = bs.read_bits_leq32(2)?;
    let param_bit_width = match method_enc {
        0x0 => 4,
        0x1 => 5,
        _ => return decode_error("flac: residual method set to reserved value"),
    };

    let order = bs.read_bits_leq32(4)?;
    let n_partitions = 1usize << order;
    let n_partition_samples = buf.len() >> order;

    if n_prelude_samples as usize > n_partition_samples {
        return decode_error("flac: residual partition too small for given predictor order");
    }
    if n_partitions * n_partition_samples != buf.len() {
        return decode_error("flac: block size is not same as encoded residual");
    }

    decode_rice_partition_wide(
        bs,
        param_bit_width,
        &mut buf[n_prelude_samples as usize..n_partition_samples],
    )?;

    for buf_chunk in buf[n_partition_samples..].chunks_mut(n_partition_samples) {
        decode_rice_partition_wide(bs, param_bit_width, buf_chunk)?;
    }

    Ok(())
}

fn decode_rice_partition_wide<B: ReadBitsLtr>(
    bs: &mut B,
    param_bit_width: u32,
    buf: &mut [i64],
) -> Result<()> {
    let rice_param = bs.read_bits_leq32(param_bit_width)?;

    if rice_param < (1 << param_bit_width) - 1 {
        for sample in buf.iter_mut() {
            let q = bs.read_unary_zeros()?;
            let r = bs.read_bits_leq32(rice_param)?;
            *sample = rice_signed_to_i32((q << rice_param) | r) as i64;
        }
    } else {
        let residual_bits = bs.read_bits_leq32(5)?;
        for sample in buf.iter_mut() {
            *sample = sign_extend_leq64_to_i64(
                bs.read_bits_leq64(residual_bits)?,
                residual_bits,
            );
        }
    }

    Ok(())
}

fn fixed_predict_wide(order: u32, buf: &mut [i64]) {
    match order {
        0 => (),
        1 => {
            for i in 1..buf.len() {
                buf[i] = buf[i].wrapping_add(buf[i - 1]);
            }
        }
        2 => {
            for i in 2..buf.len() {
                let a = Wrapping(-1) * Wrapping(buf[i - 2]);
                let b = Wrapping(2) * Wrapping(buf[i - 1]);
                buf[i] = buf[i].wrapping_add((a + b).0);
            }
        }
        3 => {
            for i in 3..buf.len() {
                let a = Wrapping(1) * Wrapping(buf[i - 3]);
                let b = Wrapping(-3) * Wrapping(buf[i - 2]);
                let c = Wrapping(3) * Wrapping(buf[i - 1]);
                buf[i] = buf[i].wrapping_add((a + b + c).0);
            }
        }
        4 => {
            for i in 4..buf.len() {
                let a = Wrapping(-1) * Wrapping(buf[i - 4]);
                let b = Wrapping(4) * Wrapping(buf[i - 3]);
                let c = Wrapping(-6) * Wrapping(buf[i - 2]);
                let d = Wrapping(4) * Wrapping(buf[i - 1]);
                buf[i] = buf[i].wrapping_add((a + b + c + d).0);
            }
        }
        _ => unreachable!(),
    }
}

fn lpc_predict_wide<const N: usize>(
    order: usize,
    coeffs: &[i32; N],
    coeff_shift: u32,
    buf: &mut [i64],
) {
    let n_prefill = cmp::min(N, buf.len()) - order;

    for i in order..order + n_prefill {
        let predicted = coeffs[N - order..N]
            .iter()
            .zip(&buf[i - order..i])
            .map(|(&c, &sample)| i128::from(c) * i128::from(sample))
            .sum::<i128>();
        buf[i] = buf[i].wrapping_add((predicted >> coeff_shift) as i64);
    }

    if buf.len() <= N {
        return;
    }

    for i in N..buf.len() {
        let predicted = coeffs
            .iter()
            .zip(&buf[i - N..i])
            .map(|(&c, &s)| i128::from(c) * i128::from(s))
            .sum::<i128>();
        buf[i] = buf[i].wrapping_add((predicted >> coeff_shift) as i64);
    }
}
