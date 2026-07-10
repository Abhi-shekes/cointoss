#!/usr/bin/env python3
"""Synthesize the app's cinematic SFX procedurally (no external clips).
Writes 44.1kHz mono WAVs to assets/audio/. Re-run to tweak.

  whoosh.wav      coin launch / spin
  clink.wav       metallic landing
  reveal.wav      warm brass result swell
  ambient_bar.wav looping smoky-room bed
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


def main():
    os.makedirs(OUT, exist_ok=True)
    save("whoosh.wav", whoosh())
    save("clink.wav", clink())
    save("reveal.wav", reveal())
    save("ambient_bar.wav", ambient())
    print("Wrote SFX to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
