class_name ContentModuleLoader
extends RefCounted

## Failure-returning boundary for replaceable visual content.
##
## Core scenes and UI never preload an external World's or Character's asset.
## They pass a declared path and the roots that domain is allowed to use. A
## missing, misplaced, or non-scene resource becomes a result dictionary; the
## caller keeps its fallback and unrelated modules never receive a half-built
## node. This class owns no selection, health registry, or global mutable state.
##
## GDScript cannot catch a native crash, an infinite loop, or every script parse
## error. External packages therefore forbid runtime scripts; their source
## tooling is reviewed separately before an internal adapter is changed.
const WORLD_ROOTS: Array[String] = [
	"res://assets/forge/worlds/",
	"res://assets/world/kenney_space_kit/",
	"res://content/worlds/",
]
const CHARACTER_ROOTS: Array[String] = [
	"res://assets/characters/",
	"res://assets/enemies/",
	"res://assets/weapons/",
	"res://content/characters/",
	# Existing enemy actors still use this licensed shared kit. New external
	# packages belong under content/characters, not the World source library.
	"res://assets/world/kenney_space_kit/",
]


## Load a PackedScene without throwing a null result into a caller's build.
## Result keys: ok, code, message, path, scene. `scene` is null on failure.
static func load_scene(path: String, allowed_roots: Array[String]) -> Dictionary:
	if not is_allowed_path(path, allowed_roots):
		return _failure(
			"outside_allowed_roots",
			path,
			"Content path is empty, malformed, or outside the declaring domain."
		)
	if not ResourceLoader.exists(path):
		return _failure("missing", path, "Content scene is not available.")
	var resource := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	var packed := resource as PackedScene
	if packed == null:
		return _failure("not_packed_scene", path, "Content resource is not a PackedScene.")
	if not packed.can_instantiate():
		return _failure("cannot_instantiate", path, "Content scene cannot be instantiated.")
	return {
		"ok": true,
		"code": "ok",
		"message": "",
		"path": path,
		"scene": packed,
	}


## Only normalized, local resource paths below an explicitly allowed root.
## Prefix checks include the root's trailing slash, so `characters_old` does
## not accidentally qualify as `characters`.
static func is_allowed_path(path: String, allowed_roots: Array[String]) -> bool:
	if path.is_empty() or not path.begins_with("res://") or path.contains("\\"):
		return false
	var relative := path.trim_prefix("res://")
	for segment in relative.split("/"):
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	for root in allowed_roots:
		if root.begins_with("res://") and root.ends_with("/"):
			if path.begins_with(root) and path.length() > root.length():
				return true
	return false


static func _failure(code: String, path: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"message": message,
		"path": path,
		"scene": null,
	}
