"""Render the top-down brain image for the 2D map from tools/brain-source.usdz:
App/Assets.xcassets/BrainTop.imageset/brain-top.png. The app no longer uses a 3D mesh.

    /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/bake_brain.py
"""
import os, bpy, bmesh, mathutils

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "brain-source.usdz")
TARGET_TRIS = 40_000  # enough detail for a clean top-view render

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.usd_import(filepath=SRC)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")  # the importer's Y-up→Z-up rotation lives on a parent
bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.01)
bmesh.ops.triangulate(bm, faces=bm.faces)
bm.to_mesh(obj.data)
bm.free()

ratio = min(1.0, TARGET_TRIS / len(obj.data.polygons))
mod = obj.modifiers.new("decimate", "DECIMATE")
mod.ratio = ratio
bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.shade_smooth()

# Source: Z up, nose towards -Y. The bounds below frame the top-view render.
mesh = obj.data
verts = [v.co.copy() for v in mesh.vertices]
lo = mathutils.Vector([min(c) for c in zip(*verts)])
hi = mathutils.Vector([max(c) for c in zip(*verts)])
centre = (lo + hi) / 2

# Top-down render for the 2D map: orthographic, nose up, framed exactly to the brain's footprint.
TOP = os.path.join(ROOT, "App", "Assets.xcassets", "BrainTop.imageset")
os.makedirs(TOP, exist_ok=True)
scene = bpy.context.scene
camera = bpy.data.objects.new("top", bpy.data.cameras.new("top"))
scene.collection.objects.link(camera)
camera.data.type = "ORTHO"
camera.data.ortho_scale = hi.y - lo.y
camera.location = (centre.x, centre.y, hi.z + 1)
camera.rotation_euler = (0, 0, 3.14159265)  # look down -Z with -Y (the nose) at the top
scene.camera = camera
render = scene.render
render.engine = "BLENDER_WORKBENCH"
render.film_transparent = True
render.resolution_y = 768
render.resolution_x = round(768 * (hi.x - lo.x) / (hi.y - lo.y))
shading = scene.display.shading
shading.light = "STUDIO"
shading.color_type = "SINGLE"
shading.single_color = (0.85, 0.80, 0.78)
shading.show_cavity = True
shading.cavity_type = "BOTH"
shading.curvature_ridge_factor = 1.5
shading.curvature_valley_factor = 1.5
render.filepath = os.path.join(TOP, "brain-top.png")
bpy.ops.render.render(write_still=True)
with open(os.path.join(TOP, "Contents.json"), "w") as f:
    f.write('{"images":[{"filename":"brain-top.png","idiom":"universal"}],"info":{"author":"xcode","version":1}}\n')
print(f"RENDERED {render.resolution_x}x{render.resolution_y} -> {render.filepath}")
