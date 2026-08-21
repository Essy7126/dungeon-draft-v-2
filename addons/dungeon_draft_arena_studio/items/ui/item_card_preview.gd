@tool
class_name ItemCardPreview
extends PanelContainer

const MUTED_COLOR := Color(0.72, 0.77, 0.84)
const COMPACT_THUMBNAIL := Vector2(64, 84)

var compact := false: set = set_compact

var texture_rect: TextureRect
var name_label: Label
var rarity_label: Label
var description_label: Label
var _definition: ItemDefinition = null


func _ready() -> void:
	_rebuild()


func set_compact(value: bool) -> void:
	if compact == value:
		return
	compact = value
	if is_node_ready():
		_rebuild()


func show_definition(definition: ItemDefinition) -> void:
	_definition = definition
	if texture_rect == null:
		return
	texture_rect.texture = definition.get_reward_card_texture() if definition != null else null
	texture_rect.visible = not compact or texture_rect.texture != null
	name_label.text = definition.display_name if definition != null else "Aucun objet"
	rarity_label.text = str(definition.rarity).to_upper() if definition != null else ""
	if description_label == null:
		return
	description_label.text = definition.description if definition != null \
		else "Sélectionnez un objet dans le catalogue."
	if definition != null and definition.is_relic():
		var summaries: Array[String] = []
		var registry := RelicEffectRegistry.new()
		for effect in definition.reactive_effects:
			if effect != null:
				summaries.append(registry.summarize(effect))
		description_label.text += "\n\nACTIVE POUR LA RUN\n" + "\n".join(summaries)


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	description_label = null
	if compact:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		custom_minimum_size.y = 0
		_build_compact()
	else:
		remove_theme_stylebox_override("panel")
		custom_minimum_size.y = 210
		_build_full()
	show_definition(_definition)


func _build_compact() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = COMPACT_THUMBNAIL
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.tooltip_text = "Carte de récompense telle que la voit le joueur"
	row.add_child(texture_rect)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	texts.add_child(name_label)
	rarity_label = Label.new()
	rarity_label.add_theme_color_override("font_color", MUTED_COLOR)
	texts.add_child(rarity_label)


func _build_full() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(0, 120)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(texture_rect)
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 17)
	root.add_child(name_label)
	rarity_label = Label.new()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_color_override("font_color", MUTED_COLOR)
	root.add_child(rarity_label)
	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.add_theme_color_override("font_color", MUTED_COLOR)
	root.add_child(description_label)
