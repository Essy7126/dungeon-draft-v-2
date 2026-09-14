extends Node2D

## Playable on the game's real painted map, grid, obstacles and pathfinder.
const ACTOR := preload("res://characters/achilles/2d/veilleur_walk_player.gd")
const DIRECTIONS := ["E", "S", "N", "W"]
const STEPS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]
@export_file(
	"*.json"
) var manifest_path := "res://assets/characters/Achilles/veilleur_walk_iso_v1/manifest.json"
@export var review_title := "Veilleur — marche, quatre directions"
var visual: PaintedMapVisualData
var grid: GridData
var finder: Pathfinder
var actor: Node2D
var world: Node2D
var cell := Vector2i(6, 7)
var actor_position := Vector2.ZERO
var direction := "E"
var phase := 0.0
var rate := 1.0
var paused := false
var route: Array = []
var label: Label
var show_grid := true
var completed_cells := 0
var demo := false
var demo_index := 0


func _ready() -> void:
	get_window().title = review_title
	get_window().content_scale_size = Vector2i(1376, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	visual = load("res://data/maps/painted/room_01_forest_visual.tres")
	var layout: RoomGridLayout = load("res://data/maps/painted/room_01_forest_layout.tres")
	grid = GridData.new(layout.logical_size.x, layout.logical_size.y)
	layout.apply_to_grid(grid)
	finder = Pathfinder.new(grid)
	var background := Sprite2D.new()
	background.texture = visual.load_background_texture()
	background.centered = false
	background.z_index = -10
	add_child(background)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	actor = Node2D.new()
	actor.set_script(ACTOR)
	actor.manifest_path = manifest_path
	world.add_child(actor)
	var occluder := visual.create_foreground_occluder(background.texture)
	if occluder != null:
		world.add_child(occluder)
	actor_position = visual.cell_to_display(cell)
	_build_controls()
	refresh()


func _build_controls() -> void:
	var panel := ColorRect.new()
	panel.color = Color("172622")
	panel.position = Vector2(0, 768)
	panel.size = Vector2(1376, 132)
	add_child(panel)
	label = Label.new()
	label.position = Vector2(24, 779)
	label.add_theme_font_size_override("font_size", 20)
	add_child(label)
	var row := HBoxContainer.new()
	row.position = Vector2(24, 817)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for i in DIRECTIONS.size():
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.text = ["↘ Bas droite", "↙ Bas gauche", "↗ Haut droite", "↖ Haut gauche"][i]
		button.pressed.connect(request_step.bind(STEPS[i]))
		row.add_child(button)
	var tour := Button.new()
	tour.focus_mode = Control.FOCUS_NONE
	tour.text = "Tour des 4 vues"
	tour.pressed.connect(
		func():
			demo = not demo,
	)
	row.add_child(tour)
	var pause_button := Button.new()
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.text = "Pause"
	pause_button.pressed.connect(
		func():
			paused = not paused,
	)
	row.add_child(pause_button)
	var speed := OptionButton.new()
	for text: String in ["Ralenti ×¼", "Normal", "Rapide ×2"]:
		speed.add_item(text)
	speed.select(1)
	speed.item_selected.connect(
		func(index: int):
			rate = [0.25, 1.0, 2.0][index],
	)
	row.add_child(speed)
	var grid_button := Button.new()
	grid_button.focus_mode = Control.FOCUS_NONE
	grid_button.text = "Grille"
	grid_button.pressed.connect(
		func():
			show_grid = not show_grid
			queue_redraw(),
	)
	row.add_child(grid_button)
	var help := Label.new()
	help.position = Vector2(24, 861)
	help.text = "Cliquer une case pour marcher · Flèches : un pas · Espace : pause · Marche seule : repos et virages animés à travailler."
	add_child(help)


func request_step(delta: Vector2i) -> void:
	demo = false
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
		demo = false
		request_path(visual.display_to_cell(get_global_mouse_position()))
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT:
				request_step(Vector2i.RIGHT)
			KEY_DOWN:
				request_step(Vector2i.DOWN)
			KEY_UP:
				request_step(Vector2i.UP)
			KEY_LEFT:
				request_step(Vector2i.LEFT)
			KEY_SPACE:
				paused = not paused


func _process(delta: float) -> void:
	if demo and route.is_empty() and not paused:
		# Cardinal cycle closes geometrically; validate each leg against obstacles.
		var step: Vector2i = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][demo_index]
		if request_path(cell + step):
			demo_index = (demo_index + 1) % 4
		else:
			demo = false
	advance(delta)


func advance(delta: float) -> void:
	if paused:
		return
	var remaining := delta * rate
	while remaining > 0.000001 and not route.is_empty():
		var target: Vector2i = route[0]
		direction = DIRECTIONS[STEPS.find(target - cell)]
		var cycle_distance: float = actor.cycle_distance(direction)
		var duration: float = actor.data.duration
		var speed := cycle_distance / duration
		var destination := visual.cell_to_display(target)
		var distance := actor_position.distance_to(destination)
		var used := minf(remaining, distance / speed)
		actor_position = actor_position.move_toward(destination, used * speed)
		phase = fposmod(phase + used / duration, 1.0)
		remaining -= used
		if actor_position.distance_to(destination) < 0.0001:
			cell = target
			route.pop_front()
			completed_cells += 1
	refresh()


func refresh() -> void:
	var count: int = actor.data.frame_count
	var display_phase: float = phase
	if route.is_empty() and actor.data.has("rest_frame"):
		display_phase = float(actor.data.rest_frame) / count
	actor.sample(direction, display_phase)
	actor.position = actor_position
	label.text = "%s    %s · pose %02d/%d · %s" % [
		review_title,
		actor.data.views[direction].label,
		actor.sprite.frame + 1,
		count,
		"en déplacement" if not route.is_empty() else "à l’arrêt",
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
					draw_polyline(polygon, Color(0.8, 0.9, 0.7, 0.19), 1.0)
	for next: Vector2i in route:
		draw_circle(visual.cell_to_display(next), 3, Color("dbba78"))
	draw_arc(actor_position, 12, 0, TAU, 32, Color(0.8, 0.7, 0.4, 0.5), 1.0)
