class_name CombatFeedbackGallery
extends Control

const FloatingTextScene := preload("res://battle/floating_text.tscn")
const SETTINGS: CombatFeedbackSettings = preload(
	"res://battle/combat_feedback/combat_feedback_settings.tres"
)

@export var legacy_preset := false

var _entries: Array[Dictionary] = []
var _instances: Array[FloatingCombatText] = []
var _preview_settings: CombatFeedbackSettings = null


func _ready() -> void:
	_preview_settings = SETTINGS.duplicate(true) as CombatFeedbackSettings
	_preview_settings.text_scale = clampf(
		minf(size.x / 1920.0, size.y / 1080.0), 0.70, 1.15
	)
	_build_gallery()
	await get_tree().process_frame
	await get_tree().process_frame
	_position_feedbacks()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_update_responsive_grid()
		_position_feedbacks.call_deferred()


func _build_gallery() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("111722")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "FEEDBACK DE COMBAT — %s" % (
		"CURRENT (RECONSTRUCTION)" if legacy_preset else "AFTER — CONTRAT RÉSOLU"
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f2d8a1"))
	layout.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Valeurs finales appliquées · map claire/sombre · variantes, AOE et files"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("aebbd0"))
	layout.add_child(subtitle)
	var grid := GridContainer.new()
	grid.name = "GalleryGrid"
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(grid)

	_add_fact_card(grid, "Dégâts 8", _fact(&"hp_damage_taken", 8))
	_add_fact_card(grid, "Dégâts 42", _fact(&"hp_damage_taken", 42, {"damage_type": 1}))
	_add_fact_card(grid, "Dégâts 125", _fact(&"hp_damage_taken", 125))
	_add_fact_card(grid, "Critique 240", _fact(&"hp_damage_taken", 240, {"is_critical": true}))
	_add_fact_card(grid, "Soin effectif 32", _fact(&"heal_received", 32, {"overheal": 18}))
	_add_fact_card(grid, "Bouclier absorbé 18", _fact(&"shield_absorbed", 0, {"amount_absorbed": 18}))
	_add_fact_card(grid, "Bouclier gagné 12", _fact(&"shield_granted", 12))
	_add_fact_card(grid, "Esquive", _fact(&"attack_dodged", 0))
	_add_fact_card(grid, "Immunité", _fact(&"attack_immune", 0))
	_add_fact_card(grid, "Poison 6", _fact(&"hp_damage_taken", 6, {"is_periodic": true, "status_id": &"poison"}))
	_add_fact_card(grid, "Brûlure 9", _fact(&"hp_damage_taken", 9, {"is_periodic": true, "status_id": &"brulure"}))
	_add_fact_card(grid, "Statut appliqué", _fact(&"status_added", 0, {"status_id": &"vulnerable"}))
	_add_fact_card(grid, "Statut expiré", _fact(&"status_expired", 0, {"status_id": &"poison"}))
	_add_fact_card(grid, "Multi-impact 3×", _fact(&"hp_damage_taken", 12), [
		_fact(&"hp_damage_taken", 9, {"sequence_index": 1}),
		_fact(&"hp_damage_taken", 7, {"sequence_index": 2}),
	])
	_add_fact_card(grid, "AOE — 3 cibles", _fact(&"hp_damage_taken", 21), [
		_fact(&"hp_damage_taken", 18, {"damage_type": 1}),
		_fact(&"hp_damage_taken", 24, {"is_critical": true}),
	], true)
	_add_fact_card(grid, "File même cible", _fact(&"shield_absorbed", 0, {"amount_absorbed": 10}), [
		_fact(&"hp_damage_taken", 30),
		_fact(&"status_added", 0, {"status_id": &"vulnerable"}),
	])
	_update_responsive_grid()


func _fact(event_type: StringName, amount: int, metadata: Dictionary = {}) -> CombatEventFact:
	var data := metadata.duplicate()
	data["amount_applied"] = amount
	return CombatEventFact.create(event_type, self, null, data)


func _add_fact_card(
		grid: GridContainer,
		title: String,
		primary: CombatEventFact,
		extra: Array = [],
		aoe_layout := false
	) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 128)
	var style := StyleBoxFlat.new()
	var light := grid.get_child_count() % 3 == 1
	style.bg_color = Color("d6d0bf") if light else Color("202938")
	style.border_color = Color("947544") if light else Color("52627a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	grid.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	card.add_child(content)
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("20242c") if light else Color("c9d2df"))
	content.add_child(caption)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(260, 92)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview)
	var facts: Array = [primary]
	facts.append_array(extra)
	var local_instances: Array[FloatingCombatText] = []
	for fact_value in facts:
		var fact := fact_value as CombatEventFact
		var floating := FloatingTextScene.instantiate() as FloatingCombatText
		preview.add_child(floating)
		floating.play_fact(
			fact, _preview_settings.style_for_fact(fact), _preview_settings,
			true, legacy_preset
		)
		_instances.append(floating)
		local_instances.append(floating)
	_entries.append({
		"preview": preview,
		"instances": local_instances,
		"aoe": aoe_layout,
	})


func _update_responsive_grid() -> void:
	var grid := find_child("GalleryGrid", true, false) as GridContainer
	if grid == null:
		return
	grid.columns = 5 if size.x >= 2100.0 else 4
	var rows := ceili(16.0 / float(grid.columns))
	var card_width := maxf(220.0, (size.x - 70.0) / float(grid.columns))
	# Reserve title/subtitle/margins and the inter-row gaps explicitly so the
	# final row stays fully inside the viewport at every baseline resolution.
	var card_height := maxf(
		118.0,
		(size.y - 165.0 - float(rows - 1) * 8.0) / float(rows)
	)
	for child in grid.get_children():
		if child is Control:
			child.custom_minimum_size = Vector2(card_width, card_height)


func _position_feedbacks() -> void:
	for entry in _entries:
		var preview := entry["preview"] as Control
		if not is_instance_valid(preview):
			continue
		var instances := entry["instances"] as Array
		# Feedback nodes are children of the preview, so their anchors are local to it.
		# Production feedback lives under a full-screen overlay where local and screen
		# coordinates coincide; the gallery deliberately uses card-local coordinates.
		var center := preview.size * 0.5
		var spread := 68.0 * _preview_settings.text_scale
		for index in instances.size():
			var floating := instances[index] as FloatingCombatText
			if not is_instance_valid(floating):
				continue
			var centered_index := float(index) - float(instances.size() - 1) * 0.5
			var offset := Vector2(
				centered_index * spread,
				(float(index % 2) * 20.0 - 10.0) * _preview_settings.text_scale
			)
			floating.screen_anchor = center + offset


func get_layout_metrics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_collect_control_metrics(self, result)
	return result


func _collect_control_metrics(node: Node, result: Array[Dictionary]) -> void:
	if node is Control:
		var control := node as Control
		result.append({
			"node_path": str(get_path_to(control)),
			"class": control.get_class(),
			"position": [control.global_position.x, control.global_position.y],
			"size": [control.size.x, control.size.y],
			"visible": control.visible,
			"minimum_size": [control.get_combined_minimum_size().x, control.get_combined_minimum_size().y],
			"text": control.text if control is Label else "",
		})
	for child in node.get_children():
		_collect_control_metrics(child, result)
