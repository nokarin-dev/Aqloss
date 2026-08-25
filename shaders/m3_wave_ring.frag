#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uActive;
uniform vec4 uTrack;
uniform vec4 uGeom;
uniform vec4 uStroke;

out vec4 fragColor;

const float PI = 3.14159265359;
const float PI2 = 6.28318530718;

float cover(float d, float aa) {
  return clamp(0.5 - d / max(aa, 0.001), 0.0, 1.0);
}

vec2 polarCap(vec2 c, float ang, float radius, float amp, float phase, float waveK,
              float waveOrigin) {
  float alongWave = mod(ang - waveOrigin + PI2, PI2);
  float r = radius + amp * sin(phase + alongWave * radius * waveK);
  return c + vec2(cos(ang), sin(ang)) * r;
}

float sdRingArc(vec2 p, vec2 c, float radius, float a0, float sweep, float amp,
                float phase, float waveK, float halfW, float waveOrigin) {
  float alive = step(0.002, sweep);
  vec2 d = p - c;
  float dist = length(d);
  float ang = atan(d.y, d.x);
  float along = mod(ang - a0 + PI2, PI2);
  float alongWave = mod(ang - waveOrigin + PI2, PI2);
  float rMid = radius + amp * sin(phase + alongWave * radius * waveK);
  float sdRad = abs(dist - rMid) - halfW;
  float sdAng = max(-along * radius, (along - sweep) * radius);
  float sd = max(sdRad, sdAng);
  vec2 cap0 = polarCap(c, a0, radius, amp, phase, waveK, waveOrigin);
  vec2 cap1 = polarCap(c, a0 + sweep, radius, amp, phase, waveK, waveOrigin);
  sd = min(sd, min(length(p - cap0) - halfW, length(p - cap1) - halfW));
  return mix(1.0e6, sd, alive);
}

vec4 evalAt(vec2 p) {
  float progress = clamp(uGeom.x, 0.0, 1.0);
  float phase = uGeom.y;
  float amp = uGeom.z;
  float wavelength = max(uGeom.w, 1.0);
  float stroke = uStroke.x;
  float trackStroke = uStroke.y;
  float loading = uStroke.z;
  float dpr = max(uStroke.w, 1.0);
  float aa = 1.5 / dpr;

  vec2 c = uSize * 0.5;
  float maxStroke = max(stroke, trackStroke);
  float radius = (min(uSize.x, uSize.y) - maxStroke) * 0.5 - amp;
  float empty = step(radius, 1.0);
  float turns = max(floor((PI2 * radius) / wavelength + 0.5), 1.0);
  float waveK = turns / max(radius, 1.0);

  vec2 q = p;
  float ca = mix(1.0, cos(phase * 0.85), loading);
  float sa = mix(0.0, sin(phase * 0.85), loading);
  vec2 rel = p - c;
  q = c + vec2(ca * rel.x + sa * rel.y, -sa * rel.x + ca * rel.y);

  float start = -0.5 * PI;
  float loadSweep = mix(0.18, 0.72, (sin(phase) + 1.0) * 0.5) * PI2;
  float activeSweep = mix(progress * PI2, loadSweep, loading);
  float trackStart = start + activeSweep + mix(0.12, 0.0, loading);
  float trackSweep = mix(PI2 - activeSweep - 0.24, PI2 - loadSweep - 0.4, loading);

  float dTrack = sdRingArc(q, c, radius, trackStart, trackSweep, amp, phase, waveK,
                           trackStroke * 0.5, start);
  float dActive = sdRingArc(q, c, radius, start, activeSweep, amp, phase, waveK,
                            stroke * 0.5, start);

  float aT = cover(dTrack, aa) * (1.0 - empty);
  float aA = cover(dActive, aa) * (1.0 - empty);

  vec4 col = vec4(0.0);
  col = uTrack * aT + col * (1.0 - aT * uTrack.a);
  col = uActive * aA + col * (1.0 - aA * uActive.a);
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
