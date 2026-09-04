class_name EquipmentRewardPresentationLab
extends Control

const CATALOG := preload("res://data/items/catalogs/default_item_catalog.tres")
const REWARD_IDS := [
	&"cendres_du_phenix", &"chaines_de_promethee",
	&"croc_de_cerbere", &"fureur_d_ares", &"lyre_d_orphee",
	&"plume_de_nike", &"sablier_de_chronos", &"sandales_d_hermes",
]

@export var show_debug_controls := true

@onready var overlay: EquipmentRewardOverlay = %EquipmentRewardOverlay
@onready var toolbar: PanelContainer = %Toolbar
@onready var status_label: Label = %StatusLabel

var first_index := 0
var second_index := 5
var reduced_motion := false
var inventory_full := false
var missing_texture := false
var bad_margins := false


func _ready() -> void:
	toolbar.visible = show_debug_controls
	overlay.confirmation_requested.connect(_on_confirmation_requested)
	open_overlay()


func open_overlay() -> void:
	var options := _build_options()
	overlay.present(options, reduced_motion)
	_update_status()


func select_left() -> void:
	overlay.select_item_by_id(overlay.get_card(0).item_id)


func select_right() -> void:
	overlay.select_item_by_id(overlay.get_card(1).item_id)


func simulate_hover(card_index: int, hovered: bool) -> void:
	var card := overlay.get_card(card_index)
	if card == null:
		return
	if hovered:
		card.interaction.mouse_entered.emit()
	else:
		card.interaction.mouse_exited.emit()


func confirm_selection() -> void:
	overlay.request_confirmation()


func set_resolution_for_lab(viewport_size: Vector2i) -> void:
	get_window().size = viewport_size
	overlay.apply_viewport_size_for_test(viewport_size)


func set_reduced_motion_for_lab(value: bool) -> void:
	reduced_motion = value
	open_overlay()


func set_missing_texture_for_lab(value: bool) -> void:
	missing_texture = value
	bad_margins = false
	open_overlay()


func set_bad_margins_for_lab(value: bool) -> void:
	bad_margins = value
	missing_texture = false
	open_overlay()


func set_inventory_full_for_lab(value: bool) -> void:
	inventory_full = value
	open_overlay()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			set_resolution_for_lab(Vector2i(1280, 720))
		KEY_F2:
			set_resolution_for_lab(Vector2i(1920, 1080))
		KEY_F3:
			set_resolution_for_lab(Vector2i(2560, 1440))
		KEY_R:
			set_reduced_motion_for_lab(not reduced_motion)
		KEY_M:
			set_missing_texture_for_lab(not missing_texture)
		KEY_A:
			set_bad_margins_for_lab(not bad_margins)
		KEY_O:
			set_inventory_full_for_lab(not inventory_full)
		KEY_Q:
			first_index = posmod(first_index - 1, REWARD_IDS.size())
			open_overlay()
		KEY_E:
			second_index = posmod(second_index + 1, REWARD_IDS.size())
			open_overlay()


func _build_options() -> Array[Dictionary]:
	var first := CATALOG.get_definition(REWARD_IDS[first_index])
	var second := CATALOG.get_definition(REWARD_IDS[second_index])
	if first == second:
		second_index = (second_index + 1) % REWARD_IDS.size()
		second = CATALOG.get_definition(REWARD_IDS[second_index])
	if missing_texture:
		first = _missing_definition()
	elif bad_margins:
		first = _bad_margin_definition()
	return [
		{
			"reward_id": first.item_id,
			"item_id": first.item_id,
			"definition": first,
			"compatible_character_ids": [&"elf", &"mage", &"warrior"],
		},
		{
			"reward_id": second.item_id,
			"item_id": second.item_id,
			"definition": second,
			"compatible_character_ids": [&"elf", &"mage", &"warrior"],
		},
	]


func _missing_definition() -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.item_id = &"lab_missing_texture"
	definition.display_name = "Vestige sans image"
	definition.description = "Le fallback reste lisible et sélectionnable."
	definition.category = ItemDefinition.Category.ACCESSORY
	definition.equipment_slot = ItemDefinition.EquipmentSlot.ACCESSORY
	return definition


func _bad_margin_definition() -> ItemDefinition:
	var image := Image.create(1000, 1000, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.005, 0.005, 0.005, 1.0))
	image.fill_rect(Rect2i(330, 90, 340, 820), Color(0.42, 0.27, 0.13, 1.0))
	var definition := _missing_definition()
	definition.item_id = &"lab_bad_margins"
	definition.display_name = "Carte à marges opaques"
	definition.card_texture = ImageTexture.create_from_image(image)
	return definition


func _on_confirmation_requested(_item_id: StringName) -> void:
	if inventory_full:
		overlay.resolve_confirmation(false, "Inventaire plein — aucun objet n’a été perdu.")
	else:
		overlay.resolve_confirmation(true)


func _update_status() -> void:
	status_label.text = (
		"F1/F2/F3 résolution · Q/E cartes · R mouvement réduit · "
		+ "M texture absente · A marges opaques · O inventaire plein\n"
		+ "reduced_motion=%s · missing=%s · bad_margins=%s · inventory_full=%s"
	) % [reduced_motion, missing_texture, bad_margins, inventory_full]
