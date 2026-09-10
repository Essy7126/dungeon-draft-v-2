extends Node2D

## Isolated animation playground. Campaign Spell resources are never modified.
@export var asset_root: String = "res://art/source/characters/achilles/passe_rive_spells_v1/delivery/"
var manifest: Dictionary
var actor: AnimatedSprite2D
var actor_position := Vector2(325, 425)
var targets: Array[Dictionary] = []
var active: Dictionary = { }
var cooldowns: Dictionary = { }
var clock: float = 0.0
var freeze: float = 0.0
var effect: Dictionary = { }
var queued_id: String = ""
var projectile: Dictionary = { }
var hit_count: int = 0
var cast_count: int = 0
var release_count: int = 0
var rate: float = 1.0
var fx_enabled: bool = true
var paused: bool = false
var status_label: Label
var map: Texture2D
var walking: bool = false
var walk_time: float = 0.0
var shield_time: float = 0.0


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1280, 770)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	manifest = JSON.parse_string(FileAccess.get_file_as_string(asset_root + "manifest.json"))
	map = load(asset_root + "map.png") as Texture2D
	actor = AnimatedSprite2D.new()
	actor.sprite_frames = load(asset_root + "sprite_frames.tres") as SpriteFrames
	actor.centered = false
	actor.scale = Vector2.ONE * 0.55
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(actor)
	_build_ui()
	reset_lab()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "PASSE-RIVE  /  Six gestes à jouer"
	title.position = Vector2(28, 20)
	title.add_theme_font_size_override("font_size", 25)
	layer.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(28, 594)
	layer.add_child(status_label)
	var row := HBoxContainer.new()
	row.position = Vector2(28, 640)
	row.add_theme_constant_override("separation", 8)
	layer.add_child(row)
	for i in range(manifest.actions.size()):
		var definition: Dictionary = manifest.actions[i]
		var button := Button.new()
		button.text = "%d  %s" % [i + 1, definition.name]
		button.custom_minimum_size = Vector2(194, 50)
		button.pressed.connect(cast_action.bind(String(definition.id)))
		button.focus_mode = Control.FOCUS_NONE
		row.add_child(button)
	var help := Label.new()
	help.text = "1–6 : sorts   •   Flèches / ZQSD : déplacement   •   R : replacer   •   V : effets   •   T : ralenti   •   Espace : pause\nUne direction fixe. Chiffres du laboratoire uniquement. La campagne conserve ses règles."
	help.position = Vector2(28, 705)
	help.add_theme_font_size_override("font_size", 15)
	layer.add_child(help)


func reset_lab() -> void:
	actor_position = Vector2(325, 425)
	targets = [
		{ "position": Vector2(505, 425), "hp": 100, "respawn": 0.0 },
		{ "position": Vector2(685, 430), "hp": 100, "respawn": 0.0 },
		{ "position": Vector2(860, 365), "hp": 100, "respawn": 0.0 },
	]
	active = { }
	projectile = { }
	effect = { }
	cooldowns = { }
	queued_id = ""
	freeze = 0.0
	shield_time = 0.0
	hit_count = 0
	cast_count = 0
	release_count = 0
	actor.animation = &"idle"
	_update_sprite()


func cast_action(id: String) -> bool:
	if not active.is_empty():
		if float(active.spell.total_ms) / 1000.0 - float(active.time) <= 0.16:
			queued_id = id
			return true
		return false
	if float(cooldowns.get(id, 0.0)) > 0.0:
		return false
	for definition: Dictionary in manifest.actions:
		if definition.id == id:
			active = { "spell": definition, "time": 0.0, "fired": false, "start": actor_position }
			cooldowns[id] = float(definition.cooldown_ms) / 1000.0
			actor.animation = StringName(id)
			actor.frame = 0
			cast_count += 1
			return true
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_6:
		cast_action(String(manifest.actions[key.physical_keycode - KEY_1].id))
	elif key.physical_keycode == KEY_R:
		reset_lab()
	elif key.physical_keycode == KEY_V:
		fx_enabled = not fx_enabled
	elif key.physical_keycode == KEY_T:
		rate = 0.25 if rate == 1.0 else 1.0
	elif key.physical_keycode == KEY_SPACE:
		paused = not paused


func _process(delta: float) -> void:
	if not paused:
		advance(minf(delta, 0.05) * rate)
	_update_sprite()
	status_label.text = "%d gestes  ·  %d impacts  ·  %s  ·  %d %%" % [
		cast_count,
		hit_count,
		String(active.get("spell", { }).get("name", "En garde")),
		int(rate * 100),
	]
	queue_redraw()


func advance(dt: float) -> void:
	clock += dt
	for id: String in cooldowns:
		cooldowns[id] = maxf(0.0, float(cooldowns[id]) - dt)
	for target: Dictionary in targets:
		if int(target.hp) == 0:
			target.respawn = float(target.respawn) - dt
			if float(target.respawn) <= 0.0:
				target.hp = 100
	shield_time = maxf(0.0, shield_time - dt)
	if not effect.is_empty():
		effect.age = float(effect.age) + dt
		if float(effect.age) >= 0.5:
			effect = { }
	if freeze > 0.0:
		freeze -= dt
		return
	if not active.is_empty():
		active.time = float(active.time) + dt
		var definition: Dictionary = active.spell
		if not active.fired and float(active.time) + 0.000001 >= float(definition.event_ms) / 1000.0:
			active.fired = true
			_release(definition)
		if definition.mode == "dash":
			var u := clampf((float(active.time) - 0.1) / 0.2, 0.0, 1.0)
			var start: Vector2 = active.start
			var destination := minf(1100, start.x + 220 * (1 - pow(1 - u, 3)))
			for target: Dictionary in targets:
				var p: Vector2 = target.position
				if target.hp > 0 and p.x > start.x and absf(p.y - start.y) < 65:
					destination = minf(destination, p.x - 85)
			actor_position.x = destination
		if float(active.time) >= float(definition.total_ms) / 1000.0:
			active = { }
			actor.animation = &"idle"
			var next := queued_id
			queued_id = ""
			if not next.is_empty():
				cast_action(next)
	else:
		var direction := Vector2(
			float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D))
			- float(
				Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_Q)
				or Input.is_physical_key_pressed(KEY_A)
			),
			float(Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S))
			- float(
				Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_Z)
				or Input.is_physical_key_pressed(KEY_W)
			),
		)
		walking = direction.length_squared() > 0.0
		if walking:
			var next_position := actor_position + direction.normalized() * Vector2(114, 80) * dt
			var blocked := false
			for target: Dictionary in targets:
				if int(target.hp) > 0 and (Vector2(target.position) - next_position).length() < 50:
					blocked = true
			if not blocked:
				actor_position = next_position.clamp(Vector2(180, 330), Vector2(1080, 555))
			walk_time += dt
	if not projectile.is_empty():
		projectile.x = float(projectile.x) + 1000 * dt
		for target: Dictionary in targets:
			var p: Vector2 = target.position
			if (
				int(target.hp) > 0 and p.x >= float(projectile.x) - 70
				and p.x <= float(projectile.x) + 15 and absf(p.y - actor_position.y) < 80
			):
				_hit(target, projectile.spell)
				projectile = { }
				break
		if not projectile.is_empty() and float(projectile.x) - float(projectile.origin) > 670:
			projectile = { }


func _release(definition: Dictionary) -> void:
	release_count += 1
	effect = {
		"mode": definition.mode,
		"position": actor_position,
		"color": Color(definition.color),
		"age": 0.0,
	}
	if definition.mode == "guard":
		shield_time = 2.0
		freeze = float(definition.hitstop_ms) / 1000.0
		return
	if definition.mode == "dash":
		return
	if definition.mode == "shot":
		projectile = {
			"x": actor_position.x + 130,
			"y": actor_position.y - 125,
			"origin": actor_position.x,
			"spell": definition,
		}
		return
	for target: Dictionary in targets:
		var delta_position: Vector2 = Vector2(target.position) - actor_position
		var in_range := (
			delta_position.x > 30 and delta_position.x < float(definition.range)
			and absf(delta_position.y) < 72
		)
		if definition.mode == "sweep":
			in_range = (delta_position * Vector2(1, 1.5)).length() <= float(definition.range)
		if int(target.hp) > 0 and in_range:
			_hit(target, definition)
			if definition.mode != "sweep":
				break


func _hit(target: Dictionary, definition: Dictionary) -> void:
	target.hp = maxi(0, int(target.hp) - int(definition.damage))
	target.respawn = 1.7
	hit_count += 1
	freeze = float(definition.hitstop_ms) / 1000.0
	if definition.mode == "bash":
		var p: Vector2 = target.position
		target.position = Vector2(minf(1110, p.x + 70), p.y)


func _update_sprite() -> void:
	actor.position = actor_position - Vector2(320, 662) * 0.55
	if not active.is_empty():
		var t: float = active.time
		actor.animation = StringName(active.spell.id)
		for i in range(4):
			t -= float(active.spell.frames[i].duration_ms) / 1000.0
			if t < -0.000001:
				actor.frame = i
				break
	elif walking:
		actor.animation = &"walk"
		actor.frame = int(walk_time * 10) % 12
	else:
		actor.animation = &"idle"
		actor.frame = 0


func _draw() -> void:
	if map:
		draw_texture_rect(map, Rect2(0, 0, 1280, 630), false, Color(0.5, 0.6, 0.52))
	else:
		draw_rect(Rect2(0, 0, 1280, 630), Color("203c30"))
	for target: Dictionary in targets:
		if int(target.hp) <= 0:
			continue
		var p: Vector2 = target.position
		draw_colored_polygon(
			PackedVector2Array(
				[
					p + Vector2(-28, 0),
					p + Vector2(-18, -150),
					p + Vector2(0, -185),
					p + Vector2(28, -147),
					p + Vector2(25, -4),
				]
			),
			Color("647660"),
		)
		draw_arc(p + Vector2(0, -120), 20, 0, TAU, 32, Color("e0cc92"), 2)
		draw_rect(Rect2(p + Vector2(-28, -204), Vector2(56, 5)), Color("15221a"))
		draw_rect(
			Rect2(p + Vector2(-28, -204), Vector2(56 * float(target.hp) / 100, 5)),
			Color("d2c894"),
		)
	if not fx_enabled:
		return
	if shield_time > 0:
		draw_arc(actor_position + Vector2(30, -125), 92, -1.5, 1.5, 40, Color("d8c18f"), 3)
	if not projectile.is_empty():
		draw_line(
			Vector2(float(projectile.x) - 90, projectile.y),
			Vector2(float(projectile.x) + 15, projectile.y),
			Color("baedd8"),
			5,
		)
	if effect.is_empty():
		return
	var point: Vector2 = effect.position
	var color: Color = effect.color
	var progress := clampf(float(effect.age) / 0.5, 0, 1)
	color.a = 1 - progress
	if effect.mode == "sweep":
		draw_arc(
			point + Vector2(30, -100),
			180,
			-1.5,
			-1.5 + 4.3 * minf(1, progress * 2.5),
			48,
			color,
			12 * (1 - progress) + 1,
		)
	elif effect.mode == "bash":
		draw_arc(point + Vector2(145, -127), 50 + 80 * progress, -1.2, 1.2, 32, color, 6)
	elif effect.mode == "melee":
		draw_line(point + Vector2(90, -163), point + Vector2(235, -163), color, 5)
	elif effect.mode == "dash":
		for i in range(4):
			draw_line(
				point + Vector2(-90, -100 + i * 20),
				point + Vector2(20, -100 + i * 20),
				color,
				3,
			)
