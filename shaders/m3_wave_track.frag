#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uActive;
uniform vec4 uInactive;
uniform vec4 uGeom;
uniform vec4 uBar;
uniform vec4 uMeta;

out vec4 fragColor;

const float PI2 = 6.28318530718;

float sdRoundBox(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + vec2(r);
  return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float cover(float d, float aa) {
  return clamp(0.5 - d / max(aa, 0.001), 0.0, 1.0);
}

float waveY(float x, float cy, float amp, float phase, float origin, float k) {
  return cy + amp * sin(phase + (x - origin) * k);
}

float sdWaveBar(vec2 p, float x0, float x1, float cy, float amp, float phase,
                float origin, float k, float r) {
  float alive = step(x0 + 0.25, x1);
  vec2 c0 = vec2(x0, waveY(x0, cy, amp, phase, origin, k));
  vec2 c1 = vec2(x1, waveY(x1, cy, amp, phase, origin, k));
  float dCaps = min(length(p - c0), length(p - c1)) - r;
  float x = clamp(p.x, x0, x1);
  float dBody = abs(p.y - waveY(x, cy, amp, phase, origin, k)) - r;
  float inside = step(x0, p.x) * step(p.x, x1);
  return mix(1.0e6, mix(dCaps, dBody, inside), alive);
}

vec4 evalAt(vec2 p) {
  float value = clamp(uGeom.x, 0.0, 1.0);
  float phase = uGeom.y;
  float amp = uGeom.z;
  float wavelength = max(uGeom.w, 1.0);
  float trackH = uBar.x;
  float handleW = uBar.y;
  float handleH = uBar.z;
  float handleGap = uBar.w;
  float dpr = max(uMeta.x, 1.0);
  float aa = 1.5 / dpr;

  float pad = handleW * 0.5 + 1.0;
  float left = pad;
  float right = uSize.x - pad;
  float span = right - left;
  float empty = step(span, 1.0);
  float thumbX = left + span * value;
  float cy = uSize.y * 0.5;
  float k = PI2 / wavelength;
  float halfT = trackH * 0.5;
  float activeEnd = thumbX - handleW * 0.5 - handleGap;
  float inactiveStart = thumbX + handleW * 0.5 + handleGap;

  float dInact = sdWaveBar(p, inactiveStart, right, cy, 0.0, 0.0, left, k, halfT);
  float dAct = sdWaveBar(p, left, activeEnd, cy, amp, phase, left, k, halfT);
  float dHandle = sdRoundBox(
      p - vec2(thumbX, cy),
      vec2(handleW, handleH) * 0.5,
      min(handleW, handleH) * 0.5);

  float aIn = cover(dInact, aa) * (1.0 - empty);
  float aAc = cover(dAct, aa) * (1.0 - empty);
  float aH = cover(dHandle, aa) * (1.0 - empty);

  vec4 col = vec4(0.0);
  col = uInactive * aIn + col * (1.0 - aIn * uInactive.a);
  col = uActive * aAc + col * (1.0 - aAc * uActive.a);
  col = uActive * aH + col * (1.0 - aH * uActive.a);
  return col;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec4 c = evalAt(p + vec2(-0.375, -0.125));
  c += evalAt(p + vec2(0.125, -0.375));
  c += evalAt(p + vec2(-0.125, 0.375));
  c += evalAt(p + vec2(0.375, 0.125));
  fragColor = c * 0.25;
}
