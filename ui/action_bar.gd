# ui/# ui/action_bar.gd
# ============================================================
# ACTION BAR — Barre d'action en bas.
# Boutons fixes (Déplacer, Attaquer, Fin de tour) + boutons de sorts
# générés dynamiquement selon l'unité active.
# ============================================================

extends CanvasLayer

signal move_pressed
signal attack_pressed
signal end_turn_pressed
signal spell_pressed(spell)   # un sort a été cliqué

var _panel: PanelContainer
var _hbox: HBoxContainer
var _move_btn: Button
var _attack_btn: Button
var _end_btn: Button
var _info_label: Label

# Conteneur dédié aux boutons de sorts (vidé/rempli à chaque unité).
var _spell_box: HBoxContainer
var _spell_buttons: Array = []

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -70
	add_child(_panel)

	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 12)
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(_hbox)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 16)
	_info_label.custom_minimum_size = Vector2(200, 0)
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hbox.add_child(_info_label)

	_move_btn = Button.new()
	_move_btn.text = "Déplacer"
	_move_btn.custom_minimum_size = Vector2(100, 44)
	_move_btn.pressed.connect(func(): move_pressed.emit())
	_hbox.add_child(_move_btn)

	_attack_btn = Button.new()
	_attack_btn.text = "Attaquer"
	_attack_btn.custom_minimum_size = Vector2(100, 44)
	_attack_btn.pressed.connect(func(): attack_pressed.emit())
	_hbox.add_child(_attack_btn)

	# Séparateur visuel + conteneur de sorts.
	var sep = VSeparator.new()
	_hbox.add_child(sep)

	_spell_box = HBoxContainer.new()
	_spell_box.add_theme_constant_override("separation", 8)
	_hbox.add_child(_spell_box)

	var sep2 = VSeparator.new()
	_hbox.add_child(sep2)

	_end_btn = Button.new()
	_end_btn.text = "Fin de tour"
	_end_btn.custom_minimum_size = Vector2(100, 44)
	_end_btn.pressed.connect(func(): end_turn_pressed.emit())
	_hbox.add_child(_end_btn)

# ============================================================
# GÉNÉRATION DES BOUTONS DE SORTS
# Appelé à chaque changement d'unité active.
# ============================================================

func build_spell_buttons(unit) -> void:
	# On vide les anciens boutons.
	for btn in _spell_buttons:
		btn.queue_free()
	_spell_buttons.clear()

	if unit == null:
		return

	# Un bouton par sort de l'unité.
	for spell in unit.spells:
		var btn = Button.new()
		btn.text = "%s\n(%d PA)" % [spell.spell_name, spell.ap_cost]
		btn.custom_minimum_size = Vector2(110, 44)
		# On capture le sort dans la lambda.
		btn.pressed.connect(func(): spell_pressed.emit(spell))
		_spell_box.add_child(btn)
		_spell_buttons.append(btn)

# ============================================================
# MISE À JOUR
# ============================================================

func update_info(unit) -> void:
	if unit == null:
		_info_label.text = ""
		return
	_info_label.text = "%s\nPA: %d  PM: %d" % [unit.unit_name, unit.current_ap, unit.current_mp]

func set_player_controls_enabled(enabled: bool) -> void:
	_move_btn.disabled = not enabled
	_attack_btn.disabled = not enabled
	_end_btn.disabled = not enabled
	for btn in _spell_buttons:
		btn.disabled = not enabled

# Met en évidence le mode actif. mode = "move", "attack", "spell", ou ""
func set_active_mode(mode: String, active_spell = null) -> void:
	_move_btn.modulate = Color(0.6, 1.0, 0.6) if mode == "move" else Color.WHITE
	_attack_btn.modulate = Color(1.0, 0.6, 0.6) if mode == "attack" else Color.WHITE
	# Surbrillance du sort actif.
	for i in _spell_buttons.size():
		var btn = _spell_buttons[i]
		btn.modulate = Color.WHITE
