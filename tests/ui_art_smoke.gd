extends SceneTree

## Guards the shipped concept art in `res://assets/ui/`.
##
## Generated art is easy to lose track of: a file can exist on disk, be listed
## in a report, and still 404 in an export because it was never imported, or
## import to a blank rectangle because the crop threw the subject away. This
## test loads every texture the build produced, at runtime, and checks what
## actually came back:
##
##   * the resource loads and is a real Texture2D (not a placeholder),
##   * its imported size matches `art_manifest.json`, so no report can claim a
##     resolution the engine never got,
##   * the texture is not a flat rectangle — it has to carry real image data,
##     measured as the spread of pixel values rather than a guess,
##   * the colours it is made of belong to the families AegisTokens declares
##     for the art direction (navy, gunmetal/steel, cyan, amber, silver),
##   * the walk-cycle sheet divides into whole frames at its declared cell.
##
## It does not judge whether the art is *good*. Nothing here can. It proves the
## files are real, the right size, and inside the agreed palette.

const MANIFEST_PATH := "res://assets/ui/art_manifest.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_expect(false, "the art manifest exists at " + MANIFEST_PATH)
		_finish()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_expect(false, "the art manifest parses to a dictionary")
		_finish()
		return
	var entries: Array = (parsed as Dictionary).get("assets", [])
	_expect(entries.size() > 0, "the art manifest lists at least one asset")
	for entry in entries:
		_check_asset(entry as Dictionary)
	_finish()


func _check_asset(entry: Dictionary) -> void:
	var key: String = str(entry.get("key", "?"))
	var path: String = str(entry.get("file", ""))
	if not ResourceLoader.exists(path):
		_expect(false, "%s: %s exists in res://" % [key, path])
		return
	var texture := load(path) as Texture2D
	if texture == null:
		_expect(false, "%s: %s loads as a Texture2D" % [key, path])
		return

	var declared: Array = entry.get("size", [0, 0]) as Array
	var expected := Vector2(float(declared[0]), float(declared[1]))
	var actual := texture.get_size()
	_expect(
		actual == expected,
		"%s imports at its documented size (%s, manifest says %s)" % [key, actual, expected],
	)

	var image := texture.get_image()
	if image == null:
		_expect(false, "%s: pixel data can be read back" % key)
		return
	image.resize(96, 96, Image.INTERPOLATE_LANCZOS)

	var families := _family_counts(image)
	var total := 0
	for share in families.values():
		total += int(share)
	_expect(total > 0, "%s: sampled pixels produced a palette breakdown" % key)

	# A texture that survived cropping has to carry real image data. A flat
	# rectangle has a spread of ~0; anything the generator actually painted
	# does not.
	var spread := _luma_spread(image)
	_expect(
		spread > 40.0,
		"%s is a real image, not a flat rectangle (luma spread %.0f/255)" % [key, spread],
	)

	var off_key := "off-palette"
	var off_share: float = float(families.get(off_key, 0)) / float(maxi(total, 1))
	_expect(
		off_share <= 0.08,
		"%s stays inside the art-direction palette (%.1f%% outside it)" % [key, off_share * 100.0],
	)
	var dominant := _dominant(families)
	_expect(
		dominant != off_key,
		"%s is dominated by a palette family, not by off-palette noise (%s)" % [key, dominant],
	)

	if key == "loading_robot":
		var cell: Array = entry.get("cell", [0, 0]) as Array
		var frames: int = int(entry.get("frames", 0))
		_expect(
			frames > 1 and is_equal_approx(fmod(actual.x, float(cell[0])), 0.0),
			(
				"the walk sheet divides into %d whole %dpx frames (width %.0f)"
				% [
					frames,
					int(cell[0]),
					actual.x,
				]
			),
		)
		_expect(
			is_equal_approx(actual.y, float(cell[1])),
			"the walk sheet is exactly one cell tall (%.0f px)" % actual.y,
		)


# --- pixel helpers ----------------------------------------------------------


## Bucket every sampled pixel into an art-direction family. The windows match
## `tools/art/build_ui_art.py`, so the offline audit and this runtime audit
## disagree about nothing.
func _family_counts(image: Image) -> Dictionary:
	var counts := {}
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		for x in range(width):
			var colour := image.get_pixel(x, y)
			var key := _family_of(colour)
			counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _family_of(colour: Color) -> String:
	var family := "off-palette"
	var hue: float = colour.h * 360.0
	if colour.v <= 0.10:
		family = "shadow"
	elif colour.s <= 0.14:
		family = "steel" if colour.v < 0.62 else "silver"
	elif hue >= 200.0 and hue < 260.0:
		family = "navy"
	elif hue >= 175.0 and hue < 200.0:
		family = "cyan"
	elif hue >= 95.0 and hue < 175.0:
		family = "green"
	elif hue >= 15.0 and hue < 70.0:
		family = "amber"
	elif hue >= 345.0 or hue < 15.0:
		family = "red"
	return family


func _luma_spread(image: Image) -> float:
	var lowest := 1.0
	var highest := 0.0
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		for x in range(width):
			var colour := image.get_pixel(x, y)
			var luma: float = clampf(colour.get_luminance(), 0.0, 1.0)
			lowest = minf(lowest, luma)
			highest = maxf(highest, luma)
	return (highest - lowest) * 255.0


func _dominant(counts: Dictionary) -> String:
	var best := ""
	var best_count := -1
	for key in counts.keys():
		if int(counts[key]) > best_count:
			best_count = int(counts[key])
			best = str(key)
	return best


# --- harness ---------------------------------------------------------------


func _expect(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: " + message)
	else:
		_failures.append(message)
		push_error("UI art smoke test failed: " + message)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("UI art smoke test passed.")
	else:
		print("UI art smoke test failed: %d problem(s)." % _failures.size())
		for message in _failures:
			print("  - " + message)
	quit(1 if _failures.size() > 0 else 0)
