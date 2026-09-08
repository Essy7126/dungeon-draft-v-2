extends Control
## One previewable reward. The expedition screen owns selection and confirmation.

signal choice_requested(reward_id: String)

const CARD_SCENE := preload("res://ui/post_combat/RewardCardChoice.tscn")
const ART_THEME := preload("res://ui/expedition/catabase_ui_theme.gd")

var interaction: Button
var reward_id := ""
var _card: RewardCardChoice
var _item_definition: ItemDefinition
var _offer: Dictionary = {}
var _index := 0
var _reduced_motion := false
var _selected := false
var _locked := false
var _extent := Vector2(270, 390)
var _authored_readout: PanelContainer
var _authored_effect: Label
var _authored_destination: Label


func _ready() -> void:
	custom_minimum_size = _extent
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	_card = CARD_SCENE.instantiate() as RewardCardChoice
	_card.name = "CollectibleCard"
	add_child(_card)
	_card.theme = ART_THEME.get_theme()
	interaction = _card.interaction
	interaction.toggle_mode = true
	# The invisible hit area must never paint over the illustrated card.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		interaction.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_card.choice_requested.connect(_on_choice_requested)
	_create_authored_readout()
	_card.resized.connect(_fit_content)
	if not GameManager.reduced_motion_changed.is_connected(_on_reduced_motion_changed):
		GameManager.reduced_motion_changed.connect(_on_reduced_motion_changed)
	_render_offer()


func configure(offer: Dictionary, index: int, reduced_motion: bool) -> void:
	_offer = offer.duplicate()
	_index = index
	_reduced_motion = reduced_motion
	reward_id = str(offer.get("id", offer.get("reward_id", "")))
	set_meta("reward_id", reward_id)
	if is_instance_valid(_card):
		_render_offer()


func set_selected(value: bool) -> void:
	_selected = value
	set_meta("selected", value)
	if not is_instance_valid(_card):
		return
	interaction.set_pressed_no_signal(value)
	_card.set_selected(value)
	_card.selection_badge.text = "✓"
	_update_accessible_copy()


func set_locked(value: bool) -> void:
	_locked = value
	if is_instance_valid(_card):
		_card.set_locked(value)


func set_card_extent(extent: Vector2) -> void:
	_extent = Vector2(maxf(245, extent.x), maxf(360, extent.y))
	custom_minimum_size = _extent
	size = _extent
	if is_instance_valid(_card):
		_card.set_card_size(_extent)
		_fit_content()


func grab_card_focus() -> void:
	if is_instance_valid(interaction):
		interaction.grab_focus()


func _render_offer() -> void:
	if _offer.is_empty():
		return
	var definition := _offer.get("definition") as ItemDefinition
	if definition == null and _offer.has("item_id") and GameManager.item_catalog != null:
		definition = GameManager.item_catalog.get_definition(StringName(_offer.item_id))
	_item_definition = definition
	var presentation := definition
	if presentation == null:
		presentation = ItemDefinition.new()
		presentation.display_name = str(_offer.get("title", "Récompense"))
		presentation.description = str(_offer.get("description", ""))
		presentation.icon = _offer.get("icon") as Texture2D
		if presentation.icon == null:
			presentation.icon = _fallback_icon()
	_card.configure({"item_id": StringName(reward_id), "definition": presentation}, _index, _reduced_motion)
	if _card.fallback_icon.texture == null:
		_card.fallback_icon.texture = ART_THEME.icon("nav", "equipment")
	# Retain the shared card's lift, gold selection glow and restrained particles;
	# align resting cards so reading and comparing their effects stays easy.
	_card.set("_rest_rotation", 0.0)
	_card.set("_float_phase", float(_index) * 1.3)
	_card.set_card_size(_extent)
	_card.fallback_meta.text = _category(definition)
	_card.fallback_title.text = str(_offer.get("title", presentation.display_name))
	_card.fallback_description.text = _summary(definition)
	_card.fallback_footer.text = _destination(definition)
	_authored_readout.visible = _card.card_texture.visible
	_authored_effect.text = _card.fallback_description.text
	_authored_destination.text = _card.fallback_footer.text
	_card.fallback_footer.add_theme_color_override("font_color", ART_THEME.TEAL)
	_card.selection_badge.text = "✓"
	_card.selection_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction.name = "RewardOption_%d" % _index
	interaction.set_meta("reward_id", reward_id)
	interaction.focus_mode = Control.FOCUS_ALL
	var particle_material := _card.particles.process_material.duplicate() as ParticleProcessMaterial
	particle_material.emission_box_extents = Vector3(_extent.x * 0.42, _extent.y * 0.42, 1)
	_card.particles.process_material = particle_material
	_card.particles.amount = 10
	_card.particles.visible = not _reduced_motion
	_fit_content()
	set_selected(_selected)
	set_locked(_locked)
	_update_accessible_copy()


func _fit_content() -> void:
	if not is_instance_valid(_card):
		return
	var small := _extent.y < 390
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_card.fallback_margin.add_theme_constant_override(side, 14)
	_card.fallback_content.add_theme_constant_override("separation", 7)
	_card.illustration_frame.custom_minimum_size.y = 105 if small else 128
	_card.illustration_frame.size_flags_vertical = Control.SIZE_FILL
	_card.fallback_meta.add_theme_font_size_override("font_size", 12)
	_card.fallback_title.add_theme_font_size_override("font_size", 20)
	_card.fallback_title.add_theme_font_override("font", PremiumUI.SKIN.font_regular)
	_card.fallback_title.max_lines_visible = 2
	_card.fallback_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_card.fallback_description.add_theme_font_size_override("font_size", 15)
	_card.fallback_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_card.fallback_description.max_lines_visible = 5
	_card.fallback_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_card.fallback_footer.add_theme_font_size_override("font_size", 12)
	_card.fallback_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.selection_badge.add_theme_font_size_override("font_size", 12)
	_card.selection_badge.offset_left = -36
	_card.selection_badge.offset_right = -2
	_card.selection_badge.offset_top = -12
	_card.selection_badge.offset_bottom = 16
	_card.particles.visibility_rect = Rect2(-_extent * 0.6, _extent * 1.2)


func _summary(definition: ItemDefinition) -> String:
	if is_known_technique_compensation():
		return "Vous connaissez déjà cette technique. Recevez 40 oboles pour vos prochains achats."
	if _offer.has("beginner_summary"):
		return str(_offer.beginner_summary)
	match reward_id:
		"supplies": return "+40 oboles à dépenser chez le marchand. Récupérez 5 % de vos PV maximum."
		"rest": return "Récupérez 30 % de vos PV maximum."
		"wager": return "+100 oboles, contre 15 % de vos PV maximum. Il faut assez de vie pour payer."
		"scout": return "+25 oboles et un passage secret révélé sur la carte."
	if _offer.has("branch_id"):
		return "Ouvre une nouvelle branche de compétences. Dépensez ensuite vos points de destin pour y apprendre des techniques."
	var description := str(_offer.get("description", ""))
	if description.is_empty() and definition != null:
		description = definition.description
	return description


func _category(definition: ItemDefinition) -> String:
	if is_known_technique_compensation():
		return "COMPENSATION · OBOLES"
	if definition != null:
		match definition.category:
			ItemDefinition.Category.WEAPON: return "ARME · OBJET"
			ItemDefinition.Category.ARMOR: return "ARMURE · OBJET"
			ItemDefinition.Category.ACCESSORY: return "ACCESSOIRE · OBJET"
			ItemDefinition.Category.RELIC: return "RELIQUE"
			_: return "CONSOMMABLE"
	if _offer.has("spell_id"):
		return "NOUVELLE TECHNIQUE"
	if _offer.has("branch_id"):
		return "NOUVELLE BRANCHE"
	match reward_id:
		"wager": return "PARI · COÛT EN VIE"
		"rest": return "SOIN"
		"scout": return "EXPLORATION"
		"supplies": return "OR & SOIN"
		_: return "RÉCOMPENSE"


func _destination(definition: ItemDefinition) -> String:
	if is_known_technique_compensation():
		return "+40 oboles à la validation"
	if definition != null:
		if definition.is_relic():
			return "À activer en combat" if definition.has_manual_activation() else "Effet automatique pendant la run"
		if definition.is_consumable():
			return "Inventaire · à utiliser au bon moment"
		return "Inventaire · à équiper ensuite"
	if _offer.has("spell_id"):
		return "Compétences · à équiper ensuite"
	if _offer.has("branch_id"):
		return "Compétences · nouvelles possibilités"
	return "Appliqué après votre validation"


func _fallback_icon() -> Texture2D:
	if is_known_technique_compensation():
		return ART_THEME.icon("resources", "oboles")
	if _offer.has("spell_id") and GameManager.expedition != null:
		var spell := GameManager.expedition.build.catalog.get_spell(str(_offer.spell_id))
		if spell != null and spell.icon != null:
			return spell.icon
	if _offer.has("branch_id"):
		return ART_THEME.icon("nav", "tree")
	if reward_id == "rest":
		return ART_THEME.icon("resources", "health")
	if reward_id == "scout":
		return ART_THEME.icon("nav", "map")
	return ART_THEME.icon("resources", "oboles")


func _update_accessible_copy() -> void:
	if not is_instance_valid(interaction):
		return
	var action := "Sélectionnée. Validez votre choix en bas de l'écran." if _selected else "Sélectionnez cette carte pour la comparer, puis validez votre choix."
	interaction.tooltip_text = "%s\n%s\n%s\n%s" % [
		str(_offer.get("title", "Récompense")), str(_offer.get("description", "")),
		_card.fallback_footer.text, action,
	]
	# Godot exposes the full card as one keyboard target with an explicit name.
	interaction.accessibility_name = str(_offer.get("title", "Récompense"))
	interaction.accessibility_description = interaction.tooltip_text


func _on_choice_requested(_item_id: StringName) -> void:
	if not _locked:
		choice_requested.emit(reward_id)


func _create_authored_readout() -> void:
	# Legacy card paintings can contain old rules text. Keep their illustration,
	# and cover that text with the current run's authoritative effect and usage.
	_authored_readout = PanelContainer.new()
	_authored_readout.name = "CurrentRewardEffect"
	_authored_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visual_root.add_child(_authored_readout)
	_authored_readout.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_authored_readout.anchor_top = 0.60
	_authored_readout.offset_left = 7
	_authored_readout.offset_top = 0
	_authored_readout.offset_right = -7
	_authored_readout.offset_bottom = -7
	var backing := StyleBoxFlat.new()
	backing.bg_color = ART_THEME.INK
	backing.border_color = ART_THEME.BRONZE
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(5)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		backing.set_content_margin(side, 10)
	_authored_readout.add_theme_stylebox_override("panel", backing)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 7)
	_authored_readout.add_child(column)
	_authored_effect = Label.new()
	_authored_effect.name = "CurrentEffect"
	_authored_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_authored_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_authored_effect.add_theme_font_size_override("font_size", 14)
	_authored_effect.add_theme_color_override("font_color", ART_THEME.TEXT)
	_authored_effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_authored_effect.max_lines_visible = 4
	_authored_effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_authored_effect)
	_authored_destination = Label.new()
	_authored_destination.name = "RewardDestination"
	_authored_destination.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_authored_destination.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_authored_destination.add_theme_font_size_override("font_size", 12)
	_authored_destination.add_theme_color_override("font_color", ART_THEME.TEAL)
	column.add_child(_authored_destination)

func _exit_tree() -> void:
	if is_instance_valid(GameManager) and GameManager.reduced_motion_changed.is_connected(_on_reduced_motion_changed):
		GameManager.reduced_motion_changed.disconnect(_on_reduced_motion_changed)


func _on_reduced_motion_changed(enabled: bool) -> void:
	_reduced_motion = enabled
	if not is_instance_valid(_card):
		return
	_card.reduced_motion = enabled
	# Settle an in-flight hover/entrance immediately. Do not reconfigure the offer:
	# selection, focus, item art and the confirmation preview must stay unchanged.
	for property_name in ["_state_tween", "_entrance_tween"]:
		var animation := _card.get(property_name) as Tween
		if animation != null and animation.is_valid():
			animation.kill()
		_card.set(property_name, null)
	_card.modulate.a = 1.0
	_card.floating_root.position.y = 0.0
	_card.particles.visible = not enabled
	_card.particles.emitting = _selected and not _locked and not enabled
	_card.call("_refresh_state", false)

func get_destination_summary() -> String:
	return _destination(_item_definition)


func is_known_technique_compensation() -> bool:
	if not _offer.has("spell_id") or GameManager.expedition == null:
		return false
	var session := GameManager.expedition
	var spell := session.build.catalog.get_spell(str(_offer.spell_id))
	if spell == null:
		return false
	# Same rule as ExpeditionSession._spell_card; claim grants 40 oboles.
	return session.character.loadout.knows_spell_id(spell.get_effective_spell_id())