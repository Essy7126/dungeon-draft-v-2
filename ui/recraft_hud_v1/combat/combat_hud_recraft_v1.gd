extends "res://ui/action_bar.gd"

signal utility_skill_tree_requested(character_id: StringName, discipline_id: StringName)

const SPELL_SLOT_SCENE := preload(
	"res://ui/recraft_hud_v1/components/spell_slot/spell_slot_view.tscn"
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
@onready var _energy_bar: Control = %EnergyBar
@onready var _ap_badge: Control = %ActionPointsBadge
@onready var _mp_badge: Control = %MovementPointsBadge
@onready var _energy_name_label: Label = %EnergyNameLabel
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
var _active_spell_imprinted := false
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


func _ready() -> void:
	if character_themes.is_empty() and skin_variant == HudSkinVariant.ORNATE:
		character_themes.append(DEFAULT_CHARACTER_THEME)
	_hbox = %SpellSlotsContainer
	_info_label = %CharacterName
	_spell_box = %SpellSlotsContainer
	_move_btn = %MoveButton
	_attack_btn = %AttackButton
	_awakening_btn = %AwakeningButton
	_reaction_btn = %ReactionButton
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
	_awakening_btn.set_label("Éveil")
	_reaction_btn.set_label("Garde")
	_end_btn.set_label("Fin de tour")

	if not get_viewport().size_changed.is_connected(_apply_layout_metrics):
		get_viewport().size_changed.connect(_apply_layout_metrics)
	_move_btn.tooltip_text = "Déplacer — choisissez une case accessible (coût en PM)."
	_move_btn.pressed.connect(func() -> void: move_pressed.emit())
	_attack_btn.pressed.connect(func() -> void: attack_pressed.emit())
	_awakening_btn.pressed.connect(func() -> void: awakening_pressed.emit())
	_reaction_btn.pressed.connect(func() -> void: reaction_pressed.emit())
	_end_btn.pressed.connect(func() -> void: end_turn_pressed.emit())
	_skills_button.pressed.connect(_on_skills_button_pressed)
	var skills_shortcut := Shortcut.new()
	var skills_key := InputEventKey.new()
	skills_key.physical_keycode = KEY_K
	skills_shortcut.events = [skills_key]
	_skills_button.shortcut = skills_shortcut
	_skills_button.shortcut_in_tooltip = true
	if not EventBus.turn_started.is_connected(_on_event_bus_turn_started):
		EventBus.turn_started.connect(_on_event_bus_turn_started)
	_set_energy_controls_visible(false)
	_apply_layout_metrics()
	_refresh_resource_bars(null)
	_refresh_button_states()
	set_ui_mode(_ui_mode)


func _exit_tree() -> void:
	unbind_combat_context()
	if EventBus.turn_started.is_connected(_on_event_bus_turn_started):
		EventBus.turn_started.disconnect(_on_event_bus_turn_started)
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
	# The production Refined HUD is PA/PM-only. Legacy Ornate/Clean screens keep
	# their historical energy actions and signals unchanged.
	if skin_variant != HudSkinVariant.REFINED:
		_connect_action_to_context(awakening_pressed, &"_on_awakening_pressed")
		_connect_action_to_context(reaction_pressed, &"_on_reaction_pressed")
	_connect_action_to_context(end_turn_pressed, &"_on_end_turn_pressed")


func _disconnect_context_actions() -> void:
	if not is_instance_valid(_combat_context):
		return
	_disconnect_action_from_context(move_pressed, &"_on_move_pressed")
	_disconnect_action_from_context(attack_pressed, &"_on_attack_pressed")
	_disconnect_action_from_context(spell_pressed, &"_on_spell_pressed")
	_disconnect_action_from_context(awakening_pressed, &"_on_awakening_pressed")
	_disconnect_action_from_context(reaction_pressed, &"_on_reaction_pressed")
	_disconnect_action_from_context(end_turn_pressed, &"_on_end_turn_pressed")


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


func _add_spell_button(unit, spell, imprinted: bool) -> void:
	var button := SPELL_SLOT_SCENE.instantiate() as Button
	if button == null:
		push_error("Impossible d'instancier SpellSlotView.")
		return
	var ap_cost: int = unit.get_spell_ap_cost(spell)
	var energy_cost: float = (
		unit.get_spell_fervor_cost(spell, imprinted)
		if unit.has_energy()
		else 0.0
	)
	var energy_name: String = unit.energy_type.energy_name if unit.has_energy() else ""
	_spell_box.add_child(button)
	button.configure(
		spell,
		ap_cost,
		energy_cost,
		energy_name,
		str(_spell_buttons.size() + 1),
		imprinted
	)
	var shortcut_index := _spell_buttons.size()
	if shortcut_index < SPELL_SHORTCUT_KEYS.size():
		var shortcut_event := InputEventKey.new()
		shortcut_event.physical_keycode = SPELL_SHORTCUT_KEYS[shortcut_index]
		var shortcut := Shortcut.new()
		shortcut.events = [shortcut_event]
		button.shortcut = shortcut
		button.shortcut_in_tooltip = true
	if _active_character_theme != null:
		button.set_icon_override(
			_active_character_theme.get_spell_icon_for(spell)
		)
		button.set_frame_override(
			_active_character_theme.get_spell_frame_for(spell)
		)
	button.set_refined_style(_refined_skin_active())
	button.set_meta("spell", spell)
	button.set_meta("imprinted", imprinted)
	button.mouse_entered.connect(func() -> void: _show_spell_card(unit, spell, imprinted))
	button.mouse_exited.connect(_hide_keyword_tooltip)
	button.pressed.connect(func() -> void: spell_pressed.emit(spell, imprinted))
	_spell_buttons.append(button)
	_apply_spell_button_layout(button)
	_update_spell_section_geometry()


func build_spell_buttons(unit) -> void:
	super.build_spell_buttons(unit)
	_apply_layout_metrics()


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
	if not unit.energy_changed.is_connected(_on_resource_changed):
		unit.energy_changed.connect(_on_resource_changed)
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
		_energy_bar.set_resource(
			0.0, 1.0, Color(0.36, 0.25, 0.58), null, "EN", true, animate_changes
		)
		_energy_bar.clear_preview()
		_ap_badge.set_badge(0, 0, Color(0.92, 0.69, 0.18), null, "PA")
		_mp_badge.set_badge(0, 0, Color(0.31, 0.67, 0.9), null, "PM")
		_energy_name_label.text = ""
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

	if not unit.has_energy():
		_set_energy_controls_visible(false)
		_energy_name_label.text = ""
		_energy_bar.clear_preview()
		return

	_set_energy_controls_visible(true)
	var energy_type: EnergyTypeData = unit.energy_type
	var displayed_energy_name := energy_type.energy_name
	var displayed_energy_color := energy_type.get_school_color()
	if _active_character_theme != null:
		if not _active_character_theme.energy_name.is_empty():
			displayed_energy_name = _active_character_theme.energy_name
		displayed_energy_color = _active_character_theme.energy_color
	_energy_name_label.text = displayed_energy_name
	_energy_bar.set_resource(
		unit.current_energy,
		energy_type.max_energy,
		displayed_energy_color,
		null,
		displayed_energy_name.left(1).to_upper(),
		true,
		animate_changes
	)
	_energy_bar.set_preview(_selected_energy_cost(unit), 0.0)


func _refresh_button_states() -> void:
	if not is_node_ready() or _move_btn == null:
		return
	_move_btn.disabled = not _player_controls_enabled
	_end_btn.disabled = not _player_controls_enabled

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

	var can_awaken: bool = (
		_current_unit != null
		and _current_unit.has_method("can_activate_awakening")
		and _current_unit.can_activate_awakening()
	)
	_awakening_btn.disabled = not _player_controls_enabled or not can_awaken

	var can_toggle_reaction := false
	if (
		_current_unit != null
		and _current_unit.team == 0
		and _current_unit.has_method("can_arm_reaction")
	):
		can_toggle_reaction = _current_unit.can_arm_reaction() or _current_unit.reaction_armed
	_reaction_btn.disabled = not _player_controls_enabled or not can_toggle_reaction
	_reaction_btn.set_label(
		_reaction_button_text(_current_unit)
		.replace("\n", " · ")
		.replace(" Ferveur", " F")
	)
	_reaction_btn.tooltip_text = _reaction_tooltip(_current_unit)

	for button_value in _spell_buttons:
		var button := button_value as Button
		var spell = button.get_meta("spell") if button.has_meta("spell") else null
		var imprinted: bool = button.get_meta("imprinted", false)
		var reason := _spell_unusable_reason(_current_unit, spell, imprinted)
		var is_selected: bool = (
			_active_mode == "spell"
			and spell == _active_spell
			and imprinted == _active_spell_imprinted
		)
		if not _player_controls_enabled:
			button.set_visual_state(RecraftSpellSlotView.VisualState.DISABLED)
		elif not reason.is_empty():
			button.set_visual_state(RecraftSpellSlotView.VisualState.UNAFFORDABLE)
		elif is_selected:
			button.set_visual_state(RecraftSpellSlotView.VisualState.SELECTED)
		else:
			button.set_visual_state(RecraftSpellSlotView.VisualState.NORMAL)

	_sync_primary_button(_move_btn, _active_mode == "move")
	_sync_primary_button(_attack_btn, _active_mode == "attack")
	_sync_primary_button(_awakening_btn, false)
	_sync_primary_button(
		_reaction_btn,
		_current_unit != null and _current_unit.reaction_armed
	)
	_sync_primary_button(_end_btn, false)


func set_active_mode(mode: String, active_spell = null, imprinted: bool = false) -> void:
	_active_mode = mode
	_active_spell = active_spell
	_active_spell_imprinted = imprinted
	_selected_spell_plate.visible = (
		mode == "move" or (mode == "spell" and active_spell != null)
	)
	if mode == "move":
		_selected_spell_plate.text = (
			"Déplacer  ·  Choisissez une case  ·  Échap pour annuler"
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


func _apply_base_button_modulates() -> void:
	_refresh_button_states()


func _set_energy_controls_visible(visible: bool) -> void:
	_energy_name_label.visible = false
	for control in [_energy_bar, _awakening_btn, _reaction_btn]:
		if control != null:
			control.visible = visible


func _selected_energy_cost(unit) -> float:
	if (
		unit == null
		or _active_mode != "spell"
		or _active_spell == null
		or not unit.has_energy()
	):
		return 0.0
	return unit.get_spell_fervor_cost(_active_spell, _active_spell_imprinted)


func _sync_primary_button(button: Button, active: bool) -> void:
	if button != null and button.has_method("refresh_visual_state"):
		button.refresh_visual_state(active)


func get_active_character_theme() -> CharacterHUDThemeData:
	return _active_character_theme


func get_turn_intro_banner() -> CharacterTurnIntroBanner:
	return _turn_intro_banner


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
		_energy_bar.set_refined_style(false)
		_ap_badge.set_refined_style(false)
		_mp_badge.set_refined_style(false)
		_move_btn.set_refined_style(false)
		_attack_btn.set_refined_style(false)
		_end_btn.set_refined_style(false)
		_identity_discipline_label.text = ""
		_identity_discipline_label.visible = false
		_utility_dock.visible = false
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
	_energy_bar.set_refined_style(refined)
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
		or unit.team != 0
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
	var total_width := (
		character_width
		+ resources_width
		+ move_width
		+ ability_width
		+ turn_width
		+ block_gap * (4.0 if _clean_skin_active() else 2.0)
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
	_set_control_rect(
		_spell_slots_center,
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
		_spell_slots_center.position.y = 28.0 * calibration_scale
		_spell_slots_center.size.y = content_height - 36.0 * calibration_scale
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
	_set_anchor_geometry(
		_turn_anchor,
		Vector4(1.0, 1.0, 1.0, 1.0),
		Vector4(-170.0, -140.0, -18.0, -10.0)
	)
	_set_anchor_geometry(
		_spell_slots_center,
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
		if _clean_skin_active():
			_energy_bar.apply_calibrated_layout(layout_data.special_resource_bar_size * visual_scale, visual_scale)
		else:
			_energy_bar.apply_layout(_layout_scale)
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
		_energy_bar.apply_layout(_layout_scale)
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
	for action_button in [_move_btn, _awakening_btn, _reaction_btn]:
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
	for spell_button in _spell_buttons:
		_apply_spell_button_layout(spell_button)
	_update_spell_section_geometry()
	_layout_debug_overlay.set_debug_enabled(show_layout_debug)


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
