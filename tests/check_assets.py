"""Static contract checks; no claim of rendering or gameplay validation."""
import json
import struct
from math import hypot
from pathlib import Path

root = Path(__file__).resolve().parents[1]
project_config = (root / 'project.godot').read_text()
assert 'textures/default_filters/anisotropic_filtering_level=2' in project_config
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
ice_phase1 = json.loads((base / 'ice_planet_phase1.json').read_text())['placements']
assert len(ice_phase1) == 9
assert {item['asset'] for item in ice_phase1} == {
    'glacier_shelf', 'frozen_spire', 'sentinel_archive', 'cryo_pylon',
}
assert (root / 'source/aetherfall_ice_planet.blend').is_file()
for filename, minimum_meshes in [
    ('glacier_shelf.glb', 15),
    ('frozen_spire.glb', 6),
    ('sentinel_archive.glb', 34),
    ('cryo_pylon.glb', 12),
]:
    data = (base / 'ice_planet' / filename).read_bytes()
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data)), filename
    json_len = struct.unpack_from('<I', data, 12)[0]
    payload = json.loads(data[20:20 + json_len])
    assert len(payload.get('meshes', [])) >= minimum_meshes, filename
    assert payload.get('materials') and payload.get('textures'), filename
    for material in payload['materials']:
        pbr = material.get('pbrMetallicRoughness', {})
        assert material.get('normalTexture'), f'normal map missing: {filename}/{material["name"]}'
        assert pbr.get('metallicRoughnessTexture'), f'ORM map missing: {filename}/{material["name"]}'
    if filename == 'sentinel_archive.glb':
        node_names = {node.get('name') for node in payload.get('nodes', [])}
        assert 'ArchiveCore' not in node_names, 'Archive masih memakai core solid yang menutup interior'
        assert {'ArchiveRearShell', 'ArchiveFrontLintel', 'ArchiveSideShell_-5.82', 'ArchiveSideShell_5.82'} <= node_names
assert sum(len(item.get('collision_boxes', [])) for item in ice_phase1) == 6
# Phase 3 converts the former visual-only Archive door into a shell threshold.
archive_shell = next(item for item in ice_phase1 if item['id'] == 'sentinel_archive_exterior')
for box in archive_shell['collision_boxes']:
    # local point just inside the south/front threshold must remain unobstructed
    inside = all(abs(point - float(center)) <= float(size) / 2.0 for point, center, size in zip((0.0, 2.5, -2.25), box['center'], box['size']))
    assert not inside, 'Archive threshold is sealed by an exterior collision box'
# Phase 3 adds precisely one compact vestibule and one named final-tech source.
# It is deliberately independent from combat/AI and persists the Data Core only
# after the Archive Computer has an access credential and a successful write.
archive_phase3 = json.loads((base / 'archive_phase3.json').read_text())
archive_interior = archive_phase3['interior']
archive_computer = archive_phase3['computer']
assert archive_interior['asset'] == 'archive_vestibule'
assert len(archive_interior['collision_boxes']) == 4
assert len(archive_interior['lights']) == 2
assert archive_computer['id'] == 'aetherfall_sentinel_computer'
assert archive_computer['data_core_id'] == 'aetherfall_sentinel_data_core'
assert archive_computer['requires']['resource'] == 'tech_data' and archive_computer['requires']['amount'] == 1
assert archive_computer['download_seconds'] > 0.0
assert 'locked, authorized, downloading, collected' in archive_computer['purpose']
assert (root / 'source/aetherfall_archive_interior.blend').is_file()
for required in [
    'assets/world/aetherfall/archive/archive_vestibule.glb',
    'assets/world/aetherfall/archive/archive_computer.glb',
    'scenes/props/archive_computer.tscn', 'scripts/archive_computer.gd',
    'tests/archive_phase3.gd',
]:
    assert (root / required).is_file(), required
for filename, minimum_meshes, animation in [
    ('archive_vestibule.glb', 55, None),
    ('archive_computer.glb', 23, 'ArchiveComputer_Download'),
]:
    data = (base / 'archive' / filename).read_bytes()
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data)), filename
    json_len = struct.unpack_from('<I', data, 12)[0]
    payload = json.loads(data[20:20 + json_len])
    assert len(payload.get('meshes', [])) >= minimum_meshes, filename
    assert payload.get('materials') and payload.get('textures'), filename
    if animation:
        assert animation in [clip.get('name') for clip in payload.get('animations', [])], filename
    for material in payload['materials']:
        pbr = material.get('pbrMetallicRoughness', {})
        assert material.get('normalTexture'), f'normal map missing: {filename}/{material["name"]}'
        assert pbr.get('metallicRoughnessTexture'), f'ORM map missing: {filename}/{material["name"]}'
progression_source = (root / 'scripts/progression_state.gd').read_text()
computer_source = (root / 'scripts/archive_computer.gd').read_text()
for method in ['authorize_archive_computer', 'commit_archive_data_core', 'has_data_core']:
    assert method in progression_source, method
for state_name in ['LOCKED', 'AUTHORIZED', 'DOWNLOADING', 'COLLECTED']:
    assert state_name in computer_source, state_name

# Connected Expanse joins every former remote connector endpoint into one
# intentional perimeter loop. Its lowland is physical catch terrain, not an
# invisible boundary, while exposed spines retain no collision rails.
expanse_data = json.loads((base / 'world_expansion.json').read_text())
lowlands = expanse_data['lowland_fields']
shelves = expanse_data['shelves']
loop_routes = expanse_data['loop_routes']
recovery_routes = expanse_data['recovery_routes']
assert len(lowlands) == 9 and len(shelves) == 14
assert len(loop_routes) == 17 and len(recovery_routes) == 1
assert {item['asset'] for item in lowlands} == {'lowland_field'}
assert {item['asset'] for item in shelves} == {'expanse_shelf'}
assert all(item.get('purpose') for item in [*lowlands, *shelves, *loop_routes, *recovery_routes])
coverage = expanse_data['coverage']
assert coverage['lowland_x_range'] == [-120.0, 120.0]
assert coverage['lowland_z_range'] == [-108.0, 108.0]
assert coverage['outer_loop_x_range'] == [-102.0, 104.0]
assert coverage['outer_loop_z_range'] == [-90.0, 80.0]
# The catch terrain sits materially below the legacy basin. This preserves its
# physical role while keeping the default overview from reading one far field
# edge as an ice wall through the middle of the original world.
lowland_y = coverage['lowland_surface_y']
assert lowland_y == -18.5
assert all(field['position'][1] == lowland_y for field in lowlands)
recovery = recovery_routes[0]
assert recovery['to'][1] == lowland_y
recovery_run = hypot(recovery['to'][0] - recovery['from'][0], recovery['to'][2] - recovery['from'][2])
recovery_grade = abs(recovery['to'][1] - recovery['from'][1]) / recovery_run
assert recovery_run == 44.0
assert recovery_grade <= coverage['recovery_max_grade']
assert any(
    abs(recovery['to'][0] - field['position'][0]) <= 40.0
    and abs(recovery['to'][2] - field['position'][2]) <= 36.0
    for field in lowlands
)
# The review scene used to display an "overview" label while retaining a
# different near-horizontal scene transform. Keep the start frame bound to the
# explicit key-1 overview contract instead.
review_camera_source = (root / 'scripts/review_camera.gd').read_text()
review_scene_source = (root / 'scenes/aetherfall.tscn').read_text()
assert 'apply_review_view(VIEWS[KEY_1])' in review_camera_source
assert '"position": Vector3(0, 28, 62)' in review_camera_source
assert '"target": Vector3(0, 10, -12)' in review_camera_source
assert 'position = Vector3(0, 28, 62)' in review_scene_source
assert (root / 'source/aetherfall_connected_expanse.blend').is_file()
assert (root / 'tools/blender/build_connected_expanse.py').is_file()
assert (root / 'tests/world_expansion.gd').is_file()
for filename, minimum_meshes in [
    ('expanse_shelf.glb', 25),
    ('transit_spine.glb', 23),
    ('lowland_field.glb', 23),
]:
    data = (base / 'expanse' / filename).read_bytes()
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data)), filename
    json_len = struct.unpack_from('<I', data, 12)[0]
    payload = json.loads(data[20:20 + json_len])
    assert len(payload.get('meshes', [])) >= minimum_meshes, filename
    assert payload.get('materials') and payload.get('textures'), filename
    for material in payload['materials']:
        pbr = material.get('pbrMetallicRoughness', {})
        assert material.get('normalTexture'), f'normal map missing: {filename}/{material["name"]}'
        assert pbr.get('metallicRoughnessTexture'), f'ORM map missing: {filename}/{material["name"]}'
# 768px original maps and explicitly repeated UVs give the expanded walkable
# surfaces higher close-range density than the earlier 512px world kit.
for name in ['aether_expanse_ice', 'aether_expanse_metal', 'aether_expanse_hazard']:
    for suffix in ['', '_normal', '_orm']:
        png = (base / 'materials' / (name + suffix + '.png')).read_bytes()
        assert png[:8] == b"\x89PNG\r\n\x1a\n"
        width, height = struct.unpack('>II', png[16:24])
        assert (width, height) == (768, 768), f'{name}{suffix} expected 768px'
# Cycle proof: each outer-loop junction has exactly one arrival and departure.
degree = {}
for route in loop_routes:
    start = tuple(route['from'])
    end = tuple(route['to'])
    degree[start] = degree.get(start, 0) + 1
    degree[end] = degree.get(end, 0) + 1
assert degree and all(value == 2 for value in degree.values()), degree
route_ids = {route['id'] for route in [*loop_routes, *recovery_routes]}
for endpoint in expanse_data['legacy_endpoint_contract']:
    assert all(route_id in route_ids for route_id in endpoint['connected_route_ids']), endpoint['id']
    # West/east endpoints are loop through-points; lower canyon has the loop
    # plus its explicit recovery slope to the physical lowland.
    expected = 3 if endpoint['id'] == 'lower_canyon_remote' else 2
    assert len(endpoint['connected_route_ids']) == expected, endpoint['id']

# Phase 2 has a deliberately small set of collision-backed cover and terrain
# pieces. This validates source/GLB/PBR contracts and proves, geometrically,
# that every named preserved route retains at least 0.5m beyond the setpiece
# collision footprint and nominal route half-width. It is static evidence, not
# a substitute for Godot capsule traversal execution.
phase2_data = json.loads((base / 'phase2_cover.json').read_text())
phase2 = phase2_data['placements']
assert len(phase2) == 8
assert {item['asset'] for item in phase2} == {
    'glacier_berm', 'salvage_pod', 'cryo_bulkhead', 'ice_terrace',
}
assert (root / 'source/aetherfall_phase2_cover.blend').is_file()
assert all(len(item.get('purpose', '')) >= 40 for item in phase2)
assert sum(len(item.get('collision_boxes', [])) for item in phase2) == 12
route_contract = phase2_data.get('route_clearance', [])
assert {item['route'] for item in route_contract} == {
    'central', 'east_bridge_approach', 'west_catwalk_approach',
    'lower_canyon_descent',
}
assert all(item.get('status') == 'preserved' and item.get('reason') for item in route_contract)
for filename, minimum_meshes in [
    ('glacier_berm.glb', 10),
    ('salvage_pod.glb', 13),
    ('cryo_bulkhead.glb', 15),
    ('ice_terrace.glb', 11),
]:
    data = (base / 'phase2' / filename).read_bytes()
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data)), filename
    json_len = struct.unpack_from('<I', data, 12)[0]
    payload = json.loads(data[20:20 + json_len])
    assert len(payload.get('meshes', [])) >= minimum_meshes, filename
    assert payload.get('materials') and payload.get('textures'), filename
    for material in payload['materials']:
        pbr = material.get('pbrMetallicRoughness', {})
        assert material.get('normalTexture'), f'normal map missing: {filename}/{material["name"]}'
        assert pbr.get('metallicRoughnessTexture'), f'ORM map missing: {filename}/{material["name"]}'
routes_for_clearance = {item['name']: (item['from'], item['to'], item['width']) for item in layout['routes']}
connector_data = json.loads((base / 'connectors.json').read_text())['connectors']
routes_for_clearance.update({item['name']: (item['from'], item['to'], item['width']) for item in connector_data})
def point_segment_distance_2d(point, start, end):
    dx, dz = end[0] - start[0], end[2] - start[2]
    length_squared = dx * dx + dz * dz
    assert length_squared > 0.0
    t = max(0.0, min(1.0, ((point[0] - start[0]) * dx + (point[2] - start[2]) * dz) / length_squared))
    return ((point[0] - (start[0] + t * dx)) ** 2 + (point[2] - (start[2] + t * dz)) ** 2) ** 0.5
for item in phase2:
    footprint_radius = max((box['size'][0] ** 2 + box['size'][2] ** 2) ** 0.5 / 2.0 for box in item['collision_boxes'])
    for contract in route_contract:
        start, end, width = routes_for_clearance[contract['route']]
        clearance = point_segment_distance_2d(item['position'], start, end) - footprint_radius - width / 2.0
        assert clearance >= 0.5, f'Phase 2 blocks {contract["route"]}: {item["id"]} ({clearance:.2f}m)'

for suffix in ['', '_normal', '_orm']:
    assert (base / 'materials' / ('aether_ice' + suffix + '.png')).is_file()
for source in ['ai_weathered_steel.png', 'ai_poured_concrete.png', 'ai_sedimentary_rock.png']:
    assert (base / 'source_textures' / source).is_file()
for suffix in ['normal', 'orm']:
    assert (base / 'materials' / ('aether_metal_' + suffix + '.png')).is_file()
    assert (base / 'materials' / ('aether_concrete_' + suffix + '.png')).is_file()
    assert (base / 'materials' / ('aether_rock_' + suffix + '.png')).is_file()
connectors = json.loads((base / 'connectors.json').read_text())['connectors']
assert {x['name'] for x in connectors} == {'east_bridge_approach', 'west_catwalk_approach', 'lower_canyon_descent'}
print(f'PASS: {len(layout["placements"])} kit placement, {len(measures)} modul, 3 connector, 2 interaktif, 4 vertical, 6 landmark, 9 ice-planet placement, 8 Phase-2 cover, 1 Archive Interior, 1 Connected Expanse, 10 source Blender, PBR normal+ORM')
