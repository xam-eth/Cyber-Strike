extends SceneTree
##
## verify_import.gd — prove the forged GLBs survive Godot's own importer.
##
## Everything upstream of this file runs in three.js: the forge builds the
## models, the gallery renders them, the Khronos validator checks the binary.
## None of that proves Godot will accept them. This script does, in the engine:
##
##   1. load() every `res://assets/forge/<category>/<id>.glb` from the manifest
##   2. instantiate it and measure the real AABB in metres
##   3. check the height matches the manifest within tolerance
##   4. check every declared clip exists in the imported AnimationPlayer
##   5. check every declared socket survived as a named node
##   6. write a JSON report and exit non-zero on any failure
##
## Run it through tools/asset-forge/godot/run_verify.sh, which copies this file
## into the project (Godot only loads scripts from inside the project) and runs
## the import step first.
##
##   godot --headless --path game --import
##   godot --headless --path game --script res://verify_import.gd
##

const MANIFEST_PATH := "res://assets/forge/forge_manifest.json"
const HEIGHT_TOLERANCE := 0.06          ## ±6% against the manifest height
const LENGTH_TOLERANCE := 0.10          ## ±10% for length-normalised props

var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	print("== forge import verification ==")
	print("Godot %s" % Engine.get_version_info().get("string", "?"))

	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("manifest missing: %s" % MANIFEST_PATH)
		_finish()
		return

	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(manifest) != TYPE_DICTIONARY:
		_fail("manifest is not valid JSON")
		_finish()
		return

	var entries: Array = manifest.get("entries", [])
	if entries.is_empty():
		_fail("manifest has no entries")
		_finish()
		return

	for entry in entries:
		_verify_entry(entry)

	_finish()


func _verify_entry(entry: Dictionary) -> void:
	var id: String = entry.get("id", "?")
	var res_path: String = entry.get("resource", "")
	var row := {
		"id": id,
		"category": entry.get("category", ""),
		"resource": res_path,
		"ok": true,
		"problems": [],
	}

	if res_path.is_empty() or not ResourceLoader.exists(res_path):
		_row_fail(row, "not importable (ResourceLoader.exists == false) — did the import step run?")
		_rows.append(row)
		return

	var packed: Resource = load(res_path)
	if packed == null or not (packed is PackedScene):
		_row_fail(row, "load() did not return a PackedScene")
		_rows.append(row)
		return

	var node: Node = (packed as PackedScene).instantiate()
	if node == null:
		_row_fail(row, "instantiate() returned null")
		_rows.append(row)
		return

	get_root().add_child(node)

	# --- geometry: real AABB in metres ------------------------------------
	var aabb := _combined_aabb(node)
	var size := aabb.size
	row["height_m"] = snappedf(size.y, 0.001)
	row["width_m"] = snappedf(size.x, 0.001)
	row["depth_m"] = snappedf(size.z, 0.001)
	row["nodes"] = _count_nodes(node, 0)

	var target: Variant = entry.get("targetHeight")
	var normalised_by: String = entry.get("normalisedBy", "height")
	if target == null:
		target = entry.get("targetLength")
		normalised_by = "length"
	if target != null and float(target) > 0.0:
		var measured := size.y if normalised_by != "length" else maxf(size.x, size.z)
		var tol := HEIGHT_TOLERANCE if normalised_by != "length" else LENGTH_TOLERANCE
		var delta := absf(measured - float(target)) / float(target)
		row["target_m"] = snappedf(float(target), 0.001)
		row["delta"] = snappedf(delta, 0.0001)
		if delta > tol:
			_row_fail(row, "%s %.3f m vs target %.3f m (%.1f%% off, tolerance %.0f%%)" % [
				normalised_by, measured, float(target), delta * 100.0, tol * 100.0])

	# --- animation: clips must survive as an AnimationPlayer ----------------
	var declared: Array = entry.get("clips", [])
	var player := _find_animation_player(node)
	var imported: Array[String] = []
	if player != null:
		for name in player.get_animation_list():
			imported.append(String(name))
	row["clips"] = imported
	if not declared.is_empty():
		if player == null:
			_row_fail(row, "declares %d clip(s) but no AnimationPlayer was imported" % declared.size())
		else:
			for clip_name in declared:
				if not imported.has(String(clip_name)):
					_row_fail(row, "clip '%s' missing after import (got: %s)" % [clip_name, ", ".join(imported)])

	# --- sockets: named empties must survive ------------------------------
	var sockets: Array = entry.get("sockets", [])
	var found: Array[String] = []
	for socket_name in sockets:
		var node_found := node.find_child(String(socket_name), true, false)
		if node_found == null:
			_row_fail(row, "socket '%s' missing after import" % socket_name)
		else:
			found.append(String(socket_name))
	row["sockets"] = found

	node.queue_free()
	_rows.append(row)
	print("  %s %-24s %6.3f m  clips %d/%d  sockets %d/%d" % [
		"✓" if row["ok"] else "✗",
		id,
		float(row["height_m"]),
		imported.size(),
		declared.size(),
		found.size(),
		sockets.size(),
	])


func _combined_aabb(node: Node, xform := Transform3D.IDENTITY) -> AABB:
	var box := AABB()
	var has_box := false
	if node is Node3D:
		xform = xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			box = xform * mi.get_aabb()
			has_box = true
	for child in node.get_children():
		var child_box := _combined_aabb(child, xform)
		if child_box.size == Vector3.ZERO:
			continue
		box = child_box if not has_box else box.merge(child_box)
		has_box = true
	return box if has_box else AABB()


func _count_nodes(node: Node, acc: int) -> int:
	var total := acc + 1
	for child in node.get_children():
		total = _count_nodes(child, total)
	return total


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _row_fail(row: Dictionary, message: String) -> void:
	row["ok"] = false
	(row["problems"] as Array).append(message)
	_failures.append("%s: %s" % [row.get("id", "?"), message])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	var passed := 0
	for row in _rows:
		if row["ok"]:
			passed += 1

	var report := {
		"generated": Time.get_datetime_string_from_system(true),
		"godot": Engine.get_version_info().get("string", "?"),
		"checked": _rows.size(),
		"passed": passed,
		"failed": _rows.size() - passed,
		"rows": _rows,
		"failures": _failures,
	}
	# CI writes the report into the repository so it can be committed back and
	# read by a human or a later step; a local run keeps it in user://.
	var out := OS.get_environment("FORGE_REPORT")
	if out.is_empty():
		out = "user://forge_import_report.json"
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()

	print("")
	print("%d checked · %d passed · %d failed" % [_rows.size(), passed, _rows.size() - passed])
	for message in _failures:
		print("  ✗ %s" % message)
	var written := ProjectSettings.globalize_path(out) if out.begins_with("user://") else out
	print("report: %s" % written)
	print("== forge import verification %s ==" % ("PASSED" if _failures.is_empty() else "FAILED"))
	quit(0 if _failures.is_empty() else 1)
