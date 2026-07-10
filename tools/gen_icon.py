#!/usr/bin/env python3
"""Generate launcher-icon + splash art from the coin frame.
Outputs to assets/icon/. Re-run after re-rendering the coin."""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(__file__)
COIN = os.path.join(HERE, "..", "assets", "coin", "frame_000.png")
OUT = os.path.join(HERE, "..", "assets", "icon")
os.makedirs(OUT, exist_ok=True)


def dark_radial(size, warm=0.16):
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    r = np.sqrt(((xs - size / 2) / (size * 0.62)) ** 2 +
                ((ys - size / 2) / (size * 0.62)) ** 2)
    glow = np.clip(1 - r, 0, 1)
    base = np.array([20, 20, 24]) / 255.0
    amber = np.array([232, 165, 75]) / 255.0
    col = base[None, None] + (amber - base)[None, None] * (glow[..., None] * warm)
    col *= (1 - np.clip(r - 0.5, 0, 1)[..., None] * 0.7)
    a = np.ones((size, size, 1))
    return Image.fromarray(
        (np.clip(np.dstack([col, a]), 0, 1) * 255).astype(np.uint8), "RGBA")


def main():
    coin = Image.open(COIN).convert("RGBA")

    # Legacy square icon: coin on dark radial, full bleed.
    S = 1024
    bg = dark_radial(S)
    c = coin.resize((int(S * 0.74),) * 2, Image.LANCZOS)
    bg.alpha_composite(c, ((S - c.width) // 2, (S - c.height) // 2))
    bg.convert("RGB").save(os.path.join(OUT, "icon.png"))

    # Adaptive foreground: coin only, padded into the safe zone, transparent.
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cf = coin.resize((int(S * 0.60),) * 2, Image.LANCZOS)
    fg.alpha_composite(cf, ((S - cf.width) // 2, (S - cf.height) // 2))
    fg.save(os.path.join(OUT, "icon_foreground.png"))

    # Splash logo: coin on transparent, generous glow padding.
    L = 1152
    logo = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    cl = coin.resize((int(L * 0.5),) * 2, Image.LANCZOS)
    logo.alpha_composite(cl, ((L - cl.width) // 2, (L - cl.height) // 2))
    logo.save(os.path.join(OUT, "splash_logo.png"))

    print("Wrote icon.png, icon_foreground.png, splash_logo.png to", OUT)


if __name__ == "__main__":
    main()
