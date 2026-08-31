@tool
class_name EncounterEnemyCard
extends PanelContainer

## Carte réutilisable pour un ennemi — catalogue et composition (G3). Aucune
## donnée n'est inventée : l'illustration vient uniquement de
## `UnitData.sprite_frames` ; à défaut, un remplacement neutre par initiales
## est affiché, jamais une scène de combat instanciée pour la miniature.

signal quantity_changed(value: int)
signal removed
signal add_pressed
## Double-clic sur la carte : raccourci conservé en plus du bouton explicite.
signal activated

const THUMBNAIL_SIZE := Vector2(48, 48)

var unit: UnitData = null
var enemy_catalog: Array[UnitData] = []

var _thumbnail: TextureRect
var _initials_label: Label
var _name_label: Label
var _meta_label: Label
var _stats_label: Label
var _summon_badge: Label
var _quantity_row: HBoxContainer
var _quantity_spin: SpinBox
var _add_button: Button
var _already_added_label: Label


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		activated.emit()


func configure_roster(value: UnitData, catalog: Array[UnitData], quantity: int) -> void:
	unit = value
	enemy_catalog = catalog
	if not is_node_ready():
		await ready
	_apply_common()
	_quantity_row.show()
	_add_button.hide()
	_already_added_label.hide()
	_quantity_spin.set_value_no_signal(quantity)


func configure_catalog(value: UnitData, catalog: Array[UnitData], current_quantity: int) -> void:
	unit = value
	enemy_catalog = catalog
	if not is_node_ready():
		await ready
	_apply_common()
	_quantity_row.hide()
	_add_button.show()
	if current_quantity > 0:
		_already_added_label.text = "Déjà ajouté × %d" % current_quantity
		_already_added_label.show()
	else:
		_already_added_label.hide()


func focus_add_control() -> void:
	if _add_button != null and _add_button.visible:
		_add_button.grab_focus()
	elif _quantity_spin != null and _quantity_spin.visible:
		_quantity_spin.grab_focus()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var thumb_holder := Control.new()
	thumb_holder.custom_minimum_size = THUMBNAIL_SIZE
	row.add_child(thumb_holder)
	_thumbnail = TextureRect.new()
	_thumbnail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_holder.add_child(_thumbnail)
	_initials_label = Label.new()
	_initials_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_initials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initials_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initials_label.add_theme_font_size_override("font_size", 18)
	thumb_holder.add_child(_initials_label)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 1)
	row.add_child(texts)
	_name_label = Label.new()
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 14)
	texts.add_child(_name_label)
	_meta_label = Label.new()
	_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta_label.add_theme_color_override("font_color", EncounterVisualConstants.COLOR_MUTED)
	texts.add_child(_meta_label)
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.add_theme_color_override("font_color", EncounterVisualConstants.COLOR_MUTED)
	texts.add_child(_stats_label)
	_summon_badge = Label.new()
	_summon_badge.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	_summon_badge.hide()
	texts.add_child(_summon_badge)
	_already_added_label = Label.new()
	_already_added_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	_already_added_label.hide()
	texts.add_child(_already_added_label)

	var controls := VBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(controls)
	_quantity_row = HBoxContainer.new()
	controls.add_child(_quantity_row)
	_quantity_spin = SpinBox.new()
	_quantity_spin.min_value = 1
	_quantity_spin.max_value = 99
	_quantity_spin.custom_minimum_size.x = 64
	_quantity_spin.tooltip_text = "Quantité de cet ennemi dans l'affrontement"
	_quantity_spin.value_changed.connect(func(value): quantity_changed.emit(int(value)))
	_quantity_row.add_child(_quantity_spin)
	var minus := Button.new()
	minus.text = "−"
	minus.tooltip_text = "Retirer un exemplaire"
	minus.accessibility_name = "Retirer un exemplaire"
	minus.pressed.connect(func(): quantity_changed.emit(maxi(1, int(_quantity_spin.value) - 1)))
	_quantity_row.add_child(minus)
	var plus := Button.new()
	plus.text = "+"
	plus.tooltip_text = "Ajouter un exemplaire"
	plus.pressed.connect(func(): quantity_changed.emit(int(_quantity_spin.value) + 1))
	_quantity_row.add_child(plus)
	var remove_button := Button.new()
	remove_button.text = "Retirer"
	remove_button.tooltip_text = "Retirer complètement cet ennemi de l'affrontement"
	# G6 — action destructrice : identifiable par sa couleur de texte, sans
	# dominer l'écran (pas de fond plein, pas de taille agrandie).
	EncounterVisualConstants.apply_destructive_style(remove_button)
	remove_button.pressed.connect(func(): removed.emit())
	_quantity_row.add_child(remove_button)

	_add_button = Button.new()
	_add_button.text = "Ajouter"
	_add_button.custom_minimum_size = Vector2(88, 0)
	_add_button.pressed.connect(func(): add_pressed.emit())
	controls.add_child(_add_button)


func _apply_common() -> void:
	if unit == null:
		_name_label.text = "Ennemi introuvable"
		_meta_label.text = ""
		_stats_label.text = ""
		_summon_badge.hide()
		_thumbnail.texture = null
		_initials_label.text = ""
		return
	_name_label.text = unit.unit_name
	_name_label.tooltip_text = unit.unit_name
	_meta_label.text = "%s • %s" % [
		EncounterPresentation.faction_name(unit.faction_id),
		EncounterPresentation.role_name(unit.tactical_role_id, enemy_catalog),
	]
	_stats_label.text = "PV %d • PA %d • PM %d" % [unit.max_hp, unit.max_ap, unit.max_mp]
	var has_summon := unit.spells.any(func(spell): return spell != null and spell.is_summon())
	_summon_badge.text = "INVOCATION"
	_summon_badge.visible = has_summon
	var texture := _unit_thumbnail(unit)
	_thumbnail.texture = texture
	_thumbnail.visible = texture != null
	_initials_label.visible = texture == null
	if texture == null:
		_initials_label.text = _initials(unit.unit_name)


static func _unit_thumbnail(unit: UnitData) -> Texture2D:
	if unit == null or unit.sprite_frames == null:
		return null
	var frames := unit.sprite_frames
	var animation := unit.idle_animation
	if not frames.has_animation(animation):
		var names := frames.get_animation_names()
		if names.is_empty():
			return null
		animation = names[0]
	if frames.get_frame_count(animation) <= 0:
		return null
	return frames.get_frame_texture(animation, 0)


static func _initials(unit_name: String) -> String:
	var trimmed := unit_name.strip_edges()
	if trimmed.is_empty():
		return "?"
	var parts := trimmed.split(" ", false)
	var result := ""
	for part in parts:
		if not part.is_empty():
			result += part[0].to_upper()
		if result.length() >= 2:
			break
	return result if not result.is_empty() else trimmed.substr(0, 2).to_upper()
