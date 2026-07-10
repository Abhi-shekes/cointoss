#!/usr/bin/env python3
"""Play Store feature graphic (1024x500): a smoky-bar scene, three
silhouetted figures in flat caps, the one on the right tossing a glinting
coin. Writes assets/store/feature_graphic.png."""
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(__file__)
COIN = os.path.join(HERE, "..", "assets", "coin", "frame_000.png")
OUT = os.path.join(HERE, "..", "assets", "store")
os.makedirs(OUT, exist_ok=True)
W, H = 1024, 500

BRASS = (201, 160, 78)
BRASS_LIGHT = (243, 216, 154)
AMBER = (232, 165, 75)


def font(px, serif=True):
    paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf" if serif
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for p in paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, px)
    return ImageFont.load_default()


def background():
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    # warm doorway/back-light band low-centre behind the figures
    glow = np.exp(-(((xs - W * 0.52) / (W * 0.42)) ** 2) -
                  (((ys - H * 0.60) / (H * 0.42)) ** 2))
    base = np.array([16, 15, 18]) / 255.0
    amber = np.array(AMBER) / 255.0
    col = base[None, None] + (amber - base)[None, None] * (glow[..., None] * 0.55)
    # floor darkening + top vignette
    col *= (1 - np.clip((ys - H * 0.72) / (H * 0.28), 0, 1)[..., None] * 0.5)
    r = np.sqrt(((xs - W / 2) / (W * 0.72)) ** 2 + ((ys - H / 2) / (H * 0.72)) ** 2)
    col *= (1 - np.clip(r - 0.6, 0, 1)[..., None] * 0.85)
    img = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB")
    return img


def figure(base, cx, ground, scale, raise_arm=False):
    """Peaky-style silhouette: flat cap, head, long flaring coat, arms.
    Drawn on its own layer so it gets a warm backlit rim glow."""
    black = (6, 5, 7, 255)
    s = scale
    L = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(L)

    head_r = int(30 * s)
    head_cy = ground - int(300 * s)
    sh_y = head_cy + head_r + int(6 * s)      # shoulder line
    sh_w = int(84 * s)
    waist_y = ground - int(150 * s)
    waist_w = int(50 * s)
    hem_y = ground - int(34 * s)
    hem_w = int(80 * s)                        # coat flare

    # long coat (shoulders -> waist -> flared hem)
    coat = [
        (cx - sh_w, sh_y), (cx + sh_w, sh_y),
        (cx + waist_w, waist_y), (cx + hem_w, hem_y),
        (cx + int(hem_w * 0.5), ground), (cx - int(hem_w * 0.5), ground),
        (cx - hem_w, hem_y), (cx - waist_w, waist_y),
    ]
    d.polygon(coat, fill=black)
    # legs peeking below the hem
    lw = int(14 * s)
    d.rectangle([cx - int(26 * s) - lw, hem_y, cx - int(26 * s) + lw, ground],
                fill=black)
    d.rectangle([cx + int(26 * s) - lw, hem_y, cx + int(26 * s) + lw, ground],
                fill=black)
    # arms along the coat sides (rounded)
    aw = int(16 * s)
    d.line([(cx - sh_w + int(6 * s), sh_y + int(6 * s)),
            (cx - waist_w - int(4 * s), waist_y)], fill=black,
           width=aw, joint="curve")
    if not raise_arm:
        d.line([(cx + sh_w - int(6 * s), sh_y + int(6 * s)),
                (cx + waist_w + int(4 * s), waist_y)], fill=black,
               width=aw, joint="curve")
    # neck + head
    d.rectangle([cx - int(12 * s), sh_y - int(18 * s), cx + int(12 * s), sh_y],
                fill=black)
    d.ellipse([cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r],
              fill=black)
    # flat cap: low dome + forward brim
    cap_y = head_cy - int(16 * s)
    d.ellipse([cx - head_r - int(3 * s), cap_y - int(16 * s),
               cx + head_r + int(3 * s), cap_y + int(20 * s)], fill=black)
    d.polygon([
        (cx - int(2 * s), cap_y + int(6 * s)),
        (cx + head_r + int(30 * s), cap_y - int(1 * s)),
        (cx + head_r + int(30 * s), cap_y + int(10 * s)),
        (cx - int(2 * s), cap_y + int(18 * s)),
    ], fill=black)

    hand = None
    if raise_arm:
        hand = (cx + sh_w + int(30 * s), head_cy - int(64 * s))
        d.line([(cx + sh_w - int(8 * s), sh_y + int(8 * s)),
                (cx + sh_w + int(34 * s), head_cy + int(6 * s)),
                hand], fill=black, width=aw, joint="curve")

    # warm backlit rim: amber-tinted, blurred, offset up-right, behind figure
    alpha = L.split()[3]
    rim = Image.new("RGBA", base.size, (0, 0, 0, 0))
    rim.paste(AMBER + (150,), (0, 0), alpha)
    rim = rim.filter(ImageFilter.GaussianBlur(5))
    base.paste(rim, (5, -5), rim)
    base.paste(L, (0, 0), L)
    return hand


def main():
    img = background().convert("RGBA")
    ground = int(H * 0.98)

    # three figures: left, mid (further back / smaller), right tosser
    figure(img, int(W * 0.20), ground, 0.95)
    figure(img, int(W * 0.40), ground - int(H * 0.03), 0.80)
    hand = figure(img, int(W * 0.74), ground, 1.0, raise_arm=True)

    # tossing coin: arc from the hand up to the light, with a motion streak
    coin = Image.open(COIN).convert("RGBA").resize((92, 92), Image.LANCZOS)
    apex = (int(W * 0.83), int(H * 0.20))
    streak = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(streak)
    for i in range(14):
        t = i / 13
        x = int(hand[0] + (apex[0] - hand[0]) * t)
        y = int(hand[1] + (apex[1] - hand[1]) * t - math.sin(t * math.pi) * 30)
        a = int(120 * t)
        sd.ellipse([x - 3, y - 3, x + 3, y + 3], fill=BRASS_LIGHT + (a,))
    streak = streak.filter(ImageFilter.GaussianBlur(3))
    img.paste(streak, (0, 0), streak)
    # glow behind coin
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [apex[0] - 70, apex[1] - 70, apex[0] + 70, apex[1] + 70],
        fill=AMBER + (90,))
    img.paste(glow.filter(ImageFilter.GaussianBlur(18)), (0, 0),
              glow.filter(ImageFilter.GaussianBlur(18)))
    img.paste(coin, (apex[0] - 46, apex[1] - 46), coin)

    # title
    d = ImageDraw.Draw(img)
    tf = font(78)
    title = "COIN TOSS"
    d.text((60, 70), title, font=tf, fill=BRASS_LIGHT,
           stroke_width=2, stroke_fill=(60, 40, 12))
    sf = font(30, serif=False)
    d.text((64, 168), "CALL IT IN THE AIR", font=sf, fill=BRASS)

    # subtle film grain
    noise = (np.random.default_rng(3).random((H, W)) * 22).astype(np.int16)
    arr = np.asarray(img.convert("RGB")).astype(np.int16)
    arr = np.clip(arr + noise[..., None] - 11, 0, 255).astype(np.uint8)
    Image.fromarray(arr, "RGB").save(os.path.join(OUT, "feature_graphic.png"))
    print("Wrote", os.path.join(OUT, "feature_graphic.png"))


if __name__ == "__main__":
    main()
