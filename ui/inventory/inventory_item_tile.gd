class_name InventoryItemTile
extends Button

signal inventory_item_requested(instance_id: StringName)
signal equipment_slot_requested(slot: int)

@onready var accent_rail: ColorRect = %AccentRail
@onready var icon_view: TextureRect = %Icon
@onready var title_label: Label = %ItemTitle
@onready var meta_label: Label = %ItemMeta
@onready var quantity_label: Label = %Quantity
@onready var state_glyph: Label = %StateGlyph

var instance_id: StringName = &""
var equipment_slot := ItemDefinition.EquipmentSlot.NONE
var _hover_tween: Tween = null
static var _presentation_icon_cache: Dictionary = {}


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle_mode = true
	clip_contents = true
	theme_type_variation = &"PremiumTileButton"
	for color_name in [
		&"font_color", &"font_hover_color", &"font_focus_color",
		&"font_pressed_color", &"font_disabled_color",
	]:
		add_theme_color_override(color_name, Color.TRANSPARENT)
	pressed.connect(_on_pressed)
	mouse_entered.connect(_animate_emphasis.bind(true))
	mouse_exited.connect(_animate_emphasis.bind(false))
	focus_entered.connect(_animate_emphasis.bind(true))
	focus_exited.connect(_animate_emphasis.bind(false))
	resized.connect(_update_pivot)
	_update_pivot()


func configure_inventory(
		slot_index: int,
		instance: ItemInstance,
		definition: ItemDefinition,
		selected: bool,
		compatible := true
	) -> void:
	equipment_slot = ItemDefinition.EquipmentSlot.NONE
	instance_id = instance.instance_id if instance != null else &""
	button_pressed = selected and instance != null
	if instance == null:
		disabled = true
		text = "Emplacement %02d — vide" % (slot_index + 1)
		title_label.text = "LIBRE"
		meta_label.text = "EMPLACEMENT %02d" % (slot_index + 1)
		meta_label.theme_type_variation = &"PremiumMuted"
		meta_label.modulate = Color.WHITE
		icon_view.texture = null
		quantity_label.hide()
		state_glyph.text = "·"
		state_glyph.modulate = PremiumUI.SKIN.text_muted
		accent_rail.color = PremiumUI.SKIN.border_subtle_color
		tooltip_text = ""
		return
	disabled = false
	var item_name := definition.display_name if definition != null else str(instance.definition_id)
	var relic := definition != null and definition.is_relic()
	text = "%s\n%s" % [item_name, "Relique active" if relic else "Objet disponible"]
	title_label.text = item_name.to_upper()
	title_label.theme_type_variation = &"PremiumSubtitle"
	var rarity := definition.rarity if definition != null else &"common"
	meta_label.text = "RELIQUE ACTIVE" if relic else PremiumUI.rarity_label(rarity)
	meta_label.theme_type_variation = &"PremiumEyebrow"
	meta_label.modulate = PremiumUI.rarity_color(rarity)
	icon_view.texture = presentation_icon(definition)
	quantity_label.text = "×%d" % instance.quantity
	quantity_label.visible = instance.quantity > 1
	state_glyph.text = "◆" if selected else ("×" if not compatible else "")
	state_glyph.modulate = (
		PremiumUI.SKIN.border_selected_color
		if selected else Color(0.92, 0.34, 0.26, 1.0)
	)
	accent_rail.color = PremiumUI.rarity_color(rarity)
	tooltip_text = definition.description if definition != null else ""


func configure_equipment(
		slot: int,
		instance: ItemInstance,
		definition: ItemDefinition,
		selected: bool
	) -> void:
	equipment_slot = slot
	instance_id = &""
	disabled = false
	button_pressed = selected
	custom_minimum_size = Vector2(0.0, 70.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slot_name := EquipmentLoadout.get_slot_display_name(slot).to_upper()
	var item_name := definition.display_name if definition != null else "Emplacement libre"
	text = "%s : %s" % [slot_name, item_name]
	title_label.text = item_name.to_upper()
	meta_label.text = slot_name
	meta_label.theme_type_variation = &"PremiumEyebrow"
	meta_label.modulate = (
		PremiumUI.SKIN.text_secondary
		if definition != null else PremiumUI.SKIN.text_muted
	)
	icon_view.texture = presentation_icon(definition)
	quantity_label.hide()
	state_glyph.text = "◆" if selected else ("◇" if definition == null else "")
	state_glyph.modulate = (
		PremiumUI.SKIN.border_selected_color
		if selected else PremiumUI.SKIN.text_muted
	)
	accent_rail.color = (
		PremiumUI.rarity_color(definition.rarity)
		if definition != null else PremiumUI.SKIN.border_subtle_color
	)
	tooltip_text = definition.description if definition != null else "Emplacement libre"


func _on_pressed() -> void:
	if equipment_slot != ItemDefinition.EquipmentSlot.NONE:
		equipment_slot_requested.emit(equipment_slot)
	elif instance_id != &"":
		inventory_item_requested.emit(instance_id)


func _animate_emphasis(enabled: bool) -> void:
	if disabled:
		enabled = false
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(
		self, "scale", Vector2.ONE * (1.018 if enabled else 1.0), 0.1
	)
	_hover_tween.tween_property(
		self,
		"modulate",
		Color(1.04, 1.02, 0.96, 1.0) if enabled else Color.WHITE,
		0.1
	)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


static func presentation_icon(definition: ItemDefinition) -> Texture2D:
	if definition == null:
		return null
	var source := definition.get_inventory_icon()
	if source == null:
		return null
	var cache_key := source.get_instance_id()
	if _presentation_icon_cache.has(cache_key):
		return _presentation_icon_cache[cache_key] as Texture2D
	# Les dimensions de Texture2D suffisent pour distinguer les anciennes
	# planches horizontales. Éviter get_image() garde ce chemin sans lecture
	# CPU ni décompression au premier affichage de l'inventaire.
	var width := source.get_width()
	var height := source.get_height()
	if width <= 0 or height <= 0:
		_presentation_icon_cache[cache_key] = source
		return source
	if float(width) / maxf(1.0, float(height)) < 1.3:
		_presentation_icon_cache[cache_key] = source
		return source
	# Les anciennes planches placent l'illustration utile au centre d'un canvas
	# horizontal. Un AtlasTexture evite de dupliquer ou de deteriorer ces sources.
	var side := mini(int(round(width * 0.23)), int(round(height * 0.42)))
	var region := Rect2(
		Vector2(width * 0.39, height * 0.21),
		Vector2(side, side)
	)
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = region
	cropped.filter_clip = true
	_presentation_icon_cache[cache_key] = cropped
	return cropped
