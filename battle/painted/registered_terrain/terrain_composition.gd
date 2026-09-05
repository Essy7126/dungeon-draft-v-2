extends Node2D

const STYLE := preload("res://battle/painted/registered_terrain/terrain_style.gd")

# Native image coordinates are shared with the grid. Geometry belongs to the
# plan; textures only shade that geometry and never define playable boundaries.
const CHROMA_SHADER := preload("res://battle/painted/registered_terrain/shaders/decor_chroma_key.gdshader")
var plan: Dictionary = {}
var grid_view: Node2D
var visual_data: PaintedMapVisualData
var y_sorted_world: Node2D
var _land_polygon := PackedVector2Array()
var _allowed_floor_polygon := PackedVector2Array()
var _excluded_floor_polygons: Array[PackedVector2Array] = []
var _external_decor: Array[Dictionary] = []
var _errors: Array[String] = []
var _texture_cache: Dictionary = {}
var _configured := false

func configure_from_file(path: String, view: Node2D, world: Node2D) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["terrain_plan_missing:%s" % path]}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {"ok": false, "errors": ["terrain_plan_json_invalid"]}
	return configure(parsed, view, world)

func configure(value: Dictionary, view: Node2D, world: Node2D) -> Dictionary:
	_clear_created_nodes()
	plan = value.duplicate(true)
	grid_view = view
	y_sorted_world = world
	visual_data = view.get("visual_data") as PaintedMapVisualData if view != null else null
	_errors.clear()
	if visual_data == null or get_parent() == null:
		return {"ok": false, "errors": ["terrain_requires_grid_view_and_scene_parent"]}
	var canvas_size := _vector(plan.get("canvas_size", []), Vector2.ZERO)
	_land_polygon = _points(plan.get("land_polygon", []))
	_allowed_floor_polygon = _points(plan.get("allowed_floor_polygon", plan.get("land_polygon", [])))
	_excluded_floor_polygons.clear()
	for excluded: Variant in plan.get("excluded_floor_polygons", []):
		var polygon: Array = excluded.get("polygon", excluded.get("points", [])) if excluded is Dictionary else excluded
		_excluded_floor_polygons.append(_points(polygon))
	if int(plan.get("version", 1)) != 1 or canvas_size.x <= 0 or canvas_size.y <= 0 or _land_polygon.size() < 3:
		return {"ok": false, "errors": ["terrain_plan_version_canvas_or_polygon_invalid"]}
	if Vector2(visual_data.source_image_size) != canvas_size:
		_errors.append("terrain_canvas_differs_from_arena_source_image_size")
	z_index = -80
	_sync_native_transform()
	_add_surface("Water", PackedVector2Array([Vector2.ZERO, Vector2(canvas_size.x,0), canvas_size, Vector2(0,canvas_size.y)]), plan.get("water", {}), Color("288e98"), 0)
	_add_surface("Land", _land_polygon, plan.get("land", {}), Color("87925c"), 1)
	var soil_index := 0
	for patch: Dictionary in plan.get("soil_patches", []):
		_add_surface("Soil_%d" % soil_index, _points(patch.get("polygon", [])), patch, Color("b7a675"), 2)
		soil_index += 1
	var shore_index := 0
	for shore: Dictionary in plan.get("shorelines", []):
		var points := _points(shore.get("points", []))
		if points.size() < 2:
			_errors.append("shoreline_needs_two_points:%d" % shore_index)
			continue
		if bool(shore.get("closed", false)) and not points[0].is_equal_approx(points[points.size()-1]):
			points.append(points[0])
		var line := Line2D.new()
		line.name = "Shore_%d" % shore_index
		line.points = points
		line.width = maxf(0.1, float(shore.get("width", 12.0)))
		line.default_color = _color(shore.get("color", "#b6b48a"), Color("b6b48a"))
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		line.z_index = 3
		var texture := _load_texture(str(shore.get("texture_path", "")))
		if texture != null:
			line.texture = texture
			line.texture_mode = Line2D.LINE_TEXTURE_TILE
			line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		add_child(line)
		shore_index += 1
	for entry: Dictionary in plan.get("world_decor", []):
		_add_world_decor(entry)
	_configured = _errors.is_empty()
	set_process(_configured)
	return composition_report()

func _add_surface(label: String, polygon: PackedVector2Array, style: Dictionary, fallback: Color, layer: int) -> void:
	if polygon.size() < 3:
		_errors.append("surface_needs_polygon:%s" % label)
		return
	var node := Polygon2D.new()
	node.name = label
	node.polygon = polygon
	node.z_index = layer
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture := _load_texture(str(style.get("texture_path", "")))
	if texture == null:
		node.color = _color(style.get("color", ""), fallback)
	else:
		node.texture = texture
		# A native-canvas painting keeps the same UV coordinates as tiled land.
		# Only sampling changes; the authored polygon remains authoritative.
		node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED if bool(style.get("texture_repeat", true)) else CanvasItem.TEXTURE_REPEAT_DISABLED
		node.color = _color(style.get("tint", "#ffffff"), Color.WHITE)
		var texture_scale := _vector(style.get("texture_scale", [1,1]), Vector2.ONE)
		texture_scale = Vector2(maxf(absf(texture_scale.x),0.001),maxf(absf(texture_scale.y),0.001))
		var uv := PackedVector2Array()
		for point: Vector2 in polygon:
			uv.append(point / texture_scale)
		node.uv = uv
	var shader_path := str(style.get("shader_path", ""))
	if not shader_path.is_empty():
		var shader := load(shader_path) as Shader if ResourceLoader.exists(shader_path) else null
		if shader == null:
			_errors.append("terrain_shader_missing:%s" % shader_path)
		else:
			var material := ShaderMaterial.new()
			material.shader = shader
			STYLE.apply_shader_parameters(material,style.get("shader_parameters",{}))
			node.material = material
	add_child(node)

func _add_world_decor(entry: Dictionary) -> void:
	if entry.has("scene_path"):
		_add_scene_decor(entry)
		return
	var texture := _load_texture(str(entry.get("texture_path", "")))
	if texture == null:
		_errors.append("decor_texture_missing:%s" % entry.get("id", "unnamed"))
		return
	var sprite := Sprite2D.new()
	sprite.name = "WorldDecor_%s" % str(entry.get("id", "unnamed"))
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var region := Rect2(Vector2.ZERO, texture.get_size())
	var region_value: Variant = entry.get("region_px", [])
	if region_value is Array and region_value.size() == 4:
		region = Rect2(float(region_value[0]), float(region_value[1]), float(region_value[2]), float(region_value[3]))
		if region.size.x <= 0 or region.size.y <= 0 or not Rect2(Vector2.ZERO, texture.get_size()).encloses(region):
			_errors.append("decor_region_outside_atlas:%s" % sprite.name)
			sprite.free()
			return
		sprite.region_enabled = true
		sprite.region_rect = region
		sprite.region_filter_clip_enabled = true
	var pivot := _vector(entry.get("pivot", [0.5,1.0]), Vector2(0.5,1))
	sprite.offset = -region.size * pivot
	sprite.modulate = _color(entry.get("tint", "#ffffff"), Color.WHITE)
	var layer := str(entry.get("layer", "y_sorted"))
	var parent: Node2D = y_sorted_world if layer == "y_sorted" else self
	if parent == null:
		_errors.append("decor_y_sorted_world_missing")
		sprite.free()
		return
	sprite.z_index = 0 if layer == "y_sorted" else (100 if layer == "foreground" else 10)
	parent.add_child(sprite)
	_apply_decor_transform(sprite, entry)
	sprite.set_meta("terrain_decor_id", str(entry.get("id", "unnamed")))
	sprite.set_meta("native_anchor", _vector(entry.get("anchor", [0,0]), Vector2.ZERO))
	sprite.set_meta("native_region", region)
	if entry.has("chroma_key"):
		var image := texture.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			var region_image := image.get_region(Rect2i(region))
			if region_image.detect_alpha() == Image.ALPHA_NONE:
				var key: Dictionary = entry.chroma_key
				var material := ShaderMaterial.new()
				material.shader = CHROMA_SHADER
				material.set_shader_parameter("key_color", _color(key.get("color", "#ff00ff"), Color.MAGENTA))
				material.set_shader_parameter("threshold", float(key.get("threshold", 0.10)))
				material.set_shader_parameter("softness", float(key.get("softness", 0.05)))
				material.set_shader_parameter("magenta_despill", clampf(float(key.get("magenta_despill", 0.0)), 0.0, 1.0))
				sprite.material = material
				sprite.set_meta("chroma_key_applied", true)
			else:
				sprite.set_meta("chroma_key_skipped_native_alpha", true)
	_external_decor.append({"sprite": sprite, "entry": entry.duplicate(true)})

func _process(_delta: float) -> void:
	if not _configured or not is_instance_valid(grid_view):
		return
	_sync_native_transform()
	for value: Dictionary in _external_decor:
		var sprite := value.sprite as Node2D
		if is_instance_valid(sprite):
			_apply_decor_transform(sprite, value.entry)

func _sync_native_transform() -> void:
	var parent := get_parent() as Node2D
	if parent == null or grid_view == null or visual_data == null:
		return
	var native_to_display := Transform2D(Vector2(visual_data.image_scale.x,0), Vector2(0,visual_data.image_scale.y), visual_data.image_offset)
	transform = parent.global_transform.affine_inverse() * grid_view.global_transform * native_to_display

func _apply_decor_transform(sprite: Node2D, entry: Dictionary) -> void:
	var parent := sprite.get_parent() as Node2D
	var anchor := _resolve_anchor(entry)
	var scale_value := _vector(entry.get("scale", [1,1]), Vector2.ONE)
	var angle := deg_to_rad(float(entry.get("rotation_degrees", 0.0)))
	var local := Transform2D(Vector2(cos(angle),sin(angle))*scale_value.x, Vector2(-sin(angle),cos(angle))*scale_value.y, anchor)
	var next_transform := parent.global_transform.affine_inverse() * global_transform * local
	var geometry_signature := str([next_transform, visual_data.axis_x, visual_data.axis_y])
	if str(sprite.get_meta("terrain_geometry_signature", "")) == geometry_signature:
		return
	sprite.transform = next_transform
	sprite.set_meta("terrain_geometry_signature", geometry_signature)
	if sprite.has_method("configure_footprint"):
		var footprint := PackedVector2Array()
		for corner: Vector2 in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
			footprint.append(sprite.to_local(to_global(anchor + corner.x * visual_data.axis_x + corner.y * visual_data.axis_y)))
		sprite.configure_footprint(footprint)

func validate_floor_registration(arena: ArenaDefinition) -> Dictionary:
	var errors: Array[String] = []
	var tested := 0
	var outside_area := 0.0
	var excluded_area := 0.0
	var min_margin := INF
	for definition in arena.cells:
		if definition == null or not definition.defined or definition.cell_type == GridData.CellType.HOLE:
			continue
		var polygon := GridTransformService.cell_polygon(definition.coordinate, arena.grid_origin, arena.axis_x, arena.axis_y)
		tested += 1
		for piece: PackedVector2Array in Geometry2D.clip_polygons(polygon, _allowed_floor_polygon):
			outside_area += absf(_signed_area(piece))
		for excluded: PackedVector2Array in _excluded_floor_polygons:
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(polygon, excluded):
				excluded_area += absf(_signed_area(piece))
		min_margin = minf(min_margin, _polygon_distance(polygon, _allowed_floor_polygon))
	if outside_area > 0.05:
		errors.append("tactical_floor_outside_allowed_land:%.3fpx2" % outside_area)
	if excluded_area > 0.05:
		errors.append("tactical_floor_intersects_excluded_decor:%.3fpx2" % excluded_area)
	var required_margin := float(plan.get("minimum_floor_margin_px", 0.0))
	if min_margin + 0.05 < required_margin:
		errors.append("tactical_floor_margin_%.3f_below_required_%.3f" % [min_margin,required_margin])
	return {"ok": errors.is_empty(), "errors": errors, "floor_polygons_tested": tested, "outside_allowed_land_area_px2": outside_area, "excluded_decor_overlap_area_px2": excluded_area, "minimum_native_margin_px": min_margin, "required_native_margin_px": required_margin}

func composition_report() -> Dictionary:
	return {"ok": _errors.is_empty(), "errors": _errors.duplicate(), "source": "explicit terrain_plan native geometry", "canvas_size": plan.get("canvas_size", []), "land_vertices": _land_polygon.size(), "soil_layers": plan.get("soil_patches", []).size(), "shoreline_layers": plan.get("shorelines", []).size(), "world_decor_nodes": _external_decor.size(), "native_transform": str(transform)}

func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	if texture == null:
		_errors.append("terrain_texture_missing:%s" % path)
	else:
		_texture_cache[path] = texture
	return texture

func _clear_created_nodes() -> void:
	_configured = false
	for value: Dictionary in _external_decor:
		var sprite := value.sprite as Node2D
		if is_instance_valid(sprite) and sprite.get_parent() != self:
			sprite.free()
	_external_decor.clear()
	for child in get_children():
		child.free()

func _exit_tree() -> void:
	for value: Dictionary in _external_decor:
		var sprite := value.sprite as Node2D
		if is_instance_valid(sprite) and sprite.get_parent() != self:
			sprite.queue_free()

static func _points(value: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for entry: Variant in value:
		points.append(_vector(entry, Vector2.ZERO))
	return points

static func _vector(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]),float(value[1]))
	if value is int or value is float:
		return Vector2.ONE * float(value)
	return fallback

static func _color(value: Variant, fallback: Color) -> Color:
	return STYLE.color(value, fallback)

static func _signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		area += polygon[index].cross(polygon[(index+1)%polygon.size()])
	return area * 0.5

static func _polygon_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var distance := INF
	for i in range(a.size()):
		for j in range(b.size()):
			distance = minf(distance, a[i].distance_to(Geometry2D.get_closest_point_to_segment(a[i],b[j],b[(j+1)%b.size()])))
			distance = minf(distance, b[j].distance_to(Geometry2D.get_closest_point_to_segment(b[j],a[i],a[(i+1)%a.size()])))
	return distance

func _resolve_anchor(entry: Dictionary) -> Vector2:
	if entry.has("anchor_grid"):
		var cell := _vector(entry.anchor_grid, Vector2.ZERO)
		return visual_data.grid_origin + cell.x * visual_data.axis_x + cell.y * visual_data.axis_y
	return _vector(entry.get("anchor", [0,0]), Vector2.ZERO)

func _add_scene_decor(entry: Dictionary) -> void:
	var path := str(entry.get("scene_path", ""))
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed == null:
		_errors.append("terrain_decor_scene_missing:%s" % path)
		return
	var node := packed.instantiate() as Node2D
	if node == null:
		_errors.append("terrain_decor_scene_requires_node2d:%s" % path)
		return
	node.name = "WorldDecor_%s" % str(entry.get("id", "unnamed"))
	var layer := str(entry.get("layer", "y_sorted"))
	var parent: Node2D = y_sorted_world if layer == "y_sorted" else self
	if parent == null:
		_errors.append("terrain_decor_scene_parent_missing")
		node.free()
		return
	node.z_index = 0 if layer == "y_sorted" else (100 if layer == "foreground" else 10)
	parent.add_child(node)
	if node.has_method("configure_palette"):
		node.configure_palette(entry.get("props_palette",plan.get("props_palette",{})))
	_apply_decor_transform(node, entry)
	node.set_meta("terrain_decor_id", str(entry.get("id", "unnamed")))
	node.set_meta("native_anchor", _resolve_anchor(entry))
	node.set_meta("peripheral_prop_without_gameplay_blocker", true)
	_external_decor.append({"sprite": node, "entry": entry.duplicate(true)})

func set_world_decor_visible(value: bool) -> void:
	for entry: Dictionary in _external_decor:
		var node := entry.sprite as Node2D
		if is_instance_valid(node):
			node.visible = value
