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
var _shield_bar: ProgressBar   # barre bleue au-dessus des PV
var _is_active: bool = false
var _flash_tween: Tween = null  # tween de flash en cours (annulé si nouveau flash)

func setup(p_unit: Unit) -> void:
	unit = p_unit
	_build_visual()
	unit.hp_changed.connect(_on_hp_changed)
	unit.died.connect(_on_died)
	unit.shield_changed.connect(_on_shield_changed)
	EventBus.shield_absorbed.connect(_on_shield_absorbed)
	EventBus.shield_broken.connect(_on_shield_broken)
	EventBus.shield_gained.connect(_on_shield_gained)
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

	# --- Barre de bouclier (au-dessus des PV, bleue, masquée par défaut) ---
	_shield_bar = ProgressBar.new()
	_shield_bar.size = Vector2(UNIT_SIZE, 4)
	_shield_bar.position = Vector2(-UNIT_SIZE / 2.0, -51)
	_shield_bar.min_value = 0
	_shield_bar.max_value = 100          # redimensionné dynamiquement
	_shield_bar.value = 0
	_shield_bar.show_percentage = false
	_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_bar.visible = false
	var shield_style = StyleBoxFlat.new()
	shield_style.bg_color = Color(0.35, 0.65, 1.0)
	_shield_bar.add_theme_stylebox_override("fill", shield_style)
	add_child(_shield_bar)

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

func _update_shield_bar() -> void:
	if _shield_bar == null:
		return
	var shield := unit.current_shield
	_shield_bar.visible = shield > 0
	if shield > 0:
		# Le max de la barre = max entre le bouclier actuel et les HP max (lisibilité)
		_shield_bar.max_value = max(shield, unit.max_hp.get_int())
		_shield_bar.value = shield
	queue_redraw()   # redessine l'arc bouclier

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

# ============================================================
# HANDLERS SIGNAUX
# ============================================================

func _on_hp_changed(_unit: Unit) -> void:
	_update_hp_bar()

func _on_died(_unit: Unit) -> void:
	queue_free()

func _on_shield_changed(u: Unit) -> void:
	if u != unit:
		return
	_update_shield_bar()

func _on_shield_gained(u: Unit, amount: int) -> void:
	if u != unit:
		return
	_flash(Color(0.85, 0.75, 0.2), 0.18)   # flash doré : bouclier reçu
	_show_floating_number("+%d" % amount, Color(0.4, 0.7, 1.0))

func _on_shield_absorbed(u: Unit, amount: int) -> void:
	if u != unit:
		return
	_flash(Color(0.4, 0.65, 1.0), 0.15)    # flash bleu : absorption

func _on_shield_broken(u: Unit) -> void:
	if u != unit:
		return
	_flash(Color(1.0, 0.45, 0.1), 0.25)    # flash orange : bouclier brisé

# ============================================================
# ANIMATIONS
# ============================================================

# Flash coloré du sprite (modulate temporaire via Tween).
# Interrompt le flash précédent si un nouveau arrive avant la fin.
func _flash(color: Color, duration: float) -> void:
	if _sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, duration)

# Nombre flottant qui monte et disparaît (gain de bouclier, absorption...).
func _show_floating_number(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.position = Vector2(-8, -UNIT_SIZE - 4)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", -UNIT_SIZE - 24, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)

# ============================================================
# DESSIN
# Arc jaune = unité active. Arc bleu = bouclier actif.
# Les deux peuvent s'afficher en même temps.
# ============================================================

func _draw() -> void:
	# Arc bouclier (bleu, plus épais, légèrement plus grand)
	if unit != null and unit.current_shield > 0:
		var ratio := float(unit.current_shield) / float(max(unit.current_shield, unit.max_hp.get_int()))
		var arc_end := TAU * ratio           # arc partiel selon ratio bouclier/PV max
		draw_arc(Vector2.ZERO, UNIT_SIZE * 0.82, -PI / 2.0, -PI / 2.0 + arc_end,
			32, Color(0.35, 0.65, 1.0, 0.75), 4.0)

	# Arc actif (jaune, tour en cours)
	if _is_active:
		draw_arc(Vector2.ZERO, UNIT_SIZE * 0.75, 0, TAU, 32, Color(1.0, 0.9, 0.2), 3.0)
