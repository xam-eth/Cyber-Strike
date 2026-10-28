"""Static contract checks; no claim of rendering or gameplay validation."""
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
base = root / 'assets/world/aetherfall'
layout = json.loads((base / 'layout.json').read_text())
measures = json.loads((base / 'measurements.json').read_text())['assets']
assert layout['unit'] == 'meters' and layout['up'] == 'Y'
assert len(layout['placements']) == 251
assert {p['asset'] for p in layout['placements']} == set(measures)
for p in layout['placements']:
    assert len(p['pos']) == len(p['rot']) == 3 and p['scale'] > 0
for name in [*measures, 'energy_orbit', 'connector_ramp']:
    data = (base / 'models' / (name + '.glb')).read_bytes()
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data)), name
    json_len = struct.unpack_from('<I', data, 12)[0]
    payload = json.loads(data[20:20 + json_len])
    if name == 'energy_orbit':
        assert payload.get('animations'), 'animasi orbit hilang'
    else:
        assert payload.get('materials'), name
assert (root / 'source/aetherfall_kit.blend').is_file()
assert (root / 'source/energy_orbit.blend').is_file()
assert (root / 'source/connector_ramp.blend').is_file()
connectors = json.loads((base / 'connectors.json').read_text())['connectors']
assert {x['name'] for x in connectors} == {'east_bridge_approach', 'west_catwalk_approach'}
print(f'PASS: {len(layout["placements"])} placement, {len(measures)} modul, GLB orbit beranimasi, 2 connector, 3 sumber Blender')
