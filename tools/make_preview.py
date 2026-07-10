#!/usr/bin/env python3
"""Compose the coin frames into a preview GIF using the app's cinematic
flip curve + toss arc, on a dark bar-style background. Illustration only."""
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(__file__)
FRAMES_DIR = os.path.join(HERE, "..", "assets", "coin")
OUT = os.path.join(HERE, "..", "preview.gif")
W, H = 512, 760
GIF_FRAMES = 64
COIN = 300
NFR = 90


def cinematic(t):  # mirrors _CinematicFlipCurve in toss_scene.dart
    if t < 0.45:
        u = t / 0.45
        return 0.5 * (1 - (1 - u) ** 2)
    if t < 0.72:
        return 0.5 + 0.12 * (t - 0.45) / (0.72 - 0.45)
    u = (t - 0.72) / (1 - 0.72)
    ease = 2 * u * u if u < 0.5 else 1 - (-2 * u + 2) ** 2 / 2
    return 0.62 + 0.38 * ease


def bg():
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    r = np.sqrt(((xs - W / 2) / (W * 0.7)) ** 2 + ((ys - H * 0.42) / (H * 0.6)) ** 2)
    glow = np.clip(1 - r, 0, 1)
    base = np.array([23, 23, 27]) / 255.0
    warm = np.array([232, 165, 75]) / 255.0
    col = base[None, None] + (warm - base)[None, None] * (glow[..., None] * 0.18)
    col *= (1 - np.clip(r - 0.4, 0, 1)[..., None] * 0.85)  # vignette
    return Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB")


def font(px):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, px)
    return ImageFont.load_default()


def main():
    coin_frames = [Image.open(os.path.join(FRAMES_DIR, f"frame_{i:03d}.png"))
                   .resize((COIN, COIN), Image.LANCZOS) for i in range(NFR)]
    turns = 5
    total = turns * 2 * math.pi + math.pi  # land on TAILS
    out = []
    for k in range(GIF_FRAMES):
        t = k / (GIF_FRAMES - 1)
        p = cinematic(t)
        spin = total * p
        frac = (spin / (2 * math.pi)) % 1.0
        idx = round(frac * NFR) % NFR
        arc = math.sin(math.pi * (t * t * (3 - 2 * t)))  # smoothstep arc
        lift = int(arc * H * 0.16)
        frame = bg().copy()
        cx, cy = (W - COIN) // 2, int(H * 0.34) - lift
        frame.paste(coin_frames[idx], (cx, cy), coin_frames[idx])
        out.append(frame)
    # reveal hold
    reveal = bg().copy()
    reveal.paste(coin_frames[45], ((W - COIN) // 2, int(H * 0.30)), coin_frames[45])
    d = ImageDraw.Draw(reveal)
    txt = "TAILS"
    f = font(72)
    bb = d.textbbox((0, 0), txt, font=f)
    d.text(((W - (bb[2] - bb[0])) / 2, H * 0.72), txt, fill=(243, 216, 154), font=f)
    out += [reveal] * 10

    durations = [70] * GIF_FRAMES + [90] * 10
    out[0].save(OUT, save_all=True, append_images=out[1:], duration=durations,
                loop=0, disposal=2)
    print("Wrote", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
