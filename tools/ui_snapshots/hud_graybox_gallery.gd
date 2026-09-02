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
const ACHILLES_UNIT_DATA: UnitData = preload("res://data/units/allies/achilles.tres")
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_backdrop()
	_fixture = FIXTURE_UNIT.new() as HudGrayboxFixtureUnit
	_fixture.configure_for_state(state_id, SPELLS)
	add_child(_fixture)
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


func _build_premium_timeline() -> void:
	_timeline = TURN_ORDER_TIMELINE_SCENE.instantiate() as TurnOrderTimeline
	_timeline.visual_skin = PREMIUM_VISUAL_SKIN
	add_child(_timeline)
	var achilles := Unit.from_data(ACHILLES_UNIT_DATA)
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
	_hud.set_reduced_motion(true)
	_hud.set_ui_mode(0)
	_hud.update_info(_fixture)
	_hud.build_spell_buttons(_fixture)
	_hud.set_active_mode("", null)
	if state_id in [&"targeting_valid", &"targeting_invalid", &"resolving"]:
		_hud.set_active_mode("spell", SPELLS[0])
	_hud.apply_presentation_snapshot(_snapshot_for_state())
	match state_id:
		&"hover":
			var hovered := _spell_slot(0)
			if hovered != null:
				hovered._on_mouse_entered()
		&"selected":
			# A selection exists just before the presentation authority enters
			# PLAYER_TARGETING. Apply it after the idle snapshot so the fixture can
			# isolate the persistent selected cue from the targeting hierarchy.
			_hud.set_active_mode("spell", SPELLS[1])
		&"unavailable":
			_hud.show_context_feedback("PA insuffisants · 1 disponible / 3 requis", &"error")
		&"cooldown":
			_hud.show_context_feedback("Percée en recharge · encore 2 activations", &"warning")
		&"locked":
			_hud.show_context_feedback("Garde d’airain déjà utilisée pendant cette activation", &"info")
	_hud._apply_layout_metrics()


func _snapshot_for_state() -> Dictionary:
	var snapshot := PLAYER_SNAPSHOT.duplicate(true)
	match state_id:
		&"targeting_valid":
			snapshot["phase_name"] = &"PLAYER_TARGETING"
			snapshot["selection_mode"] = &"spell"
			snapshot["focus_active"] = true
			snapshot["feedback_text"] = "Cible valide · portée 2 · 2 PA"
			snapshot["feedback_kind"] = &"info"
		&"targeting_invalid":
			snapshot["phase_name"] = &"PLAYER_TARGETING"
			snapshot["selection_mode"] = &"spell"
			snapshot["focus_active"] = true
			snapshot["feedback_text"] = "Cible hors de portée · choisissez une case à 1–2"
			snapshot["feedback_kind"] = &"error"
		&"resolving":
			snapshot = {
				"controls_enabled": false,
				"ownership": &"system",
				"phase_name": &"RESOLVING_ACTION",
				"selection_mode": &"spell",
				"resolution_kind": &"spell",
				"focus_active": true,
				"feedback_text": "Frappe de lance · résolution en cours",
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
