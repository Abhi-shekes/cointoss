# 🎬 CINEMATIC PLAN v2 — "The Toss" (Blender film-grade pipeline)

> Goal: the toss should play like a scene cut from Peaky Blinders — a backlit man
> in a smoky bar flicks a heavy sovereign, the camera moves like a film camera,
> time dilates at the apex, and the coin slams down for the reveal.
>
> This machine: **i5-11260H (12 threads) · 16 GB RAM · NVIDIA RTX 3050 Laptop (OptiX)** —
> all render estimates below are grounded in this hardware.

---

## ⏱️ The headline answers

| Question | Answer |
|---|---|
| How long is one coin toss on screen? | **~8 seconds** (skippable by tap; "Quick toss" mode stays) |
| How long to render the photoreal **coin asset** (90 frames, 1024², Cycles+OptiX)? | **~7–15 s/frame → 10–25 min total render** + ~1–2 h one-time modeling/look-dev |
| How long to render the **full scene film** (one 8 s variant)? | **EEVEE: ~15–40 min** · Cycles w/ volumetrics: ~4–12 h |
| Both variants (heads + tails endings)? | EEVEE: **under 1.5 h** · Cycles: 1–2 overnights |
| Total human effort (modeling, animation, lighting, integration)? | **~5–8 focused days** |

---

## 1. Creative direction

**Reference grammar (Peaky Blinders):** low-key tungsten light, heavy backlight
through haze, silhouettes with rim light, slow deliberate camera moves, shallow
depth of field, anamorphic-feel flares, desaturated shadows / warm highlights,
2.39:1 letterbox.

**Rule:** the camera is always moving — even "static" shots breathe (handheld
micro-drift). Every cut lands on a sound.

---

## 2. The film — shot by shot (~8 s total)

| # | Shot | Dur | Camera & lens (Blender) | Action | Light | Sound |
|---|------|-----|--------------------------|--------|-------|-------|
| 1 | **The Bar** (establishing) | 1.8 s | 35 mm, dolly R→L on a curved track, f/2.8, focus on the man | Smoky bar. Backlit man at a table, coat + flat cap, cigarette smoke curling through a window light shaft. Coin glints on his thumb. Letterbox bars slide in | Single hard window key behind him (volumetric shaft), warm practical lamps as bokeh | Bar murmur, distant gramophone, cloth rustle |
| 2 | **The Flick** (close-up) | 1.4 s | 85 mm macro push-in on the hand, f/1.8 razor DoF | Stillness — one breath. Thumb tenses… **flick.** Coin leaves frame top; camera **tilts up** to follow, motion blur streaks | Rim on knuckles from the window; coin catches a hot glint at launch | Near-silence → metallic *ting* → rising whoosh |
| 3 | **The Apex** (slow-motion) | 3.0 s | 100 mm, slow **orbit** (15° arc) around the hovering coin, f/2.0 | Time dilates to ~5 %. The sovereign turns lazily in the light shaft, dust motes suspended, engraving flashing H…T…H. A smoke wisp curls past behind it | Coin *inside* the volumetric shaft — edge flares each half-turn; background falls to black | Audio low-passes into a sub drone + slowed heartbeat; each glint = soft chime |
| 4 | **The Land & Reveal** | 1.8 s + hold | **Whip-pan down** (8 frames, heavy directional blur) → 65 mm dolly-in on the coin face | Time snaps back. Coin **slams** onto the oak table, bounces once with sparks, wobble-settles. Camera pushes in tight on the face; light flares across the engraving → **HEADS / TAILS** title | Key flares up on impact, then settles into a hero spotlight on the coin | Snap-whoosh → heavy clink + felt thud + haptic → brass reveal sting |

**The two-variant trick:** the result is decided *before* playback, so we render
**two videos** — identical through Shot 3, different landing face in Shot 4:
`toss_heads.mp4`, `toss_tails.mp4`. The app just picks one. No runtime 3D needed.

---

## 3. Blender production pipeline

### 3.1 Assets to build (one-time)

| Asset | Approach | Est. effort |
|---|---|---|
| **The coin** (hero) | Cylinder + milled edge (procedural bump), sculpted/displaced H & T reliefs, aged-brass PBR (anisotropic brushed metal, edge wear via pointiness mask, fingerprints roughness map) | 1–2 h |
| **The man** | Silhouette-first: base mesh (or free CC0 scan) + long coat cloth sim + flat cap; NO facial detail needed — he's always backlit. Rig: simple armature, only the right arm needs real animation | 3–5 h |
| **The set** | One wall + window (light shaft source), oak table, 3–4 bottle/glass props for bokeh, floor. Low poly — it lives in shadow | 2–3 h |
| **Smoke / haze** | Two layers: room haze = Principled Volume (cheap), cigarette wisp = small smoke sim baked once (~20 min bake) | 1–2 h |
| **Animation** | Arm flick (12 frames of keyframes + follow-through), coin ballistic + spin via keyframed physics-match, camera paths on curves, wobble-settle on landing | 3–4 h |

### 3.2 Render strategy (the pragmatic hybrid)

- **Shots 1, 2, 4 → EEVEE-Next**: volumetric shafts, bloom, DoF, motion blur are
  all excellent in EEVEE and render in seconds per frame. Film grain added in
  post anyway — nobody can tell on a phone screen.
- **Shot 3 (the hero slow-mo) → Cycles + OptiX**: this is the money shot where
  real metal reflections matter. 3 s × 24 fps = 72 frames, ~2048×858 letterboxed.
- Composite pass (grain, vignette, subtle chromatic aberration, grade) in
  Blender's compositor or ffmpeg.

### 3.3 Render settings & times (RTX 3050, OptiX denoise)

| Job | Frames | Res | Engine / samples | Per frame | Total |
|---|---|---|---|---|---|
| Coin asset frames (for app widget/icon reuse) | 90 | 1024² | Cycles 128 + OptiX denoise | 7–15 s | **10–25 min** |
| Shots 1+2+4 (per variant) | ~120 | 1920×804 | EEVEE-Next | 3–8 s | 6–16 min |
| Shot 3 hero slow-mo (shared) | 72 | 1920×804 | Cycles 192 + denoise + volume shaft | 45–120 s | 55 min–2.4 h |
| **One full variant** | ~192 | — | hybrid | — | **≈ 1–3 h** |
| **Both variants** (Shot 3 shared!) | ~312 | — | hybrid | — | **≈ 1.3–3.5 h** |
| All-Cycles "maximum" version (optional) | 384 | 1920×804 | Cycles 256 + volumetrics | 2–6 min | 13–38 h (overnights) |

> ⚠️ RTX 3050 Laptop has 4 GB VRAM — keep textures ≤2K, bake the smoke sim at
> modest resolution, and render shots as separate scenes to stay inside memory.

### 3.4 Output files

```
assets/video/toss_heads.mp4   (~8s, H.264, 1920×804, ~6–8 MB @ CRF 20)
assets/video/toss_tails.mp4
assets/coin/frame_###.png     (photoreal replacements, drop-in — zero code change)
```

APK grows ~12–16 MB. Acceptable; still ~35 MB delivered.

---

## 4. Flutter integration

1. **`video_player`** plugin; both MP4s bundled as assets, pre-initialized at
   app start (instant playback on tap).
2. Tap → decide result → play matching video full-screen under the existing
   grain/vignette overlays (they stay live Flutter layers, so the image still
   feels alive over the video).
3. **Skip:** tap during playback → seek to the landing timestamp (≈ 6.2 s).
4. **Sound:** baked into the video track (perfect sync, replaces per-event SFX
   during the sequence); haptic fired at the landing timestamp from Dart.
5. **Reveal text + sparks** stay as live Flutter layers on top (crisper than
   baked-in text, and localizable).
6. **Fallback:** current procedural 2.5D scene remains in the code path for
   "Quick toss" mode and as insurance.
7. Home-screen widget upgrades automatically when the photoreal coin frames
   replace the procedural ones (same filenames).

---

## 5. Phases & schedule

| Phase | Work | Est. |
|---|---|---|
| **B1 — Setup** | Fetch portable Blender (~350 MB, no root needed) into scratchpad; verify OptiX sees the RTX 3050 | 0.5 h |
| **B2 — Hero coin** | Model + shade the sovereign; render the 90-frame asset sequence → instantly upgrades app + widget | 2–3 h (render: 10–25 min) |
| **B3 — Set & man** | Build set, haze, silhouette man, cloth/cap | 1 day |
| **B4 — Animation & cameras** | Flick, ballistic coin, 4 camera paths, wobble-settle | 1 day |
| **B5 — Light & look-dev** | Window shaft, practicals, per-shot grade, test stills approved | 0.5–1 day |
| **B6 — Render + post** | Batch render both variants (≈1.3–3.5 h GPU time), grain/grade pass, encode | 0.5 day |
| **B7 — App integration** | video_player flow, skip, haptic sync, Quick-toss fallback, perf test | 1 day |
| **B8 — Ship** | Version bump → push → CI publishes signed APK/AAB release | 0.5 h |

**Total: ~5–8 focused days**, of which GPU render time is only a few hours —
the RTX 3050 makes this very feasible on this exact machine.

### Sequencing note
B2 (hero coin) is worth doing **first and alone**: ~half a day total, and the
app + widget visibly jump in quality before any of the film work lands.

---

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| 4 GB VRAM overflow on volumetrics | Separate scene files per shot; modest smoke bake; CPU+GPU hybrid tiles if needed |
| Character looks cheap in close-up | He never is in close-up — Shot 2 is hand-only, everything else silhouette |
| Video playback jank on low-end phones | H.264 baseline profile, 804 p letterboxed; pre-initialize controllers; fallback mode |
| App size creep | CRF 20, two shared-audio tracks; cap videos ≤ 8 MB each |
| Blender learning curve for maintenance | All scene generation scripted in `tools/` (`render_coin.py` pattern) so re-renders are one command |
