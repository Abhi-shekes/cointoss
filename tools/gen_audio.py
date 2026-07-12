#!/usr/bin/env python3
"""Synthesize the app's cinematic SFX procedurally (no external clips).
Writes 44.1kHz mono WAVs to assets/audio/. Re-run to tweak.

  whoosh.wav      coin launch / spin
  clink.wav       metallic landing
  reveal.wav      warm brass result swell
  ambient_bar.wav looping smoky-room bed
  ting.wav        thumbnail flick — bright metallic ping
  thunder.wav     distant storm roll for the opening crane shot
  apex.wav        looping sub-drone + heartbeat under the slow-mo apex
  sting.wav       low brass hit stamped under HEADS/TAILS
"""
import os
import wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def save(name, x):
    x = np.clip(x, -1, 1)
    x = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(x.tobytes())


def onepole_lp(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = a * x[i] + (1 - a) * acc
        y[i] = acc
    return y


def env(n, attack, release):
    a = int(SR * attack)
    r = int(SR * release)
    e = np.ones(n)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] = np.linspace(1, 0, r) ** 1.5
    return e


def whoosh(dur=0.55):
    n = int(SR * dur)
    t = np.linspace(0, dur, n)
    noise = rng.standard_normal(n)
    # sweep the low-pass cutoff up then down -> passing "whoosh"
    swept = onepole_lp(noise, 0.02) * 1.5 + onepole_lp(noise, 0.12) * 0.6
    e = np.sin(np.pi * t / dur) ** 1.6            # swell in-out
    doppler = 1 + 0.25 * np.sin(2 * np.pi * 1.4 * t)
    return swept * e * doppler * 0.55


def clink(dur=0.45):
    n = int(SR * dur)
    t = np.linspace(0, dur, n)
    partials = [(2410, 1.0), (3660, 0.7), (5200, 0.5), (6130, 0.35), (7750, 0.2)]
    body = np.zeros(n)
    for f, amp in partials:
        body += amp * np.sin(2 * np.pi * f * t) * np.exp(-t * (8 + f / 900))
    transient = rng.standard_normal(n) * np.exp(-t * 90) * 0.6  # strike click
    return (body / len(partials) + transient) * 0.9


def reveal(dur=1.3):
    n = int(SR * dur)
    t = np.linspace(0, dur, n)
    chord = [220.0, 277.18, 329.63, 440.0]        # warm A-major swell
    tone = np.zeros(n)
    for i, f in enumerate(chord):
        tone += np.sin(2 * np.pi * f * t) * (1.0 - 0.15 * i)
        tone += 0.15 * np.sin(2 * np.pi * f * 2 * t)  # brass shimmer
    shimmer = 0.05 * np.sin(2 * np.pi * 6 * t) * np.sin(2 * np.pi * 1760 * t)
    e = env(n, 0.12, 0.9)
    return (tone / len(chord) + shimmer) * e * 0.5


def ambient(dur=4.0):
    n = int(SR * dur)
    brown = np.cumsum(rng.standard_normal(n))
    brown = onepole_lp(brown, 0.0006)
    brown /= np.max(np.abs(brown)) + 1e-9
    drone = 0.15 * np.sin(2 * np.pi * 55 * np.linspace(0, dur, n))
    crackle = np.zeros(n)                          # sparse vinyl pops
    for idx in rng.integers(0, n, size=90):
        crackle[idx] = rng.standard_normal() * 0.4
    crackle = onepole_lp(crackle, 0.5)
    mix = brown * 0.5 + drone + crackle * 0.3
    # crossfade ends so the loop is seamless
    x = int(SR * 0.25)
    fade = np.ones(n)
    fade[:x] = np.linspace(0, 1, x)
    fade[-x:] = np.linspace(1, 0, x)
    loopable = mix.copy()
    loopable[:x] = mix[:x] * fade[:x] + mix[-x:] * fade[-x:][::-1]
    return loopable * 0.35


def ting(dur=0.35):
    n = int(SR * dur)
    t = np.linspace(0, dur, n)
    partials = [(3950, 1.0), (5880, 0.6), (8300, 0.35)]
    body = np.zeros(n)
    for f, amp in partials:
        body += amp * np.sin(2 * np.pi * f * t) * np.exp(-t * (14 + f / 700))
    strike = rng.standard_normal(n) * np.exp(-t * 160) * 0.4
    return (body / len(partials) + strike) * 0.8


def thunder(dur=2.6):
    n = int(SR * dur)
    t = np.linspace(0, dur, n)
    rumble = onepole_lp(rng.standard_normal(n), 0.004)
    rumble /= np.max(np.abs(rumble)) + 1e-9
    # two rolling swells — a near crack decaying into a distant roll
    swell = np.exp(-t * 2.2) * 0.9 + np.exp(-((t - 1.1) ** 2) / 0.18) * 0.5
    crack = onepole_lp(rng.standard_normal(n), 0.08) * np.exp(-t * 24) * 0.5
    return (rumble * swell + crack) * 0.8


def apex(dur=4.0):
    """Loopable time-dilation bed: 45 Hz sub-drone + slowed heartbeat."""
    n = int(SR * dur)
    t = np.linspace(0, dur, n)
    drone = 0.35 * np.sin(2 * np.pi * 45 * t) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.5 * t))
    drone += 0.12 * np.sin(2 * np.pi * 90 * t + 0.5)
    beat = np.zeros(n)
    for start in np.arange(0, dur, 1.0):          # 60 bpm, lub-dub
        for off, amp in ((0.0, 1.0), (0.16, 0.6)):
            i0 = int((start + off) * SR)
            if i0 >= n:
                continue
            seg = min(int(SR * 0.10), n - i0)
            tb = np.linspace(0, seg / SR, seg)
            beat[i0:i0 + seg] += amp * np.sin(2 * np.pi * 58 * tb) * np.exp(-tb * 40)
    mix = drone + beat * 0.8
    x = int(SR * 0.2)                              # seamless loop crossfade
    fade = np.linspace(0, 1, x)
    mix[:x] = mix[:x] * fade + mix[-x:] * fade[::-1]
    return mix * 0.6


def sting(dur=1.1):
    n = int(SR * dur)
    t = np.linspace(0, dur, n)
    chord = [110.0, 164.81, 220.0]                 # low A stack — a verdict
    tone = np.zeros(n)
    for f in chord:
        for k, amp in ((1, 1.0), (2, 0.45), (3, 0.22)):  # brassy harmonics
            tone += amp * np.sin(2 * np.pi * f * k * t + 0.1 * k)
    tone = onepole_lp(tone, 0.25)
    hit = onepole_lp(rng.standard_normal(n), 0.02) * np.exp(-t * 30) * 0.5
    e = env(n, 0.008, 0.8)
    return (tone / (len(chord) * 1.7) + hit) * e * 0.85


def main():
    os.makedirs(OUT, exist_ok=True)
    save("whoosh.wav", whoosh())
    save("clink.wav", clink())
    save("reveal.wav", reveal())
    save("ambient_bar.wav", ambient())
    save("ting.wav", ting())
    save("thunder.wav", thunder())
    save("apex.wav", apex())
    save("sting.wav", sting())
    print("Wrote SFX to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
