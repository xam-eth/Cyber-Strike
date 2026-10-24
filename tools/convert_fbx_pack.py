"""Convert a folder of FBX models to self-contained GLB, for Blender's CLI.

    blender --background --factory-startup --python tools/convert_fbx_pack.py -- \
        <pack_dir> <out_dir> [--texture-size 512] [--texture-quality 80]

Why this exists: the uploaded `3DScifiStarterKitFree.zip` is a 259 MB Git LFS
pointer, and the LFS host and GitHub artifact host are both unreachable from the
sandbox this repository is developed in. A GitHub runner can fetch the archive,
so the conversion happens there and the small GLB output comes back through git.

Textures in the pack are 4K PNG/AO/TIF pairs. Every model is re-exported with its
images downscaled and packed into the GLB, which is the only form small enough to
commit and still self-contained (no URI that can break on a different machine).

The script is deliberately boring: import one file, clamp its images, export,
repeat. A failure on one model is reported and skipped rather than killing a
125-model run.
"""

import json
import os
import sys
import traceback

import bpy

TEXTURE_EXTENSIONS = (".png", ".jpg", ".jpeg", ".tga", ".tif", ".tiff", ".bmp", ".exr")


def parse_args() -> tuple[str, str, int, int]:
    argv = sys.argv
    if "--" not in argv:
        raise SystemExit("usage: ... -- <pack_dir> <out_dir> [--texture-size N] [--texture-quality Q]")
    args = argv[argv.index("--") + 1 :]
    if len(args) < 2:
        raise SystemExit("need a pack directory and an output directory")
    pack_dir, out_dir = args[0], args[1]
    texture_size, quality = 512, 80
    if "--texture-size" in args:
        texture_size = int(args[args.index("--texture-size") + 1])
    if "--texture-quality" in args:
        quality = int(args[args.index("--texture-quality") + 1])
    return pack_dir, out_dir, texture_size, quality


def find_fbx(pack_dir: str) -> list[str]:
    found = []
    for root, _dirs, files in os.walk(pack_dir):
        for name in files:
            if name.lower().endswith(".fbx"):
                found.append(os.path.join(root, name))
    return sorted(found)


def index_textures(pack_dir: str) -> dict[str, str]:
    """Basename -> path, so a model whose textures live elsewhere can still load."""
    index: dict[str, str] = {}
    for root, _dirs, files in os.walk(pack_dir):
        for name in files:
            if name.lower().endswith(TEXTURE_EXTENSIONS):
                index.setdefault(name.lower(), os.path.join(root, name))
    return index


def prepare_textures(pack_dir: str, cache_dir: str, size: int, quality: int) -> dict[str, str]:
    """Downscale every texture once and return basename -> small file path.

    Doing this up front keeps the per-model work to "point at the cached file":
    loading a 4K TIF 125 times would dominate the run.
    """
    os.makedirs(cache_dir, exist_ok=True)
    prepared: dict[str, str] = {}
    for root, _dirs, files in os.walk(pack_dir):
        for name in files:
            lower = name.lower()
            if not lower.endswith(TEXTURE_EXTENSIONS):
                continue
            source = os.path.join(root, name)
            stem = os.path.splitext(name)[0]
            # Normal maps keep more resolution than albedo but are still lossy
            # enough that a JPEG at high quality is the right trade for a kit
            # that ships in a git repository.
            is_normal = "norm" in stem.lower()
            target_size = size if not is_normal else max(size // 2, 128)
            target_quality = min(quality + 12, 95) if is_normal else quality
            target = os.path.join(cache_dir, stem + ".jpg")
            if os.path.exists(target):
                prepared[lower] = target
                continue
            try:
                image = bpy.data.images.load(source, check_existing=False)
                width, height = image.size
                if width <= 0 or height <= 0:
                    raise RuntimeError("no pixels")
                scale = min(1.0, float(target_size) / float(max(width, height)))
                image.scale(max(1, int(width * scale)), max(1, int(height * scale)))
                image.filepath_raw = target
                image.file_format = "JPEG"
                scene = bpy.context.scene
                scene.render.image_settings.file_format = "JPEG"
                scene.render.image_settings.quality = target_quality
                image.save()
                prepared[lower] = target
                print(f"texture {name} {width}x{height} -> {target_size} ({target_quality}%)")
            except Exception as error:  # noqa: BLE001 - report and keep going
                print(f"texture FAILED {name}: {error}")
            finally:
                if "image" in locals() and image:
                    bpy.data.images.remove(image)
                    image = None
    return prepared


def remap_images(prepared: dict[str, str], texture_index: dict[str, str]) -> int:
    """Point every image in the current scene at its small cached copy."""
    remapped = 0
    for image in list(bpy.data.images):
        if image.name == "Render Result" or image.name == "Viewer Node":
            continue
        basename = os.path.basename(image.filepath_raw or image.filepath or image.name).lower()
        target = prepared.get(basename)
        if target is None and not image.has_data:
            # The FBX may reference an author path; fall back to a name match
            # anywhere in the archive.
            for candidate, source in texture_index.items():
                if candidate == basename or candidate.startswith(os.path.splitext(basename)[0]):
                    target = prepared.get(candidate)
                    if target:
                        break
        try:
            if target:
                image.filepath_raw = target
                image.file_format = "JPEG"
                image.reload()
            if not image.has_data:
                continue
            # Pack so the GLB carries the image; a URI would break on any move.
            image.pack()
            remapped += 1
        except Exception as error:  # noqa: BLE001
            print(f"image {image.name} failed: {error}")
    return remapped


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def model_stats() -> dict:
    triangles = 0
    meshes = 0
    materials = set()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.data is None:
            continue
        meshes += 1
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        for slot in obj.material_slots:
            if slot.material:
                materials.add(slot.material.name)
    return {"meshes": meshes, "triangles": triangles, "materials": sorted(materials)}


def main() -> None:
    pack_dir, out_dir, texture_size, quality = parse_args()
    os.makedirs(out_dir, exist_ok=True)
    cache_dir = "/tmp/fbx-textures"
    texture_index = index_textures(pack_dir)
    prepared = prepare_textures(pack_dir, cache_dir, texture_size, quality)
    print(f"cached {len(prepared)} textures from {len(texture_index)} candidates")

    models = find_fbx(pack_dir)
    print(f"found {len(models)} FBX files")
    report = []
    used_names: set[str] = set()

    for index, path in enumerate(models, start=1):
        stem = os.path.splitext(os.path.basename(path))[0]
        slug = "".join(char if char.isalnum() or char in "-_" else "_" for char in stem)
        while slug.lower() in used_names:
            slug += "_"
        used_names.add(slug.lower())
        target = os.path.join(out_dir, slug + ".glb")
        entry = {"source": os.path.relpath(path, pack_dir), "model": os.path.basename(target)}
        try:
            reset_scene()
            bpy.ops.import_scene.fbx(filepath=path)
            entry["images"] = remap_images(prepared, texture_index)
            entry.update(model_stats())
            bpy.ops.export_scene.gltf(
                filepath=target,
                export_format="GLB",
                export_apply=True,
                export_image_format="JPEG",
                export_jpeg_quality=quality,
                export_yup=True,
            )
            entry["bytes"] = os.path.getsize(target)
            print(f"[{index}/{len(models)}] {stem} -> {entry['model']} "
                  f"({entry['triangles']} tris, {entry['bytes']} B)")
        except Exception as error:  # noqa: BLE001
            entry["error"] = f"{error}"
            print(f"[{index}/{len(models)}] {stem} FAILED: {error}")
            traceback.print_exc()
        report.append(entry)

    report_path = os.path.join(os.path.dirname(out_dir.rstrip("/")), "conversion-report.json")
    with open(report_path, "w", encoding="utf-8") as handle:
        json.dump({"texture_size": texture_size, "quality": quality, "models": report}, handle, indent=2)
    ok = sum(1 for entry in report if "error" not in entry)
    print(f"converted {ok}/{len(report)} models; report at {report_path}")


if __name__ == "__main__":
    main()
