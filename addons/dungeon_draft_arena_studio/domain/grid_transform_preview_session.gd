@tool
class_name GridTransformPreviewSession
extends RefCounted

## Transaction éphémère d'un geste de calibration. Cette classe ne possède
## volontairement aucune référence vers ArenaDefinition : une preview ne peut
## donc pas muter la source canonique ni déclencher une projection runtime.

var base_snapshot: GridTransformSnapshot = null
var preview_snapshot: GridTransformSnapshot = null
var base_anchor_cells: Array[Vector2i] = []
var base_anchor_pixels: Array[Vector2] = []
var preview_anchor_cells: Array[Vector2i] = []
var preview_anchor_pixels: Array[Vector2] = []
var active_handle := -1
var latest_pointer_position := Vector2.ZERO
var dirty := false
var pointer_pending := false
var pointer_events_received := 0
var previews_applied := 0


func begin(arena: ArenaDefinition, handle: int) -> bool:
	if arena == null:
		return false
	base_snapshot = GridTransformSnapshot.from_arena(arena)
	preview_snapshot = base_snapshot.copy()
	base_anchor_cells.assign(arena.calibration_cells)
	base_anchor_pixels.assign(arena.calibration_pixels)
	preview_anchor_cells.assign(base_anchor_cells)
	preview_anchor_pixels.assign(base_anchor_pixels)
	active_handle = handle
	dirty = false
	pointer_pending = false
	pointer_events_received = 0
	previews_applied = 0
	return true


func set_transform(candidate: GridTransformSnapshot) -> bool:
	if candidate == null or base_snapshot == null:
		return false
	preview_snapshot = candidate.copy()
	dirty = not preview_snapshot.is_equal_to(base_snapshot) \
		or preview_anchor_cells != base_anchor_cells \
		or preview_anchor_pixels != base_anchor_pixels
	previews_applied += 1
	return true


func set_anchors(cells: Array[Vector2i], pixels: Array[Vector2]) -> bool:
	if base_snapshot == null or cells.size() != pixels.size():
		return false
	preview_anchor_cells.assign(cells)
	preview_anchor_pixels.assign(pixels)
	dirty = not preview_snapshot.is_equal_to(base_snapshot) \
		or preview_anchor_cells != base_anchor_cells \
		or preview_anchor_pixels != base_anchor_pixels
	previews_applied += 1
	return true


func queue_pointer(position: Vector2) -> void:
	latest_pointer_position = position
	pointer_pending = true
	pointer_events_received += 1


func consume_pointer() -> Vector2:
	pointer_pending = false
	return latest_pointer_position


func transform() -> GridTransformSnapshot:
	return preview_snapshot.copy() if preview_snapshot != null else null


func anchor_cells() -> Array[Vector2i]:
	return preview_anchor_cells.duplicate()


func anchor_pixels() -> Array[Vector2]:
	return preview_anchor_pixels.duplicate()


func metrics() -> Dictionary:
	return {
		"pointer_events_received": pointer_events_received,
		"previews_applied": previews_applied,
		"coalesced_events": maxi(0, pointer_events_received - previews_applied),
		"dirty": dirty,
	}
