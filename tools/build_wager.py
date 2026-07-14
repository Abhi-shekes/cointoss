"""Builds and renders "The Wager" — the GTA-cutscene-grade coin toss film.

One 16 s scene @ 24 fps, 2.39:1 (1280x536), Cycles/OptiX:

  f1-72     S1 ESTABLISH   crane down past the lamp; lightning at the window
  f73-120   S2 FACES       lateral dolly, rack focus challenger → witness;
                           the cigarette ember flares
  f121-168  S3 THE SET     push-in: the tosser's fist rises, coin on thumb
  f169-180  S4 FLICK       low angle; the coin fires up into the lamp light
  f181-276  S5 APEX        slow-mo orbit; the sovereign turns lazily in the
                           volumetric shaft            [shared master ends]
  f277-300  S6 DROP+SLAM   whip down; coin slams the oak, bounces, settles
  f301-384  S7 REVEAL      macro push-in on the result       [per ending]

Frames 1-276 are shared; 277-384 are rendered per ending (heads/tails).

Usage (headless):
  blender -b --python tools/build_wager.py -- --mode stills --ending heads
  blender -b --python tools/build_wager.py -- --mode anim --ending heads \
      --start 1 --end 276 --out film_work/master
  # anim mode skips frames that already exist → resumable.
"""
import math
import os
import random
import sys

import bpy  # type: ignore
from mathutils import Vector  # type: ignore

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
MAPS = os.path.join(HERE, "coin_maps")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(flag, default):
    return type(default)(argv[argv.index(flag) + 1]) if flag in argv else default


MODE = arg("--mode", "stills")          # stills | anim
ENDING = arg("--ending", "heads")       # heads | tails
START = arg("--start", 1)
END = arg("--end", 384)
OUT = arg("--out", os.path.join(ROOT, "film_work", "stills"))
RES_X = arg("--resx", 704)   # portrait full-screen (19.6:9 vertical),
RES_Y = arg("--resy", 1536)  # multiples of 16 for happy hardware decoders
SAMPLES = arg("--samples", 44)
MBLUR = arg("--mblur", 1)  # 1 only for the flick + drop ranges — it is the
#                            dominant cost on volume-heavy frames
ENGINE = arg("--engine", "cycles")  # cycles | eevee (GL — survives dead CUDA)

FPS = 24
F_FACES, F_SET, F_FLICK, F_APEX, F_DROP, F_REVEAL, F_END = (
    73, 121, 169, 181, 277, 301, 384)

# Palette
WOOL_DARK = (0.010, 0.009, 0.011, 1)
WOOL_OXBLOOD = (0.028, 0.010, 0.009, 1)
WOOL_GREY = (0.016, 0.016, 0.018, 1)
SKIN = (0.07, 0.042, 0.028, 1)
BRASS = (0.72, 0.55, 0.24, 1.0)
GRIME = (0.25, 0.17, 0.07, 1.0)

rng = random.Random(7)


# ---------------------------------------------------------------- utilities
def link(obj):
    bpy.context.collection.objects.link(obj)
    return obj


def mat_principled(name, color, rough=0.8, metallic=0.0, sheen=0.0,
                   subsurface=0.0, clearcoat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metallic
    if sheen and "Sheen Weight" in b.inputs:
        b.inputs["Sheen Weight"].default_value = sheen
    if subsurface and "Subsurface Weight" in b.inputs:
        b.inputs["Subsurface Weight"].default_value = subsurface
        b.inputs["Subsurface Radius"].default_value = (0.008, 0.004, 0.003)
    if clearcoat and "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = clearcoat
    return m


def wood_material(name, base=(0.16, 0.085, 0.04), dark=(0.05, 0.025, 0.012),
                  scale=3.0, rough=0.35, coat=0.25):
    """Procedural plank/ring wood with a faintly wet clearcoat."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (scale, scale * 3, scale)
    nt.links.new(tex.outputs["Object"], mapping.inputs["Vector"])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.0
    noise.inputs["Detail"].default_value = 8.0
    nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = 0.6
    wave.inputs["Distortion"].default_value = 1.6
    wave.inputs["Detail"].default_value = 3.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*base, 1)
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    rough_ramp = nt.nodes.new("ShaderNodeMath")
    rough_ramp.operation = "MULTIPLY_ADD"
    nt.links.new(noise.outputs["Fac"], rough_ramp.inputs[0])
    rough_ramp.inputs[1].default_value = 0.25
    rough_ramp.inputs[2].default_value = rough
    nt.links.new(rough_ramp.outputs["Value"], b.inputs["Roughness"])
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = coat
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.15
    bump.inputs["Distance"].default_value = 0.002
    nt.links.new(wave.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def smooth():
    # Angle-based smoothing via the data API — the shade ops return
    # CANCELLED in background mode. Sharp edges keep cylinder caps flat.
    me = bpy.context.active_object.data
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    try:
        me.set_sharp_from_angle(angle=math.radians(50))
    except Exception:
        pass
    me.update()


def add_cyl(name, r, depth, loc, mat, verts=32, scale=None, rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth,
                                        location=loc)
    o = bpy.context.active_object
    o.name = name
    if scale:
        o.scale = scale
    if rot:
        o.rotation_euler = rot
    if mat:
        o.data.materials.append(mat)
    smooth()
    return o


def add_sphere(name, r, loc, mat, scale=None, rot=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc,
                                         segments=24, ring_count=16)
    o = bpy.context.active_object
    o.name = name
    if scale:
        o.scale = scale
    if rot:
        o.rotation_euler = rot
    if mat:
        o.data.materials.append(mat)
    smooth()
    return o


def add_box(name, dims, loc, mat, rot=None):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (dims[0] / 2, dims[1] / 2, dims[2] / 2)
    if rot:
        o.rotation_euler = rot
    if mat:
        o.data.materials.append(mat)
    return o


def key(obj, path, frame, value, interp="BEZIER"):
    if path == "location":
        obj.location = value
    elif path == "rotation_euler":
        obj.rotation_euler = value
    elif path == "scale":
        obj.scale = value
    obj.keyframe_insert(data_path=path, frame=frame)
    fc = obj.animation_data.action
    for f in fc.fcurves:
        for kp in f.keyframe_points:
            if abs(kp.co[0] - frame) < 0.5:
                kp.interpolation = interp


def key_input(node_input, frame, value):
    node_input.default_value = value
    node_input.keyframe_insert(data_path="default_value", frame=frame)


# ---------------------------------------------------------------- the room
def build_room():
    floor = add_box("Floor", (10, 10, 0.05), (0, 0, -0.025),
                    wood_material("FloorWood", base=(0.08, 0.04, 0.018),
                                  dark=(0.02, 0.01, 0.005), scale=2.5,
                                  rough=0.32, coat=0.35))
    plaster = mat_principled("Plaster", (0.055, 0.05, 0.042, 1), rough=0.9)
    nt = plaster.node_tree
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 8.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.3
    bump.inputs["Distance"].default_value = 0.004
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"],
                 nt.nodes["Principled BSDF"].inputs["Normal"])
    add_box("WallBack", (10, 0.1, 3.4), (0, 2.6, 1.7), plaster)
    add_box("WallLeft", (0.1, 10, 3.4), (-3.1, 0, 1.7), plaster)
    add_box("WallRight", (0.1, 10, 3.4), (3.1, 0, 1.7), plaster)
    add_box("Ceiling", (10, 10, 0.1), (0, 0, 3.35), plaster)
    # Dark wainscot band around the walls.
    dado = wood_material("Dado", base=(0.07, 0.04, 0.02),
                         dark=(0.02, 0.012, 0.008), scale=2.0, coat=0.1)
    add_box("DadoBack", (10, 0.06, 1.1), (0, 2.54, 0.55), dado)
    add_box("DadoLeft", (0.06, 10, 1.1), (-3.04, 0, 0.55), dado)
    return floor


def build_table():
    oak = wood_material("TableOak", base=(0.085, 0.042, 0.018),
                        dark=(0.022, 0.011, 0.006), scale=11.0, rough=0.3,
                        coat=0.3)
    add_cyl("TableTop", 0.75, 0.05, (0, 0, 0.75), oak, verts=64)
    add_cyl("TablePost", 0.07, 0.68, (0, 0, 0.37), oak)
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        add_box(f"TableFoot{i}", (0.4, 0.07, 0.05),
                (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.04),
                oak, rot=(0, 0, a))
    dark = wood_material("Chair", base=(0.06, 0.032, 0.016),
                         dark=(0.02, 0.01, 0.006), scale=3.0, coat=0.1)
    # Challenger's chair, back-left of the table.
    cx, cy, rotz = -0.45, 0.95, math.radians(205)
    add_box("ChairSeat", (0.42, 0.42, 0.04), (cx, cy, 0.46), dark,
            rot=(0, 0, rotz))
    for dx, dy in ((-0.18, -0.18), (0.18, -0.18), (-0.18, 0.18), (0.18, 0.18)):
        add_cyl("ChairLeg", 0.02, 0.46, (cx + dx, cy + dy, 0.23), dark)
    for i in range(3):
        add_cyl("ChairSlat", 0.015, 0.5,
                (cx - 0.16 + i * 0.16, cy + 0.2, 0.72), dark)
    add_box("ChairRail", (0.42, 0.04, 0.06), (cx, cy + 0.2, 0.96), dark,
            rot=(0, 0, 0))


def build_lamp():
    metal = mat_principled("LampMetal", (0.02, 0.025, 0.02, 1), rough=0.4,
                           metallic=0.8)
    inner = mat_principled("LampInner", (0.9, 0.85, 0.7, 1), rough=0.6)
    add_cyl("LampCord", 0.006, 1.25, (0, 0, 2.72), metal)
    bpy.ops.mesh.primitive_cone_add(radius1=0.19, radius2=0.045, depth=0.17,
                                    location=(0, 0, 2.1))
    shade = bpy.context.active_object
    shade.name = "LampShade"
    shade.data.materials.append(metal)
    smooth()
    bulb_mat = bpy.data.materials.new("Bulb")
    bulb_mat.use_nodes = True
    nt = bulb_mat.node_tree
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1.0, 0.72, 0.42, 1)
    nt.links.new(em.outputs["Emission"],
                 nt.nodes["Material Output"].inputs["Surface"])
    add_sphere("BulbGlow", 0.035, (0, 0, 2.04), bulb_mat)
    # The bare bulb mirror-reflects in the coin face at the apex — dim it
    # there or the gold blows out to white.
    for f, s in ((1, 90), (F_FLICK + 8, 90), (F_APEX + 2, 4),
                 (F_DROP - 1, 4), (F_DROP, 90)):
        key_input(em.inputs["Strength"], f, s)

    spot = bpy.data.lights.new("KeySpot", "SPOT")
    spot.energy = 650
    spot.color = (1.0, 0.65, 0.35)
    spot.spot_size = math.radians(52)
    spot.spot_blend = 0.4
    spot.shadow_soft_size = 0.14
    o = bpy.data.objects.new("KeySpot", spot)
    o.location = (0, 0, 1.99)  # just below the shade lip — no self-shadow
    o.rotation_euler = (0, 0, 0)  # -Z default aim = straight down
    link(o)
    # Per-shot trim: EEVEE's speculars run hot — dim across the slow-mo apex
    # so the gold face reads instead of blowing out, and ease down for the
    # macro reveal.
    for f, e in ((1, 650), (F_FLICK + 8, 650), (F_APEX + 2, 55),
                 (F_DROP - 1, 55), (F_DROP, 450),
                 (F_REVEAL, 300), (F_END, 300)):
        spot.energy = e
        spot.keyframe_insert(data_path="energy", frame=f)

    # Practical fill for THE SET: the raised fist sits outside the lamp cone
    # and EEVEE has no diffuse GI to lift it — fade a soft warm source in.
    fill = bpy.data.lights.new("SetFill", "AREA")
    fill.energy = 0
    fill.color = (1.0, 0.72, 0.45)
    fill.size = 0.5
    fo = bpy.data.objects.new("SetFill", fill)
    fo.location = (0.85, -0.55, 1.35)
    fo.rotation_euler = (math.radians(55), 0, math.radians(50))
    link(fo)
    for f, e in ((F_SET - 1, 0), (F_SET + 5, 16), (F_FLICK + 11, 16),
                 (F_APEX + 2, 0)):
        fill.energy = e
        fill.keyframe_insert(data_path="energy", frame=f)

    # Whisper of warm bounce so shadow sides aren't pure void.
    bounce = bpy.data.lights.new("Bounce", "AREA")
    bounce.energy = 28
    bounce.color = (1.0, 0.75, 0.5)
    bounce.size = 3.0
    ob = bpy.data.objects.new("Bounce", bounce)
    ob.location = (0, -0.3, 0.3)
    ob.rotation_euler = (math.radians(-90), 0, 0)
    link(ob)


def build_window():
    frame_mat = mat_principled("WinFrame", (0.03, 0.028, 0.025, 1), rough=0.7)
    # On the left wall, high — cool street light + rain silhouette.
    add_box("WinFrame", (0.12, 1.5, 1.9), (-3.05, 0.9, 1.9), frame_mat)
    glass = bpy.data.materials.new("WinGlass")
    glass.use_nodes = True
    nt = glass.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Transmission Weight"].default_value = 1.0
    b.inputs["Roughness"].default_value = 0.25
    add_box("WinGlassPane", (0.02, 1.3, 1.7), (-3.05, 0.9, 1.9), glass)
    add_box("WinMuntinV", (0.05, 0.04, 1.7), (-3.04, 0.9, 1.9), frame_mat)
    add_box("WinMuntinH", (0.05, 1.3, 0.04), (-3.04, 0.9, 1.9), frame_mat)

    # Backlit rain sheet outside: streaked noise on an emissive plane.
    rain = bpy.data.materials.new("Rain")
    rain.use_nodes = True
    nt = rain.node_tree
    tex = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (40.0, 1.5, 1.0)
    nt.links.new(tex.outputs["Generated"], mapping.inputs["Vector"])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 3.0
    noise.inputs["Detail"].default_value = 4.0
    nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.55
    ramp.color_ramp.elements[1].position = 0.75
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.55, 0.68, 0.9, 1)
    em.inputs["Strength"].default_value = 3.0
    mix = nt.nodes.new("ShaderNodeMixShader")
    transp = nt.nodes.new("ShaderNodeBsdfTransparent")
    nt.links.new(ramp.outputs["Color"], mix.inputs["Fac"])
    nt.links.new(transp.outputs["BSDF"], mix.inputs[1])
    nt.links.new(em.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"],
                 nt.nodes["Material Output"].inputs["Surface"])
    sheet = add_box("RainSheet", (0.01, 1.4, 1.8), (-3.35, 0.9, 1.9), None)
    sheet.data.materials.append(rain)
    # Animate the streaks sliding down for the whole timeline.
    key_input(mapping.inputs["Location"], 1, (0.0, 0.0, 0.0))
    key_input(mapping.inputs["Location"], F_END, (0.0, -6.0, 0.0))

    # The cool "moon/street" light through the window (lightning host).
    street = bpy.data.lights.new("Street", "AREA")
    street.energy = 220
    street.color = (0.45, 0.6, 0.95)
    street.size = 1.4
    street.size_y = 1.9
    o = bpy.data.objects.new("Street", street)
    o.location = (-3.6, 0.9, 1.9)
    o.rotation_euler = (0, math.radians(-90), 0)
    link(o)
    # Lightning: two spikes during the establish, a flicker at the slam.
    for f, e in ((1, 220), (16, 220), (19, 6000), (22, 500), (26, 3500),
                 (32, 220), (288, 220), (290, 1500), (294, 220)):
        street.energy = e
        street.keyframe_insert(data_path="energy", frame=f)
    return street


def build_backbar():
    shelfm = wood_material("Shelf", base=(0.07, 0.04, 0.02),
                           dark=(0.02, 0.012, 0.008), scale=2.0)
    add_box("Shelf", (2.6, 0.25, 0.04), (0.8, 2.45, 1.55), shelfm)
    add_box("Shelf2", (2.6, 0.25, 0.04), (0.8, 2.45, 1.15), shelfm)
    tints = [(0.05, 0.12, 0.04), (0.12, 0.06, 0.02), (0.04, 0.05, 0.10),
             (0.10, 0.08, 0.02)]
    for i in range(9):
        x = -0.35 + i * 0.28 + rng.uniform(-0.03, 0.03)
        z = 1.57 if i % 2 == 0 else 1.17
        h = rng.uniform(0.22, 0.3)
        tint = tints[i % len(tints)]
        glass = bpy.data.materials.new(f"Bottle{i}")
        glass.use_nodes = True
        b = glass.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*tint, 1)
        b.inputs["Transmission Weight"].default_value = 1.0
        b.inputs["Roughness"].default_value = 0.08
        body = add_cyl(f"BottleBody{i}", 0.045, h, (x, 2.42, z + h / 2), glass)
        add_cyl(f"BottleNeck{i}", 0.016, 0.1,
                (x, 2.42, z + h + 0.05), glass)
        body.data.materials.append(glass)
    # Tiny warm picture light over the shelf → bokeh glints on the glass.
    strip = bpy.data.lights.new("ShelfLight", "AREA")
    strip.energy = 30
    strip.color = (1.0, 0.7, 0.4)
    strip.size = 2.4
    strip.size_y = 0.05
    o = bpy.data.objects.new("ShelfLight", strip)
    o.location = (0.8, 2.35, 1.85)
    o.rotation_euler = (math.radians(-35), 0, 0)
    link(o)


def build_haze():
    # Room haze.
    bpy.ops.mesh.primitive_cube_add(location=(0, 0, 1.6))
    vol = bpy.context.active_object
    vol.name = "Haze"
    vol.scale = (3.2, 3.2, 1.7)
    m = bpy.data.materials.new("HazeVol")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    pv = nt.nodes.new("ShaderNodeVolumePrincipled")
    pv.inputs["Density"].default_value = 0.004
    pv.inputs["Anisotropy"].default_value = 0.45
    nt.links.new(pv.outputs["Volume"],
                 nt.nodes["Material Output"].inputs["Volume"])
    vol.data.materials.append(m)
    vol.display_type = "WIRE"
    vol.visible_shadow = False


# ---------------------------------------------------------------- the men
def build_man(name, loc, rotz, coat_color, seated=False, height=1.0):
    """A period figure: long wool coat, waistcoat V, head with flat cap.
    Returns dict of key parts for animation."""
    wool = mat_principled(f"{name}Wool", coat_color, rough=0.88, sheen=0.35)
    skin = mat_principled(f"{name}Skin", SKIN, rough=0.55, subsurface=0.12)
    shirt = mat_principled(f"{name}Shirt", (0.09, 0.08, 0.065, 1), rough=0.8)
    capm = mat_principled(f"{name}Cap", coat_color, rough=0.92, sheen=0.4)

    parts = {}
    z0 = 0.0 if not seated else 0.0
    torso_z = (1.06 if not seated else 0.78) * height
    head_z = (1.62 if not seated else 1.28) * height

    # Coat: shoulders → hem, kept soft by subsurf.
    coat = add_cyl(f"{name}Coat", 0.21, 0.95 if not seated else 0.62,
                   (loc[0], loc[1], torso_z), wool, verts=24,
                   scale=(1.15, 0.8, 1.0))
    sub = coat.modifiers.new("Sub", "SUBSURF")
    sub.levels = sub.render_levels = 2
    # Shoulder mass.
    add_sphere(f"{name}Shoulders", 0.24, (loc[0], loc[1], torso_z + (
        0.42 if not seated else 0.28) * height), wool,
        scale=(1.15, 0.75, 0.55))
    # Waistcoat V + collar.
    fwd = Vector((math.sin(rotz), -math.cos(rotz), 0))
    chest = Vector(loc) + fwd * 0.16
    add_box(f"{name}Vee", (0.14, 0.02, 0.3),
            (chest.x, chest.y, torso_z + 0.25 * height), shirt,
            rot=(0, 0, rotz))
    # Head + neck.
    add_cyl(f"{name}Neck", 0.05, 0.09,
            (loc[0], loc[1], head_z - 0.13 * height), skin)
    head = add_sphere(f"{name}Head", 0.105,
                      (loc[0], loc[1], head_z), skin,
                      scale=(0.92, 1.0, 1.12), rot=(0, 0, rotz))
    parts["head"] = head
    # Nose — tiny cone on the facing side.
    nose_pos = Vector((loc[0], loc[1], head_z - 0.01)) + fwd * 0.10
    bpy.ops.mesh.primitive_cone_add(radius1=0.018, radius2=0.004, depth=0.05,
                                    location=nose_pos)
    nose = bpy.context.active_object
    nose.name = f"{name}Nose"
    nose.rotation_euler = (math.radians(90), 0, rotz)
    nose.data.materials.append(skin)
    smooth()
    # Flat cap: low squashed crown sitting back on the skull + brim.
    crown_pos = Vector((loc[0], loc[1], head_z + 0.055)) - fwd * 0.015
    cap = add_sphere(f"{name}CapCrown", 0.095, tuple(crown_pos), capm,
                     scale=(1.0, 1.14, 0.22), rot=(math.radians(9), 0, rotz))
    brim_pos = Vector((loc[0], loc[1], head_z + 0.038)) + fwd * 0.105
    add_cyl(f"{name}CapBrim", 0.062, 0.011,
            (brim_pos.x, brim_pos.y, brim_pos.z), capm,
            scale=(1.0, 1.0, 1.0), rot=(math.radians(12), 0, rotz))
    parts["cap"] = cap

    if seated:
        # Thighs toward the table + a hint of shin.
        add_cyl(f"{name}Thigh", 0.09, 0.42,
                (loc[0] + fwd.x * 0.2, loc[1] + fwd.y * 0.2, 0.5), wool,
                rot=(math.radians(90) * -fwd.y, math.radians(90) * fwd.x, 0),
                scale=(1, 1, 1))
    return parts


def build_men():
    men = {}
    # THE TOSSER — standing behind the table, facing the camera.
    men["tosser"] = build_man("Tosser", (0, 0.95, 0), math.pi, WOOL_DARK)
    # Tosser's right arm: upper arm + forearm + fist, animated to the set.
    wool = bpy.data.materials["TosserWool"]
    skin = bpy.data.materials["TosserSkin"]
    upper = add_cyl("TosserUpperArm", 0.055, 0.34, (0.24, 0.85, 1.28), wool,
                    rot=(0, math.radians(20), 0))
    # Coat sleeve covers the forearm — only the fist reads as skin.
    fore = add_cyl("TosserForearm", 0.05, 0.32, (0.30, 0.72, 1.02), wool,
                   rot=(math.radians(58), 0, 0))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.055,
                                         location=(0.30, 0.62, 0.92),
                                         segments=48, ring_count=32)
    fist = bpy.context.active_object
    fist.name = "TosserFist"
    fist.scale = (1.0, 1.15, 0.85)
    fist.data.materials.append(skin)
    fsub = fist.modifiers.new("Sub", "SUBSURF")
    fsub.levels = fsub.render_levels = 2
    smooth()
    thumb = add_cyl("TosserThumb", 0.013, 0.06, (0.30, 0.57, 0.95), skin,
                    verts=24, rot=(math.radians(35), 0, 0))
    men["fore"], men["fist"], men["thumb"], men["upper"] = fore, fist, thumb, upper

    # THE CHALLENGER — seated across, hunched in.
    men["challenger"] = build_man("Challenger", (-0.45, 0.95, 0),
                                  math.radians(155), WOOL_OXBLOOD, seated=True)
    ch_wool = bpy.data.materials["ChallengerWool"]
    add_cyl("ChallengerArmL", 0.045, 0.38, (-0.38, 0.78, 0.815), ch_wool,
            rot=(math.radians(80), 0, math.radians(-20)))
    add_cyl("ChallengerArmR", 0.045, 0.38, (-0.58, 0.84, 0.815), ch_wool,
            rot=(math.radians(80), 0, math.radians(15)))

    # THE WITNESS — standing off to the right, smoking.
    men["witness"] = build_man("Witness", (1.45, 0.55, 0),
                               math.radians(245), WOOL_GREY)
    w_skin = bpy.data.materials["WitnessSkin"]
    w_wool = bpy.data.materials["WitnessWool"]
    add_cyl("WitnessArm", 0.05, 0.36, (1.28, 0.48, 1.25), w_wool,
            rot=(math.radians(40), math.radians(-30), 0))
    add_sphere("WitnessHand", 0.045, (1.18, 0.42, 1.42), w_skin)
    cig = add_cyl("Cigarette", 0.005, 0.08, (1.15, 0.40, 1.47),
                  mat_principled("CigPaper", (0.75, 0.72, 0.65, 1), rough=0.7),
                  rot=(math.radians(70), 0, math.radians(30)))
    ember_mat = bpy.data.materials.new("Ember")
    ember_mat.use_nodes = True
    nt = ember_mat.node_tree
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1.0, 0.25, 0.05, 1)
    nt.links.new(em.outputs["Emission"],
                 nt.nodes["Material Output"].inputs["Surface"])
    add_sphere("EmberTip", 0.007, (1.135, 0.385, 1.50), ember_mat)
    # The drag: ember flares during the FACES shot, again pre-flick.
    for f, s in ((1, 3), (92, 3), (100, 26), (110, 4), (163, 14), (172, 3)):
        key_input(em.inputs["Strength"], f, s)

    # Cigarette smoke: a slim noisy volume column rising off the tip.
    bpy.ops.mesh.primitive_cone_add(radius1=0.05, radius2=0.22, depth=1.0,
                                    location=(1.12, 0.36, 2.05))
    plume = bpy.context.active_object
    plume.name = "SmokePlume"
    m = bpy.data.materials.new("SmokeVol")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    pv = nt.nodes.new("ShaderNodeVolumePrincipled")
    pv.inputs["Density"].default_value = 0.0
    pv.inputs["Anisotropy"].default_value = 0.3
    tex = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (3.0, 3.0, 1.2)
    nt.links.new(tex.outputs["Object"], mapping.inputs["Vector"])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.2
    noise.inputs["Detail"].default_value = 6.0
    nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.42
    ramp.color_ramp.elements[1].position = 0.75
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    dens = nt.nodes.new("ShaderNodeMath")
    dens.operation = "MULTIPLY"
    nt.links.new(ramp.outputs["Color"], dens.inputs[0])
    dens.inputs[1].default_value = 0.9
    nt.links.new(dens.outputs["Value"], pv.inputs["Density"])
    nt.links.new(pv.outputs["Volume"],
                 nt.nodes["Material Output"].inputs["Volume"])
    plume.data.materials.append(m)
    plume.display_type = "WIRE"
    plume.visible_shadow = False
    # Smoke churns upward all scene long.
    key_input(mapping.inputs["Location"], 1, (0.0, 0.0, 0.0))
    key_input(mapping.inputs["Location"], F_END, (0.3, 0.2, -3.0))
    return men


# ---------------------------------------------------------------- the coin
def coin_face_material(name, height_png, mirror_x, bump_dist):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex_coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    nt.links.new(tex_coord.outputs["Generated"], mapping.inputs["Vector"])
    if mirror_x:
        # Flip Y: unmirror + 180° so tails reads upright after the half-turn.
        mapping.inputs["Scale"].default_value = (1.0, -1.0, 1.0)
        mapping.inputs["Location"].default_value = (0.0, 1.0, 0.0)
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(height_png)
    img.image.colorspace_settings.name = "Non-Color"
    img.interpolation = "Cubic"
    nt.links.new(mapping.outputs["Vector"], img.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.5
    bump.inputs["Distance"].default_value = bump_dist
    nt.links.new(img.outputs["Color"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.30
    ramp.color_ramp.elements[1].position = 0.55
    nt.links.new(img.outputs["Color"], ramp.inputs["Fac"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = GRIME
    mix.inputs["B"].default_value = BRASS
    nt.links.new(ramp.outputs["Color"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.26
    return mat


def build_coin():
    r = 0.016  # a sovereign is ~22 mm — stage-scaled slightly hero-large
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=r, depth=r * 0.14,
                                        location=(0, 0, 0))
    coin = bpy.context.active_object
    coin.name = "Coin"
    smooth()
    heads = coin_face_material("CoinHeads",
                               os.path.join(MAPS, "heads_height.png"),
                               False, r * 0.03)
    tails = coin_face_material("CoinTails",
                               os.path.join(MAPS, "tails_height.png"),
                               True, r * 0.03)
    edge = mat_principled("CoinEdge", BRASS, rough=0.3, metallic=1.0)
    coin.data.materials.append(heads)
    coin.data.materials.append(tails)
    coin.data.materials.append(edge)
    for poly in coin.data.polygons:
        if poly.normal.z > 0.5:
            poly.material_index = 0
        elif poly.normal.z < -0.5:
            poly.material_index = 1
        else:
            poly.material_index = 2
    return coin


def animate_coin(coin, ending):
    thumb = (0.30, 0.60, 0.97)       # on the tosser's fist
    apex = (0.0, 0.06, 1.70)         # dead centre of the lamp beam
    land = (0.0, 0.10, 0.789)        # on the tabletop (top 0.775 + half coin)

    # Hidden under the table until the set.
    key(coin, "location", 1, (0, 0.6, 0.5))
    key(coin, "scale", 1, (0.001, 0.001, 0.001))
    key(coin, "scale", F_SET + 6, (0.001, 0.001, 0.001), "CONSTANT")
    key(coin, "scale", F_SET + 7, (1, 1, 1), "CONSTANT")
    key(coin, "location", F_SET + 6, (thumb[0], thumb[1], thumb[2] - 0.25))
    # Rises with the fist during the set.
    key(coin, "location", F_SET + 30, thumb)
    key(coin, "location", F_FLICK, thumb)
    # Launch — arcing out of the fist into the beam.
    key(coin, "location", F_FLICK + 6, (0.17, 0.38, 1.34), "LINEAR")
    key(coin, "location", F_APEX, (apex[0] + 0.02, apex[1], apex[2] - 0.06),
        "LINEAR")
    # Apex float — a lazy parabola crest across the slow-mo.
    key(coin, "location", F_APEX + 48, (apex[0], apex[1], apex[2] + 0.05))
    key(coin, "location", F_DROP - 1, (apex[0], apex[1], apex[2] - 0.04))
    # The drop — violent.
    key(coin, "location", F_DROP + 13, land, "LINEAR")
    # Bounce and settle.
    key(coin, "location", F_DROP + 17, (land[0] + 0.012, land[1] - 0.008,
                                        land[2] + 0.055))
    key(coin, "location", F_DROP + 21, land)
    key(coin, "location", F_END, land)

    # On the thumbnail the coin tips mostly face-up — a readable disc with a
    # crescent glint rather than a blown mirror flash.
    tilt = math.radians(76)
    key(coin, "rotation_euler", F_SET + 6, (tilt, 0, 0))
    # Spin about X: fast flick, 4% apex crawl, violent drop, settle flat.
    total = 16 * math.pi + (math.pi if ending == "tails" else 0)
    key(coin, "rotation_euler", F_FLICK, (tilt, 0, 0))
    key(coin, "rotation_euler", F_APEX, (4 * math.pi + 0.9, 0, 0.06), "LINEAR")
    key(coin, "rotation_euler", F_DROP - 1,
        (4 * math.pi + 0.9 + 2.4 * math.pi, 0, -0.06), "LINEAR")
    key(coin, "rotation_euler", F_DROP + 13, (total - 0.35, 0, 0), "LINEAR")
    # Wobble-settle on the oak.
    key(coin, "rotation_euler", F_DROP + 17, (total + 0.22, 0, 0.05))
    key(coin, "rotation_euler", F_DROP + 21, (total - 0.08, 0, -0.02))
    key(coin, "rotation_euler", F_DROP + 24, (total, 0, 0))
    key(coin, "rotation_euler", F_END, (total, 0, 0))


def animate_tosser(men):
    """The fist rises through the set, snaps on the flick."""
    fore, fist, thumb = men["fore"], men["fist"], men["thumb"]
    rest_f = ((0.30, 0.72, 0.80), (math.radians(15), 0, 0))
    set_f = ((0.30, 0.72, 1.02), (math.radians(58), 0, 0))
    for obj, rest, at_set in (
        (fore, rest_f[0], set_f[0]),
        (fist, (0.30, 0.66, 0.62), (0.30, 0.62, 0.92)),
        (thumb, (0.30, 0.61, 0.65), (0.30, 0.57, 0.95)),
    ):
        key(obj, "location", 1, rest)
        key(obj, "location", F_SET + 4, rest)
        key(obj, "location", F_SET + 30, at_set)
        key(obj, "location", F_FLICK, at_set)
        # The snap: wrist jumps 6 cm in 3 frames, then eases back down.
        snap = (at_set[0], at_set[1] + 0.01, at_set[2] + 0.06)
        key(obj, "location", F_FLICK + 3, snap, "LINEAR")
        key(obj, "location", F_FLICK + 10, (at_set[0], at_set[1], at_set[2] - 0.05))
        key(obj, "location", F_END, (at_set[0], at_set[1], at_set[2] - 0.05))
    key(fore, "rotation_euler", 1, rest_f[1])
    key(fore, "rotation_euler", F_SET + 4, rest_f[1])
    key(fore, "rotation_euler", F_SET + 30, set_f[1])

    # Breathing: heads bob a couple of millimetres through the long shots.
    for who in ("tosser", "challenger", "witness"):
        head = men[who]["head"]
        base = tuple(head.location)
        for i, f in enumerate(range(1, F_END, 36)):
            dz = 0.004 if i % 2 else 0.0
            key(head, "location", f, (base[0], base[1], base[2] + dz))


# ---------------------------------------------------------------- cameras
def make_cam(name, lens, fstop, focus=None):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    # Lock the 36mm sensor to the horizontal axis: portrait renders keep the
    # same left-right framing as the landscape look-dev and simply gain
    # vertical field (lamp above, table pool below).
    data.sensor_fit = "HORIZONTAL"
    data.dof.use_dof = True
    data.dof.aperture_fstop = fstop
    if focus is not None:
        data.dof.focus_object = focus
    cam = bpy.data.objects.new(name, data)
    link(cam)
    return cam


def track(cam, target):
    c = cam.constraints.new("TRACK_TO")
    c.target = target
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"


def empty(name, loc):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    link(e)
    return e


def build_cameras(coin):
    scene = bpy.context.scene
    table_focus = empty("TableFocus", (0, 0.45, 1.0))
    faces_focus = empty("FacesFocus", (-0.45, 0.9, 1.25))
    # Hold focus on the challenger's profile the whole dolly — the world
    # slides behind him.
    key(faces_focus, "location", F_FACES, (-0.45, 0.95, 1.28))
    key(faces_focus, "location", F_SET, (-0.45, 0.95, 1.28))

    # S1 crane: high and wide past the lamp, settling across the table so
    # the three silhouettes ring the pool of light.
    crane = make_cam("CamCrane", 28, 4.0, table_focus)
    track(crane, table_focus)
    key(crane, "location", 1, (0.55, -1.7, 2.75))
    key(crane, "location", F_FACES - 1, (0.0, -2.05, 1.32))

    # S2 faces: lateral dolly at eye level, shallow focus.
    faces = make_cam("CamFaces", 65, 2.8, faces_focus)
    track(faces, faces_focus)
    key(faces, "location", F_FACES, (-1.35, -0.72, 1.24))
    key(faces, "location", F_SET - 1, (0.45, -0.95, 1.30))

    # S3 the set: push-in on the raised fist, silhouetted against the pool,
    # the tilted sovereign glinting on the thumbnail.
    fist_focus = empty("FistFocus", (0.30, 0.595, 0.965))
    setcam = make_cam("CamSet", 85, 2.2, fist_focus)
    track(setcam, fist_focus)
    key(setcam, "location", F_SET, (0.62, -0.9, 1.08))
    key(setcam, "location", F_FLICK - 1, (0.48, -0.55, 1.02))

    # S4 flick: low angle looking up past the tosser.
    flick_focus = empty("FlickFocus", (0.28, 0.55, 1.15))
    key(flick_focus, "location", F_FLICK, (0.30, 0.60, 1.00))
    key(flick_focus, "location", F_APEX - 1, (0.10, 0.40, 1.65))
    flick = make_cam("CamFlick", 35, 2.8, flick_focus)
    track(flick, flick_focus)
    key(flick, "location", F_FLICK, (0.5, -0.35, 0.78))
    key(flick, "location", F_APEX - 1, (0.52, -0.38, 0.82))

    # S5 apex: the money shot — camera hangs off the coin, tracking it,
    # drifting through a shallow arc while the sovereign turns in the shaft.
    apex = make_cam("CamApex", 100, 4.0, None)
    apex.data.dof.focus_object = coin
    track(apex, coin)
    key(apex, "location", F_APEX, (-0.16, -0.26, 1.62))
    key(apex, "location", F_APEX + 48, (0.0, -0.34, 1.68))
    key(apex, "location", F_DROP - 1, (0.17, -0.27, 1.75))

    # S6 drop: whip-tilt down to the slam.
    drop_focus = empty("DropFocus", (0.0, 0.10, 1.6))
    key(drop_focus, "location", F_DROP, (0.0, 0.10, 1.65))
    key(drop_focus, "location", F_DROP + 12, (0.0, 0.10, 0.80), "LINEAR")
    key(drop_focus, "location", F_REVEAL - 1, (0.0, 0.10, 0.80))
    drop = make_cam("CamDrop", 65, 2.8, drop_focus)
    track(drop, drop_focus)
    key(drop, "location", F_DROP, (0.58, -0.62, 1.45))
    key(drop, "location", F_DROP + 12, (0.56, -0.65, 1.25))
    key(drop, "location", F_REVEAL - 1, (0.56, -0.65, 1.22))

    # S7 reveal: macro push-in on the coin on the oak.
    reveal_focus = empty("RevealFocus", (0.0, 0.10, 0.79))
    reveal = make_cam("CamReveal", 100, 2.5, reveal_focus)
    track(reveal, reveal_focus)
    key(reveal, "location", F_REVEAL, (0.25, -0.30, 1.08))
    key(reveal, "location", F_END, (0.10, -0.06, 0.90))

    # Bind cameras to the timeline.
    for f, cam in ((1, crane), (F_FACES, faces), (F_SET, setcam),
                   (F_FLICK, flick), (F_APEX, apex), (F_DROP, drop),
                   (F_REVEAL, reveal)):
        mk = scene.timeline_markers.new(f"M{f}", frame=f)
        mk.camera = cam
    scene.camera = crane


# ---------------------------------------------------------------- render
def setup_world_and_render():
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.012, 0.012, 0.016, 1)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world

    if ENGINE == "eevee":
        scene.render.engine = "BLENDER_EEVEE_NEXT"
        ee = scene.eevee
        ee.taa_render_samples = max(SAMPLES, 32)
        ee.use_raytracing = True
        ee.volumetric_tile_size = "2"
        ee.volumetric_samples = 96
        ee.use_volumetric_shadows = True
        ee.use_shadows = True
    else:
        scene.render.engine = "CYCLES"
        scene.cycles.samples = SAMPLES
        scene.cycles.use_denoising = True
        scene.cycles.adaptive_threshold = 0.04
        scene.cycles.device = "GPU"
        scene.cycles.max_bounces = 8
        scene.cycles.transmission_bounces = 8
        scene.cycles.volume_bounces = 1
        scene.cycles.volume_step_rate = 2.0
        scene.cycles.volume_max_steps = 256
        scene.cycles.sample_clamp_indirect = 10.0
    scene.render.resolution_x = RES_X
    scene.render.resolution_y = RES_Y
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = F_END
    scene.render.use_motion_blur = bool(MBLUR)
    scene.render.motion_blur_shutter = 0.5
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0.9

    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "OPTIX"
    except Exception:
        prefs.compute_device_type = "CUDA"
    prefs.get_devices()
    for d in prefs.devices:
        d.use = d.type in {"OPTIX", "CUDA"}


def build_all(ending):
    # NOTE: read_factory_settings(use_empty=True) permanently breaks OPTIX
    # device enumeration in headless sessions (GPU list comes back empty and
    # Cycles silently renders on CPU). Clear the startup scene by hand.
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    build_room()
    build_table()
    build_lamp()
    build_window()
    build_backbar()
    build_haze()
    men = build_men()
    coin = build_coin()
    animate_coin(coin, ending)
    animate_tosser(men)
    build_cameras(coin)
    setup_world_and_render()


def render_stills():
    os.makedirs(OUT, exist_ok=True)
    scene = bpy.context.scene
    for label, f in (("s1_establish", 36), ("s2_faces", 100),
                     ("s3_set", 155), ("s4_flick", 175), ("s5_apex", 228),
                     ("s6_slam", 295), ("s7_reveal", 350)):
        scene.frame_set(f)
        scene.render.filepath = os.path.join(OUT, f"{label}.png")
        bpy.ops.render.render(write_still=True)
        print("STILL", label, "done")


def render_anim():
    os.makedirs(OUT, exist_ok=True)
    scene = bpy.context.scene
    warmed = False
    for f in range(START, END + 1):
        path = os.path.join(OUT, f"{f:04d}.png")
        if os.path.exists(path):
            continue
        scene.frame_set(f)
        if ENGINE == "eevee" and not warmed:
            # EEVEE's first headless render can beat async shader compile
            # and come out black — burn one throwaway frame.
            scene.render.filepath = os.path.join(OUT, "_warmup.png")
            bpy.ops.render.render(write_still=True)
            warmed = True
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
    warm = os.path.join(OUT, "_warmup.png")
    if os.path.exists(warm):
        os.remove(warm)
    print(f"ANIM done {START}-{END} -> {OUT}")


if __name__ == "__main__":
    build_all(ENDING)
    if MODE == "stills":
        render_stills()
    else:
        render_anim()
