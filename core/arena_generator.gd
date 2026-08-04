class_name ArenaGenerator
extends RefCounted

const ArenaGenerationProfileScript = preload(
	"res://data/rooms/arena_generation_profile.gd"
)

## Generation logique pure. Cette classe ne connait ni les sprites, ni les
## scenes, ni les pixels. Elle retourne uniquement cellule -> CellType.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]


static func generate(
		grid: GridData,
		profile: ArenaGenerationProfileScript,
		protected_cells: Array[Vector2i],
		requested_seed: int = 0
	) -> Dictionary:
	var result := {
		"success": false,
		"seed": 0,
		"features": {},
	}
	if grid == null or profile == null or not profile.enabled:
		return result
	if not profile.validation_errors().is_empty():
		return result

	var generation_seed := requested_seed
	if profile.use_test_seed:
		generation_seed = profile.test_seed
	elif generation_seed == 0:
		generation_seed = int(Time.get_unix_time_from_system() * 1000.0) \
			^ Time.get_ticks_msec()
	result["seed"] = generation_seed

	var candidates := _collect_candidates(grid, profile, protected_cells)
	if candidates.is_empty() and profile.minimum_obstacle_count > 0:
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = generation_seed
	for _attempt in range(profile.maximum_generation_attempts):
		var shuffled := candidates.duplicate()
		_shuffle_with_rng(shuffled, rng)
		var requested_count := rng.randi_range(
			profile.minimum_obstacle_count,
			profile.maximum_obstacle_count
		)
		requested_count = mini(requested_count, shuffled.size())
		var features := _build_features(
			shuffled,
			requested_count,
			grid,
			profile,
			rng
		)
		if features.size() < profile.minimum_obstacle_count:
			continue
		if _is_playable(grid, features, protected_cells):
			result["success"] = true
			result["features"] = features
			return result
	return result


static func _collect_candidates(
		grid: GridData,
		profile: ArenaGenerationProfileScript,
		protected_cells: Array[Vector2i]
	) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for x in range(grid.cols):
		for y in range(grid.rows):
			var cell := Vector2i(x, y)
			if grid.get_type(cell) != GridData.CellType.NORMAL:
				continue
			if _is_near_protected(
				cell,
				protected_cells,
				profile.spawn_safety_distance
			):
				continue
			candidates.append(cell)
	return candidates


static func _is_near_protected(
		cell: Vector2i,
		protected_cells: Array[Vector2i],
		distance: int
	) -> bool:
	for protected_cell in protected_cells:
		if absi(cell.x - protected_cell.x) \
				+ absi(cell.y - protected_cell.y) <= distance:
			return true
	return false


static func _build_features(
		candidates: Array[Vector2i],
		requested_count: int,
		grid: GridData,
		profile: ArenaGenerationProfileScript,
		rng: RandomNumberGenerator
	) -> Dictionary:
	var features := {}
	var target_size := features.size() + requested_count
	var base_walkable_count := 0
	for x in range(grid.cols):
		for y in range(grid.rows):
			if GridData.PROPERTIES[grid.get_type(Vector2i(x, y))]["walkable"]:
				base_walkable_count += 1
	var blocked_limit := floori(
		float(base_walkable_count) * profile.maximum_blocked_cell_ratio
	)
	var blocked_count := 0
	for existing_type in features.values():
		if not GridData.PROPERTIES[existing_type]["walkable"]:
			blocked_count += 1

	for cell in candidates:
		if features.size() >= target_size:
			break
		if features.has(cell):
			continue
		if _is_near_existing_feature(
			cell,
			features,
			profile.minimum_feature_distance
		):
			continue
		var cell_type := _pick_type(profile, rng)
		if not GridData.PROPERTIES[cell_type]["walkable"]:
			if blocked_count >= blocked_limit:
				continue
			blocked_count += 1
		features[cell] = cell_type
	return features


static func _is_near_existing_feature(
		cell: Vector2i,
		features: Dictionary,
		minimum_distance: int
	) -> bool:
	for existing_cell in features:
		if absi(cell.x - existing_cell.x) + absi(cell.y - existing_cell.y) \
				< minimum_distance:
			return true
	return false


static func _pick_type(
		profile: ArenaGenerationProfileScript,
		rng: RandomNumberGenerator
	) -> GridData.CellType:
	var weighted_types := [
		[GridData.CellType.WALL, profile.wall_weight],
		[GridData.CellType.HOLE, profile.hole_weight],
		[GridData.CellType.LAVA, profile.lava_weight],
		[GridData.CellType.ICE, profile.ice_weight],
		[GridData.CellType.SHADOW, profile.shadow_weight],
		[GridData.CellType.RUNE, profile.rune_weight],
	]
	var roll := rng.randi_range(1, profile.total_type_weight())
	for entry in weighted_types:
		roll -= int(entry[1])
		if roll <= 0:
			return entry[0]
	return GridData.CellType.WALL


static func _is_playable(
		grid: GridData,
		features: Dictionary,
		protected_cells: Array[Vector2i]
	) -> bool:
	var anchors: Array[Vector2i] = []
	for cell in protected_cells:
		if grid.is_valid(cell) and _is_walkable_with_features(grid, features, cell):
			anchors.append(cell)
	if anchors.is_empty():
		return false

	var visited := {anchors[0]: true}
	var frontier: Array[Vector2i] = [anchors[0]]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if visited.has(neighbor):
				continue
			if not _is_walkable_with_features(grid, features, neighbor):
				continue
			visited[neighbor] = true
			frontier.append(neighbor)

	for anchor in anchors:
		if not visited.has(anchor):
			return false
		if _walkable_neighbor_count(grid, features, anchor) == 0:
			return false
	return true


static func _walkable_neighbor_count(
		grid: GridData,
		features: Dictionary,
		cell: Vector2i
	) -> int:
	var count := 0
	for direction in DIRECTIONS:
		if _is_walkable_with_features(grid, features, cell + direction):
			count += 1
	return count


static func _is_walkable_with_features(
		grid: GridData,
		features: Dictionary,
		cell: Vector2i
	) -> bool:
	if not grid.is_valid(cell):
		return false
	var cell_type: GridData.CellType = features.get(cell, grid.get_type(cell))
	return GridData.PROPERTIES[cell_type]["walkable"]


static func _shuffle_with_rng(
		values: Array[Vector2i],
		rng: RandomNumberGenerator
	) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[other]
		values[other] = temporary
