extends "res://ui/action_bar.gd"

const SPELL_SLOT_SCENE := preload(
	"res://ui/recraft_hud_v1/components/spell_slot/spell_slot_view.tscn"
)
const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")
const SPELLBAR_TEXTURE_RATIO := 3155.0 / 612.0

enum RunUIMode {
	COMBAT,
	NON_COMBAT,
	TRANSITION,
}

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
@onready var _character_anchor: Control = %CharacterAnchor
@onready var _spell_anchor: Control = %SpellAnchor
@onready var _turn_anchor: Control = %TurnAnchor
@onready var _character_section: MarginContainer = %CharacterSection
@onready var _turn_section: MarginContainer = %TurnSection
@onready var _spell_section: Control = %SpellSection
@onready var _spellbar_background: TextureRect = %SpellBarBackground
@onready var _character_info: VBoxContainer = %CharacterInfo
@onready var _character_row: HBoxContainer = %CharacterRow
@onready var _bar_stack: VBoxContainer = %BarStack
@onready var _action_buttons: GridContainer = %ActionButtons
@onready var _resource_badges: HBoxContainer = %ResourceBadges
@onready var _turn_content: Control = %TurnContent
@onready var _turn_label: Label = %TurnLabel
@onready var _layout_debug_overlay: Control = %LayoutDebugOverlay

var _active_mode := ""
var _active_spell = null
var _active_spell_imprinted := false
var _layout_scale := 1.0
var _combat_context: Node = null
var _context_tree_exiting_callback := Callable()
var _ui_mode: RunUIMode = RunUIMode.TRANSITION


func _ready() -> void:
	_hbox = %SpellSlotsContainer
	_info_label = %CharacterName
	_spell_box = %SpellSlotsContainer
	_move_btn = %MoveButton
	_attack_btn = %AttackButton
	_awakening_btn = %AwakeningButton
	_reaction_btn = %ReactionButton
	_end_btn = %EndTurnButton

	_move_btn.set_label("Déplacer")
	_attack_btn.set_label("Attaquer")
	_awakening_btn.set_label("Éveil")
	_reaction_btn.set_label("Garde")
	_end_btn.set_label("Fin de tour")

	if not get_viewport().size_changed.is_connected(_apply_layout_metrics):
		get_viewport().size_changed.connect(_apply_layout_metrics)
	_move_btn.tooltip_text = "PM : sert uniquement au deplacement."
	_move_btn.pressed.connect(func() -> void: move_pressed.emit())
	_attack_btn.pressed.connect(func() -> void: attack_pressed.emit())
	_awakening_btn.pressed.connect(func() -> void: awakening_pressed.emit())
	_reaction_btn.pressed.connect(func() -> void: reaction_pressed.emit())
	_end_btn.pressed.connect(func() -> void: end_turn_pressed.emit())
	_set_energy_controls_visible(false)
	_apply_layout_metrics()
	_refresh_resource_bars(null)
	_refresh_button_states()
	set_ui_mode(_ui_mode)


func _exit_tree() -> void:
	unbind_combat_context()
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
	button.set_meta("spell", spell)
	button.set_meta("imprinted", imprinted)
	button.mouse_entered.connect(func() -> void: _show_spell_card(unit, spell, imprinted))
	button.mouse_exited.connect(_hide_keyword_tooltip)
	button.pressed.connect(func() -> void: spell_pressed.emit(spell, imprinted))
	_spell_buttons.append(button)
	button.apply_layout(_layout_scale)
	_update_spell_section_geometry()


func update_info(unit) -> void:
	_disconnect_current_unit()
	_current_unit = unit
	if unit == null:
		_info_label.text = ""
		_portrait_view.set_character_data(null)
		_portrait_view.set_active(false)
		_refresh_resource_bars(null, false)
		_refresh_button_states()
		return

	_info_label.text = unit.unit_name
	_portrait_view.set_character_data(unit.character_data)
	_portrait_view.set_active(true)
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
	_energy_name_label.text = energy_type.energy_name
	_energy_bar.set_resource(
		unit.current_energy,
		energy_type.max_energy,
		energy_type.get_school_color(),
		null,
		energy_type.energy_name.left(1).to_upper(),
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
	_attack_btn.set_label(
		"Attaquer · %d PA" % _current_unit.get_basic_attack_ap_cost()
		if _current_unit != null
		else "Attaquer"
	)
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


func _apply_layout_metrics() -> void:
	if not is_node_ready():
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	_layout_scale = METRICS.scale_for(viewport_width)

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
		int(METRICS.scaled(METRICS.CHARACTER_SECTION_GAP, _layout_scale))
	)
	_info_label.custom_minimum_size.y = METRICS.scaled(
		METRICS.CHARACTER_NAME_HEIGHT, _layout_scale
	)
	_info_label.add_theme_font_size_override(
		"font_size",
		METRICS.scaled_font(METRICS.CHARACTER_NAME_FONT_SIZE, _layout_scale)
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
	for action_button in [_move_btn, _attack_btn, _awakening_btn, _reaction_btn]:
		action_button.apply_layout(action_size, action_font)

	var end_turn_size := METRICS.scaled_vector(
		METRICS.END_TURN_SIZE, _layout_scale
	)
	_end_btn.apply_layout(
		end_turn_size,
		METRICS.scaled_font(METRICS.PRIMARY_BUTTON_FONT_SIZE, _layout_scale)
	)
	_turn_content.custom_minimum_size = Vector2(
		end_turn_size.x,
		METRICS.scaled(68.0, _layout_scale)
	)
	_end_btn.set_anchors_preset(Control.PRESET_CENTER)
	_end_btn.offset_left = -end_turn_size.x * 0.5
	_end_btn.offset_top = -end_turn_size.y * 0.5
	_end_btn.offset_right = end_turn_size.x * 0.5
	_end_btn.offset_bottom = end_turn_size.y * 0.5
	var turn_label_height := METRICS.scaled(12.0, _layout_scale)
	var turn_label_gap := METRICS.scaled(METRICS.TURN_LABEL_GAP, _layout_scale)
	_turn_label.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(METRICS.SECONDARY_FONT_SIZE, _layout_scale)
	)
	_turn_label.set_anchors_preset(Control.PRESET_CENTER)
	_turn_label.offset_left = -end_turn_size.x * 0.5
	_turn_label.offset_right = end_turn_size.x * 0.5
	_turn_label.offset_top = -end_turn_size.y * 0.5 - turn_label_gap - turn_label_height
	_turn_label.offset_bottom = _turn_label.offset_top + turn_label_height

	_spell_box.add_theme_constant_override(
		"separation",
		int(METRICS.scaled(METRICS.SPELL_GAP, _layout_scale))
	)
	for spell_button in _spell_buttons:
		spell_button.apply_layout(_layout_scale)
	_update_spell_section_geometry()
	_layout_debug_overlay.set_debug_enabled(show_layout_debug)


func _update_spell_section_geometry() -> void:
	if not is_node_ready():
		return
	var slot_count := maxi(_spell_buttons.size(), 1)
	var slot_width := METRICS.scaled(METRICS.SPELL_VISUAL_SIZE, _layout_scale)
	var slot_gap := METRICS.scaled(METRICS.SPELL_GAP, _layout_scale)
	var panel_padding := METRICS.scaled(METRICS.SPELL_PANEL_PADDING, _layout_scale)
	var panel_width := (
		slot_count * slot_width
		+ maxi(slot_count - 1, 0) * slot_gap
		+ panel_padding * 2.0
	)
	var panel_height := METRICS.scaled(METRICS.SPELL_PANEL_HEIGHT, _layout_scale)
	var texture_size := Vector2(panel_width, panel_height)
	if texture_size.aspect() > SPELLBAR_TEXTURE_RATIO:
		texture_size.y = texture_size.x / SPELLBAR_TEXTURE_RATIO
	else:
		texture_size.x = texture_size.y * SPELLBAR_TEXTURE_RATIO
	_spellbar_background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_spellbar_background.position = (
		_spell_section.size - texture_size
	) * 0.5
	_spellbar_background.size = texture_size
