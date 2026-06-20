# battle/unit_view.gd
# ============================================================
# UNIT VIEW — Visuel d'une unité. Le sprite vient de l'unité elle-même
# (via sa UnitData), donc chaque unité a son propre skin.
#
# On crée l'AnimatedSprite2D PAR CODE maintenant : la scène unit_view.tscn
# n'a plus besoin d'un sprite pré-rempli.
# ============================================================

extends Node2D

const UNIT_SIZE = 48

var unit: Unit
var _sprite: AnimatedSprite2D
var _hp_bar: ProgressBar
var _is_active: bool = false

func setup(p_unit: Unit) -> void:
	unit = p_unit
	_build_visual()
	unit.hp_changed.connect(_on_hp_changed)
	unit.died.connect(_on_died)
	_update_hp_bar()

func _build_visual() -> void:
	# --- Sprite propre à cette unité ---
	_sprite = AnimatedSprite2D.new()
	if unit.sprite_frames != null:
		_sprite.sprite_frames = unit.sprite_frames
		_sprite.scale = Vector2(unit.sprite_scale, unit.sprite_scale)
		# On joue l'animation idle si elle existe, sinon la première dispo.
		var anims = unit.sprite_frames.get_animation_names()
		if unit.idle_animation in anims:
			_sprite.play(unit.idle_animation)
		elif anims.size() > 0:
			_sprite.play(anims[0])
	add_child(_sprite)

	# --- Barre de PV ---
	_hp_bar = ProgressBar.new()
	_hp_bar.size = Vector2(UNIT_SIZE, 6)
	_hp_bar.position = Vector2(-UNIT_SIZE / 2.0, -45)
	_hp_bar.min_value = 0
	_hp_bar.max_value = unit.max_hp.get_int()
	_hp_bar.value = unit.current_hp
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_bar)

func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = unit.max_hp.get_int()
	_hp_bar.value = unit.current_hp
	var ratio = unit.get_hp_ratio()
	var bar_color: Color
	if ratio > 0.5:
		bar_color = Color(0.3, 0.8, 0.3)
	elif ratio > 0.25:
		bar_color = Color(0.9, 0.8, 0.2)
	else:
		bar_color = Color(0.9, 0.3, 0.2)
	var style = StyleBoxFlat.new()
	style.bg_color = bar_color
	_hp_bar.add_theme_stylebox_override("fill", style)

func set_active(active: bool) -> void:
	_is_active = active
	queue_redraw()

func face_direction(from: Vector2, to: Vector2) -> void:
	if _sprite == null:
		return
	if to.x < from.x:
		_sprite.flip_h = true
	elif to.x > from.x:
		_sprite.flip_h = false

func _on_hp_changed(_unit: Unit) -> void:
	_update_hp_bar()

func _on_died(_unit: Unit) -> void:
	queue_free()

func _draw() -> void:
	if _is_active:
		draw_arc(Vector2.ZERO, UNIT_SIZE * 0.75, 0, TAU, 32, Color(1.0, 0.9, 0.2), 3.0)
