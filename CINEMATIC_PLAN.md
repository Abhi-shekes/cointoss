# 🎬 CINEMATIC PLAN v3 — "THE WAGER" (GTA-cutscene grade, 15–30 s per flip)

> Target look: a **GTA-style in-game cutscene** — realistic characters, a lived-in
> 1920s bar, film-language cameras (crane, rack focus, cut-on-action), heavy
> atmosphere, cinematic grade. One flip = one **25-second scene** (configurable
> 15–30 s, skippable at any moment).
>
> Render machine: **i5-11260H · 16 GB RAM · RTX 3050 Laptop 4 GB (OptiX)** —
> every estimate below is grounded in this hardware.

---

## ⏱️ Headline numbers

| Question | Answer |
|---|---|
| One flip on screen | **~25 s full scene** (15 s "Short" cut and instant "Quick toss" also shipped — see §6) |
| Photoreal hero **coin asset** (90 frames, reused app-wide) | ~7–15 s/frame → **10–25 min render** + 1–2 h modeling |
| Full scene render, **hybrid** EEVEE/Cycles (recommended) | **≈ 4–12 h GPU total** for BOTH endings |
| Full scene render, **all-Cycles ultra** | 20–50 h (2–3 overnights, scripted + resumable) |
| Added app size | **+20–30 MB** (segmented videos, H.264 CRF 20 letterboxed) |
| Total production effort | **≈ 2–4 weeks focused** (this is a real short-film pipeline) |

---

## 1. Why this is achievable at "GTA grade"

GTA cutscenes read as real because of **lighting, camera language, animation
weight, and grade** — not raw polygon counts. On a phone screen at 804 p
letterboxed, a Blender scene with:
- mocap-based body animation (Mixamo, free),
- believable skin/cloth shaders + shallow DoF,
- volumetric smoke and hard backlight,
- 2.39:1 bars, grain, halation, teal-shadow/amber-highlight grade

…lands squarely in that territory. Faces are kept in half-shadow and profile
(Peaky lighting), which is both the aesthetic *and* what sells realism cheaply.

---

## 2. The scene — "The Wager" (screenplay + shot list, 25 s master cut)

**Cast (3 men, as briefed):** THE TOSSER (center, coin man), the CHALLENGER
(across the table), the WITNESS (standing, smoking). A dispute is being settled
the old way.

| # | TC | Shot | Lens / camera | Action | Audio |
|---|----|------|---------------|--------|-------|
| 1 | 0:00–0:04 | **Crane down** through smoke | 28 mm, top-down crane descending past a hanging lamp into the table | The bar at night. Rain on the window. Three men around a table — tension. Letterbox bars close in. Title whisper: *"Call it."* | Rain, muffled gramophone, thunder roll |
| 2 | 0:04–0:07 | **Faces** (coverage) | 65 mm, slow lateral dolly; rack focus Challenger → Witness | Challenger leans forward, jaw set. Witness drags his cigarette; the ember flares, smoke crosses the lamp light | Cigarette crackle, chair creak |
| 3 | 0:07–0:10 | **The coin comes out** | 50 mm, push-in on the Tosser | He rises slowly (mocap stand), reaches into his waistcoat, produces the sovereign. Rolls it once across his knuckles | Coat rustle, coin-on-skin whisper |
| 4 | 0:10–0:12 | **Macro — the set** | 100 mm macro, f/1.8, micro handheld drift | Coin on thumbnail. Every scratch visible. A beat of absolute stillness — the room holds its breath | Room tone drops away; heartbeat enters |
| 5 | 0:12–0:13.5 | **The flick** (cut on action) | Two angles cut mid-flick: side 85 mm → low-angle 35 mm looking up past his chin | Thumb fires. Coin leaves frame; low angle catches it rising past his face into the lamp light | *TING* → rising whoosh |
| 6 | 0:13.5–0:19 | **THE APEX** (hero slow-mo) | 100 mm, 20° orbit + slow rise, f/2.0 | Time collapses to 4 %. The sovereign turns lazily inside the volumetric shaft; dust hangs; the engraving strobes H…T…H; in the coin's polished rim, the three warped faces stare up | Sub-drone + slowed heartbeat; a soft chime on each glint |
| 7 | 0:19–0:21 | **The drop** | Whip-tilt down (10 frames, heavy directional blur) → 65 mm high-speed tracking | Time snaps back. Coin plummets, **slams** the oak, bounces once — sparks — wobble-settles | Snap-whoosh → CLINK + table thud (haptic) |
| 8 | 0:21–0:24 | **Reveal** | 85 mm dolly-in to macro on the face | Lamplight flares across the engraving. **HEADS / TAILS** title stamps in engraved gold | Brass sting |
| 9 | 0:24–0:25+ | **Reactions** (ending-specific) | 65 mm, two quick cuts | Winner's slow smirk; loser exhales smoke and looks away. Hold on the coin | Gramophone swells back, rain returns |

### The variant strategy (critical for size + render time)
Result is decided at tap-time, so the film is **segmented**:

```
intro.mp4     0:00–0:12   shared            (~12 s)
flick.mp4     0:12–0:21   shared            (~9 s — flick, apex, drop-to-blur)
end_heads.mp4 0:21–0:25   heads landing + reactions (~4–5 s)
end_tails.mp4 0:21–0:25   tails landing + reactions (~4–5 s)
```
Only ~5 s is duplicated. Playback is gapless via two pre-initialized
`video_player` controllers. **Total video ≈ 20–30 MB.**

---

## 3. Production pipeline (Blender, all on this machine)

### 3.1 Characters — the "GTA" part
| Element | Approach | Effort |
|---|---|---|
| Bodies & faces | 3 base humans from **MakeHuman/MPFB (free)** or CC0 scans; GTA-level fidelity needs decent topology + PBR skin (subsurface), not film-VFX detail. Faces styled gaunt, mustaches, period haircuts | 2–3 days |
| Wardrobe | Long wool coats (cloth-sim, baked), waistcoats, **flat caps**; fabric from PolyHaven CC0 textures | 1–2 days |
| Animation | **Mixamo (free)** mocap retargeted: sit-lean, smoke idle, stand-up, arm gestures. Hand-keyed: knuckle roll, thumb flick, reactions. Facial: minimal — jaw/brow bones + the lighting does the acting | 2–3 days |

### 3.2 Environment
- Modular 1920s bar corner: table, bentwood chairs, back bar shelf w/ bottles
  (bokeh fodder), hanging cone lamp, sash window with **rain** (animated normal
  map + streak particles), wet-look floor.
- Props/textures from **PolyHaven (CC0)** + BlenderKit free tier; hero table &
  coin fully custom. Effort: 2–3 days.

### 3.3 Atmosphere & light
- Room haze: Principled Volume (cheap). Cigarette wisp + apex smoke: one small
  baked sim (~30 min bake).
- Key: hanging lamp (warm, hard). Back: window (cool moon/street). Ember, match
  flare as practicals. Per-shot relight is allowed — film rules, not game rules.

### 3.4 Render strategy (hybrid — the sane path)
| Shots | Engine | Why |
|---|---|---|
| 1, 2, 3, 9 (people, set) | **EEVEE-Next** | Character shots need DoF/bloom/volumes — all excellent and 5–15 s/frame |
| 4, 5, 7, 8 (coin close-ups) | **Cycles + OptiX** | Real metal reflections on the hero object |
| 6 (apex orbit) | **Cycles + OptiX** | The money shot — reflections of the three men in the rim |

### 3.5 Render-time budget (RTX 3050, 1920×804, OptiX denoise)
| Job | Frames | Per frame | Total |
|---|---|---|---|
| EEVEE shots (1,2,3,9 both endings) | ~330 | 5–15 s | 0.5–1.5 h |
| Cycles close-ups (4,5,7,8) | ~200 | 45–120 s | 2.5–6.5 h |
| Cycles apex orbit (6) | ~130 | 60–150 s | 2–5.5 h |
| **Hybrid total (both endings)** | ~660 | — | **≈ 5–13 h** (1 overnight) |
| All-Cycles ultra pass (optional final) | ~660 | 2–5 min | 22–55 h (2–3 overnights) |

> 4 GB VRAM rules: one .blend per shot, 2K texture cap, modest smoke bakes,
> persistent-data off between shots. Batch script with resume (`tools/render_scene.py`).

### 3.6 Post
Blender compositor or ffmpeg pass: grain, halation, vignette, teal/amber grade,
2.39:1 hard matte, audio mix (rain/gramophone bed + foley + score sting) →
H.264 CRF 20 segments.

---

## 4. Sound design (as important as pixels)
- Bed: rain + gramophone jazz (period-correct, royalty-free or synthesized)
- Foley: cloth, chair, coin-knuckle roll, cigarette
- The dilation moment: all ambience ducks into a sub-drone + heartbeat at 0:13.5
- Impact stack: snap-whoosh + clink + felt thud, haptic fired from Dart in sync
- Endings: two reaction mixes

---

## 5. App integration
1. Segmented gapless playback (`video_player`, dual pre-initialized controllers);
   result picked at tap → queue `end_heads` or `end_tails`.
2. Live Flutter layers stay on top: film grain, HEADS/TAILS title (crisper than
   baked, localizable), sparks, haptics.
3. **Skip**: any tap → jump to 0:21 (the landing). Double-tap → instant result.
4. Widget & app icon inherit the photoreal coin frames automatically (same
   `assets/coin/` filenames).
5. Battery/thermal: video decode is cheap (hardware decoder) — *lighter* than
   the current real-time effect stack during playback.

---

## 6. UX honesty — the 25-second problem
A 25 s scene is glorious **once** and exhausting on flip #14. Shipping plan:
- **First launch:** full 25 s scene (the "wow" that justifies ₹100)
- **Cinematic (default after):** 15 s cut (shots 4–9 — macro, flick, apex, land)
- **Quick toss:** current real-time flip (~3 s) — settings toggle
- Skip always available mid-scene. This protects reviews.

---

## 7. Schedule (phases)

| Phase | Work | Duration |
|---|---|---|
| G1 | Portable Blender install (~350 MB, no root) + OptiX verify | 0.5 h |
| G2 | **Hero coin** model/shade + 90-frame render → app & widget upgrade ships immediately | 0.5 day |
| G3 | Characters: bodies, wardrobe, caps, look-dev stills for approval | 3–5 days |
| G4 | Environment + rain + haze; lighting look-dev stills for approval | 2–3 days |
| G5 | Animation: mocap retarget + hand-keyed flick/reactions; blocking playblast (fast preview render) for approval | 3–5 days |
| G6 | Final lighting per shot + hybrid render (1 overnight) + post/grade/audio mix | 2–3 days |
| G7 | App integration: segmented playback, skip UX, modes, haptic sync | 1–2 days |
| G8 | Device/perf test → version bump → push → CI signs & releases | 0.5 day |

**Approval gates** at G3/G4/G5 (stills + playblast) so nothing renders overnight
before the look is signed off.

---

## 8. Risks
| Risk | Mitigation |
|---|---|
| Characters read "uncanny" in close-up | Peaky lighting: faces half-shadow/profile; the only true macro shots are hands & coin |
| 4 GB VRAM | Per-shot .blends, 2K caps, EEVEE for people shots |
| Render time balloons | Hybrid strategy locked; ultra pass optional at the very end |
| APK size | Segmented videos, CRF 20, cap ≈ 30 MB added; Play delivers per-device |
| 25 s fatigue | Three modes + skip (§6) |
| Asset licensing | Mixamo (free w/ Adobe terms, allowed in apps), PolyHaven CC0, MPFB open-source — all safe for commercial use; log every asset in `CREDITS.md` |
