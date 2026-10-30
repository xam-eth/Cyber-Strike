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
# Geometry budget for every authored reusable object. This deliberately checks
# form complexity rather than claiming visual realism or runtime performance.
minimum_meshes = {
    'access_gate': 25, 'background_silhouette': 14, 'beam': 14,
    'bridge_deck': 32, 'bridge_support': 15, 'cable_bundle': 14,
    'cliff_face': 20, 'cloud_puff': 12, 'conduit': 13,
    'cooling_vent': 19, 'cover_barrier': 9, 'cover_machine': 13,
    'damaged_slab': 15, 'debris_cluster': 14, 'deck_6x6': 30,
    'deck_edge': 16, 'energy_core': 20, 'machinery': 24,
    'pillar': 12, 'railing': 15, 'rock_boulder': 9,
    'terrain_chunk': 25, 'tower_foundation': 36, 'tower_spire': 13,
    'tower_tier': 35, 'walkway_deck': 28, 'wall_section': 19,
}
assert set(minimum_meshes) == set(measures)
for asset, minimum in minimum_meshes.items():
    assert measures[asset]['objects'] >= minimum, f'form detail missing: {asset}'
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
        if name == 'connector_ramp':
            assert len(payload.get('meshes', [])) >= 26, 'detail connector hilang'
        # All opaque PBR surface materials must carry real normal and
        # metallic-roughness maps, not only a base-colour texture.
        textured = {"Steel", "PaintedSteel", "Titanium", "Concrete", "Composite", "Rock", "Stratum", "Rubber", "Cable", "Hazard", "WarningRed", "RampSteel", "RampHazard"}
        for material in payload['materials']:
            if material.get('name') in textured:
                pbr = material.get('pbrMetallicRoughness', {})
                assert material.get('normalTexture'), f"normal map missing: {name}/{material['name']}"
                assert pbr.get('metallicRoughnessTexture'), f"ORM map missing: {name}/{material['name']}"
assert (root / 'source/aetherfall_kit.blend').is_file()
assert (root / 'source/energy_orbit.blend').is_file()
assert (root / 'source/connector_ramp.blend').is_file()
# Stellar Horizon stops at two authored reusable hero props until this vertical
# slice is validated; this contract guards their Blender source, PBR maps and
# authored state clips without claiming a renderer/performance result.
slice_data = json.loads((base / 'stellar_horizon_slice.json').read_text())
interactives = slice_data['interactives']
assert len(interactives) == 2
assert {item['kind'] for item in interactives} == {'tech_cache', 'objective_device'}
assert (root / 'source/aetherfall_interactives.blend').is_file()
for filename, animation, minimum_meshes in [
    ('tech_cache.glb', 'TechCache_Open', 22),
    ('objective_device.glb', 'ObjectiveDevice_Activate', 19),
]:
    data = (base / 'interactives' / filename).read_bytes()
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data)), filename
    json_len = struct.unpack_from('<I', data, 12)[0]
    payload = json.loads(data[20:20 + json_len])
    assert len(payload.get('meshes', [])) >= minimum_meshes, filename
    assert animation in [clip.get('name') for clip in payload.get('animations', [])], filename
    assert payload.get('materials') and payload.get('textures'), filename
    for material in payload['materials']:
        pbr = material.get('pbrMetallicRoughness', {})
        assert material.get('normalTexture'), f'normal map missing: {filename}/{material["name"]}'
        assert pbr.get('metallicRoughnessTexture'), f'ORM map missing: {filename}/{material["name"]}'
for required in [
    'scenes/aetherfall_player.tscn', 'scenes/props/tech_cache.tscn',
    'scenes/props/objective_device.tscn', 'scripts/progression_state.gd',
    'scripts/interaction_target.gd', 'scripts/tech_cache.gd',
    'scripts/objective_device.gd', 'tests/interactive_slice.gd',
]:
    assert (root / required).is_file(), required
# Purpose-authored visual density: structural buildings and cargo setpieces are
# distinct from the preserved kit layout, with their own collision contract.
landmark_data = json.loads((base / 'landmarks.json').read_text())
landmarks = landmark_data['placements']
assert len(landmarks) == 6
assert {item['asset'] for item in landmarks} == {
    'field_outpost', 'relay_annex', 'service_hangar', 'cargo_service_cluster',
}
assert (root / 'source/aetherfall_landmarks.blend').is_file()
for filename, minimum_meshes in [
    ('field_outpost.glb', 28),
    ('relay_annex.glb', 30),
    ('service_hangar.glb', 32),
    ('cargo_service_cluster.glb', 13),
]:
    data = (base / 'landmarks' / filename).read_bytes()
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data)), filename
    json_len = struct.unpack_from('<I', data, 12)[0]
    payload = json.loads(data[20:20 + json_len])
    assert len(payload.get('meshes', [])) >= minimum_meshes, filename
    assert len(payload.get('materials', [])) >= 5 and payload.get('textures'), filename
    for material in payload['materials']:
        pbr = material.get('pbrMetallicRoughness', {})
        assert material.get('normalTexture'), f'normal map missing: {filename}/{material["name"]}'
        assert pbr.get('metallicRoughnessTexture'), f'ORM map missing: {filename}/{material["name"]}'
assert sum(len(item.get('collision_boxes', [])) for item in landmarks) == 9
verticality_data = json.loads((base / 'verticality.json').read_text())
verticality = verticality_data['placements']
assert len(verticality) == 4
assert {item['asset'] for item in verticality} == {
    'refinery_stack', 'overhead_gantry', 'raised_ops_deck',
}
assert (root / 'source/aetherfall_vertical_infrastructure.blend').is_file()
for filename, minimum_meshes in [
    ('refinery_stack.glb', 57),
    ('overhead_gantry.glb', 36),
    ('raised_ops_deck.glb', 25),
]:
    data = (base / 'vertical' / filename).read_bytes()
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data)), filename
    json_len = struct.unpack_from('<I', data, 12)[0]
    payload = json.loads(data[20:20 + json_len])
    assert len(payload.get('meshes', [])) >= minimum_meshes, filename
    assert len(payload.get('materials', [])) >= 5 and payload.get('textures'), filename
    for material in payload['materials']:
        pbr = material.get('pbrMetallicRoughness', {})
        assert material.get('normalTexture'), f'normal map missing: {filename}/{material["name"]}'
        assert pbr.get('metallicRoughnessTexture'), f'ORM map missing: {filename}/{material["name"]}'
assert sum(len(item.get('collision_boxes', [])) for item in verticality) == 12
for source in ['ai_weathered_steel.png', 'ai_poured_concrete.png', 'ai_sedimentary_rock.png']:
    assert (base / 'source_textures' / source).is_file()
for suffix in ['normal', 'orm']:
    assert (base / 'materials' / ('aether_metal_' + suffix + '.png')).is_file()
    assert (base / 'materials' / ('aether_concrete_' + suffix + '.png')).is_file()
    assert (base / 'materials' / ('aether_rock_' + suffix + '.png')).is_file()
connectors = json.loads((base / 'connectors.json').read_text())['connectors']
assert {x['name'] for x in connectors} == {'east_bridge_approach', 'west_catwalk_approach', 'lower_canyon_descent'}
print(f'PASS: {len(layout["placements"])} kit placement, {len(measures)} modul, 3 connector, 2 interaktif, 4 vertical, 6 landmark, 6 source Blender, PBR normal+ORM')
