class_name ArenaFeatureRenderer
extends Node

const ArenaVisualProfileScript = preload(
	"res://data/rooms/arena_visual_profile.gd"
)

## Rend les cases generees sans connaitre les regles de generation.
## Chaque racine est placee au centre de sa case dans le conteneur Y-sort.

var _grid_view: Node2D
var _feature_parent: Node2D
var _visual_profile: ArenaVisualProfileScript
var _feature_roots: Dictionary = {}
var _last_geometry_signature := PackedVector2Array()


func configure(
		grid_view: Node2D,
		feature_parent: Node2D,
		visual_profile: ArenaVisualProfileScript
	) -> void:
	_grid_view = grid_view
	_feature_parent = feature_parent
	_visual_profile = visual_profile
	set_process(true)


func _process(_delta: float) -> void:
	## Suit aussi les modifications de transform appliquees pendant l'execution.
	var signature := _geometry_signature()
	if _signatures_match(signature, _last_geometry_signature):
		return
	_last_geometry_signature = signature
	for cell in _feature_roots:
		_update_feature_transform(cell, _feature_roots[cell])


func render(features: Dictionary) -> void:
	if _grid_view == null or _feature_parent == null or _visual_profile == null:
		return
	for cell in features:
		_create_feature(cell, features[cell])
	_last_geometry_signature = _geometry_signature()


func _create_feature(cell: Vector2i, cell_type: GridData.CellType) -> void:
	var texture := _visual_profile.texture_for(cell_type)
	if texture == null:
		return

	var root := Node2D.new()
	root.name = "ArenaFeature_%d_%d" % [cell.x, cell.y]
	root.position = _feature_parent.to_local(
		_grid_view.to_global(_grid_view.grid_to_local(cell))
	)
	root.set_meta("grid_cell", cell)
	root.set_meta("cell_type", cell_type)
	_feature_parent.add_child(root)
	_feature_roots[cell] = root

	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.modulate = _visual_profile.modulate_for(cell_type)
	sprite.centered = false
	root.add_child(sprite)
	_update_feature_transform(cell, root)


func _update_feature_transform(cell: Vector2i, root: Node2D) -> void:
	if not is_instance_valid(root) or not _grid_view.has_method("get_cell_polygon"):
		return
	var sprite := root.get_node_or_null("Visual") as Sprite2D
	if sprite == null or sprite.texture == null:
		return

	var polygon := _cell_polygon_in_parent(cell)
	if polygon.size() < 4:
		return
	var center := _feature_parent.to_local(
		_grid_view.to_global(_grid_view.grid_to_local(cell))
	)
	root.position = center

	var source_size := Vector2(sprite.texture.get_size())
	var source_top := _visual_profile.source_top_ratio * source_size
	var source_right := _visual_profile.source_right_ratio * source_size
	var source_left := _visual_profile.source_left_ratio * source_size
	var source_transform := Transform2D(
		source_right - source_top,
		source_left - source_top,
		source_top
	)
	if is_zero_approx(source_transform.determinant()):
		return

	var target_top: Vector2 = polygon[0] - center
	var target_right: Vector2 = polygon[1] - center
	var target_left: Vector2 = polygon[3] - center
	var keep_ratio := 1.0 - _visual_profile.cell_inset_ratio
	target_top *= keep_ratio
	target_right *= keep_ratio
	target_left *= keep_ratio
	var target_transform := Transform2D(
		target_right - target_top,
		target_left - target_top,
		target_top
	)
	sprite.transform = target_transform * source_transform.affine_inverse()


func _cell_polygon_in_parent(cell: Vector2i) -> PackedVector2Array:
	var converted := PackedVector2Array()
	for point in _grid_view.get_cell_polygon(cell):
		converted.append(_feature_parent.to_local(_grid_view.to_global(point)))
	return converted


func _geometry_signature() -> PackedVector2Array:
	if _grid_view == null or _feature_parent == null \
			or not _grid_view.has_method("get_cell_polygon"):
		return PackedVector2Array()
	return _cell_polygon_in_parent(Vector2i.ZERO)


func _signatures_match(
		first: PackedVector2Array,
		second: PackedVector2Array
	) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if not first[index].is_equal_approx(second[index]):
			return false
	return true
