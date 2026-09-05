extends Node2D

const STYLE := preload("res://battle/painted/registered_terrain/terrain_style.gd")
var _detail_style: Dictionary = {}

# Cosmetic bank strata and contact marks, all in the terrain plan's native
# coordinates. This node owns no terrain, tactical cell, collider or obstacle.
# Preferred parent: GreekTerrainComposition (surfaces z0..3, back decor z10).
const DETAIL_SEED := 2026090507
const LAND := 0
const WATER := 1
const ANY_SURFACE := 2
const SHORE_STEP := 19.0
const MAX_SHORE_STONES := 34

var arena: ArenaDefinition
var grid_view: Node2D
var terrain_composition: Node2D
var plan: Dictionary = {}
var _land := PackedVector2Array()
var _canvas := PackedVector2Array()
var _floors: Array[Dictionary] = []
var _fills: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _shore_sections := 0
var _grass_tufts := 0
var _shore_stones := 0
var _contact_decors := 0
var _contact_texture_sizes: Dictionary = {}
var _floor_clip_operations := 0
var _configured := false

func configure(value: ArenaDefinition, view: Node2D, terrain: Node2D) -> Dictionary:
	arena = value
	grid_view = view
	terrain_composition = terrain
	_configured = false
	_fills.clear()
	_floors.clear()
	_shore_sections = 0
	_grass_tufts = 0
	_shore_stones = 0
	_contact_decors = 0
	_contact_texture_sizes.clear()
	_floor_clip_operations = 0
	if arena == null or terrain_composition == null:
		return {"ok": false, "errors": ["ground_details_require_arena_and_terrain"]}
	var raw_plan: Variant = terrain_composition.get("plan")
	if not raw_plan is Dictionary:
		return {"ok": false, "errors": ["ground_details_require_terrain_plan"]}
	plan = raw_plan
	_detail_style = plan.get("ground_details", {})
	modulate = STYLE.color(_detail_style.get("tint","#ffffff"),Color.WHITE)
	_land = _points(plan.get("land_polygon", []))
	var size := _vector(plan.get("canvas_size", []), Vector2.ZERO)
	if _land.size() < 3 or size.x <= 0.0 or size.y <= 0.0:
		return {"ok": false, "errors": ["ground_details_invalid_land_or_canvas"]}
	_canvas = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	for definition in arena.cells:
		if definition == null or not definition.defined or definition.cell_type == GridData.CellType.HOLE:
			continue
		var polygon := GridTransformService.cell_polygon(
			definition.coordinate, arena.grid_origin, arena.axis_x, arena.axis_y)
		_floors.append({"polygon": polygon, "bounds": _bounds(polygon)})
	_rng.seed = int(_detail_style.get("seed",DETAIL_SEED))
	z_index = 4
	_sync_native_transform()
	if bool(_detail_style.get("enabled",true)):
		if str(_detail_style.get("mode","all")) != "contacts_only":
			for shore: Dictionary in plan.get("shorelines", []):
				_build_shore(_points(shore.get("points", [])))
		for entry: Dictionary in plan.get("world_decor", []):
			if entry.has("texture_path"):
				_build_decor_contact(entry)
	_configured = true
	set_process(true)
	queue_redraw()
	set_meta("greek_ground_details_report", details_report())
	return details_report()

func _process(_delta: float) -> void:
	if _configured and is_instance_valid(terrain_composition):
		_sync_native_transform()

func _sync_native_transform() -> void:
	var parent := get_parent() as Node2D
	if parent == null or terrain_composition == null:
		return
	transform = parent.global_transform.affine_inverse() * terrain_composition.global_transform
	if parent == terrain_composition:
		z_as_relative = true
		z_index = 4
	else:
		# Sibling integration remains safe: keep this layer above the terrain's
		# shore lines but below its back sprites, regardless of native scaling.
		z_as_relative = false
		z_index = _effective_z(terrain_composition) + 4

func _draw() -> void:
	for entry: Dictionary in _fills:
		draw_colored_polygon(entry.polygon, entry.color)

func _build_shore(points: PackedVector2Array) -> void:
	for index in range(points.size() - 1):
		var start: Vector2 = points[index]
		var end: Vector2 = points[index + 1]
		var length := start.distance_to(end)
		if length < 1.0:
			continue
		var tangent := (end - start) / length
		var inward := Vector2(-tangent.y, tangent.x)
		var midpoint := (start + end) * 0.5
		if not Geometry2D.is_point_in_polygon(midpoint + inward * 5.0, _land):
			inward = -inward
		var divisions := maxi(1, int(ceil(length / SHORE_STEP)))
		for step in range(divisions):
			var a := start.lerp(end, float(step) / float(divisions))
			var b := start.lerp(end, float(step + 1) / float(divisions))
			var middle := (a + b) * 0.5
			var inner_a := _rng.randf_range(4.5, 9.0)
			var inner_b := _rng.randf_range(3.5, 8.0)
			var earth := Color("958453").lerp(Color("b6a572"), _rng.randf_range(0.0, 0.46))
			earth.a = 0.70
			# The authored shoreline itself never moves. Small clipped strips
			# paint its two sides; they cannot create a second land silhouette.
			_emit_polygon(PackedVector2Array([
				a, b, b + inward * inner_b, a + inward * inner_a,
			]), earth, LAND)
			_emit_polygon(PackedVector2Array([
				a, a - inward * _rng.randf_range(2.0, 4.0),
				b - inward * _rng.randf_range(1.5, 3.5), b,
			]), Color(0.16, 0.28, 0.23, 0.22), WATER)
			# A broken, fine edge catches the upper lip without a continuous
			# bright outline around the island.
			if _rng.randf() < 0.52:
				var lip_a := a.lerp(b, 0.18) + inward * 1.3
				var lip_b := a.lerp(b, _rng.randf_range(0.40, 0.78)) + inward * 1.3
				_emit_stroke(lip_a, lip_b, 0.9, Color(0.75, 0.69, 0.43, 0.38), LAND)
			if _rng.randf() < 0.43:
				var root := middle + inward * _rng.randf_range(8.0, 18.0)
				if _ground_clear(root, 13.0):
					_build_tuft(root, tangent)
			if _shore_stones < MAX_SHORE_STONES and _rng.randf() < 0.105:
				var stone := middle + inward * _rng.randf_range(3.5, 10.0)
				if _ground_clear(stone, 14.0):
					_build_stone(stone)
			if _rng.randf() < 0.105:
				var ripple := middle - inward * _rng.randf_range(11.0, 20.0)
				var half_length := _rng.randf_range(5.0, 12.0)
				_emit_stroke(ripple - tangent * half_length, ripple + tangent * half_length,
					0.85, Color(0.69, 0.83, 0.68, 0.13), WATER)
			_shore_sections += 1

func _build_tuft(root: Vector2, tangent: Vector2) -> void:
	var count := _rng.randi_range(3, 5)
	for blade in range(count):
		var base := root + tangent * _rng.randf_range(-3.5, 3.5)
		var height := _rng.randf_range(4.0, 9.0)
		var lean := _rng.randf_range(-4.5, 4.5)
		var tip := base + Vector2(lean, -height)
		var tint := Color("65713f").lerp(Color("9da557"), _rng.randf_range(0.0, 0.75))
		tint.a = 0.86
		_emit_polygon(PackedVector2Array([
			base + Vector2(-0.75, 0), tip, base + Vector2(0.75, 0),
		]), tint, LAND)
		if blade % 2 == 0:
			_emit_stroke(base, base.lerp(tip, 0.63), 0.55, Color(0.72, 0.72, 0.39, 0.45), LAND)
	_grass_tufts += 1

func _build_stone(center: Vector2) -> void:
	var radius := _rng.randf_range(3.2, 6.5)
	var height := _rng.randf_range(1.9, 3.8)
	var left := center + Vector2(-radius, 0)
	var right := center + Vector2(radius, 0)
	var bottom := center + Vector2(radius * 0.08, height)
	var rear := center + Vector2(-radius * 0.18, -height)
	_emit_polygon(PackedVector2Array([
		left + Vector2(1.5, 1.5), right + Vector2(2.7, 1.5),
		bottom + Vector2(2.2, 2.0), left + Vector2(1.8, 2.6),
	]), Color(0.21, 0.23, 0.14, 0.18), LAND)
	_emit_polygon(PackedVector2Array([left, rear, right, center + Vector2(0, 0.5)]),
		Color("b6aa7b"), LAND)
	_emit_polygon(PackedVector2Array([left, center + Vector2(0, 0.5), bottom]),
		Color("948b61"), LAND)
	_emit_polygon(PackedVector2Array([center + Vector2(0, 0.5), right, bottom]),
		Color("797955"), LAND)
	_emit_stroke(left, rear, 0.7, Color(0.40, 0.41, 0.27, 0.62), LAND)
	_emit_stroke(rear, right, 0.6, Color(0.89, 0.82, 0.57, 0.66), LAND)
	_shore_stones += 1

func _build_decor_contact(entry: Dictionary) -> void:
	if bool(entry.get("contact_disabled", false)):
		return
	var id := str(entry.get("id", ""))
	# Authored profiles are normalized within the atlas region or full texture,
	# using exactly the sprite's pivot, scale, rotation and native anchor.
	var profiles: Array[PackedVector2Array] = []
	var authored: Variant = entry.get("contact_profiles", entry.get("contact_profiles_uv", null))
	if authored is Array:
		for value: Variant in authored:
			if value is Array:
				var profile := _points(value)
				if profile.size() >= 2:
					profiles.append(profile)
	elif entry.has("contact_profiles") or entry.has("contact_profiles_uv"):
		return
	else:
		match id:
			"rock_mass_rear_right":
				profiles.append(PackedVector2Array([
					Vector2(0.09, 0.915), Vector2(0.235, 0.937), Vector2(0.43, 0.957),
					Vector2(0.62, 0.944), Vector2(0.78, 0.921), Vector2(0.93, 0.883),
				]))
			"tree_foreground_left":
				profiles.append(PackedVector2Array([
					Vector2(0.28, 0.923), Vector2(0.383, 0.958), Vector2(0.48, 0.970),
					Vector2(0.59, 0.946), Vector2(0.687, 0.913),
				]))
			"trees_upper_left":
				profiles.append(PackedVector2Array([Vector2(0.12, 0.864), Vector2(0.24, 0.886), Vector2(0.31, 0.871)]))
				profiles.append(PackedVector2Array([Vector2(0.37, 0.880), Vector2(0.47, 0.907), Vector2(0.59, 0.889)]))
				profiles.append(PackedVector2Array([Vector2(0.69, 0.884), Vector2(0.80, 0.894), Vector2(0.90, 0.856)]))
			"rock_mass_foreground_right":
				profiles.append(PackedVector2Array([
					Vector2(0.07, 0.831), Vector2(0.225, 0.874), Vector2(0.375, 0.865),
					Vector2(0.57, 0.887), Vector2(0.74, 0.846), Vector2(0.90, 0.811),
				]))
			_:
				return
	if profiles.is_empty() or _decor_region_size(entry).is_zero_approx():
		return
	for profile: PackedVector2Array in profiles:
		for index in range(profile.size() - 1):
			var a := _decor_native_point(entry, profile[index])
			var b := _decor_native_point(entry, profile[index + 1])
			var depth := _rng.randf_range(2.2, 4.2)
			var offset := Vector2(1.8, depth)
			# Thin irregular ribbons only, following the rock/root feet.
			# The foreground rock may touch water: this is a contact shadow,
			# never a new land patch. All tactical polygons are subtracted.
			_emit_polygon(PackedVector2Array([a, b, b + offset * 1.5, a + offset]),
				STYLE.color(_detail_style.get("contact_outer",Color(0.18,0.22,0.14,0.105)),Color(0.18,0.22,0.14,0.105)), ANY_SURFACE)
			_emit_polygon(PackedVector2Array([a, b, b + offset * 0.57, a + offset * 0.5]),
				STYLE.color(_detail_style.get("contact_inner",Color(0.16,0.20,0.12,0.21)),Color(0.16,0.20,0.12,0.21)), ANY_SURFACE)
	_contact_decors += 1

func _decor_native_point(entry: Dictionary, fraction: Vector2) -> Vector2:
	var size := _decor_region_size(entry)
	var pivot := _vector(entry.get("pivot", [0.5, 1]), Vector2(0.5, 1))
	var scale_value := _vector(entry.get("scale", 1.0), Vector2.ONE)
	var point := (fraction - pivot) * size * scale_value
	point = point.rotated(deg_to_rad(float(entry.get("rotation_degrees", 0.0))))
	var anchor := _vector(entry.get("anchor", [0, 0]), Vector2.ZERO)
	if entry.has("anchor_grid") and arena != null:
		var cell := _vector(entry.anchor_grid, Vector2.ZERO)
		anchor = arena.grid_origin + cell.x * arena.axis_x + cell.y * arena.axis_y
	return anchor + point

func _decor_region_size(entry: Dictionary) -> Vector2:
	var region: Variant = entry.get("region_px", [])
	if region is Array and region.size() == 4:
		return Vector2(float(region[2]), float(region[3]))
	var path := str(entry.get("texture_path", ""))
	if _contact_texture_sizes.has(path):
		var cached_size: Vector2 = _contact_texture_sizes[path]
		return cached_size
	var size := Vector2.ZERO
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			size = texture.get_size()
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			size = Vector2(image.get_size())
	_contact_texture_sizes[path] = size
	return size

func _ground_clear(point: Vector2, clearance: float) -> bool:
	if not Geometry2D.is_point_in_polygon(point, _land):
		return false
	for floor_entry: Dictionary in _floors:
		var rect: Rect2 = floor_entry.bounds
		if not rect.grow(clearance).has_point(point):
			continue
		var polygon: PackedVector2Array = floor_entry.polygon
		if Geometry2D.is_point_in_polygon(point, polygon):
			return false
		for index in range(polygon.size()):
			var closest := Geometry2D.get_closest_point_to_segment(
				point, polygon[index], polygon[(index + 1) % polygon.size()])
			if point.distance_to(closest) < clearance:
				return false
	return true

func _emit_stroke(a: Vector2, b: Vector2, width: float, tint: Color, surface: int) -> void:
	if a.distance_squared_to(b) < 0.01:
		return
	var perpendicular := Vector2(-(b - a).y, (b - a).x).normalized() * width * 0.5
	_emit_polygon(PackedVector2Array([a + perpendicular, b + perpendicular, b - perpendicular, a - perpendicular]), tint, surface)

func _emit_polygon(polygon: PackedVector2Array, tint: Color, surface: int) -> void:
	if polygon.size() < 3:
		return
	var pieces: Array[PackedVector2Array] = []
	if surface == LAND:
		pieces = Geometry2D.intersect_polygons(polygon, _land)
	elif surface == WATER:
		pieces = Geometry2D.clip_polygons(polygon, _land)
	else:
		pieces = Geometry2D.intersect_polygons(polygon, _canvas)
	for floor_entry: Dictionary in _floors:
		var next: Array[PackedVector2Array] = []
		var floor_bounds: Rect2 = floor_entry.bounds
		var floor_polygon: PackedVector2Array = floor_entry.polygon
		for piece: PackedVector2Array in pieces:
			if not _bounds(piece).intersects(floor_bounds):
				next.append(piece)
				continue
			next.append_array(Geometry2D.clip_polygons(piece, floor_polygon))
			_floor_clip_operations += 1
		pieces = next
		if pieces.is_empty():
			return
	for piece: PackedVector2Array in pieces:
		if piece.size() >= 3 and absf(_area(piece)) > 0.02:
			_fills.append({"polygon": piece, "color": tint})

func details_report() -> Dictionary:
	return {
		"ok": _configured,
		"seed": _rng.seed,
		"mode": str(_detail_style.get("mode","all")),
		"shore_sections": _shore_sections,
		"grass_tufts": _grass_tufts,
		"shore_stones": _shore_stones,
		"decor_contacts": _contact_decors,
		"rendered_pieces": _fills.size(),
		"floor_polygons_subtracted": _floors.size(),
		"floor_clip_operations": _floor_clip_operations,
		"authority": "Fixed terrain_plan shorelines; decorative polygons clipped to land/water and subtracted from all live FLOOR polygons.",
		"changes_floor_or_collision": false,
	}

static func _points(value: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Variant in value:
		result.append(_vector(point, Vector2.ZERO))
	return result

static func _vector(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is int or value is float:
		return Vector2.ONE * float(value)
	return fallback

static func _bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var result := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		result = result.expand(point)
	return result

static func _area(polygon: PackedVector2Array) -> float:
	var result := 0.0
	for index in range(polygon.size()):
		result += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return result * 0.5

static func _effective_z(item: CanvasItem) -> int:
	var result := item.z_index
	var current := item
	while current.z_as_relative:
		current = current.get_parent() as CanvasItem
		if current == null:
			break
		result += current.z_index
	return result
