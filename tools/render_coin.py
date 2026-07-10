"""Photoreal coin flip renderer for Blender (Phase 2 final asset).

Produces the SAME output contract as gen_placeholder_frames.py so it drops
straight into the app: assets/coin/frame_000.png .. frame_089.png,
one seamless full rotation about the horizontal axis, frame 0 = HEADS up,
frame 45 = TAILS up, RGBA with transparent background.

Usage:
    blender --background --python tools/render_coin.py
    # optional: --  --frames 90 --res 1024 --samples 256

Model it once (engrave your own H/T reliefs, set a gold/brass PBR metal),
then let this script animate the spin and batch-render. Tweak FRAMES/RES/
SAMPLES for quality vs. size. Keep frames square and centered.
"""
import math
import os
import sys

import bpy  # type: ignore  (only available inside Blender)

# ---- args ----------------------------------------------------------------
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(flag, default):
    return type(default)(argv[argv.index(flag) + 1]) if flag in argv else default


FRAMES = arg("--frames", 90)
RES = arg("--res", 1024)
SAMPLES = arg("--samples", 256)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "coin")
COIN_RADIUS = 1.0
COIN_THICK = 0.13

BRASS = (0.79, 0.63, 0.31, 1.0)      # aged brass base color
ENGRAVE_ROUGH = 0.55                  # engraved recesses read matte


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_brass_material():
    mat = bpy.data.materials.new("Brass")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = BRASS
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.28
    if "Anisotropic" in bsdf.inputs:
        bsdf.inputs["Anisotropic"].default_value = 0.35  # milled-metal streaks
    return mat


def build_coin():
    # Cylinder body. Replace/boolean your engraved H/T reliefs here.
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=128, radius=COIN_RADIUS, depth=COIN_THICK)
    coin = bpy.context.active_object
    coin.rotation_euler[0] = math.radians(90)  # face the camera
    bpy.ops.object.shade_smooth()
    bpy.ops.object.modifier_add(type="BEVEL")
    coin.modifiers["Bevel"].width = 0.015
    coin.modifiers["Bevel"].segments = 3
    coin.data.materials.append(make_brass_material())
    return coin


def setup_lighting():
    # Warm three-point rig for the Peaky tungsten mood.
    def add_light(name, loc, energy, color, size=3.0):
        light = bpy.data.lights.new(name, "AREA")
        light.energy = energy
        light.color = color
        light.size = size
        obj = bpy.data.objects.new(name, light)
        obj.location = loc
        bpy.context.collection.objects.link(obj)
        obj.rotation_euler = (
            math.atan2(math.hypot(loc[0], loc[1]), loc[2]), 0,
            math.atan2(loc[1], loc[0]) + math.pi / 2)
        return obj

    add_light("Key", (-3, -2, 4), 1200, (1.0, 0.85, 0.6), 4)
    add_light("Rim", (3, 3, 2), 500, (1.0, 0.7, 0.4), 3)
    add_light("Fill", (2, -3, 1), 200, (0.8, 0.85, 1.0), 5)


def setup_camera():
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (0, -5, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam_data.lens = 85  # portrait-flattering, low distortion
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = SAMPLES
    scene.render.resolution_x = RES
    scene.render.resolution_y = RES
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.cycles.device = "GPU"
    except Exception:
        pass


def render_sequence(coin):
    os.makedirs(OUT, exist_ok=True)
    for i in range(FRAMES):
        theta = (i / FRAMES) * 2 * math.pi
        coin.rotation_euler[0] = math.radians(90) + theta  # spin about X
        bpy.context.scene.render.filepath = os.path.join(
            OUT, f"frame_{i:03d}.png")
        bpy.ops.render.render(write_still=True)
    print(f"Rendered {FRAMES} frames -> {os.path.abspath(OUT)}")


def main():
    reset_scene()
    coin = build_coin()
    setup_lighting()
    setup_camera()
    setup_render()
    render_sequence(coin)


if __name__ == "__main__":
    main()
