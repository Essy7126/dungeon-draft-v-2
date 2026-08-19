@tool
class_name ItemCardPreview
extends PanelContainer

var texture_rect: TextureRect
var name_label: Label
var rarity_label: Label
var description_label: Label


func _ready() -> void:
	custom_minimum_size.y = 190
	var root := VBoxContainer.new()
	add_child(root)
	var title := Label.new()
	title.text = "APERÇU DE CARTE"
	root.add_child(title)
	texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(0, 90)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(texture_rect)
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 17)
	root.add_child(name_label)
	rarity_label = Label.new()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(rarity_label)
	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(description_label)


func show_definition(definition: ItemDefinition) -> void:
	if texture_rect == null:
		return
	texture_rect.texture = definition.get_reward_card_texture() if definition != null else null
	name_label.text = definition.display_name if definition != null else "Aucun objet"
	rarity_label.text = str(definition.rarity).to_upper() if definition != null else ""
	description_label.text = definition.description if definition != null else "Sélectionnez un objet dans le catalogue."
	if definition != null and definition.is_relic():
		var summaries: Array[String] = []
		var registry := RelicEffectRegistry.new()
		for effect in definition.reactive_effects:
			if effect != null:
				summaries.append(registry.summarize(effect))
		description_label.text += "\n\nACTIVE POUR LA RUN\n" + "\n".join(summaries)
