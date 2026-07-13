#!/usr/bin/env python3
"""Generate minted-relief height maps for the photoreal coin.

Writes tools/coin_maps/heads_height.png and tails_height.png (2048x2048,
grayscale). 128 = field, brighter = raised relief, darker = engraved recess.
render_coin.py feeds these into bump/roughness so the coin reads as struck
metal under raking light.

Heads: profile bust of a capped man, "COIN TOSS" arc + "1926".
Tails: laurel wreath around a large serif T monogram, "THE WAGER" arc.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 2048
C = SIZE // 2
FIELD = 128
SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
OUT = os.path.join(os.path.dirname(__file__), "coin_maps")


def base():
    img = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(img)
    # Coin field (everything outside the disc is irrelevant, keep dark).
    d.ellipse([40, 40, SIZE - 40, SIZE - 40], fill=FIELD)
    # Raised rim.
    d.ellipse([40, 40, SIZE - 40, SIZE - 40], outline=235, width=54)
    # Beading — the ring of dots inside the rim.
    r_bead = C - 150
    for i in range(96):
        a = i / 96 * 2 * math.pi
        x, y = C + r_bead * math.cos(a), C + r_bead * math.sin(a)
        d.ellipse([x - 16, y - 16, x + 16, y + 16], fill=225)
    return img, d


def arc_text(d, text, radius, a0, a1, size, fill=210, flip=False):
    """Letters placed along an arc, each rotated to the local tangent.
    flip=True lays text along the bottom arc, upright and reading L→R."""
    font = ImageFont.truetype(SERIF, size)
    n = len(text)
    for i, ch in enumerate(text):
        if ch == " ":
            continue
        # Bottom-arc text runs clockwise, so traverse the angles backwards.
        u = (n - 1 - i + 0.5) / n if flip else (i + 0.5) / n
        a = a0 + (a1 - a0) * u
        x, y = C + radius * math.cos(a), C + radius * math.sin(a)
        glyph = Image.new("L", (size * 2, size * 2), 0)
        gd = ImageDraw.Draw(glyph)
        gd.text((size, size), ch, font=font, fill=fill, anchor="mm")
        deg = -math.degrees(a) - 90 if not flip else -math.degrees(a) + 90
        glyph = glyph.rotate(deg, resample=Image.BICUBIC, center=(size, size))
        d._image.paste(  # additive-ish paste keeps the field untouched
            Image.new("L", glyph.size, fill), (int(x - size), int(y - size)),
            glyph.point(lambda p: 255 if p > 96 else 0))


def heads():
    img, d = base()
    arc_text(d, "COIN TOSS", C - 300, math.pi * 1.15, math.pi * 1.85, 150)
    arc_text(d, "1926", C - 300, math.pi * 0.38, math.pi * 0.62, 150, flip=True)

    # Profile bust facing left, one rounded silhouette (1000-unit space).
    def M(x, y):
        return (C - 500 + x, C - 560 + y)

    def P(pts, fill):
        d.polygon([M(x, y) for x, y in pts], fill=fill)

    bust = [
        (392, 380),                                      # under the brim
        (386, 420), (372, 438),                          # brow
        (356, 458), (338, 505), (356, 522),              # nose
        (352, 543), (362, 558),                          # upper lip
        (356, 582), (372, 612), (394, 648),              # lower lip → chin
        (438, 682), (500, 700),                          # jaw
        (540, 726), (552, 788),                          # neck front
        (520, 815),                                      # collar notch
        (610, 835), (760, 872),                          # shoulder rise
        (800, 960), (400, 960), (452, 845), (500, 812),  # chest base
        (585, 792), (612, 735),                          # nape → back neck
        (668, 660), (700, 560), (702, 462), (682, 392),  # rounded skull
    ]
    P(bust, 198)
    # Flat cap: full crown overlapping the skull, sloping to the brim.
    P([(330, 348), (392, 268), (500, 222), (630, 216), (716, 268),
       (730, 348), (700, 386), (560, 396), (400, 386)], 215)
    P([(302, 372), (348, 322), (438, 352), (440, 396), (322, 400)], 222)
    # Cap band groove (engraved).
    d.line([M(408, 388), M(700, 380)], fill=95, width=13)
    # Ear.
    d.ellipse([M(540, 480)[0], M(540, 480)[1], M(608, 592)[0], M(608, 592)[1]],
              fill=210)
    d.ellipse([M(558, 508)[0], M(558, 508)[1], M(592, 566)[0], M(592, 566)[1]],
              fill=172)
    # Eye slit + brow (engraved).
    d.line([M(398, 442), M(452, 436)], fill=90, width=12)
    # Mustache under the nose, tucked against the lip.
    P([(358, 528), (428, 520), (438, 552), (366, 556)], 105)
    # Collar seam.
    d.line([M(520, 818), M(568, 770)], fill=100, width=12)
    return img


def tails():
    img, d = base()
    arc_text(d, "THE WAGER", C - 300, math.pi * 1.12, math.pi * 1.88, 150)

    # Laurel wreath: two arcs of leaves meeting at the bottom.
    for side in (-1, 1):
        for i in range(13):
            a = math.pi * 0.5 + side * (0.25 + i * 0.095) * math.pi
            r = C - 560
            x, y = C + r * math.cos(a), C + r * math.sin(a)
            leaf = Image.new("L", (200, 200), 0)
            ld = ImageDraw.Draw(leaf)
            ld.ellipse([70, 30, 130, 170], fill=205)
            leaf = leaf.rotate(-math.degrees(a) + side * 35,
                               resample=Image.BICUBIC)
            img.paste(Image.new("L", leaf.size, 205), (int(x - 100), int(y - 100)),
                      leaf.point(lambda p: 255 if p > 96 else 0))
    # Bow at the bottom of the wreath.
    d.ellipse([C - 70, C + 560 - 70 - 130, C + 70, C + 560 + 70 - 130], fill=210)

    # Big struck T monogram.
    font = ImageFont.truetype(SERIF, 760)
    d.text((C, C + 40), "T", font=font, fill=208, anchor="mm")
    return img


def finish(img, name):
    # Soft shoulders on the relief so bump reads as struck, not stamped paper.
    img = img.filter(ImageFilter.GaussianBlur(3.0))
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name))
    print("wrote", os.path.join(OUT, name))


if __name__ == "__main__":
    finish(heads(), "heads_height.png")
    finish(tails(), "tails_height.png")
