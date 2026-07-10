#!/usr/bin/env python3
"""Procedural brass-coin flip renderer (interim, until Blender frames exist).

Renders one seamless full rotation (0..2pi) of a coin spinning about its
horizontal axis, as RGBA PNGs. Frame 0 = HEADS up, frame N/2 = TAILS up.
Output: assets/coin/frame_###.png  (drop Blender output in the same place).

Run:  python3 tools/gen_placeholder_frames.py
Deps: pillow, numpy
"""
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

SIZE = 512
FRAMES = 90
R = 200.0            # face radius (px)
THICK = 26.0         # coin thickness (px)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "coin")

# Peaky-brass palette (linear-ish RGB 0..1)
BRASS = np.array([201, 160, 78]) / 255.0
BRASS_LIGHT = np.array([243, 216, 154]) / 255.0
BRASS_DEEP = np.array([120, 92, 40]) / 255.0
ENGRAVE = np.array([58, 15, 15]) / 255.0


def _font(px):
    for p in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf",
    ]:
        if os.path.exists(p):
            return ImageFont.truetype(p, int(px))
    return ImageFont.load_default()


def letter_mask(char, squash):
    """Alpha mask (SIZE,SIZE) of a vertically-squashed engraved glyph."""
    img = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(img)
    f = _font(R * 1.05)
    bb = d.textbbox((0, 0), char, font=f)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    d.text(((SIZE - w) / 2 - bb[0], (SIZE - h) / 2 - bb[1]), char, fill=255, font=f)
    if squash < 0.999:
        newh = max(1, int(SIZE * max(squash, 0.02)))
        img = img.resize((SIZE, newh), Image.LANCZOS)
        canvas = Image.new("L", (SIZE, SIZE), 0)
        canvas.paste(img, (0, (SIZE - newh) // 2))
        img = canvas
    return np.asarray(img, dtype=np.float32) / 255.0


def render_frame(theta):
    cos, sin = math.cos(theta), math.sin(theta)
    ac = abs(cos)
    faceH = R * ac                       # face ellipse semi-height
    d = (THICK / 2) * sin                # near/far face y-offset
    cx = cy = SIZE / 2

    ys, xs = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    u = (xs - cx) / R
    rgb = np.zeros((SIZE, SIZE, 3), np.float32)
    alpha = np.zeros((SIZE, SIZE), np.float32)

    # --- Rim band (drawn first, the coin's milled edge) ---
    rim_h = faceH + abs(d) + 2
    with np.errstate(divide="ignore", invalid="ignore"):
        rim_v = (ys - cy) / np.where(rim_h > 0, rim_h, 1)
    rim_mask = (u * u + rim_v * rim_v) <= 1.0
    # vertical milling stripes
    mill = 0.5 + 0.5 * np.cos((xs - cx) / R * 34.0)
    rim_col = BRASS_DEEP[None, None, :] * (0.6 + 0.4 * mill[..., None])
    rgb[rim_mask] = rim_col[rim_mask]
    alpha[rim_mask] = 1.0

    # --- Visible face (near side) ---
    if faceH > 0.5:
        fv = (ys - (cy + d)) / max(faceH, 1e-3)
        face_mask = (u * u + fv * fv) <= 1.0
        # radius within unit disk, and a sweeping key light from upper-left
        rr = np.sqrt(np.clip(u * u + fv * fv, 0, 1))
        light = np.clip(1.0 - ((u + 0.45) ** 2 + (fv + 0.5) ** 2) * 0.6, 0, 1)
        shade = np.clip(0.45 + 0.75 * light - 0.35 * rr, 0.15, 1.3)[..., None]
        base = BRASS[None, None, :] * shade
        base = base + (BRASS_LIGHT - BRASS)[None, None, :] * np.clip(
            light[..., None] - 0.55, 0, 1) * 1.4
        # inner bevel ring
        ring = np.clip(1.0 - abs(rr - 0.82) * 22, 0, 1)[..., None]
        base = base * (1 - 0.35 * ring) + BRASS_LIGHT[None, None, :] * 0.35 * ring

        # engraved letter (H at theta~0, T at theta~pi), squashed like the face
        char = "H" if cos >= 0 else "T"
        lm = letter_mask(char, max(ac, 0.02))[..., None]
        engraved = base * (1 - 0.85 * lm) + ENGRAVE[None, None, :] * 0.85 * lm
        # tiny top-lit lip on the engraving for depth
        engraved += BRASS_LIGHT[None, None, :] * 0.25 * np.clip(
            np.roll(lm, -2, axis=0) - lm, 0, 1)

        rgb[face_mask] = engraved[face_mask]
        alpha[face_mask] = 1.0

    img = np.dstack([np.clip(rgb, 0, 1), alpha]) * 255.0
    return Image.fromarray(img.astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    for i in range(FRAMES):
        theta = (i / FRAMES) * 2 * math.pi
        render_frame(theta).save(os.path.join(OUT, f"frame_{i:03d}.png"))
    print(f"Wrote {FRAMES} frames to {os.path.abspath(OUT)}")


if __name__ == "__main__":
    main()
