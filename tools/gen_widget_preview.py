#!/usr/bin/env python3
"""Mockup of the home-screen widget card (two states) for the store/preview.
Writes assets/store/widget_preview.png."""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(__file__)
HEADS = os.path.join(HERE, "..", "assets", "coin", "frame_000.png")
TAILS = os.path.join(HERE, "..", "assets", "coin", "frame_045.png")
OUT = os.path.join(HERE, "..", "assets", "store")
os.makedirs(OUT, exist_ok=True)


def font(px):
    p = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
    return ImageFont.truetype(p, px) if os.path.exists(p) else ImageFont.load_default()


def card(coin_path, result, size=(300, 380)):
    w, h = size
    card = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    # radial dark bg + brass border
    bg = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(bg).rounded_rectangle([0, 0, w - 1, h - 1], radius=28,
                                          fill=(20, 20, 22, 255),
                                          outline=(138, 107, 46, 255), width=2)
    card.alpha_composite(bg)
    d.text((w / 2, 26), "COIN TOSS", font=font(15), fill=(154, 149, 140),
           anchor="mm")
    coin = Image.open(coin_path).convert("RGBA").resize((190, 190), Image.LANCZOS)
    card.alpha_composite(coin, ((w - 190) // 2, 60))
    d.text((w / 2, h - 40), result, font=font(30), fill=(243, 216, 154),
           anchor="mm")
    return card


def main():
    pad, gap = 40, 40
    a = card(HEADS, "HEADS")
    b = card(TAILS, "TAILS")
    W = pad * 2 + a.width + gap + b.width
    H = pad * 2 + a.height
    # soft wallpaper backdrop
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    g = np.exp(-(((xs - W / 2) / (W * 0.6)) ** 2 + ((ys - H / 2) / (H * 0.6)) ** 2))
    col = (np.array([28, 24, 30]) / 255)[None, None] + \
          (np.array([70, 40, 40]) / 255 - np.array([28, 24, 30]) / 255)[None, None] * g[..., None] * 0.5
    canvas = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")
    # drop shadow under cards
    for i, cimg in enumerate((a, b)):
        x = pad + i * (a.width + gap)
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle(
            [x + 6, pad + 10, x + cimg.width + 6, pad + cimg.height + 10],
            radius=28, fill=(0, 0, 0, 150))
        canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(12)))
        canvas.alpha_composite(cimg, (x, pad))
    canvas.convert("RGB").save(os.path.join(OUT, "widget_preview.png"))
    print("Wrote", os.path.join(OUT, "widget_preview.png"))


if __name__ == "__main__":
    main()
