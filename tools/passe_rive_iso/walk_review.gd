extends Node2D

## Isolated WALK inspection. No campaign state, spells or idle are loaded.
const ROOT := "res://artifacts/spine_trial/passe_rive_walk_iso_v1/"
const DIRECTIONS := ["E", "S", "N", "W"]
const STEPS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]
const ART_SCALE := 0.35
const PIVOT := Vector2(384, 662)
var visual: PaintedMapVisualData
var grid: GridData
var finder: Pathfinder
var data: Dictionary
var textures: Dictionary = { }
var cell := Vector2i(6, 7)
var actor_position := Vector2.ZERO
var direction := "E"
var phase := 0.0
var rate := 1.0
var paused := false
var route: Array = []
var sprite: Sprite2D
var label: Label
var show_grid := true
var completed_cells := 0


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1376, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	visual = load("res://data/maps/painted/room_01_forest_visual.tres")
	var layout: RoomGridLayout = load("res://data/maps/painted/room_01_forest_layout.tres")
	grid = GridData.new(layout.logical_size.x, layout.logical_size.y)
	layout.apply_to_grid(grid)
	finder = Pathfinder.new(grid)
	data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "walk_review.json"))
	for d: String in DIRECTIONS:
		textures[d] = []
		for file: String in data.views[d].frames:
			var image := Image.load_from_file(ProjectSettings.globalize_path(ROOT + file))
			assert(image != null and not image.is_empty(), "Missing walk image: " + file)
			textures[d].append(ImageTexture.create_from_image(image))
	var background := Sprite2D.new()
	background.texture = visual.load_background_texture()
	background.centered = false
	background.z_index = -10
	add_child(background)
	var world := Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = -PIVOT
	sprite.scale = Vector2.ONE * ART_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	world.add_child(sprite)
	var occluder := visual.create_foreground_occluder(background.texture)
	if occluder != null:
		world.add_child(occluder)
	actor_position = visual.cell_to_display(cell)
	_build_controls()
	refresh()


func _build_controls() -> void:
	var panel := ColorRect.new()
	panel.color = Color("172622")
	panel.position = Vector2(0, 770)
	panel.size = Vector2(1376, 130)
	add_child(panel)
	label = Label.new()
	label.position = Vector2(24, 778)
	add_child(label)
	var row := HBoxContainer.new()
	row.position = Vector2(24, 817)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for i in DIRECTIONS.size():
		var button := Button.new()
		button.text = ["Bas droite", "Bas gauche", "Haut droite", "Haut gauche"][i]
		button.pressed.connect(request_step.bind(STEPS[i]))
		row.add_child(button)
	var pause_button := Button.new()
	pause_button.text = "Pause / reprise"
	pause_button.pressed.connect(
		func():
			paused = not paused,
	)
	row.add_child(pause_button)
	var slow_button := Button.new()
	slow_button.text = "Normal / ralenti"
	slow_button.pressed.connect(
		func():
			rate = 0.25 if rate == 1.0 else 1.0,
	)
	row.add_child(slow_button)
	var help := Label.new()
	help.position = Vector2(24, 861)
	help.text = "Cliquer une case pour marcher · Flèches : un pas · Espace : pause · Marche seule, contrôle en cours."
	add_child(help)


func request_step(delta: Vector2i) -> void:
	if route.is_empty():
		request_path(cell + delta)


func request_path(target: Vector2i) -> bool:
	if not route.is_empty():
		return false
	var result := finder.find_path(cell, target)
	if result.size() < 2:
		return false
	route = result.slice(1)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		request_path(visual.display_to_cell(get_global_mouse_position()))
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT:
				request_step(Vector2i.RIGHT)
			KEY_LEFT:
				request_step(Vector2i.LEFT)
			KEY_DOWN:
				request_step(Vector2i.DOWN)
			KEY_UP:
				request_step(Vector2i.UP)
			KEY_SPACE:
				paused = not paused


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if paused:
		return
	var remaining := delta * rate
	while remaining > 0.000001 and not route.is_empty():
		var target: Vector2i = route[0]
		direction = DIRECTIONS[STEPS.find(target - cell)]
		var stride: Array = data.views[direction].stride
		var cycle_distance := Vector2(stride[0], stride[1]).length() * ART_SCALE
		var speed := cycle_distance / 1.2
		var destination := visual.cell_to_display(target)
		var distance := actor_position.distance_to(destination)
		var used := minf(remaining, distance / speed)
		actor_position = actor_position.move_toward(destination, used * speed)
		phase = fposmod(phase + used / 1.2, 1.0)
		remaining -= used
		if actor_position.distance_to(destination) < 0.0001:
			cell = target
			route.pop_front()
			completed_cells += 1
	refresh()


func refresh() -> void:
	sprite.texture = textures[direction][mini(11, floori(phase * 12.0))]
	sprite.position = actor_position
	label.text = "PASSE-RIVE — MARCHE EN CONTRÔLE    %s · image %02d/12    Distance provisoire, appuis à mesurer" % [
		direction,
		floori(phase * 12.0) + 1,
	]
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	if show_grid:
		for y in grid.rows:
			for x in grid.cols:
				var pos := Vector2i(x, y)
				if grid.is_walkable(pos):
					var polygon := visual.cell_polygon_display(pos)
					polygon.append(polygon[0])
					draw_polyline(polygon, Color(0.8, 0.9, 0.7, 0.22), 1.0)
	for next: Vector2i in route:
		draw_circle(visual.cell_to_display(next), 4, Color("dbba78"))
	draw_circle(actor_position, 4, Color("dcab73"))
