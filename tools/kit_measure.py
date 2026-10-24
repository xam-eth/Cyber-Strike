#!/usr/bin/env python3
"""Measure every module in the imported sci-fi kit.

    python3 tools/kit_measure.py            # rewrite the measurements file
    python3 tools/kit_measure.py --check    # fail if it is stale

Why this exists: the pack authors most modules off-origin — `Wall_Console_01_Half`
starts 1.76 m to its own left and 0.74 m up, `Fence_Long_01` starts 2.5 m to its
right — so placing one by its node origin either floats it or buries it, and its
collider lands somewhere else again. This reads each glass's POSITION accessors
and writes the bounding box and minimum corner, which is what
`ScifiKitLibrary` uses to centre a module on its footprint.

It is a measurement, not an estimate: the numbers come out of the committed GLBs,
so re-converting the pack and forgetting to re-measure is detectable with
`--check`, which the static check group runs.
"""
import json
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODELS = ROOT / "game" / "assets" / "world" / "scifi_starter_kit" / "models"
OUT = ROOT / "game" / "assets" / "world" / "scifi_starter_kit" / "measurements.json"


def measure(path):
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise SystemExit(f"{path.name}: not a GLB")
    offset, doc = 12, None
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        if kind == 0x4E4F534A:
            doc = json.loads(data[offset + 8:offset + 8 + length].decode("utf-8"))
            break
        offset += 8 + length + ((4 - length % 4) % 4)
    if doc is None:
        raise SystemExit(f"{path.name}: no JSON chunk")
    low, high = [1e9] * 3, [-1e9] * 3
    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
            if "min" not in accessor:
                continue
            for axis in range(3):
                a, b = accessor["min"][axis], accessor["max"][axis]
                low[axis] = min(low[axis], min(a, b))
                high[axis] = max(high[axis], max(a, b))
    return [round(high[i] - low[i], 3) for i in range(3)], [round(low[i], 3) for i in range(3)]


def dump(payload):
    """One line per module: 125 models stay readable and the diff stays small."""
    head = {k: v for k, v in payload.items() if k != "models"}
    lines = [json.dumps(head, indent=1).rstrip().rstrip("}").rstrip() + ',', ' "models": {']
    items = list(payload["models"].items())
    for index, (name, entry) in enumerate(items):
        comma = "," if index < len(items) - 1 else ""
        lines.append(f'  {json.dumps(name)}: {json.dumps(entry)}{comma}')
    lines.append(" }")
    lines.append("}")
    return "\n".join(lines) + "\n"


def build():
    models = {}
    for path in sorted(MODELS.glob("*.glb")):
        size, low = measure(path)
        models[path.stem] = {"size": size, "min": low}
    return {
        "source": "3DScifiStarterKitFree.zip",
        "note": (
            "Measured from the committed GLB POSITION accessors by tools/kit_measure.py. "
            "size and min are metres; min is the model's own minimum corner."
        ),
        "models": models,
    }


def main():
    payload = build()
    text = dump(payload)
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text() != text:
            print(f"FAIL: {OUT.relative_to(ROOT)} is stale; run tools/kit_measure.py")
            return 1
        print(f"OK: {OUT.relative_to(ROOT)} matches the {len(payload['models'])} committed modules")
        return 0
    OUT.write_text(text)
    print(f"wrote {OUT.relative_to(ROOT)}: {len(payload['models'])} modules")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
