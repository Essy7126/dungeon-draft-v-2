class_name DungeonDraftVFXLab
extends Node2D

const EFFECT_NAMES := [
	"Boule de feu", "Mur de glace", "Onde sismique",
	"Charge", "Garde / bouclier", "Tempete orageuse",
]
const EFFECT_SCENES := [
	preload("res://tools/labs/vfx_lab/effects/FireballLabVFX.tscn"),
	preload("res://tools/labs/vfx_lab/effects/IceWallLabVFX.tscn"),
	preload("res://tools/labs/vfx_lab/effects/SeismicWaveLabVFX.tscn"),
	preload("res://tools/labs/vfx_lab/effects/ChargeLabVFX.tscn"),
	preload("res://tools/labs/vfx_lab/effects/GuardLabVFX.tscn"),
	preload("res://tools/labs/vfx_lab/effects/LightningStormLabVFX.tscn"),
]
const EFFECT_COLORS := [
	Color("ff7a22"), Color("6be6ff"), Color("d49a5b"),
	Color("8fdcff"), Color("5dccff"), Color("879cff"),
]
const BOARD_ORIGIN := Vector2(514.0, 225.0)

var selected_effect := 0
var seed_value := 1337
var playback_speed := 1.0
var fireball_variant := &"A"
var current_effect: Node2D = null

var board: Node2D = null
var world: Node2D = null
var caster: Node2D = null
var targets: Array[Node2D] = []
var effect_selector: OptionButton = null
var effect_title: Label = null
var status_label: Label = null
var seed_spin: SpinBox = null
var speed_selector: OptionButton = null
var fireball_variant_selector: OptionButton = null


func _ready() -> void:
	_build_backdrop()
	_build_stage()
	_build_interface()
	_select_effect(0)
	play_effect(0)


func play_effect(index: int = -1, seed_override: int = -1) -> Node2D:
	if index >= 0:
		_select_effect(clampi(index, 0, EFFECT_NAMES.size() - 1))
	if seed_override >= 0:
		seed_value = seed_override
		if is_instance_valid(seed_spin):
			seed_spin.value = seed_value
	clear_effect()
	_reset_units()
	current_effect = EFFECT_SCENES[selected_effect].instantiate() as Node2D
	world.add_child(current_effect)
	current_effect.effect_finished.connect(_on_effect_finished)
	var parameters := _parameters_for_effect(selected_effect)
	parameters["seed"] = seed_value
	parameters["playback_speed"] = playback_speed
	current_effect.play(parameters)
	_update_stage_highlights()
	_set_status("LECTURE  •  seed %d  •  %.2fx" % [seed_value, playback_speed])
	return current_effect


func replay_effect() -> Node2D:
	return play_effect(selected_effect, seed_value)


func clear_effect() -> void:
	if is_instance_valid(current_effect):
		current_effect.stop_and_clear()
		current_effect.free()
	current_effect = null
	_reset_units()
	_set_status("PRET")


func set_playback_speed(value: float) -> void:
	playback_speed = clampf(value, 0.1, 2.0)
	if is_instance_valid(current_effect):
		current_effect.playback_speed = playback_speed


func get_effect_count() -> int:
	return EFFECT_SCENES.size()


func grid_to_world(cell: Vector2i) -> Vector2:
	return board.call("grid_to_local", cell) as Vector2


func _parameters_for_effect(index: int) -> Dictionary:
	var start := grid_to_world(Vector2i(1, 3))
	var target := grid_to_world(Vector2i(7, 3))
	match index:
		0:
			return {
				"start": start + Vector2(0.0, -42.0),
				"target": target,
				"variant": fireball_variant,
			}
		1:
			return {"positions": _cells_to_positions([Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)]), "crystal_count": 11}
		2:
			return {"positions": _cells_to_positions([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]), "propagation_speed": 0.23}
		3:
			return {"actor": caster, "start": start, "target": grid_to_world(Vector2i(7, 2)), "movement_duration": 0.96}
		4:
			return {"target": grid_to_world(Vector2i(5, 3)), "shield_opacity": 0.48, "pulse_speed": 1.0}
		5:
			return {"positions": _cells_to_positions([Vector2i(5, 2), Vector2i(6, 3), Vector2i(5, 4)]), "strike_offsets": [0.72, 1.16, 1.58], "lightning_segment_count": 16, "jitter": 18.0}
	return {}


func _cells_to_positions(cells: Array[Vector2i]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for cell in cells:
		result.append(grid_to_world(cell))
	return result


func _build_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.position = Vector2.ZERO
	backdrop.size = get_viewport_rect().size
	backdrop.color = Color("081018")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -100
	add_child(backdrop)
	var atmosphere := ColorRect.new()
	atmosphere.position = Vector2(0.0, 72.0)
	atmosphere.size = Vector2(get_viewport_rect().size.x, get_viewport_rect().size.y - 72.0)
	atmosphere.color = Color(0.03, 0.1, 0.14, 0.54)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.z_index = -99
	add_child(atmosphere)


func _build_stage() -> void:
	board = preload("res://tools/labs/vfx_lab/vfx_lab_board.gd").new() as Node2D
	board.name = "TacticalBoard"
	board.position = BOARD_ORIGIN
	add_child(board)
	world = Node2D.new()
	world.name = "VFXStage"
	world.position = BOARD_ORIGIN
	add_child(world)
	caster = _create_unit("CASTER", Color("59d5ff"), Vector2i(1, 3))
	targets.append(_create_unit("CIBLE A", Color("ff6978"), Vector2i(5, 2)))
	targets.append(_create_unit("CIBLE B", Color("ffbb57"), Vector2i(6, 3)))
	targets.append(_create_unit("CIBLE C", Color("b08cff"), Vector2i(5, 4)))


func _create_unit(label_text: String, color: Color, cell: Vector2i) -> Node2D:
	var unit := preload("res://tools/labs/vfx_lab/vfx_lab_unit.gd").new() as Node2D
	unit.name = label_text.replace(" ", "")
	world.add_child(unit)
	unit.position = grid_to_world(cell)
	unit.set_meta("home_position", unit.position)
	unit.call("configure", label_text, color)
	return unit


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LabInterface"
	add_child(layer)
	var header := ColorRect.new()
	header.position = Vector2.ZERO
	header.size = Vector2(get_viewport_rect().size.x, 72.0)
	header.color = Color("0d1b26")
	layer.add_child(header)
	var eyebrow := Label.new()
	eyebrow.position = Vector2(28.0, 12.0)
	eyebrow.text = "DUNGEON DRAFT  /  OUTIL ISOLE"
	eyebrow.add_theme_color_override("font_color", Color("63869c"))
	eyebrow.add_theme_font_size_override("font_size", 12)
	header.add_child(eyebrow)
	effect_title = Label.new()
	effect_title.position = Vector2(27.0, 30.0)
	effect_title.text = "VFX LAB"
	effect_title.add_theme_color_override("font_color", Color("eaf7ff"))
	effect_title.add_theme_font_size_override("font_size", 26)
	header.add_child(effect_title)
	var badge := Label.new()
	badge.position = Vector2(935.0, 24.0)
	badge.text = "PROCEDURAL  •  GODOT 4.7"
	badge.add_theme_color_override("font_color", Color("7bdfff"))
	badge.add_theme_font_size_override("font_size", 13)
	header.add_child(badge)

	var panel := PanelContainer.new()
	panel.position = Vector2(920.0, 94.0)
	panel.size = Vector2(268.0, 770.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10212c")
	style.border_color = Color(0.25, 0.56, 0.68, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 11)
	panel.add_child(stack)
	var lab_label := Label.new()
	lab_label.text = "PROTOTYPES"
	lab_label.add_theme_color_override("font_color", Color("6e91a5"))
	lab_label.add_theme_font_size_override("font_size", 12)
	stack.add_child(lab_label)
	effect_selector = OptionButton.new()
	for effect_name in EFFECT_NAMES:
		effect_selector.add_item(effect_name)
	effect_selector.item_selected.connect(_select_effect)
	stack.add_child(effect_selector)
	var separator := HSeparator.new()
	stack.add_child(separator)
	var fireball_variant_label := Label.new()
	fireball_variant_label.text = "FIREBALL VARIANT"
	fireball_variant_label.add_theme_color_override("font_color", Color("6e91a5"))
	fireball_variant_label.add_theme_font_size_override("font_size", 12)
	stack.add_child(fireball_variant_label)
	fireball_variant_selector = OptionButton.new()
	for label_text in [
		"A  —  Compact / nervous",
		"B  —  Organic / turbulent",
		"C  —  Magical / stylized",
	]:
		fireball_variant_selector.add_item(label_text)
	fireball_variant_selector.item_selected.connect(_on_fireball_variant_selected)
	stack.add_child(fireball_variant_selector)
	var play_button := Button.new()
	play_button.text = "PLAY"
	play_button.pressed.connect(func(): play_effect())
	stack.add_child(play_button)
	var replay_button := Button.new()
	replay_button.text = "REPLAY"
	replay_button.pressed.connect(replay_effect)
	stack.add_child(replay_button)
	var clear_button := Button.new()
	clear_button.text = "STOP / CLEAR"
	clear_button.pressed.connect(clear_effect)
	stack.add_child(clear_button)
	stack.add_child(HSeparator.new())
	var speed_label := Label.new()
	speed_label.text = "VITESSE"
	speed_label.add_theme_color_override("font_color", Color("6e91a5"))
	speed_label.add_theme_font_size_override("font_size", 12)
	stack.add_child(speed_label)
	speed_selector = OptionButton.new()
	for label_text in ["0.25x", "0.5x", "1x", "2x"]:
		speed_selector.add_item(label_text)
	speed_selector.select(2)
	speed_selector.item_selected.connect(_on_speed_selected)
	stack.add_child(speed_selector)
	var seed_label := Label.new()
	seed_label.text = "SEED REPRODUCTIBLE"
	seed_label.add_theme_color_override("font_color", Color("6e91a5"))
	seed_label.add_theme_font_size_override("font_size", 12)
	stack.add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.min_value = 1
	seed_spin.max_value = 999999
	seed_spin.value = seed_value
	seed_spin.value_changed.connect(func(value: float): seed_value = int(value))
	stack.add_child(seed_spin)
	var variant_button := Button.new()
	variant_button.text = "SEED +1"
	variant_button.pressed.connect(_next_variant)
	stack.add_child(variant_button)
	stack.add_child(HSeparator.new())
	status_label = Label.new()
	status_label.text = "PRET"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("8ee7ff"))
	stack.add_child(status_label)
	var help := Label.new()
	help.text = "1–6 : effet\nESPACE : Play\nR : Replay\nECHAP : Clear"
	help.add_theme_color_override("font_color", Color("718b99"))
	help.add_theme_font_size_override("font_size", 12)
	stack.add_child(help)


func _select_effect(index: int) -> void:
	selected_effect = clampi(index, 0, EFFECT_NAMES.size() - 1)
	if is_instance_valid(effect_selector) and effect_selector.selected != selected_effect:
		effect_selector.select(selected_effect)
	if is_instance_valid(effect_title):
		effect_title.text = "VFX LAB  —  %s" % EFFECT_NAMES[selected_effect].to_upper()
	if is_instance_valid(fireball_variant_selector):
		fireball_variant_selector.visible = selected_effect == 0
	_update_stage_highlights()


func _update_stage_highlights() -> void:
	var cells: Array[Vector2i] = []
	match selected_effect:
		0: cells = [Vector2i(1, 3), Vector2i(7, 3)]
		1: cells = [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)]
		2: cells = [Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]
		3: cells = [Vector2i(1, 3), Vector2i(7, 2)]
		4: cells = [Vector2i(5, 3)]
		5: cells = [Vector2i(5, 2), Vector2i(6, 3), Vector2i(5, 4)]
	board.call("set_highlights", cells, EFFECT_COLORS[selected_effect])


func _on_speed_selected(index: int) -> void:
	set_playback_speed([0.25, 0.5, 1.0, 2.0][clampi(index, 0, 3)])
	_set_status("VITESSE %.2fx" % playback_speed)


func _on_fireball_variant_selected(index: int) -> void:
	fireball_variant = [&"A", &"B", &"C"][clampi(index, 0, 2)]
	if selected_effect == 0:
		play_effect(0, seed_value)


func _next_variant() -> void:
	seed_value += 1
	seed_spin.value = seed_value
	play_effect(selected_effect, seed_value)


func _on_effect_finished(_effect: Node2D) -> void:
	_set_status("TERMINE  •  cleanup automatique")


func _set_status(text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = text


func _reset_units() -> void:
	if is_instance_valid(caster):
		caster.position = caster.get_meta("home_position") as Vector2
	for target in targets:
		if is_instance_valid(target):
			target.position = target.get_meta("home_position") as Vector2


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		_select_effect(int(event.keycode - KEY_1))
		play_effect()
	elif event.keycode == KEY_SPACE:
		play_effect()
	elif event.keycode == KEY_R:
		replay_effect()
	elif event.keycode == KEY_ESCAPE:
		clear_effect()
