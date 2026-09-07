class_name HudGrayboxGallery
extends Control

signal gallery_ready

const HUD_SCENE := preload("res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn")
const FIXTURE_UNIT := preload("res://tools/ui_snapshots/hud_graybox_fixture_unit.gd")
const BACKDROP := preload("res://tools/ui_snapshots/hud_graybox_backdrop.gd")
const ANNOTATION := preload("res://tools/ui_snapshots/hud_graybox_annotation.gd")
const TURN_ORDER_TIMELINE_SCENE := preload("res://ui/combat/turn_order_timeline.tscn")
const LAYOUT: CombatHUDLayoutData = preload(
	"res://data/ui/combat_hud_layout_run_v1_compact.tres"
)
const PREMIUM_VISUAL_SKIN: HudVisualSkinData = preload(
	"res://data/ui/hud_visual_skin_achilles_v1.tres"
)
const PREMIUM_CHARACTER_THEME: CharacterHUDThemeData = preload(
	"res://data/ui/achilles_hud_theme_refined.tres"
)
const PREMIUM_RUN: RunData = preload("res://data/runs/odyssey.tres")
# Preserve the original damaged-health art state, not a claimed live combat value.
const PREMIUM_SYNTHETIC_HEALTH_RATIO := 86.0 / 110.0
const SKELETON_UNIT_DATA: UnitData = preload(
	"res://data/units/ennemie/skeleton_melee.tres"
)

const SPELLS: Array[Spell] = [
	preload("res://data/spells/achilles/spear_thrust.tres"),
	preload("res://data/spells/achilles/sweep.tres"),
	preload("res://data/spells/achilles/advance.tres"),
	preload("res://data/spells/achilles/guard.tres"),
]

const PLAYER_SNAPSHOT := {
	"controls_enabled": true,
	"ownership": &"player",
	"phase_name": &"PLAYER_IDLE",
	"focus_active": false,
}

@export var state_id: StringName = &"idle"
@export var premium_skin := false

var _hud: Node = null
var _fixture: HudGrayboxFixtureUnit = null
var _backdrop: HudGrayboxBackdrop = null
var _annotation: HudGrayboxAnnotation = null
var _timeline: TurnOrderTimeline = null
var _turn_queue: TurnQueue = null
var _configuration_applied := false
var _fixture_spells: Array[Spell] = []
var _source_errors := PackedStringArray()
var _premium_hero_data: UnitData = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_backdrop()
	_load_fixture_spells()
	_fixture = FIXTURE_UNIT.new() as HudGrayboxFixtureUnit
	_fixture.configure_for_state(state_id, _fixture_spells)
	_configure_premium_fixture_stats()
	_hud = HUD_SCENE.instantiate()
	_hud.skin_variant = 2
	_hud.layout_data = LAYOUT
	if premium_skin:
		var premium_character_themes: Array[CharacterHUDThemeData] = [
			PREMIUM_CHARACTER_THEME,
		]
		_hud.visual_skin = PREMIUM_VISUAL_SKIN
		_hud.character_themes = premium_character_themes
	add_child(_hud)
	if premium_skin:
		_build_premium_timeline()
	await get_tree().process_frame
	_configure_hud()
	if not premium_skin:
		_build_annotation()
	for _frame in 5:
		await get_tree().process_frame
	gallery_ready.emit()


func _load_fixture_spells() -> void:
	_fixture_spells.clear()
	_source_errors.clear()
	_premium_hero_data = null
	if not premium_skin:
		_fixture_spells.assign(SPELLS)
		return
	# Premium captures must use the same resolved loadout as the actual run,
	# not the historical four spells whose IDs no longer match production.
	var resolution := RunHeroResolver.resolve_runtime_hero_data(PREMIUM_RUN, false)
	_source_errors.append_array(resolution.errors)
	for hero_data in resolution.heroes:
		if hero_data.get_effective_unit_id() == &"achilles":
			_premium_hero_data = hero_data
			_fixture_spells.assign(hero_data.spells)
			break
	if _fixture_spells.size() != 4:
		_source_errors.append("Catabase must resolve four canonical Achilles spells.")


func _configure_premium_fixture_stats() -> void:
	if not premium_skin or _premium_hero_data == null:
		return
	_fixture.character_data = _premium_hero_data
	_fixture.unit_id = _premium_hero_data.get_effective_unit_id()
	_fixture.unit_name = _premium_hero_data.unit_name
	_fixture.sprite_frames = _premium_hero_data.sprite_frames
	_fixture.sprite_scale = _premium_hero_data.sprite_scale
	_fixture.idle_animation = _premium_hero_data.idle_animation
	_fixture.visual_scene = _premium_hero_data.visual_scene
	_fixture.preview_visual_scene = _premium_hero_data.preview_visual_scene
	_fixture.basic_attack_enabled = _premium_hero_data.basic_attack_enabled
	_fixture.max_hp.base_value = _premium_hero_data.max_hp
	_fixture.max_ap.base_value = _premium_hero_data.max_ap
	_fixture.max_mp.base_value = _premium_hero_data.max_mp
	_fixture.current_hp = roundi(_fixture.max_hp.get_int() * PREMIUM_SYNTHETIC_HEALTH_RATIO)
	_fixture.current_ap = _fixture.max_ap.get_int()
	_fixture.current_mp = _fixture.max_mp.get_int()
	if state_id == &"unavailable":
		_fixture.current_ap = mini(1, _fixture.current_ap)


func _build_premium_timeline() -> void:
	if _premium_hero_data == null:
		return
	_timeline = TURN_ORDER_TIMELINE_SCENE.instantiate() as TurnOrderTimeline
	_timeline.visual_skin = PREMIUM_VISUAL_SKIN
	add_child(_timeline)
	var achilles := Unit.from_data(_premium_hero_data)
	var skeleton := Unit.from_data(SKELETON_UNIT_DATA)
	_turn_queue = TurnQueue.new()
	_turn_queue.setup([achilles, skeleton])
	_timeline.set_reduced_motion(true)
	_timeline.apply_visual_skin(PREMIUM_VISUAL_SKIN)
	_timeline.bind_queue(_turn_queue)
	_turn_queue.start()


func _build_backdrop() -> void:
	_backdrop = BACKDROP.new() as HudGrayboxBackdrop
	_backdrop.state_id = state_id
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)


func _configure_hud() -> void:
	if _fixture_spells.size() != 4:
		return
	_hud.set_reduced_motion(true)
	_hud.set_ui_mode(0)
	_hud.update_info(_fixture)
	_hud.build_spell_buttons(_fixture)
	_hud.set_active_mode("", null)
	if state_id in [&"targeting_valid", &"targeting_invalid", &"resolving"]:
		_hud.set_active_mode("spell", _fixture_spells[0])
	_hud.apply_presentation_snapshot(_snapshot_for_state())
	match state_id:
		&"items":
			_hud._set_active_bar_mode("item")
		&"hover":
			var hovered := _spell_slot(0)
			if hovered != null:
				hovered._on_mouse_entered()
		&"selected":
			# A selection exists just before the presentation authority enters
			# PLAYER_TARGETING. Apply it after the idle snapshot so the fixture can
			# isolate the persistent selected cue from the targeting hierarchy.
			_hud.set_active_mode("spell", _fixture_spells[1])
		&"unavailable":
			_hud.show_context_feedback("PA insuffisants · 1 disponible / %d requis" % _fixture_spells[0].ap_cost, &"error")
		&"cooldown":
			_hud.show_context_feedback("%s en recharge · encore 2 activations" % _fixture_spells[2].spell_name, &"warning")
		&"locked":
			_hud.show_context_feedback("%s déjà utilisée pendant cette activation" % _fixture_spells[3].spell_name, &"info")
	_hud._apply_layout_metrics()
	_configuration_applied = true


func _snapshot_for_state() -> Dictionary:
	var snapshot := PLAYER_SNAPSHOT.duplicate(true)
	match state_id:
		&"targeting_valid":
			snapshot["phase_name"] = &"PLAYER_TARGETING"
			snapshot["selection_mode"] = &"spell"
			snapshot["focus_active"] = true
			snapshot["feedback_text"] = "Cible valide · portée %d · %d PA" % [_fixture_spells[0].spell_range, _fixture_spells[0].ap_cost]
			snapshot["feedback_kind"] = &"info"
		&"targeting_invalid":
			snapshot["phase_name"] = &"PLAYER_TARGETING"
			snapshot["selection_mode"] = &"spell"
			snapshot["focus_active"] = true
			snapshot["feedback_text"] = "Cible hors de portée · choisissez une case à %d–%d" % [_fixture_spells[0].minimum_range, _fixture_spells[0].spell_range]
			snapshot["feedback_kind"] = &"error"
		&"resolving":
			snapshot = {
				"controls_enabled": false,
				"ownership": &"system",
				"phase_name": &"RESOLVING_ACTION",
				"selection_mode": &"spell",
				"resolution_kind": &"spell",
				"focus_active": true,
				"feedback_text": "%s · résolution en cours" % _fixture_spells[0].spell_name,
				"feedback_kind": &"info",
			}
		&"enemy_turn":
			snapshot = {
				"controls_enabled": false,
				"ownership": &"enemy",
				"phase_name": &"ENEMY_TURN",
				"focus_active": false,
				"feedback_text": "Tour adverse · commandes suspendues",
				"feedback_kind": &"info",
			}
	return snapshot


func _spell_slot(index: int) -> RecraftSpellSlotView:
	var container := _hud.find_child("SpellSlotsContainer", true, false)
	if container == null or index < 0 or index >= container.get_child_count():
		return null
	return container.get_child(index) as RecraftSpellSlotView


func _build_annotation() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GrayboxAnnotation"
	layer.layer = 30
	add_child(layer)
	_annotation = ANNOTATION.new() as HudGrayboxAnnotation
	_annotation.state_id = state_id
	_annotation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_annotation)


func get_validation_metrics() -> Dictionary:
	var setup_errors := _collect_setup_errors()
	var tab_metrics := _premium_tab_metrics()
	var root := _hud.get_node_or_null("Root") as Control
	var hud_band := _hud.find_child("HudBand", true, false) as Control
	var character_anchor := _hud.find_child("CharacterAnchor", true, false) as Control
	var spell_anchor := _hud.find_child("SpellAnchor", true, false) as Control
	var turn_anchor := _hud.find_child("TurnAnchor", true, false) as Control
	var interaction_plate := _hud.find_child("SelectedSpellPlate", true, false) as Control
	var context_feedback := _hud.find_child("ContextFeedback", true, false) as Control
	var end_turn := _hud.find_child("EndTurnButton", true, false) as Control
	var utility_dock := _hud.find_child("UtilityDock", true, false) as Control
	var slot_rects: Array = []
	for index in range(4):
		var slot := _spell_slot(index)
		if slot != null:
			slot_rects.append(_rect_to_array(slot.get_global_rect()))
	return {
		"state": String(state_id),
		"loadout_source": PREMIUM_RUN.resource_path if premium_skin else "legacy_component_fixture",
		"stats_source": PREMIUM_RUN.resource_path if premium_skin else "legacy_component_fixture",
		"synthetic_availability": true,
		"synthetic_current_hp": true,
		"synthetic_health_ratio": PREMIUM_SYNTHETIC_HEALTH_RATIO if premium_skin else 86.0 / 110.0,
		"fixture_stats": {
			"max_hp": _fixture.max_hp.get_int(),
			"current_hp": _fixture.current_hp,
			"max_ap": _fixture.max_ap.get_int(),
			"current_ap": _fixture.current_ap,
			"max_mp": _fixture.max_mp.get_int(),
			"current_mp": _fixture.current_mp,
			"basic_attack_enabled": _fixture.basic_attack_enabled,
		},
		"spell_ids": _fixture_spells.map(func(spell: Spell): return String(spell.get_effective_spell_id())),
		"setup_valid": setup_errors.is_empty(),
		"setup_errors": setup_errors,
		"active_bar_mode": _hud.get_active_bar_mode(),
		"item_empty_slot_count": _empty_item_slot_count(),
		"premium_tabs_valid": tab_metrics.valid,
		"premium_tabs": tab_metrics,
		"viewport": [size.x, size.y],
		"root_rect": _rect_to_array(root.get_global_rect()) if root != null else [],
		"hud_band_rect": _rect_to_array(hud_band.get_global_rect()) if hud_band != null else [],
		"character_rect": _rect_to_array(character_anchor.get_global_rect()) if character_anchor != null else [],
		"spell_rect": _rect_to_array(spell_anchor.get_global_rect()) if spell_anchor != null else [],
		"turn_rect": _rect_to_array(turn_anchor.get_global_rect()) if turn_anchor != null else [],
		"interaction_plate_rect": _rect_to_array(interaction_plate.get_global_rect()) if interaction_plate != null else [],
		"interaction_plate_minimum": _vector_to_array(interaction_plate.get_combined_minimum_size()) if interaction_plate != null else [],
		"interaction_plate_text_fits": _label_text_fits(interaction_plate as Label),
		"interaction_plate_overflows_spell_block": _control_overflows(interaction_plate, spell_anchor),
		"interaction_plate_intersects_turn": _controls_intersect(interaction_plate, turn_anchor),
		"context_feedback_rect": _rect_to_array(context_feedback.get_global_rect()) if context_feedback != null else [],
		"context_feedback_intersects_interaction": _visible_controls_intersect(context_feedback, interaction_plate),
		"end_turn_rect": _rect_to_array(end_turn.get_global_rect()) if end_turn != null else [],
		"utility_dock_rect": _rect_to_array(utility_dock.get_global_rect()) if utility_dock != null else [],
		"end_turn_intersects_utility_dock": _visible_controls_intersect(end_turn, utility_dock),
		"spell_slot_rects": slot_rects,
		"anchors_do_not_overlap": _anchors_do_not_overlap(character_anchor, spell_anchor, turn_anchor),
		"hud_inside_viewport": _inside_viewport(hud_band),
	}


func _collect_setup_errors() -> PackedStringArray:
	var errors := _source_errors.duplicate()
	if not _configuration_applied:
		errors.append("HUD configuration did not reach its completion marker.")
	if _hud == null or _fixture == null:
		errors.append("Missing HUD or Unit fixture.")
		return errors
	if _hud.get("_current_unit") != _fixture:
		errors.append("HUD is not bound to the requested Unit fixture.")
	var identity := _hud.find_child("CharacterName", true, false) as Label
	var expected_name := CombatGlossary.unit_display_name(_fixture)
	if premium_skin:
		expected_name = expected_name.to_upper()
	if identity == null or identity.text != expected_name:
		errors.append("Character identity was not populated by update_info().")
	var health := _hud.find_child("HealthBar", true, false)
	if health == null or health.get("current_value") != float(_fixture.current_hp) \
		or health.get("maximum_value") != float(_fixture.max_hp.get_int()):
		errors.append("Health values do not match the Unit fixture.")
	for badge_case: Dictionary in [
		{"node": "ActionPointsBadge", "value": _fixture.current_ap},
		{"node": "MovementPointsBadge", "value": _fixture.current_mp},
	]:
		var badge := _hud.find_child(badge_case.node, true, false)
		var value_label := badge.find_child("ValueLabel", true, false) as Label \
			if badge != null else null
		if value_label == null or value_label.text != str(badge_case.value):
			errors.append("Resource badge is incomplete: %s." % badge_case.node)
	var slot_container := _hud.find_child("SpellSlotsContainer", true, false)
	if slot_container == null or slot_container.get_child_count() != _fixture_spells.size():
		errors.append("Expected exactly four populated spell slots.")
	else:
		for index in _fixture_spells.size():
			var slot := _spell_slot(index)
			if slot == null or slot.spell != _fixture_spells[index]:
				errors.append("Spell slot %d does not contain its fixture spell." % index)
			elif premium_skin:
				var expected_icon := PREMIUM_CHARACTER_THEME.get_spell_icon(_fixture_spells[index].get_effective_spell_id())
				if expected_icon == null or slot.get_displayed_icon() != expected_icon:
					errors.append("Canonical spell %d is missing its explicit premium icon binding." % index)
	if premium_skin and (_timeline == null or _timeline.get_card_count() != 2):
		errors.append("Premium timeline does not contain both fixture units.")
	if state_id == &"items":
		if _hud.get_active_bar_mode() != "item":
			errors.append("The items fixture did not switch to the item bar.")
		if _empty_item_slot_count() != 4:
			errors.append("The items fixture must contain four empty item slots.")
	return errors


func _empty_item_slot_count() -> int:
	var container := _hud.find_child("ItemSlotsContainer", true, false)
	if container == null:
		return 0
	var count := 0
	for child in container.get_children():
		var item_slot := child as RecraftItemSlotView
		if item_slot != null and item_slot.is_empty_slot():
			count += 1
	return count


func _premium_tab_metrics() -> Dictionary:
	var metrics := {
		"applicable": premium_skin,
		"valid": true,
		"visible": true,
		"inside_viewport": true,
		"do_not_overlap_each_other": true,
		"do_not_overlap_active_slots": true,
		"do_not_overlap_content": true,
		"spell_tab_rect": [],
		"item_tab_rect": [],
	}
	if not premium_skin:
		return metrics
	var spell_tab := _hud.find_child("ShowSpellsButton", true, false) as Control
	var item_tab := _hud.find_child("ShowItemsButton", true, false) as Control
	metrics.visible = spell_tab != null and item_tab != null \
		and spell_tab.is_visible_in_tree() and item_tab.is_visible_in_tree()
	if not metrics.visible:
		metrics.valid = false
		return metrics
	metrics.spell_tab_rect = _rect_to_array(spell_tab.get_global_rect())
	metrics.item_tab_rect = _rect_to_array(item_tab.get_global_rect())
	metrics.inside_viewport = _inside_viewport(spell_tab) and _inside_viewport(item_tab)
	metrics.do_not_overlap_each_other = not _controls_intersect(spell_tab, item_tab)
	var active_container_name := "ItemSlotsContainer" \
		if _hud.get_active_bar_mode() == "item" else "SpellSlotsContainer"
	var active_container := _hud.find_child(active_container_name, true, false)
	if active_container == null:
		metrics.do_not_overlap_active_slots = false
	else:
		for child in active_container.get_children():
			var slot := child as Control
			if _visible_controls_intersect(spell_tab, slot) \
				or _visible_controls_intersect(item_tab, slot):
				metrics.do_not_overlap_active_slots = false
	for control_name in [
		"CharacterName", "HealthBar", "ActionPointsBadge", "MovementPointsBadge",
		"UtilityDock", "EndTurnButton", "SelectedSpellPlate", "ContextFeedback",
	]:
		var control := _hud.find_child(control_name, true, false) as Control
		if _visible_controls_intersect(spell_tab, control) \
			or _visible_controls_intersect(item_tab, control):
			metrics.do_not_overlap_content = false
	metrics.valid = metrics.visible and metrics.inside_viewport \
		and metrics.do_not_overlap_each_other and metrics.do_not_overlap_active_slots \
		and metrics.do_not_overlap_content
	return metrics


func _anchors_do_not_overlap(character: Control, spells_control: Control, turn: Control) -> bool:
	if character == null or spells_control == null or turn == null:
		return false
	return (
		not character.get_global_rect().intersects(spells_control.get_global_rect())
		and not spells_control.get_global_rect().intersects(turn.get_global_rect())
		and not character.get_global_rect().intersects(turn.get_global_rect())
	)


func _inside_viewport(control: Control) -> bool:
	if control == null:
		return false
	var viewport_rect := Rect2(Vector2.ZERO, size)
	return viewport_rect.encloses(control.get_global_rect())


func _control_overflows(control: Control, parent_control: Control) -> bool:
	if control == null or parent_control == null:
		return false
	return not parent_control.get_global_rect().encloses(control.get_global_rect())


func _label_text_fits(label: Label) -> bool:
	if label == null:
		return false
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var available_width := label.size.x
	var style := label.get_theme_stylebox("normal")
	if style != null:
		available_width -= style.get_minimum_size().x
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= available_width


func _controls_intersect(first: Control, second: Control) -> bool:
	return (
		first != null
		and second != null
		and first.get_global_rect().intersects(second.get_global_rect())
	)


func _visible_controls_intersect(first: Control, second: Control) -> bool:
	return (
		first != null
		and second != null
		and first.is_visible_in_tree()
		and second.is_visible_in_tree()
		and first.get_global_rect().intersects(second.get_global_rect())
	)


func _rect_to_array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _vector_to_array(value: Vector2) -> Array:
	return [value.x, value.y]
