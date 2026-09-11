extends Node2D
## Reusable halt study. All authored coordinates are normalized in a versioned
## manifest; changing the camera never changes the ground or navigation map.
const Navigation := preload("res://hub/sanctuary_prototype/sanctuary_navigation.gd")
const Player := preload("res://hub/painted_halt/halt_player.gd")
const ScaleReference := preload("res://hub/painted_halt/halt_scale_reference.gd")
const Atmosphere := preload("res://hub/painted_halt/halt_atmosphere.gd")
const Manifest := preload(
	"res://addons/dungeon_draft_arena_studio/halts/services/painted_halt_manifest_service.gd"
)
const Interactions := preload("res://hub/painted_halt/halt_interactions.gd")
const AmbientAudio := preload("res://hub/painted_halt/halt_audio.gd")
const LandmarkEffects := preload("res://hub/painted_halt/halt_landmark_effects.gd")
signal visit_finished
const MATERIAL_SHADER := preload("res://hub/painted_halt/living_materials.gdshader")
const BODY := preload(
	"res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf"
)
const TITLE := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
@export_file("*.json") var manifest_path := "res://data/halts/emerald_sanctuary_v1.json"
@export var preview_mode := true
@export var audio_enabled := true
var definition_override: Dictionary = { }
var preview_materials: Image
var preview_flow: Image
var definition: Dictionary = { }
var world_size := Vector2.ONE
var world: Node2D
var player: Player
var nav := Navigation.new()
var effect_material: ShaderMaterial
var atmosphere: Atmosphere
var interactions: Interactions
var ambience: AmbientAudio
var landmarks_fx: LandmarkEffects
var clock := 0.0
var paused := false
var original := false
var reduced := false
var zoom := 1.0
var layers := { "water": true, "fire": true, "atmosphere": true, "foliage": true }
var _ready_for_play := false
var _path := PackedVector2Array()
var _path_index := 0
var _speed := 0.0
var _target := Vector2.ZERO
var _marker: Destination
var _interface: Control
var _status: Label
var _pause: Button
var _original: Button
var _zoom_label: Label
var _ripples := 0
var _ripple_time := -100.0
var _mask: Image
var _flow: Image
var _error := ""


class Destination extends Node2D:
	var clock := 0.0


	func _draw() -> void:
		var ring := PackedVector2Array()
		for i in 41:
			var angle := i / 40.0 * TAU
			ring.append(Vector2(cos(angle), sin(angle) * 0.5) * (13.0 + sin(clock * 3.0)))
		draw_polyline(ring, Color(0.91, 0.8, 0.51, 0.8), 1.6, true)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101c1b"))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--halt-manifest=") and definition_override.is_empty():
			manifest_path = argument.trim_prefix("--halt-manifest=")
	if not _load_definition():
		_build_error()
		return
	_normalize_optional_definition()
	var size_data: Array = definition.source.size
	world_size = Vector2(
		float(definition.world.width),
		float(definition.world.width) * size_data[1] / size_data[0],
	)
	world = Node2D.new()
	world.name = "PaintedWorld"
	add_child(world)
	var source: Texture2D
	if not definition_override.is_empty():
		var raw := Image.load_from_file(
			ProjectSettings.globalize_path(str(definition.source.image))
		)
		source = ImageTexture.create_from_image(raw)
	else:
		source = load(str(definition.source.image))
	effect_material = ShaderMaterial.new()
	effect_material.shader = _material_shader()
	effect_material.set_shader_parameter("materials", ImageTexture.create_from_image(_mask))
	effect_material.set_shader_parameter("source_size", Vector2(size_data[0], size_data[1]))
	effect_material.set_shader_parameter("water_color", Color(str(definition.water.tint)))
	if _flow != null:
		effect_material.set_shader_parameter("flow_map", ImageTexture.create_from_image(_flow))
		effect_material.set_shader_parameter("has_flow_map", true)
	var torch_data := PackedVector4Array()
	var torch_strength := PackedVector4Array()
	for torch: Dictionary in definition.torches:
		torch_data.append(Vector4(torch.point[0], torch.point[1], torch.radius[0], torch.radius[1]))
		torch_strength.append(
			Vector4(
				float(torch.get("flame_strength", 1.0)),
				float(torch.get("light_strength", 1.0)),
				float(torch.get("steady_light", 0.0)),
				0,
			)
		)
	while torch_data.size() < 12:
		torch_data.append(Vector4.ZERO)
		torch_strength.append(Vector4.ZERO)
	effect_material.set_shader_parameter("torches", torch_data)
	effect_material.set_shader_parameter("torch_strength", torch_strength)
	effect_material.set_shader_parameter("torch_count", definition.torches.size())
	var painting := TextureRect.new()
	painting.texture = source
	painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	painting.size = world_size
	painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painting.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	painting.material = effect_material
	world.add_child(painting)
	_marker = Destination.new()
	_marker.hide()
	world.add_child(_marker)
	var actors := Node2D.new()
	actors.name = "DepthSortedActors"
	actors.y_sort_enabled = true
	world.add_child(actors)
	player = Player.new()
	player.name = "Achilles"
	_configure_player(player)
	player.position = point(definition.world.spawn)
	player.water_tint = Color(str(definition.water.tint))
	for torch: Dictionary in definition.torches:
		player.light_positions.append(point(torch.point))
	for polygon: Array in definition.water.polygons:
		var center := Vector2.ZERO
		for p: Array in polygon:
			center += point(p)
		player.water_positions.append(center / polygon.size())
	actors.add_child(player)
	for foreground: Dictionary in definition.get("foreground", []):
		var cutout := Polygon2D.new()
		cutout.position = point(foreground.anchor)
		var points := polygon(foreground.polygon)
		var uv := PackedVector2Array()
		for i in points.size():
			uv.append(points[i] / world_size * Vector2(size_data[0], size_data[1]))
			points[i] -= cutout.position
		cutout.polygon = points
		cutout.uv = uv
		cutout.texture = source
		cutout.material = effect_material
		actors.add_child(cutout)
	atmosphere = Atmosphere.new()
	atmosphere.definition = definition
	atmosphere.extent = world_size
	world.add_child(atmosphere)
	ambience = AmbientAudio.new()
	add_child(ambience)
	ambience.configure(world, player, definition, world_size)
	interactions = _create_interactions()
	add_child(interactions)
	interactions.configure(self, preview_mode)
	landmarks_fx = LandmarkEffects.new()
	landmarks_fx.hall = self
	world.add_child(landmarks_fx)
	nav.foot_radius = float(definition.world.foot_clearance)
	nav.create_debug_overlay(world)
	_build_interface()
	get_viewport().size_changed.connect(_fit_world)
	_fit_world()
	_apply_effects()
	var obstacles: Array[PackedVector2Array] = []
	for p: Array in definition.navigation.obstacles:
		obstacles.append(polygon(p))
	var configured := await nav.configure(polygon(definition.navigation.outline), obstacles)
	if not is_inside_tree():
		return
	_ready_for_play = configured and nav.is_walkable(player.position) and player.is_visual_ready()
	if not _ready_for_play:
		push_error("LIVING_HALT: invalid navigation or spawn")
	print(
		"LIVING_HALT_READY: %s; %s; world %s; source %s"
		% [_ready_for_play, definition.id, world_size, size_data]
	)


func _material_shader() -> Shader:
	return MATERIAL_SHADER


func _configure_player(actor: Player) -> void:
	actor.display_scale = ScaleReference.display_scale(definition)


func _create_interactions() -> Interactions:
	return Interactions.new()


func _load_definition() -> bool:
	if not definition_override.is_empty():
		var validation: Dictionary = Manifest.validate(definition_override)
		if not bool(validation.get("ok", false)) or preview_materials == null:
			_error = "La copie de travail doit être calibrée avant cet essai."
			return false
		definition = definition_override.duplicate(true)
		_mask = preview_materials
		_flow = preview_flow
		return true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or parsed.get("schema_version", 0) != 1:
		_error = "Manifeste de halte invalide."
		return false
	definition = parsed
	var build_path := str(definition.build_dir).path_join("build.json")
	var build: Variant = JSON.parse_string(FileAccess.get_file_as_string(build_path))
	var mask_path := str(definition.build_dir).path_join("materials.png")
	if (
		not build is Dictionary
		or str(build.get("manifest_sha256", ""))
		!= (
			Manifest.manifest_hash(manifest_path)
			if str(build.get("manifest_hash_mode", "")) == "lf_utf8_v1"
			else FileAccess.get_sha256(manifest_path)
		)
	) \
			or str(build.get("source_sha256", "")) != FileAccess.get_sha256(
		str(definition.source.image)
	) \
			or str(build.get("mask_sha256", "")) != FileAccess.get_sha256(mask_path):
		_error = "Cette version doit être préparée à nouveau dans l’atelier des haltes."
		return false
	_mask = Image.load_from_file(ProjectSettings.globalize_path(mask_path))
	var flow_path := str(definition.build_dir).path_join("flow.png")
	if build.has("flow_sha256"):
		if FileAccess.get_sha256(flow_path) != str(build.flow_sha256):
			_error = "Les courants doivent être préparés à nouveau."
			return false
		_flow = Image.load_from_file(ProjectSettings.globalize_path(flow_path))
		if _flow == null or _flow.is_empty():
			_error = "La carte des courants est illisible."
			return false
	return _mask != null and not _mask.is_empty()


func _normalize_optional_definition() -> void:
	for key in ["cascades", "torches", "foliage", "bounce", "mist", "foreground"]:
		if not definition.has(key):
			definition[key] = []
	if not definition.has("water"):
		definition["water"] = { }
	for key in ["polygons", "regions", "exclusions"]:
		if not definition.water.has(key):
			definition.water[key] = []
	if not definition.water.has("tint"):
		definition.water["tint"] = "#48d896"
	if not definition.navigation.has("obstacles"):
		definition.navigation["obstacles"] = []
	if not definition.world.has("speed"):
		definition.world["speed"] = 195
	if not definition.world.has("foot_clearance"):
		definition.world["foot_clearance"] = 12
	if not definition.has("review"):
		definition["review"] = { }


func _exit_tree() -> void:
	nav.close()
	if ambience != null:
		ambience.dispose()


func is_ready_for_play() -> bool:
	return _ready_for_play


func _process(delta: float) -> void:
	advance_world(delta)


func advance_world(delta: float) -> void:
	if world == null or not is_finite(delta) or delta < 0.0:
		return
	if not paused:
		clock += delta
		if _ready_for_play and not interactions.blocked():
			_advance_move(delta)
			interactions.after_movement()
	_apply_effects()
	player.set_environment_time(clock, player.position)
	_marker.clock = clock
	_marker.queue_redraw()
	landmarks_fx.queue_redraw()
	ambience.advance(0.0, paused, audio_enabled and not original)
	if zoom > 1.0:
		_fit_world()
	_update_status()


func _apply_effects() -> void:
	if effect_material == null:
		return
	var power := 0.0 if original else (0.28 if reduced else 1.0)
	effect_material.set_shader_parameter("effect_time", clock)
	effect_material.set_shader_parameter("strength", power)
	effect_material.set_shader_parameter("water_enabled", layers.water)
	effect_material.set_shader_parameter("fire_enabled", layers.fire)
	effect_material.set_shader_parameter("foliage_enabled", layers.foliage)
	effect_material.set_shader_parameter(
		"ripple_age",
		clock - _ripple_time if clock - _ripple_time < 3.0 else -1.0,
	)
	atmosphere.set_state(clock, power, layers.water, layers.fire, layers.atmosphere)


func point(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1])) * world_size


func polygon(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value: Array in values:
		result.append(point(value))
	return result


func request_move(destination: Vector2) -> bool:
	if not _ready_for_play or paused or (interactions != null and interactions.blocked()):
		return false
	var candidate := nav.get_path(player.position, destination)
	if candidate.is_empty():
		return false
	if interactions != null:
		interactions.cancel()
	_path = candidate
	_path_index = 0
	_target = destination
	_marker.position = destination
	_marker.show()
	return true


func is_player_moving() -> bool:
	return _path_index < _path.size()


func stop_movement(cancel_interaction := true) -> void:
	if cancel_interaction and interactions != null:
		interactions.cancel()
	_path.clear()
	_path_index = 0
	_speed = 0.0
	if player != null:
		player.play_idle()
	if _marker != null:
		_marker.hide()


func _ground_distance(offset: Vector2) -> float:
	return Vector2(offset.x, offset.y * 2.0).length()


func _advance_move(delta: float) -> void:
	if not is_player_moving():
		return
	var remaining := 0.0
	var previous := player.position
	for i in range(_path_index, _path.size()):
		remaining += _ground_distance(_path[i] - previous)
		previous = _path[i]
	_speed = move_toward(
		_speed,
		minf(float(definition.world.speed), sqrt(1200.0 * remaining)),
		800.0 * delta,
	)
	var travel := _speed * delta
	while is_player_moving() and travel > 0.0:
		var offset := _path[_path_index] - player.position
		var distance := _ground_distance(offset)
		if distance < 0.15:
			_path_index += 1
			continue
		var used := minf(travel, distance)
		var next := player.position + offset * used / distance
		if not nav.is_walkable(next):
			stop_movement()
			return
		player.play_walk(offset)
		player.position = next
		player.advance_ground_stride(used)
		ambience.advance(
			player.normalized_stride_distance(used),
			paused,
			audio_enabled and not original,
		)
		travel -= used
		if used >= distance:
			_path_index += 1
	if not is_player_moving():
		stop_movement(false)


func set_paused(value: bool) -> void:
	paused = value
	_update_status()


func set_original(value: bool) -> void:
	original = value
	_apply_effects()
	_update_status()


func set_layer(id: String, enabled: bool) -> void:
	if layers.has(id):
		layers[id] = enabled
		_apply_effects()


func set_zoom(value: float) -> void:
	zoom = clampf(value, 1.0, 1.65)
	_fit_world()
	_update_status()


func set_chrome_visible(value: bool) -> void:
	_interface.visible = value


func trigger_ripple(at: Vector2) -> bool:
	var uv := at / world_size
	if paused or original or not layers.water or uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1:
		return false
	var color := _mask.get_pixel(int(uv.x * _mask.get_width()), int(uv.y * _mask.get_height()))
	if color.r < 0.5:
		return false
	_ripples += 1
	_ripple_time = clock
	effect_material.set_shader_parameter("ripple_origin", uv)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_play:
		return
	if interactions != null and interactions.blocked():
		if (
			event is InputEventKey and event.pressed
			and event.keycode == KEY_ESCAPE and interactions.active
		):
			interactions.close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom + 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom - 0.1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			interactions.cancel()
			stop_movement()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var at := world.to_local(event.position)
			var landmark := interactions.hit_test(at)
			if landmark >= 0:
				interactions.request(landmark)
			elif not trigger_ripple(at):
				request_move(at)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				set_paused(not paused)
			KEY_TAB:
				set_original(not original)
			KEY_H:
				set_chrome_visible(not _interface.visible)
			KEY_F:
				get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			KEY_F1:
				nav.debug_enabled = not nav.debug_enabled
			KEY_ESCAPE:
				interactions.cancel()
				stop_movement()
				set_chrome_visible(true)
			KEY_1, KEY_2, KEY_3:
				var index := int(event.keycode) - int(KEY_1)
				if index < definition.landmarks.size():
					interactions.request(index)
			_:
				return
		get_viewport().set_input_as_handled()


func _fit_world() -> void:
	if world == null:
		return
	var size := get_viewport_rect().size
	var factor := minf(size.x / world_size.x, size.y / world_size.y) * zoom
	world.scale = Vector2.ONE * factor
	var center := world_size * 0.5
	if zoom > 1.0 and player != null:
		center = center.lerp(
			player.position + Vector2(0, -70 * player.display_scale / 0.52),
			clampf((zoom - 1.0) / 0.5, 0, 1),
		)
		var half := size / factor * 0.5
		center.x = clampf(
			center.x,
			minf(half.x, world_size.x * 0.5),
			maxf(world_size.x - half.x, world_size.x * 0.5),
		)
		center.y = clampf(
			center.y,
			minf(half.y, world_size.y * 0.5),
			maxf(world_size.y - half.y, world_size.y * 0.5),
		)
	world.position = size * 0.5 - center * factor


func _theme() -> Theme:
	return PremiumUI.get_theme()


func _button(parent: Node, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_interface = Control.new()
	canvas.add_child(_interface)
	_interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interface.theme = _theme()
	var top := PanelContainer.new()
	_interface.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 10
	top.offset_bottom = 74
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	top.add_child(top_row)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(names)
	var title := Label.new()
	title.text = str(definition.title)
	title.add_theme_font_override("font", TITLE)
	title.add_theme_font_size_override("font_size", 21)
	names.add_child(title)
	var subtitle := Label.new()
	subtitle.text = str(definition.get("subtitle", "PIERRE ANCIENNE · SOURCES · FEU VIVANT"))
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.modulate = Color("c4b985")
	names.add_child(subtitle)
	for i in definition.landmarks.size():
		_button(
			top_row,
			str(definition.landmarks[i].title),
			func():
				interactions.request(i),
		)
	var bottom := PanelContainer.new()
	_interface.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 18
	bottom.offset_right = -18
	bottom.offset_top = -89
	bottom.offset_bottom = -10
	var stack := VBoxContainer.new()
	bottom.add_child(stack)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	controls.add_theme_font_size_override("font_size", 14)
	stack.add_child(controls)
	_pause = _button(
		controls,
		"Pause",
		func():
			set_paused(not paused),
	)
	_original = _button(
		controls,
		"Voir l’original",
		func():
			set_original(not original),
	)
	for entry in [
		["water", "Eau"],
		["fire", "Torches"],
		["atmosphere", "Atmosphère"],
		["foliage", "Feuillage"],
	]:
		if (
			(
				entry[0] == "water" and definition.water.polygons.is_empty()
				and definition.cascades.is_empty()
			)
			or (entry[0] == "foliage" and definition.foliage.is_empty())
		):
			continue
		var toggle := _button(
			controls,
			entry[1],
			func():
				pass,
		)
		toggle.toggle_mode = true
		toggle.set_pressed_no_signal(true)
		toggle.toggled.connect(
			func(value: bool):
				set_layer(entry[0], value),
		)
	var soft := _button(
		controls,
		"Mouvement doux",
		func():
			pass,
	)
	soft.toggle_mode = true
	soft.toggled.connect(
		func(value: bool):
			reduced = value
			_apply_effects(),
	)
	var sound := _button(
		controls,
		"Son",
		func():
			pass,
	)
	sound.toggle_mode = true
	sound.set_pressed_no_signal(audio_enabled)
	sound.toggled.connect(
		func(value: bool):
			audio_enabled = value,
	)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(space)
	_button(
		controls,
		"−",
		func():
			set_zoom(zoom - 0.1),
	)
	_zoom_label = Label.new()
	controls.add_child(_zoom_label)
	_button(
		controls,
		"+",
		func():
			set_zoom(zoom + 0.1),
	)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	stack.add_child(_status)
	for panel in [top, bottom]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("211c18f2")
		style.border_color = Color("8b714c")
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		style.content_margin_left = 15
		style.content_margin_right = 15
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		panel.add_theme_stylebox_override("panel", style)
	_update_status()


func _update_status() -> void:
	if _status == null:
		return
	_status.text = "Clic : explorer ou toucher l’eau  ·  Molette : zoom  ·  Espace : pause  ·  F : plein écran  ·  H : masquer"
	_pause.text = "Reprendre" if paused else "Pause"
	_original.text = "Animer le décor" if original else "Voir l’original"
	_zoom_label.text = "%d %%" % roundi(zoom * 100)


func _build_error() -> void:
	var label := Label.new()
	label.text = _error
	label.position = Vector2(30, 30)
	add_child(label)
	push_error(_error)
