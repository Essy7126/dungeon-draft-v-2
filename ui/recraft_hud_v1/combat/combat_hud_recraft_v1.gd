extends "res://ui/action_bar.gd"

signal utility_skill_tree_requested(character_id: StringName, discipline_id: StringName)
signal utility_inventory_requested(character_id: StringName)
signal item_activation_requested(instance_id: StringName)

const SPELL_SLOT_SCENE := preload(
	"res://ui/recraft_hud_v1/components/spell_slot/spell_slot_view.tscn"
)
const ITEM_SLOT_SCENE := preload(
	"res://ui/recraft_hud_v1/components/item_slot/item_slot_view.tscn"
)
const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")
const DEFAULT_CHARACTER_THEME: CharacterHUDThemeData = preload(
	"res://data/ui/elf_hud_theme.tres"
)
const ORNATE_ELF_THEME: CharacterHUDThemeData = preload("res://data/ui/elf_hud_theme.tres")
const CLEAN_ELF_THEME: CharacterHUDThemeData = preload("res://data/ui/elf_hud_theme_clean.tres")
const REFINED_ELF_THEME: CharacterHUDThemeData = preload("res://data/ui/elf_hud_theme_refined.tres")
const DEFAULT_LAYOUT: CombatHUDLayoutData = preload("res://data/ui/combat_hud_layout_clean.tres")
const SPELLBAR_TEXTURE_RATIO := 3155.0 / 612.0
const CHARACTER_BAR_TEXTURE_RATIO := 933.0 / 219.0
const NEUTRAL_NAME_COLOR := Color(0.96, 0.86, 0.67, 1.0)
const ORNATE_PANEL_MIN_WIDTH := 920.0
const ORNATE_PANEL_MAX_WIDTH := 1200.0
const ORNATE_SPELL_VISUAL_SIZE := 100.0
const ORNATE_SPELL_ICON_SIZE := 78.0
const ORNATE_SPELL_SHORTCUT_HEIGHT := 14.0
const ORNATE_SPELL_GAP := 8.0
const ORNATE_PORTRAIT_SIZE := 112.0
const ORNATE_HEALTH_BAR_SIZE := Vector2(230.0, 26.0)
const ORNATE_BADGE_SIZE := 50.0
const ORNATE_CHARACTER_WIDTH := 360.0
const ORNATE_END_TURN_SIZE := Vector2(170.0, 54.0)
const SPELL_SHORTCUT_KEYS := [
	KEY_1,
	KEY_2,
	KEY_3,
	KEY_4,
	KEY_5,
	KEY_6,
	KEY_7,
	KEY_8,
]
# Nombre d'emplacements de la barre d'objets. Les touches 1 à 4 servent aux
# objets quand cette barre est affichée, et aux sorts sinon.
const ITEM_SLOT_COUNT := 4
const BAR_MODE_SPELL := "spell"
const BAR_MODE_ITEM := "item"

enum RunUIMode {
	COMBAT,
	NON_COMBAT,
	TRANSITION,
}

enum HudSkinVariant {
	ORNATE,
	CLEAN,
	REFINED,
}

@export var character_themes: Array[CharacterHUDThemeData] = []
@export var skin_variant := HudSkinVariant.ORNATE
@export var layout_data: CombatHUDLayoutData = DEFAULT_LAYOUT
@export var show_layout_debug := false:
	set(value):
		show_layout_debug = value
		if is_instance_valid(_layout_debug_overlay):
			_layout_debug_overlay.set_debug_enabled(value)

@onready var _portrait_view: Control = %PortraitView
@onready var _hp_bar: Control = %HealthBar
@onready var _ap_badge: Control = %ActionPointsBadge
@onready var _mp_badge: Control = %MovementPointsBadge
@onready var _hud_band: Control = %HudBand
@onready var _neutral_background: Panel = %Background
@onready var _character_theme_bar: TextureRect = %CharacterThemeBar
@onready var _character_anchor: Control = %CharacterAnchor
@onready var _spell_anchor: Control = %SpellAnchor
@onready var _turn_anchor: Control = %TurnAnchor
@onready var _character_section: MarginContainer = %CharacterSection
@onready var _turn_section: MarginContainer = %TurnSection
@onready var _spell_section: Control = %SpellSection
@onready var _spellbar_background: TextureRect = %SpellBarBackground
@onready var _basic_attack_host: CenterContainer = %BasicAttackHost
@onready var _spell_slots_center: CenterContainer = %SpellSlotsCenter
@onready var _item_slots_center: CenterContainer = %ItemSlotsCenter
@onready var _item_slots_container: HBoxContainer = %ItemSlotsContainer
@onready var _bar_toggle_anchor: Control = %BarToggleAnchor
@onready var _bar_toggle: VBoxContainer = %BarToggle
@onready var _show_spells_button: Button = %ShowSpellsButton
@onready var _show_items_button: Button = %ShowItemsButton
@onready var _character_info: VBoxContainer = %CharacterInfo
@onready var _character_row: HBoxContainer = %CharacterRow
@onready var _bar_stack: VBoxContainer = %BarStack
@onready var _action_buttons: GridContainer = %ActionButtons
@onready var _resource_badges: HBoxContainer = %ResourceBadges
@onready var _clean_resource_badges: VBoxContainer = %CleanResourceBadges
@onready var _action_resources_anchor: Control = %ActionResourcesAnchor
@onready var _move_action_host: CenterContainer = %MoveActionHost
@onready var _identity_discipline_label: Label = %IdentityDisciplineLabel
@onready var _turn_content: Control = %TurnContent
@onready var _turn_label: Label = %TurnLabel
@onready var _layout_debug_overlay: Control = %LayoutDebugOverlay
@onready var _turn_intro_banner: CharacterTurnIntroBanner = %TurnIntroBanner
@onready var _selected_spell_plate: Label = %SelectedSpellPlate
@onready var _context_feedback: Label = %ContextFeedback
@onready var _utility_dock: HBoxContainer = %UtilityDock
@onready var _inventory_button: Button = %InventoryButton
@onready var _map_button: Button = %MapButton
@onready var _skills_button: Button = %SkillsButton
@onready var _identity_depth: TextureRect = %IdentityDepth
@onready var _action_depth: TextureRect = %ActionDepth
@onready var _turn_depth: TextureRect = %TurnDepth
@onready var _identity_divider: Panel = %IdentityDivider

var _active_mode := ""
var _active_spell = null
var _layout_scale := 1.0
var _combat_context: Node = null
var _context_tree_exiting_callback := Callable()
var _ui_mode: RunUIMode = RunUIMode.TRANSITION
var _active_character_theme: CharacterHUDThemeData = null
var _attack_button_home: Node = null
var _attack_button_home_index := 0
var _attack_grouped_with_spells := false
var _character_panel_size := Vector2.ZERO
var _move_button_home: Node = null
var _move_button_home_index := 0
var _ap_badge_home: Node = null
var _ap_badge_home_index := 0
var _mp_badge_home: Node = null
var _mp_badge_home_index := 0
# Vue choisie par le joueur : sorts ou objets. Volontairement jamais remise à
# zéro entre deux tours — si le joueur a affiché ses objets, ils restent
# affichés au tour suivant.
var _active_bar_mode := BAR_MODE_SPELL
var _item_buttons: Array = []
var _presentation_snapshot: Dictionary = {}
var _last_feedback_text := ""
var _feedback_tween: Tween = null
var _reduced_motion := false


func _ready() -> void:
	if character_themes.is_empty() and skin_variant == HudSkinVariant.ORNATE:
		character_themes.append(DEFAULT_CHARACTER_THEME)
	_hbox = %SpellSlotsContainer
	_info_label = %CharacterName
	_spell_box = %SpellSlotsContainer
	_move_btn = %MoveButton
	_attack_btn = %AttackButton
	_end_btn = %EndTurnButton
	_attack_button_home = _attack_btn.get_parent()
	_attack_button_home_index = _attack_btn.get_index()
	_move_button_home = _move_btn.get_parent()
	_move_button_home_index = _move_btn.get_index()
	_ap_badge_home = _ap_badge.get_parent()
	_ap_badge_home_index = _ap_badge.get_index()
	_mp_badge_home = _mp_badge.get_parent()
	_mp_badge_home_index = _mp_badge.get_index()

	_move_btn.set_label("Déplacer")
	_attack_btn.set_label("Attaquer")
	_end_btn.set_label("Fin de tour")

	if not get_viewport().size_changed.is_connected(_apply_layout_metrics):
		get_viewport().size_changed.connect(_apply_layout_metrics)
	_move_btn.tooltip_text = "Déplacer — choisissez une case accessible (coût en PM)."
	_move_btn.shortcut = _shortcut_for_key(KEY_M)
	_move_btn.shortcut_in_tooltip = true
	_attack_btn.shortcut = _shortcut_for_key(KEY_A)
	_attack_btn.shortcut_in_tooltip = true
	_end_btn.shortcut = _shortcut_for_key(KEY_F)
	_end_btn.shortcut_in_tooltip = true
	_move_btn.pressed.connect(func() -> void: move_pressed.emit())
	_attack_btn.pressed.connect(func() -> void: attack_pressed.emit())
	_end_btn.pressed.connect(func() -> void: end_turn_pressed.emit())
	_inventory_button.pressed.connect(_on_inventory_button_pressed)
	_inventory_button.shortcut = _shortcut_for_key(KEY_I)
	_inventory_button.shortcut_in_tooltip = true
	_skills_button.pressed.connect(_on_skills_button_pressed)
	_skills_button.shortcut = _shortcut_for_key(KEY_K)
	_skills_button.shortcut_in_tooltip = true
	_show_spells_button.pressed.connect(
		func() -> void: _set_active_bar_mode(BAR_MODE_SPELL)
	)
	_show_items_button.pressed.connect(
		func() -> void: _set_active_bar_mode(BAR_MODE_ITEM)
	)
	if not EventBus.turn_started.is_connected(_on_event_bus_turn_started):
		EventBus.turn_started.connect(_on_event_bus_turn_started)
	var relic_service := _relic_service()
	if relic_service != null \
			and not relic_service.active_relics_changed.is_connected(_on_active_relics_changed):
		relic_service.active_relics_changed.connect(_on_active_relics_changed)
	_build_item_slots()
	_apply_bar_mode()
	_apply_layout_metrics()
	_refresh_resource_bars(null)
	_refresh_button_states()
	set_ui_mode(_ui_mode)


func _exit_tree() -> void:
	unbind_combat_context()
	if EventBus.turn_started.is_connected(_on_event_bus_turn_started):
		EventBus.turn_started.disconnect(_on_event_bus_turn_started)
	var relic_service := _relic_service()
	if relic_service != null \
			and relic_service.active_relics_changed.is_connected(_on_active_relics_changed):
		relic_service.active_relics_changed.disconnect(_on_active_relics_changed)
	if get_viewport().size_changed.is_connected(_apply_layout_metrics):
		get_viewport().size_changed.disconnect(_apply_layout_metrics)


func bind_combat_context(context: Node) -> void:
	if context == _combat_context and is_instance_valid(context):
		refresh_from_context()
		set_ui_mode(RunUIMode.COMBAT)
		return
	unbind_combat_context()
	if context == null:
		return
	_combat_context = context
	_connect_context_actions()
	_context_tree_exiting_callback = Callable(
		self, "_on_bound_context_tree_exiting"
	).bind(context)
	if not context.tree_exiting.is_connected(_context_tree_exiting_callback):
		context.tree_exiting.connect(_context_tree_exiting_callback)
	set_player_controls_enabled(false)
	refresh_from_context()
	set_ui_mode(RunUIMode.COMBAT)


func unbind_combat_context() -> void:
	_disconnect_context_actions()
	if (
		is_instance_valid(_combat_context)
		and _context_tree_exiting_callback.is_valid()
		and _combat_context.tree_exiting.is_connected(
			_context_tree_exiting_callback
		)
	):
		_combat_context.tree_exiting.disconnect(_context_tree_exiting_callback)
	_context_tree_exiting_callback = Callable()
	_combat_context = null
	_disconnect_current_unit()
	_clear_spell_buttons()
	update_info(null)
	_turn_intro_banner.hide_immediately()
	set_player_controls_enabled(false)
	set_ui_mode(RunUIMode.TRANSITION)


func refresh_from_context() -> void:
	if not is_instance_valid(_combat_context):
		update_info(null)
		_clear_spell_buttons()
		return
	var active_unit = null
	if _combat_context.has_method("get_active_unit"):
		active_unit = _combat_context.get_active_unit()
	else:
		var context_turn_queue = _combat_context.get("turn_queue")
		if (
			context_turn_queue != null
			and context_turn_queue.has_method("get_current_unit")
		):
			active_unit = context_turn_queue.get_current_unit()
	update_info(active_unit)
	build_spell_buttons(active_unit)


func set_ui_mode(mode: RunUIMode) -> void:
	_ui_mode = mode
	visible = mode == RunUIMode.COMBAT
	if mode != RunUIMode.COMBAT:
		set_player_controls_enabled(false)
		_turn_intro_banner.hide_immediately()


func get_ui_mode() -> RunUIMode:
	return _ui_mode


func get_combat_context() -> Node:
	return _combat_context if is_instance_valid(_combat_context) else null


func _connect_context_actions() -> void:
	if not is_instance_valid(_combat_context):
		return
	_connect_action_to_context(move_pressed, &"_on_move_pressed")
	_connect_action_to_context(attack_pressed, &"_on_attack_pressed")
	_connect_action_to_context(spell_pressed, &"_on_spell_pressed")
	_connect_action_to_context(end_turn_pressed, &"_on_end_turn_pressed")
	_connect_action_to_context(
		item_activation_requested, &"_on_item_activation_requested"
	)


func _disconnect_context_actions() -> void:
	if not is_instance_valid(_combat_context):
		return
	_disconnect_action_from_context(move_pressed, &"_on_move_pressed")
	_disconnect_action_from_context(attack_pressed, &"_on_attack_pressed")
	_disconnect_action_from_context(spell_pressed, &"_on_spell_pressed")
	_disconnect_action_from_context(end_turn_pressed, &"_on_end_turn_pressed")
	_disconnect_action_from_context(
		item_activation_requested, &"_on_item_activation_requested"
	)


func _connect_action_to_context(action_signal: Signal, method: StringName) -> void:
	if not _combat_context.has_method(method):
		return
	var callback := Callable(_combat_context, method)
	if not action_signal.is_connected(callback):
		action_signal.connect(callback)


func _disconnect_action_from_context(
		action_signal: Signal,
		method: StringName
	) -> void:
	if not _combat_context.has_method(method):
		return
	var callback := Callable(_combat_context, method)
	if action_signal.is_connected(callback):
		action_signal.disconnect(callback)


func _on_bound_context_tree_exiting(context: Node) -> void:
	if context == _combat_context:
		unbind_combat_context()


func _add_spell_button(unit, spell) -> void:
	var button := SPELL_SLOT_SCENE.instantiate() as Button
	if button == null:
		push_error("Impossible d'instancier SpellSlotView.")
		return
	var ap_cost: int = unit.get_spell_ap_cost(spell)
	_spell_box.add_child(button)
	button.configure(
		spell,
		ap_cost,
		str(_spell_buttons.size() + 1)
	)
	if _active_character_theme != null:
		button.set_icon_override(
			_active_character_theme.get_spell_icon_for(spell)
		)
		button.set_frame_override(
			_active_character_theme.get_spell_frame_for(spell)
		)
	button.set_refined_style(_refined_skin_active())
	button.set_meta("spell", spell)
	button.mouse_entered.connect(func() -> void: _show_spell_card(unit, spell))
	button.mouse_exited.connect(_hide_keyword_tooltip)
	button.pressed.connect(func() -> void: spell_pressed.emit(spell))
	_spell_buttons.append(button)
	_apply_spell_button_layout(button)
	_update_spell_section_geometry()


func build_spell_buttons(unit) -> void:
	super.build_spell_buttons(unit)
	_refresh_shortcut_bindings()
	_apply_layout_metrics()


# ============================================================
# BARRE D'OBJETS — activation manuelle
# ============================================================

func _relic_service() -> RelicRuntimeService:
	return (
		GameManager.get_relic_runtime_service()
		if GameManager.has_method("get_relic_runtime_service")
		else null
	)


# Les quatre emplacements existent en permanence : ils sont créés une seule
# fois, puis remplis ou vidés. Ainsi la barre ne change jamais de largeur selon
# le nombre d'objets possédés.
func _build_item_slots() -> void:
	for button_value in _item_buttons:
		var existing := button_value as Button
		if is_instance_valid(existing):
			existing.set_block_signals(true)
			existing.queue_free()
	_item_buttons.clear()
	for slot_index in range(ITEM_SLOT_COUNT):
		var button := ITEM_SLOT_SCENE.instantiate() as RecraftItemSlotView
		if button == null:
			push_error("Impossible d'instancier ItemSlotView.")
			return
		_item_slots_container.add_child(button)
		button.clear_item()
		button.pressed.connect(
			func() -> void: _on_item_slot_pressed(button)
		)
		_item_buttons.append(button)
	_refresh_item_slots()


# Remplit les emplacements avec les objets que le joueur peut déclencher
# lui-même, puis délègue au service la question « est-ce utilisable maintenant ».
func _refresh_item_slots() -> void:
	if _item_buttons.is_empty():
		return
	var relic_service := _relic_service()
	var entries: Array[Dictionary] = (
		relic_service.manual_activation_entries()
		if relic_service != null
		else [] as Array[Dictionary]
	)
	for slot_index in range(_item_buttons.size()):
		var button := _item_buttons[slot_index] as RecraftItemSlotView
		if slot_index >= entries.size():
			button.clear_item()
			continue
		var entry := entries[slot_index]
		button.configure_item(
			StringName(entry.get("instance_id", &"")),
			entry.get("definition") as ItemDefinition,
			str(slot_index + 1)
		)
		_apply_spell_button_layout(button)
	_refresh_item_slot_states()
	_refresh_shortcut_bindings()


func _refresh_item_slot_states() -> void:
	var relic_service := _relic_service()
	for button_value in _item_buttons:
		var button := button_value as RecraftItemSlotView
		if button.is_empty_slot():
			continue
		var state := (
			relic_service.manual_activation_state(_current_unit, button.instance_id)
			if relic_service != null
			else {}
		)
		button.apply_availability(state, _player_controls_enabled)


func _on_item_slot_pressed(button: RecraftItemSlotView) -> void:
	if button == null or button.is_empty_slot() or not _player_controls_enabled:
		return
	item_activation_requested.emit(button.instance_id)


func _on_active_relics_changed(_count: int) -> void:
	_refresh_item_slots()


func _set_active_bar_mode(mode: String) -> void:
	if _active_bar_mode == mode:
		return
	_active_bar_mode = mode
	_apply_bar_mode()


func get_active_bar_mode() -> String:
	return _active_bar_mode


func _apply_bar_mode() -> void:
	if not is_node_ready():
		return
	var items_visible := _active_bar_mode == BAR_MODE_ITEM
	_spell_slots_center.visible = not items_visible
	_item_slots_center.visible = items_visible
	# La flèche de la vue déjà affichée reste enfoncée : le joueur voit d'un
	# coup d'œil laquelle des deux barres il regarde.
	_show_spells_button.disabled = not items_visible
	_show_items_button.disabled = items_visible
	_refresh_shortcut_bindings()
	_refresh_item_slot_states()


# Les touches 1 à 4 pointent vers la barre réellement affichée. On efface
# toujours les raccourcis de l'autre barre, sinon les deux répondraient à la
# même touche.
func _refresh_shortcut_bindings() -> void:
	var items_active := _active_bar_mode == BAR_MODE_ITEM
	for index in range(_spell_buttons.size()):
		var spell_button := _spell_buttons[index] as Button
		spell_button.shortcut = (
			null if items_active else _shortcut_for_index(index)
		)
		spell_button.shortcut_in_tooltip = not items_active
	for index in range(_item_buttons.size()):
		var item_button := _item_buttons[index] as Button
		item_button.shortcut = (
			_shortcut_for_index(index) if items_active else null
		)
		item_button.shortcut_in_tooltip = items_active


func _shortcut_for_index(index: int) -> Shortcut:
	if index < 0 or index >= SPELL_SHORTCUT_KEYS.size():
		return null
	var shortcut_event := InputEventKey.new()
	shortcut_event.physical_keycode = SPELL_SHORTCUT_KEYS[index]
	var shortcut := Shortcut.new()
	shortcut.events = [shortcut_event]
	return shortcut


func update_info(unit) -> void:
	_disconnect_current_unit()
	_current_unit = unit
	if unit == null:
		_info_label.text = ""
		_portrait_view.set_character_data(null)
		_portrait_view.set_active(false)
		_apply_character_theme(null)
		_refresh_resource_bars(null, false)
		_refresh_button_states()
		return

	_info_label.text = unit.unit_name
	_portrait_view.set_character_data(unit.character_data)
	_portrait_view.set_active(true)
	_apply_character_theme(unit)
	if not unit.stats_changed.is_connected(_on_resource_changed):
		unit.stats_changed.connect(_on_resource_changed)
	if not unit.hp_changed.is_connected(_on_resource_changed):
		unit.hp_changed.connect(_on_resource_changed)
	_refresh_resource_bars(unit, false)
	_refresh_button_states()


func _disconnect_current_unit() -> void:
	if _current_unit == null or not is_instance_valid(_current_unit):
		return
	if _current_unit.hp_changed.is_connected(_on_resource_changed):
		_current_unit.hp_changed.disconnect(_on_resource_changed)
	super._disconnect_current_unit()


func _refresh_resource_bars(unit, animate_changes: bool = true) -> void:
	if not is_node_ready():
		return
	if unit == null:
		_hp_bar.set_resource(
			0.0, 1.0, Color(0.64, 0.15, 0.16), null, "PV", true, animate_changes
		)
		_ap_badge.set_badge(0, 0, Color(0.92, 0.69, 0.18), null, "PA")
		_mp_badge.set_badge(0, 0, Color(0.31, 0.67, 0.9), null, "PM")
		return

	_hp_bar.set_resource(
		unit.current_hp,
		unit.max_hp.get_int(),
		Color(0.72, 0.12, 0.15),
		null,
		"PV",
		true,
		animate_changes
	)
	_ap_badge.set_badge(
		unit.current_ap,
		unit.max_ap.get_int(),
		Color(0.94, 0.68, 0.12),
		null,
		"PA"
	)
	_mp_badge.set_badge(
		unit.current_mp,
		unit.max_mp.get_int(),
		Color(0.27, 0.62, 0.92),
		null,
		"PM"
	)



func _refresh_button_states() -> void:
	if not is_node_ready() or _move_btn == null:
		return
	_move_btn.disabled = not _player_controls_enabled
	_end_btn.disabled = not _player_controls_enabled
	_inventory_button.disabled = (
		not _player_controls_enabled
		or _current_unit == null
		or not _refined_skin_active()
	)

	var attack_available: bool = (
		_current_unit != null
		and _current_unit.can_use_basic_attack()
	)
	_attack_btn.visible = _current_unit == null or _current_unit.basic_attack_enabled
	_attack_btn.disabled = not _player_controls_enabled or not attack_available
	var attack_label := "Attaquer"
	if _current_unit != null:
		attack_label = (
			"%d PA" % _current_unit.get_basic_attack_ap_cost()
			if _attack_grouped_with_spells
			else "Attaquer · %d PA" % _current_unit.get_basic_attack_ap_cost()
		)
	_attack_btn.set_label(attack_label)
	_attack_btn.tooltip_text = _attack_tooltip(_current_unit)

	for button_value in _spell_buttons:
		var button := button_value as Button
		var spell = button.get_meta("spell") if button.has_meta("spell") else null
		var reason := _spell_unusable_reason(_current_unit, spell)
		var is_selected: bool = (
			_active_mode == "spell"
			and spell == _active_spell
		)
		if not _player_controls_enabled:
			button.set_visual_state(RecraftSpellSlotView.VisualState.DISABLED)
		elif not reason.is_empty():
			button.set_visual_state(RecraftSpellSlotView.VisualState.UNAFFORDABLE)
		elif is_selected:
			button.set_visual_state(RecraftSpellSlotView.VisualState.SELECTED)
		else:
			button.set_visual_state(RecraftSpellSlotView.VisualState.NORMAL)

	_refresh_item_slot_states()

	_sync_primary_button(_move_btn, _active_mode == "move")
	_sync_primary_button(_attack_btn, _active_mode == "attack")
	_sync_primary_button(_end_btn, false)


func set_active_mode(mode: String, active_spell = null) -> void:
	_active_mode = mode
	_active_spell = active_spell
	_selected_spell_plate.visible = (
		mode in ["move", "attack"] \
		or (mode == "spell" and active_spell != null)
	)
	if mode == "move":
		_selected_spell_plate.text = (
			"Déplacer  ·  Choisissez une case  ·  Échap pour annuler"
		)
	elif mode == "attack":
		_selected_spell_plate.text = (
			"Attaquer  ·  Choisissez un ennemi adjacent  ·  Échap pour annuler"
		)
	elif active_spell != null and _current_unit != null:
		_selected_spell_plate.text = (
			"%s  ·  %d PA  ·  Échap pour annuler"
			% [active_spell.spell_name, _current_unit.get_spell_ap_cost(active_spell)]
		)
	else:
		_selected_spell_plate.text = ""
	if _current_unit != null:
		_refresh_resource_bars(_current_unit)
	_refresh_button_states()


func set_player_controls_enabled(enabled: bool) -> void:
	super.set_player_controls_enabled(enabled)
	if not enabled or _ui_mode != RunUIMode.COMBAT or not is_node_ready():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		_move_btn.grab_focus.call_deferred()


func apply_presentation_snapshot(snapshot: Dictionary) -> void:
	_presentation_snapshot = snapshot.duplicate(true)
	set_player_controls_enabled(
		bool(snapshot.get("controls_enabled", false))
	)
	var ownership := StringName(snapshot.get("ownership", &"system"))
	var phase := StringName(snapshot.get("phase_name", &"UNKNOWN"))
	match ownership:
		&"player":
			_turn_label.text = "VOTRE TOUR"
			_end_btn.set_label("Fin de tour")
		&"enemy":
			_turn_label.text = "TOUR ADVERSE"
			_end_btn.set_label("Tour adverse")
		_:
			_turn_label.text = (
				"RÉSOLUTION"
				if phase == &"RESOLVING_ACTION"
				else "COMBAT TERMINÉ" if phase == &"BATTLE_ENDING" else "COMBAT"
			)
			_end_btn.set_label(
				"Résolution…"
				if phase == &"RESOLVING_ACTION"
				else "Combat terminé" if phase == &"BATTLE_ENDING" else "Indisponible"
			)
	var focus_active := bool(snapshot.get("focus_active", false))
	_character_section.modulate.a = 0.78 if focus_active else 1.0
	_turn_section.modulate.a = 0.72 if focus_active else 1.0
	_utility_dock.modulate.a = 0.32 if focus_active else 1.0
	_spell_section.modulate.a = (
		0.78 if phase == &"RESOLVING_ACTION" else 1.0
	)
	var feedback := str(snapshot.get("feedback_text", ""))
	if feedback.is_empty():
		_hide_context_feedback()
	elif feedback != _last_feedback_text:
		show_context_feedback(
			feedback,
			StringName(snapshot.get("feedback_kind", &"info"))
		)
	_last_feedback_text = feedback


func get_presentation_snapshot() -> Dictionary:
	return _presentation_snapshot.duplicate(true)


func show_context_feedback(
		message: String,
		kind: StringName = &"warning"
	) -> void:
	if not is_instance_valid(_context_feedback) \
			or message.strip_edges().is_empty():
		return
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_context_feedback.text = message
	_context_feedback.add_theme_color_override(
		"font_color",
		Color(1.0, 0.46, 0.4)
		if kind == &"error"
		else Color(1.0, 0.86, 0.48)
		if kind == &"warning"
		else Color(0.67, 0.88, 1.0)
	)
	_context_feedback.modulate.a = 0.0
	_context_feedback.show()
	if _reduced_motion:
		_context_feedback.modulate.a = 1.0
		_feedback_tween = create_tween()
		_feedback_tween.tween_interval(1.15)
		_feedback_tween.tween_callback(_context_feedback.hide)
		return
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_context_feedback, "modulate:a", 1.0, 0.12)
	_feedback_tween.tween_interval(1.15)
	_feedback_tween.set_ease(Tween.EASE_IN)
	_feedback_tween.tween_property(_context_feedback, "modulate:a", 0.0, 0.22)
	_feedback_tween.tween_callback(_context_feedback.hide)


func _hide_context_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = null
	if is_instance_valid(_context_feedback):
		_context_feedback.hide()
		_context_feedback.modulate.a = 0.0


func _apply_base_button_modulates() -> void:
	_refresh_button_states()


func _sync_primary_button(button: Button, active: bool) -> void:
	if button != null and button.has_method("refresh_visual_state"):
		button.refresh_visual_state(active)


func get_active_character_theme() -> CharacterHUDThemeData:
	return _active_character_theme


func get_turn_intro_banner() -> CharacterTurnIntroBanner:
	return _turn_intro_banner


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if is_instance_valid(_turn_intro_banner):
		_turn_intro_banner.set_reduced_motion(enabled)


func is_reduced_motion_enabled() -> bool:
	return _reduced_motion


func _resolve_character_theme(unit) -> CharacterHUDThemeData:
	if unit == null:
		return null
	for theme in character_themes:
		if theme != null and theme.matches_unit(unit):
			return theme
	if skin_variant == HudSkinVariant.REFINED:
		return CharacterHUDThemeCatalog.resolve_refined(unit)
	if StringName(unit.unit_id) == &"elf":
		return CLEAN_ELF_THEME if skin_variant == HudSkinVariant.CLEAN else ORNATE_ELF_THEME
	return null


func _apply_character_theme(unit) -> void:
	_active_character_theme = _resolve_character_theme(unit)
	if _active_character_theme == null:
		_character_theme_bar.texture = null
		_character_theme_bar.visible = false
		_info_label.add_theme_color_override(
			"font_color",
			NEUTRAL_NAME_COLOR
		)
		_portrait_view.set_discipline_emblem(null)
		_portrait_view.set_portrait_frame(null)
		_hp_bar.set_frame_texture(null)
		_attack_btn.set_icon(null)
		_move_btn.set_icon(null)
		_attack_btn.set_background_texture(null)
		_move_btn.set_background_texture(null)
		_end_btn.set_background_texture(null)
		_portrait_view.set_refined_style(false)
		_hp_bar.set_refined_style(false)
		_ap_badge.set_refined_style(false)
		_mp_badge.set_refined_style(false)
		_move_btn.set_refined_style(false)
		_attack_btn.set_refined_style(false)
		_end_btn.set_refined_style(false)
		_identity_discipline_label.text = ""
		_identity_discipline_label.visible = false
		_utility_dock.visible = false
		_inventory_button.disabled = true
		_skills_button.disabled = true
		_set_refined_depth_visible(false)
		_set_attack_grouped_with_spells(false)
		_set_clean_composition(false)
		_apply_layout_metrics()
		return
	_character_theme_bar.texture = _active_character_theme.character_bar_texture
	_character_theme_bar.visible = _character_theme_bar.texture != null
	_info_label.add_theme_color_override(
		"font_color",
		_active_character_theme.text_color
	)
	if _active_character_theme.portrait_texture != null:
		_portrait_view.set_portrait(
			_active_character_theme.portrait_texture,
			unit.unit_name
		)
	_portrait_view.set_portrait_frame(
		_active_character_theme.portrait_frame_texture
	)
	_portrait_view.set_discipline_emblem(
		_active_character_theme.discipline_emblem_texture,
		Color.WHITE,
		0.85
	)
	var refined := _refined_skin_active()
	_portrait_view.set_refined_style(refined)
	_identity_discipline_label.text = _active_character_theme.discipline_name.to_upper()
	_identity_discipline_label.visible = not _active_character_theme.discipline_name.is_empty()
	_hp_bar.set_frame_texture(
		_active_character_theme.health_bar_frame_texture
	)
	_hp_bar.set_refined_style(refined)
	_ap_badge.set_refined_style(refined)
	_mp_badge.set_refined_style(refined)
	_attack_btn.set_icon(
		_active_character_theme.get_spell_icon(&"basic_attack")
	)
	_move_btn.set_icon(_active_character_theme.move_action_icon)
	_attack_btn.set_background_texture(
		_active_character_theme.get_spell_frame(&"basic_attack")
	)
	_move_btn.set_background_texture(
		_active_character_theme.spell_slot_frame_texture
		if _clean_skin_active()
		else null
	)
	_end_btn.set_background_texture(
		_active_character_theme.end_turn_button_texture,
		true
	)
	_move_btn.set_refined_style(refined)
	_attack_btn.set_refined_style(refined)
	_end_btn.set_refined_style(refined, true)
	_inventory_button.icon = _active_character_theme.utility_inventory_icon
	_map_button.icon = _active_character_theme.utility_map_icon
	_skills_button.icon = _active_character_theme.utility_skills_icon
	_utility_dock.visible = refined
	_inventory_button.visible = refined and not _compact_layout_active()
	_inventory_button.disabled = not refined or not _player_controls_enabled
	_map_button.visible = refined and not _compact_layout_active()
	_skills_button.visible = refined
	_set_refined_depth_visible(refined)
	_skills_button.disabled = (
		not refined
	)
	_set_attack_grouped_with_spells(_official_chassis_active())
	_set_clean_composition(_clean_skin_active())
	_apply_layout_metrics()


func _on_event_bus_turn_started(unit) -> void:
	if (
		_ui_mode != RunUIMode.COMBAT
		or not is_instance_valid(_combat_context)
		or unit == null
	):
		return
	var active_unit = null
	if _combat_context.has_method("get_active_unit"):
		active_unit = _combat_context.get_active_unit()
	else:
		var context_turn_queue = _combat_context.get("turn_queue")
		if (
			context_turn_queue != null
			and context_turn_queue.has_method("get_current_unit")
		):
			active_unit = context_turn_queue.get_current_unit()
	if active_unit != null and active_unit != unit:
		return
	if unit.team == 1:
		_turn_intro_banner.present_enemy(unit)
		return
	var theme := _resolve_character_theme(unit)
	if theme != null:
		_turn_intro_banner.present(unit, theme)


func get_character_panel_size() -> Vector2:
	return _character_panel_size


func get_calibrated_spell_metrics() -> Dictionary:
	var viewport_width := get_viewport().get_visible_rect().size.x
	return {
		"visual_size": _effective_spell_visual_size(viewport_width),
		"icon_size": _effective_spell_icon_size(viewport_width),
		"shortcut_height": _effective_spell_shortcut_height(viewport_width),
		"gap": _effective_spell_gap(viewport_width),
		"portrait_size": _effective_portrait_size(viewport_width),
		"health_bar_size": _effective_health_bar_size(viewport_width),
		"badge_size": _effective_badge_size(viewport_width),
		"end_turn_size": _effective_end_turn_size(viewport_width),
	}


func _official_chassis_active() -> bool:
	return _active_character_theme != null


func _clean_skin_active() -> bool:
	return _official_chassis_active() and skin_variant != HudSkinVariant.ORNATE


func _refined_skin_active() -> bool:
	return (
		_official_chassis_active()
		and skin_variant == HudSkinVariant.REFINED
		and _active_character_theme.refined_components
	)


func _compact_layout_active() -> bool:
	return (
		_clean_skin_active()
		and layout_data != null
		and layout_data.overall_height <= 118.0
	)


func set_refined_polish_tuning(
		panel_depth_intensity: float = 0.68,
		dock_contrast: float = 1.0
	) -> void:
	var depth_alpha := clampf(panel_depth_intensity, 0.0, 1.0)
	var primary := (
		_active_character_theme.primary_color
		if _active_character_theme != null
		else Color.WHITE
	)
	var secondary := (
		_active_character_theme.secondary_color
		if _active_character_theme != null
		else Color.WHITE
	)
	_identity_depth.modulate = Color(primary.r, primary.g, primary.b, depth_alpha)
	_action_depth.modulate = Color(secondary.r, secondary.g, secondary.b, depth_alpha)
	_turn_depth.modulate = Color(secondary.r, secondary.g, secondary.b, depth_alpha)
	_identity_divider.modulate = secondary.lightened(0.28)
	_identity_discipline_label.add_theme_color_override(
		"font_color", secondary.lightened(0.38)
	)
	var dock_value := clampf(dock_contrast, 0.55, 1.25)
	_utility_dock.modulate = Color(dock_value, dock_value, dock_value, 1.0)


func _set_refined_depth_visible(visible: bool) -> void:
	_identity_depth.visible = visible
	_action_depth.visible = visible
	_turn_depth.visible = visible
	_identity_divider.visible = visible
	if visible:
		set_refined_polish_tuning()


func _on_skills_button_pressed() -> void:
	if (
		_current_unit == null
		or _active_character_theme == null
	):
		return
	utility_skill_tree_requested.emit(
		StringName(_current_unit.unit_id),
		_active_character_theme.default_discipline_id
	)


func _on_inventory_button_pressed() -> void:
	if _current_unit == null or not _player_controls_enabled:
		return
	utility_inventory_requested.emit(StringName(_current_unit.unit_id))


func _base_chassis_visual_scale(viewport_width: float) -> float:
	return clampf(viewport_width / 1920.0, 0.8, 1.1)


func _chassis_visual_scale(viewport_width: float) -> float:
	var base_scale := _base_chassis_visual_scale(viewport_width)
	if not _clean_skin_active() or _spell_buttons.size() <= 4:
		return base_scale
	var slot_count := _spell_buttons.size() + 1
	var unscaled_content_width := (
		layout_data.character_identity_width
		+ 58.0
		+ layout_data.move_action_size.x
		+ slot_count * layout_data.action_slot_size
		+ (slot_count - 1) * layout_data.action_slot_spacing
		+ layout_data.end_turn_size.x
		+ layout_data.block_separation * 4.0
	)
	var fit_scale := (viewport_width - 24.0) / unscaled_content_width
	return clampf(minf(base_scale, fit_scale), 0.62, base_scale)


func _effective_spell_visual_size(viewport_width: float) -> float:
	if _official_chassis_active():
		return roundf(
			(layout_data.action_slot_size if _clean_skin_active() else ORNATE_SPELL_VISUAL_SIZE) * _chassis_visual_scale(viewport_width)
		)
	return METRICS.scaled(METRICS.SPELL_VISUAL_SIZE, _layout_scale)


func _effective_spell_icon_size(viewport_width: float) -> float:
	if _official_chassis_active():
		return roundf(
			(layout_data.action_icon_size if _clean_skin_active() else ORNATE_SPELL_ICON_SIZE) * _chassis_visual_scale(viewport_width)
		)
	return METRICS.scaled(METRICS.SPELL_ICON_SIZE, _layout_scale)


func _effective_spell_shortcut_height(viewport_width: float) -> float:
	if _official_chassis_active():
		return roundf(
			(layout_data.shortcut_plate_height if _clean_skin_active() else ORNATE_SPELL_SHORTCUT_HEIGHT) * _chassis_visual_scale(viewport_width)
		)
	return METRICS.scaled(METRICS.SPELL_SHORTCUT_HEIGHT, _layout_scale)


func _effective_spell_gap(viewport_width: float) -> float:
	if _official_chassis_active():
		return clampf(
			roundf((layout_data.action_slot_spacing if _clean_skin_active() else ORNATE_SPELL_GAP) * _chassis_visual_scale(viewport_width)),
			4.0 if _compact_layout_active() else 6.0,
			10.0
		)
	return METRICS.scaled(METRICS.SPELL_GAP, _layout_scale)


func _effective_portrait_size(viewport_width: float) -> float:
	return roundf((layout_data.portrait_size if _clean_skin_active() else ORNATE_PORTRAIT_SIZE) * _chassis_visual_scale(viewport_width))


func _effective_health_bar_size(viewport_width: float) -> Vector2:
	return (
		(layout_data.health_bar_size if _clean_skin_active() else ORNATE_HEALTH_BAR_SIZE) * _chassis_visual_scale(viewport_width)
	).round()


func _effective_badge_size(viewport_width: float) -> float:
	return clampf(
		roundf((layout_data.action_resource_badge_size if _clean_skin_active() else ORNATE_BADGE_SIZE) * _chassis_visual_scale(viewport_width)),
		32.0 if _compact_layout_active() else 44.0,
		54.0
	)


func _effective_end_turn_size(viewport_width: float) -> Vector2:
	var visual_scale := _chassis_visual_scale(viewport_width)
	return Vector2(
		clampf(
			roundf((layout_data.end_turn_size.x if _clean_skin_active() else ORNATE_END_TURN_SIZE.x) * visual_scale),
			110.0 if _compact_layout_active() else 150.0,
			205.0 if _clean_skin_active() else 190.0
		),
		clampf(
			roundf((layout_data.end_turn_size.y if _clean_skin_active() else ORNATE_END_TURN_SIZE.y) * visual_scale),
			34.0 if _compact_layout_active() else 48.0,
			60.0
		)
	)


func _apply_spell_button_layout(button: RecraftSpellSlotView) -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	if _official_chassis_active():
		button.apply_calibrated_layout(
			_effective_spell_visual_size(viewport_width),
			_effective_spell_icon_size(viewport_width),
			_effective_spell_shortcut_height(viewport_width),
			_chassis_visual_scale(viewport_width)
		)
		return
	button.apply_layout(_layout_scale)


func _set_attack_grouped_with_spells(grouped: bool) -> void:
	_attack_grouped_with_spells = grouped
	if grouped:
		if _attack_btn.get_parent() != _basic_attack_host:
			_reparent_attack_button(_basic_attack_host)
		_basic_attack_host.visible = true
		return
	if (
		_attack_button_home != null
		and _attack_btn.get_parent() != _attack_button_home
	):
		_reparent_attack_button(_attack_button_home)
		_attack_button_home.move_child(
			_attack_btn,
			mini(_attack_button_home_index, _attack_button_home.get_child_count() - 1)
		)
	_basic_attack_host.visible = false
	_attack_btn.set_compact_icon_mode(false)


func _reparent_attack_button(new_parent: Node) -> void:
	var scene_owner := _attack_btn.owner
	_attack_btn.owner = null
	_attack_btn.reparent(new_parent)
	_attack_btn.owner = scene_owner


func _set_clean_composition(enabled: bool) -> void:
	_action_resources_anchor.visible = enabled
	_move_action_host.visible = enabled
	_turn_label.visible = not enabled
	if enabled:
		_reparent_control(_move_btn, _move_action_host)
		_reparent_control(_ap_badge, _clean_resource_badges)
		_reparent_control(_mp_badge, _clean_resource_badges)
		return
	_restore_control_home(_move_btn, _move_button_home, _move_button_home_index)
	_restore_control_home(_ap_badge, _ap_badge_home, _ap_badge_home_index)
	_restore_control_home(_mp_badge, _mp_badge_home, _mp_badge_home_index)


func _reparent_control(control: Control, new_parent: Node) -> void:
	if control.get_parent() == new_parent:
		return
	var scene_owner := control.owner
	control.owner = null
	control.reparent(new_parent)
	control.owner = scene_owner


func _restore_control_home(control: Control, home: Node, home_index: int) -> void:
	if home == null:
		return
	_reparent_control(control, home)
	home.move_child(control, mini(home_index, home.get_child_count() - 1))


func _apply_character_panel_layout(viewport_width: float) -> void:
	var panel_width := (
		minf(layout_data.overall_width * _base_chassis_visual_scale(viewport_width), viewport_width - 24.0)
		if _clean_skin_active()
		else clampf(viewport_width * 0.6, ORNATE_PANEL_MIN_WIDTH, ORNATE_PANEL_MAX_WIDTH)
	)
	var panel_height := (
		layout_data.overall_height * _base_chassis_visual_scale(viewport_width)
		if _clean_skin_active()
		else panel_width / CHARACTER_BAR_TEXTURE_RATIO
	)
	_character_panel_size = Vector2(panel_width, panel_height)
	_hud_band.offset_top = -panel_height
	_hud_band.offset_bottom = 0.0
	_neutral_background.visible = _character_theme_bar.texture == null
	_character_theme_bar.visible = _character_theme_bar.texture != null
	_spellbar_background.visible = false
	if _clean_skin_active():
		_set_control_rect(
			_neutral_background,
			Rect2((viewport_width - panel_width) * 0.5, 0.0, panel_width, panel_height)
		)
	else:
		_set_anchor_geometry(
			_neutral_background,
			Vector4(0.0, 0.0, 1.0, 1.0),
			Vector4.ZERO
		)
	_set_anchor_geometry(
		_character_theme_bar,
		Vector4(0.0, 0.0, 1.0, 1.0),
		Vector4.ZERO
	)

	var calibration_scale := _chassis_visual_scale(viewport_width)
	var visual_size := _effective_spell_visual_size(viewport_width)
	var shortcut_height := _effective_spell_shortcut_height(viewport_width)
	var slot_gap := _effective_spell_gap(viewport_width)
	var spell_count := maxi(_spell_buttons.size(), 4)
	var spells_width := (
		spell_count * visual_size
		+ maxi(spell_count - 1, 0) * slot_gap
	)
	var ability_width := visual_size + slot_gap + spells_width
	var character_width := roundf(
		(layout_data.character_identity_width if _clean_skin_active() else ORNATE_CHARACTER_WIDTH) * calibration_scale
	)
	var resources_width := roundf((58.0 if _clean_skin_active() else 0.0) * calibration_scale)
	var move_width := roundf((layout_data.move_action_size.x if _clean_skin_active() else 0.0) * calibration_scale)
	var turn_width := _effective_end_turn_size(viewport_width).x
	var block_gap := roundf((layout_data.block_separation if _clean_skin_active() else 12.0) * calibration_scale)
	# Les deux flèches de bascule occupent leur propre bloc de largeur, compté
	# ici que la barre d'objets soit affichée ou non : « Fin de tour » et le
	# bouton de compétences sont donc décalés vers la droite en permanence,
	# jamais seulement à l'ouverture de la barre d'objets.
	var toggle_width := roundf(METRICS.BAR_TOGGLE_WIDTH * calibration_scale)
	var total_width := (
		character_width
		+ resources_width
		+ move_width
		+ ability_width
		+ toggle_width
		+ turn_width
		+ block_gap * (5.0 if _clean_skin_active() else 3.0)
	)
	var content_height := (
		panel_height - roundf(16.0 * calibration_scale)
		if _clean_skin_active()
		else maxf(roundf(150.0 * _layout_scale), visual_size + shortcut_height)
	)
	var content_top := (
		panel_height
		- content_height
		- roundf((8.0 if _clean_skin_active() else 12.0) * calibration_scale)
	)
	var content_left := viewport_width * 0.5 - total_width * 0.5
	_set_control_rect(
		_character_anchor,
		Rect2(
			content_left,
			content_top,
			character_width,
			content_height
		)
	)
	content_left += character_width + block_gap
	if _clean_skin_active():
		_set_control_rect(
			_action_resources_anchor,
			Rect2(content_left, content_top, resources_width, content_height)
		)
		content_left += resources_width + block_gap
		_set_control_rect(
			_move_action_host,
			Rect2(content_left, content_top, move_width, content_height)
		)
		content_left += move_width + block_gap
	_set_control_rect(
		_spell_anchor,
		Rect2(
			content_left,
			content_top,
			ability_width,
			content_height
		)
	)
	content_left += ability_width + block_gap
	_set_control_rect(
		_bar_toggle_anchor,
		Rect2(content_left, content_top, toggle_width, content_height)
	)
	content_left += toggle_width + block_gap
	var turn_top := content_top
	var turn_height := content_height
	if _clean_skin_active() and not _compact_layout_active():
		turn_top += (23.0 if _refined_skin_active() else 42.0) * calibration_scale
		turn_height = (158.0 if _refined_skin_active() else 120.0) * calibration_scale
	_set_control_rect(
		_turn_anchor,
		Rect2(content_left, turn_top, turn_width, turn_height)
	)
	_set_control_rect(
		_basic_attack_host,
		Rect2(0.0, 0.0, visual_size, content_height)
	)
	# La barre d'objets occupe exactement la même bande que la barre de sorts :
	# les deux ne sont jamais visibles en même temps, et le bouton d'attaque de
	# base reste à gauche dans les deux vues.
	for slots_center in [_spell_slots_center, _item_slots_center]:
		_set_control_rect(
			slots_center,
			Rect2(
				visual_size + slot_gap,
				0.0,
				spells_width,
				content_height
			)
		)
	if _clean_skin_active():
		_basic_attack_host.position.y = 28.0 * calibration_scale
		_basic_attack_host.size.y = content_height - 36.0 * calibration_scale
		for slots_center in [_spell_slots_center, _item_slots_center]:
			slots_center.position.y = 28.0 * calibration_scale
			slots_center.size.y = content_height - 36.0 * calibration_scale
		_set_control_rect(
			_selected_spell_plate,
			Rect2(
				Vector2(6.0, 5.0) * calibration_scale,
				Vector2(
					ability_width - 12.0 * calibration_scale,
					26.0 * calibration_scale
				)
			)
		)
		_selected_spell_plate.add_theme_font_size_override("font_size", maxi(layout_data.contextual_text_size, 12))


func _restore_neutral_panel_layout() -> void:
	_character_panel_size = Vector2.ZERO
	_hud_band.offset_top = -METRICS.HUD_HEIGHT
	_hud_band.offset_bottom = 0.0
	_neutral_background.visible = true
	_spellbar_background.visible = true
	_set_anchor_geometry(
		_character_anchor,
		Vector4(0.0, 1.0, 0.0, 1.0),
		Vector4(18.0, -140.0, 440.0, -10.0)
	)
	_set_anchor_geometry(
		_spell_anchor,
		Vector4(0.5, 1.0, 0.5, 1.0),
		Vector4(-260.0, -140.0, 260.0, -10.0)
	)
	# Sans habillage de personnage, le bloc de fin de tour est collé au bord
	# droit : on ne peut pas le décaler plus loin. On réserve donc l'espace des
	# flèches juste à sa gauche, ce qui produit le même résultat — la bascule ne
	# recouvre jamais « Fin de tour ».
	_set_anchor_geometry(
		_turn_anchor,
		Vector4(1.0, 1.0, 1.0, 1.0),
		Vector4(-170.0, -140.0, -18.0, -10.0)
	)
	_set_anchor_geometry(
		_bar_toggle_anchor,
		Vector4(1.0, 1.0, 1.0, 1.0),
		Vector4(
			-170.0 - METRICS.BAR_TOGGLE_WIDTH - 8.0,
			-140.0,
			-178.0,
			-10.0
		)
	)
	for slots_center in [_spell_slots_center, _item_slots_center]:
		_set_anchor_geometry(
			slots_center,
			Vector4(0.0, 0.0, 1.0, 1.0),
			Vector4.ZERO
		)


func _set_control_rect(control: Control, rectangle: Rect2) -> void:
	_set_anchor_geometry(
		control,
		Vector4.ZERO,
		Vector4(
			rectangle.position.x,
			rectangle.position.y,
			rectangle.end.x,
			rectangle.end.y
		)
	)


func _set_anchor_geometry(
		control: Control,
		anchors: Vector4,
		offsets: Vector4
	) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w


func _apply_layout_metrics() -> void:
	if not is_node_ready():
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	_layout_scale = METRICS.scale_for(viewport_width)
	if _official_chassis_active():
		_apply_character_panel_layout(viewport_width)
	else:
		_restore_neutral_panel_layout()

	if _official_chassis_active():
		var visual_scale := _chassis_visual_scale(viewport_width)
		var portrait_size := _effective_portrait_size(viewport_width)
		var health_size := _effective_health_bar_size(viewport_width)
		var badge_size := _effective_badge_size(viewport_width)
		_portrait_view.apply_layout(
			portrait_size / METRICS.PORTRAIT_SIZE
		)
		_hp_bar.apply_calibrated_layout(health_size, visual_scale)
		_ap_badge.apply_layout(
			badge_size / METRICS.RESOURCE_BADGE_SIZE
		)
		_mp_badge.apply_layout(
			badge_size / METRICS.RESOURCE_BADGE_SIZE
		)
		_character_info.custom_minimum_size.x = health_size.x
	else:
		_portrait_view.apply_layout(_layout_scale)
		_hp_bar.apply_layout(_layout_scale)
		_ap_badge.apply_layout(_layout_scale)
		_mp_badge.apply_layout(_layout_scale)
		_character_info.custom_minimum_size.x = METRICS.scaled(
			METRICS.CHARACTER_INFO_WIDTH, _layout_scale
		)
	_character_row.add_theme_constant_override(
		"separation",
		int(roundf((6.0 if _clean_skin_active() else METRICS.CHARACTER_SECTION_GAP) * _layout_scale))
	)
	_identity_discipline_label.add_theme_font_size_override(
		"font_size", 11 if _compact_layout_active() else (13 if _clean_skin_active() else 12)
	)
	_info_label.custom_minimum_size.y = METRICS.scaled(
		METRICS.CHARACTER_NAME_HEIGHT, _layout_scale
	)
	_info_label.add_theme_font_size_override(
		"font_size",
		16 if _compact_layout_active() else 20
		if _clean_skin_active()
		else METRICS.scaled_font(
			METRICS.CHARACTER_NAME_FONT_SIZE, _layout_scale
		)
	)
	_bar_stack.add_theme_constant_override(
		"separation",
		int(METRICS.scaled(METRICS.RESOURCE_BAR_GAP, _layout_scale))
	)
	_action_buttons.add_theme_constant_override(
		"h_separation",
		int(METRICS.scaled(METRICS.ACTION_BUTTON_GAP, _layout_scale))
	)
	_action_buttons.add_theme_constant_override(
		"v_separation",
		int(METRICS.scaled(METRICS.ACTION_BUTTON_ROW_GAP, _layout_scale))
	)
	_resource_badges.add_theme_constant_override(
		"separation",
		int(METRICS.scaled(METRICS.RESOURCE_BADGE_GAP, _layout_scale))
	)
	var action_size := METRICS.scaled_vector(
		METRICS.ACTION_BUTTON_SIZE, _layout_scale
	)
	var action_font := METRICS.scaled_font(
		METRICS.ACTION_BUTTON_FONT_SIZE, _layout_scale
	)
	for action_button in [_move_btn]:
		action_button.apply_layout(action_size, action_font)
	if _clean_skin_active():
		_move_btn.apply_layout(
			Vector2(layout_data.move_action_size.x, layout_data.move_action_size.y) * _chassis_visual_scale(viewport_width),
			12 if _compact_layout_active() else 14
		)
		_move_btn.set_compact_icon_mode(
			_refined_skin_active(),
			clampf(
				(48.0 if _compact_layout_active() else 64.0) * _chassis_visual_scale(viewport_width),
				38.0 if _compact_layout_active() else 54.0,
				54.0 if _compact_layout_active() else 72.0
			)
		)
	if _attack_grouped_with_spells:
		var attack_visual_size := _effective_spell_visual_size(viewport_width)
		var attack_shortcut_height := _effective_spell_shortcut_height(
			viewport_width
		)
		_attack_btn.apply_layout(
			Vector2(
				attack_visual_size,
				attack_visual_size + attack_shortcut_height
			),
			METRICS.scaled_font(
				METRICS.COST_FONT_SIZE,
				_chassis_visual_scale(viewport_width)
			)
		)
		_attack_btn.set_compact_icon_mode(
			true,
			_effective_spell_icon_size(viewport_width) - 10.0
		)
	else:
		_attack_btn.apply_layout(action_size, action_font)
		_attack_btn.set_compact_icon_mode(false)

	var end_turn_size := (
		_effective_end_turn_size(viewport_width)
		if _official_chassis_active()
		else METRICS.scaled_vector(
			METRICS.END_TURN_SIZE, _layout_scale
		)
	)
	_end_btn.apply_layout(
		end_turn_size,
		(15 if _compact_layout_active() else 19) if _clean_skin_active() else METRICS.scaled_font(METRICS.PRIMARY_BUTTON_FONT_SIZE, _layout_scale)
	)
	var compact_turn_height := maxf(_character_panel_size.y - 16.0 * _base_chassis_visual_scale(viewport_width), 64.0)
	var turn_content_height := (
		compact_turn_height
		if _compact_layout_active()
		else (118.0 if _refined_skin_active() else 68.0)
	)
	_turn_content.custom_minimum_size = Vector2(
		end_turn_size.x,
		turn_content_height if _compact_layout_active() else METRICS.scaled(turn_content_height, _layout_scale)
	)
	if _compact_layout_active():
		var compact_scale := _chassis_visual_scale(viewport_width)
		var end_top := 11.0 * compact_scale
		_set_control_rect(
			_end_btn,
			Rect2(0.0, end_top, end_turn_size.x, end_turn_size.y)
		)
		var utility_size := clampf(28.0 * compact_scale, 22.0, 30.0)
		_skills_button.custom_minimum_size = Vector2.ONE * utility_size
		_set_control_rect(
			_utility_dock,
			Rect2(
				(end_turn_size.x - utility_size) * 0.5,
				turn_content_height - utility_size - 2.0,
				utility_size,
				utility_size
			)
		)
	else:
		_end_btn.set_anchors_preset(Control.PRESET_CENTER)
		_end_btn.offset_left = -end_turn_size.x * 0.5
		var end_turn_y_shift := -13.0 if _refined_skin_active() else 0.0
		_end_btn.offset_top = -end_turn_size.y * 0.5 + end_turn_y_shift
		_end_btn.offset_right = end_turn_size.x * 0.5
		_end_btn.offset_bottom = end_turn_size.y * 0.5 + end_turn_y_shift
	var turn_label_height := METRICS.scaled(12.0, _layout_scale)
	var turn_label_gap := METRICS.scaled(METRICS.TURN_LABEL_GAP, _layout_scale)
	_turn_label.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(METRICS.SECONDARY_FONT_SIZE, _layout_scale)
	)
	_turn_label.set_anchors_preset(Control.PRESET_CENTER)
	_turn_label.offset_left = -end_turn_size.x * 0.5
	_turn_label.offset_right = end_turn_size.x * 0.5
	_turn_label.offset_top = (
		-turn_content_height * 0.5 + 2.0
		if _refined_skin_active()
		else -end_turn_size.y * 0.5 - turn_label_gap - turn_label_height
	)
	_turn_label.offset_bottom = _turn_label.offset_top + turn_label_height

	_spell_box.add_theme_constant_override(
		"separation",
		int(_effective_spell_gap(viewport_width))
	)
	_item_slots_container.add_theme_constant_override(
		"separation",
		int(_effective_spell_gap(viewport_width))
	)
	for spell_button in _spell_buttons:
		_apply_spell_button_layout(spell_button)
	for item_button in _item_buttons:
		_apply_spell_button_layout(item_button)
	_apply_bar_toggle_layout(viewport_width)
	_update_spell_section_geometry()
	_layout_debug_overlay.set_debug_enabled(show_layout_debug)


func _apply_bar_toggle_layout(viewport_width: float) -> void:
	var toggle_scale := (
		_chassis_visual_scale(viewport_width)
		if _official_chassis_active()
		else _layout_scale
	)
	var button_size := METRICS.scaled_vector(
		METRICS.BAR_TOGGLE_BUTTON_SIZE, toggle_scale
	)
	_bar_toggle.add_theme_constant_override(
		"separation", int(METRICS.scaled(METRICS.BAR_TOGGLE_GAP, toggle_scale))
	)
	for toggle_button in [_show_spells_button, _show_items_button]:
		toggle_button.custom_minimum_size = button_size
		toggle_button.add_theme_font_size_override(
			"font_size", METRICS.scaled_font(14, toggle_scale)
		)


func _update_spell_section_geometry() -> void:
	if not is_node_ready():
		return
	var slot_count := maxi(_spell_buttons.size(), 1)
	var viewport_width := get_viewport().get_visible_rect().size.x
	var slot_width := _effective_spell_visual_size(viewport_width)
	var slot_gap := _effective_spell_gap(viewport_width)
	var panel_padding := METRICS.scaled(
		METRICS.SPELL_PANEL_PADDING,
		_layout_scale
	)
	var panel_width := (
		slot_count * slot_width
		+ maxi(slot_count - 1, 0) * slot_gap
		+ panel_padding * 2.0
	)
	var panel_height := METRICS.scaled(
		METRICS.SPELL_PANEL_HEIGHT,
		_layout_scale
	)
	if _official_chassis_active():
		panel_width = _spell_anchor.size.x
		panel_height = (
			_effective_spell_visual_size(viewport_width)
			+ _effective_spell_shortcut_height(viewport_width)
		)
	var texture_size := Vector2(panel_width, panel_height)
	if _official_chassis_active():
		texture_size.y = texture_size.x / SPELLBAR_TEXTURE_RATIO
	elif texture_size.aspect() > SPELLBAR_TEXTURE_RATIO:
		texture_size.y = texture_size.x / SPELLBAR_TEXTURE_RATIO
	else:
		texture_size.x = texture_size.y * SPELLBAR_TEXTURE_RATIO
	_spellbar_background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_spellbar_background.position = (
		_spell_section.size - texture_size
	) * 0.5
	_spellbar_background.size = texture_size
