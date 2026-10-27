class_name ProgressionLookup
extends RefCounted

## Finds the profile from inside a scene, once, without assuming the shape of the
## tree it lives in.
##
## A tier is chosen before the body is fitted and before the first hit, so both
## `CharacterVisual` and `PlayerController` need the saved profile during their
## own `_ready` -- which runs *before* `Main._ready`, so nothing above them can
## have handed it down yet. Three shapes have to work:
##
##   * the shipped game: `Main` is the current scene and owns `ProgressionService`;
##   * a smoke fixture: the scene is parented straight onto the root window, so
##     `current_scene` is null but the node is still there;
##   * a fixture with no profile at all: the caller keeps the scene's own
##     defaults (100 HP, no plate) rather than crashing or inventing one.
##
## `get_first_node_in_group` is the last resort because it costs nothing when the
## other two answered and cannot pick up a node from a different tree.

## Main adds the service to this group so a lookup cannot be fooled by a
## same-named node that is not the profile.
const GROUP := &"progression_service"


static func find(from: Node) -> ProgressionService:
	if from == null or not from.is_inside_tree():
		return null
	var tree := from.get_tree()
	if tree == null:
		return null
	var scene := tree.current_scene
	if scene != null:
		var node := scene.get_node_or_null("ProgressionService")
		if node is ProgressionService:
			return node
	var grouped := tree.get_first_node_in_group(GROUP)
	if grouped is ProgressionService:
		return grouped
	var root := tree.root
	if root == null:
		return null
	var found := root.find_child("ProgressionService", true, false)
	return found as ProgressionService
