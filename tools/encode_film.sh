#!/usr/bin/env bash
# Grade + encode the Blender-rendered PNG sequences into the app's film
# segments. Teal-shadow/amber-highlight split tone, gentle contrast, lens
# vignette; grain stays live in Flutter (cleaner + smaller files).
#
#   film_work/master/0001..0276.png -> assets/film/intro.mp4      (11.5 s)
#   film_work/heads/0277..0384.png  -> assets/film/end_heads.mp4  (4.5 s)
#   film_work/tails/0277..0384.png  -> assets/film/end_tails.mp4  (4.5 s)
set -euo pipefail
cd "$(dirname "$0")/.."

GRADE="curves=b='0/0.03 0.5/0.5 1/0.97',colorbalance=bs=0.07:rs=-0.03:rh=0.05:bh=-0.05,eq=saturation=1.06:contrast=1.05,vignette=PI/4.6"
# Main profile + fastdecode keeps cheap phone SoCs on the hardware path.
ENC=(-c:v libx264 -profile:v main -level:v 4.0 -preset medium
     -tune fastdecode -crf 21 -pix_fmt yuv420p -movflags +faststart -an)

mkdir -p assets/film
ffmpeg -y -framerate 24 -start_number 1 -i film_work/master/%04d.png \
    -vf "$GRADE" "${ENC[@]}" assets/film/intro.mp4
ffmpeg -y -framerate 24 -start_number 277 -i film_work/heads/%04d.png \
    -vf "$GRADE" "${ENC[@]}" assets/film/end_heads.mp4
ffmpeg -y -framerate 24 -start_number 277 -i film_work/tails/%04d.png \
    -vf "$GRADE" "${ENC[@]}" assets/film/end_tails.mp4

ls -la assets/film/
