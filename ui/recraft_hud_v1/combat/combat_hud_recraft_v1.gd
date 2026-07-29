extends "res://ui/action_bar.gd"

const SPELL_SLOT_SCENE := preload(
	"res://ui/recraft_hud_v1/components/spell_slot/spell_slot_view.tscn"
)

@onready var _portrait_view: Control = %PortraitView
@onready var _hp_bar: Control = %HealthBar
@onready var _energy_bar: Control = %EnergyBar
@onready var _ap_badge: Control = %ActionPointsBadge
@onready var _mp_badge: Control = %MovementPointsBadge
@onready var _energy_name_label: Label = %EnergyNameLabel

var _active_mode := ""
var _active_spell = null
var _active_spell_imprinted := false


func _ready() -> void:
	_hbox = %HudRow
	_info_label = %CharacterName
	_spell_box = %SpellSlotsContainer
	_move_btn = %MoveButton
	_attack_btn = %AttackButton
	_awakening_btn = %AwakeningButton
	_reaction_btn = %ReactionButton
	_end_btn = %EndTurnButton

	_move_btn.set_label("Deplacer")
	_attack_btn.set_label("Attaquer")
	_awakening_btn.set_label("Eveil")
	_reaction_btn.set_label("Garde")
	_end_btn.set_label("Fin de tour")

	_move_btn.tooltip_text = "PM : sert uniquement au deplacement."
	_move_btn.pressed.connect(func() -> void: move_pressed.emit())
	_attack_btn.pressed.connect(func() -> void: attack_pressed.emit())
	_awakening_btn.pressed.connect(func() -> void: awakening_pressed.emit())
	_reaction_btn.pressed.connect(func() -> void: reaction_pressed.emit())
	_end_btn.pressed.connect(func() -> void: end_turn_pressed.emit())
	_set_energy_controls_visible(false)
	_refresh_resource_bars(null)
	_refresh_button_states()


func _exit_tree() -> void:
	_disconnect_current_unit()


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


func update_info(unit) -> void:
	_disconnect_current_unit()
	_current_unit = unit
	if unit == null:
		_info_label.text = ""
		_portrait_view.set_portrait(null, "")
		_portrait_view.set_active(false)
		_refresh_resource_bars(null, false)
		_refresh_button_states()
		return

	_info_label.text = unit.unit_name
	_portrait_view.set_portrait(_portrait_texture_for_unit(unit), unit.unit_name)
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
		"Attaquer\n%d PA" % _current_unit.get_basic_attack_ap_cost()
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
	_reaction_btn.set_label(_reaction_button_text(_current_unit))
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
	for control in [_energy_bar, _energy_name_label, _awakening_btn, _reaction_btn]:
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


func _portrait_texture_for_unit(unit) -> Texture2D:
	if unit == null or unit.sprite_frames == null:
		return null
	var frames: SpriteFrames = unit.sprite_frames
	var animation := StringName(unit.idle_animation)
	if not frames.has_animation(animation):
		var animations := frames.get_animation_names()
		if animations.is_empty():
			return null
		animation = animations[0]
	if frames.get_frame_count(animation) <= 0:
		return null
	return frames.get_frame_texture(animation, 0)


func _sync_primary_button(button: Button, active: bool) -> void:
	if button != null and button.has_method("refresh_visual_state"):
		button.refresh_visual_state(active)
