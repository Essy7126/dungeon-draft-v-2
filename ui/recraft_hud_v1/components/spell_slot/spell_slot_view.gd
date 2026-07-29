class_name RecraftSpellSlotView
extends Button

enum VisualState {
	NORMAL,
	HOVER,
	SELECTED,
	DISABLED,
	UNAFFORDABLE,
	COOLDOWN,
	LOCKED,
}

@onready var background: ColorRect = %Background
@onready var spell_icon: TextureRect = %SpellIcon
@onready var frame: TextureRect = %Frame
@onready var selection_overlay: Panel = %SelectionOverlay
@onready var hover_overlay: ColorRect = %HoverOverlay
@onready var disabled_overlay: ColorRect = %DisabledOverlay
@onready var cooldown_overlay: ColorRect = %CooldownOverlay
@onready var cooldown_label: Label = %CooldownLabel
@onready var cost_icon: Label = %CostIcon
@onready var cost_label: Label = %CostLabel
@onready var energy_cost_label: Label = %EnergyCostLabel
@onready var shortcut_label: Label = %ShortcutLabel
@onready var lock_icon: Label = %LockIcon
@onready var imprint_label: Label = %ImprintLabel
@onready var fallback_label: Label = %FallbackLabel

var visual_state := VisualState.NORMAL
var spell = null
var imprinted := false
var _hovered := false


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_refresh_visuals)
	focus_exited.connect(_refresh_visuals)
	resized.connect(_update_pivot)
	_update_pivot()
	_refresh_visuals()


func configure(
		new_spell,
	ap_cost: int,
	energy_cost: float = 0.0,
	energy_name: String = "",
	shortcut: String = "",
	is_imprinted: bool = false
) -> void:
	spell = new_spell
	imprinted = is_imprinted
	var icon: Texture2D = spell.icon if spell != null else null
	spell_icon.texture = icon
	fallback_label.visible = icon == null
	fallback_label.text = _fallback_text()
	cost_icon.text = "PA"
	cost_label.text = str(maxi(ap_cost, 0))
	var energy_abbreviation := energy_name.left(1).to_upper()
	energy_cost_label.text = (
		"%d %s" % [int(energy_cost), energy_abbreviation]
		if energy_cost > 0.0
		else ""
	)
	shortcut_label.text = shortcut
	imprint_label.visible = imprinted
	tooltip_text = ""
	accessibility_name = _accessible_description(ap_cost, energy_cost, energy_name)


func set_visual_state(state: VisualState, cooldown_turns: int = 0) -> void:
	visual_state = state
	disabled = state in [
		VisualState.DISABLED,
		VisualState.UNAFFORDABLE,
		VisualState.COOLDOWN,
		VisualState.LOCKED,
	]
	cooldown_label.text = str(maxi(cooldown_turns, 1))
	_refresh_visuals()


func set_cooldown(turns: int) -> void:
	set_visual_state(VisualState.COOLDOWN if turns > 0 else VisualState.NORMAL, turns)


func set_locked(locked: bool) -> void:
	set_visual_state(VisualState.LOCKED if locked else VisualState.NORMAL)


func _refresh_visuals() -> void:
	if not is_node_ready():
		return
	var selected := visual_state == VisualState.SELECTED
	var hovered := _hovered and not disabled
	selection_overlay.visible = selected or has_focus()
	hover_overlay.visible = hovered and not selected
	disabled_overlay.visible = visual_state in [VisualState.DISABLED, VisualState.UNAFFORDABLE]
	cooldown_overlay.visible = visual_state == VisualState.COOLDOWN
	cooldown_label.visible = visual_state == VisualState.COOLDOWN
	lock_icon.visible = visual_state == VisualState.LOCKED
	disabled_overlay.color = (
		Color(0.42, 0.06, 0.06, 0.62)
		if visual_state == VisualState.UNAFFORDABLE
		else Color(0.03, 0.04, 0.055, 0.68)
	)
	frame.modulate = (
		Color(1.12, 1.08, 0.82, 1.0)
		if selected
		else Color(0.52, 0.54, 0.58, 0.78)
		if disabled
		else Color.WHITE
	)
	spell_icon.modulate = Color(0.5, 0.5, 0.52, 0.78) if disabled else Color.WHITE
	var target_scale := Vector2(1.025, 1.025) if hovered or selected else Vector2.ONE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, 0.08)


func _on_mouse_entered() -> void:
	_hovered = true
	if visual_state == VisualState.NORMAL:
		visual_state = VisualState.HOVER
	_refresh_visuals()


func _on_mouse_exited() -> void:
	_hovered = false
	if visual_state == VisualState.HOVER:
		visual_state = VisualState.NORMAL
	_refresh_visuals()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _fallback_text() -> String:
	if spell == null:
		return "?"
	var display_name: String = spell.spell_name
	return display_name.left(1).to_upper() if not display_name.is_empty() else "?"


func _accessible_description(ap_cost: int, energy_cost: float, energy_name: String) -> String:
	var display_name: String = spell.spell_name if spell != null else "Sort"
	var parts := ["%s, %d PA" % [display_name, ap_cost]]
	if energy_cost > 0.0:
		parts.append("%d %s" % [int(energy_cost), energy_name])
	if imprinted:
		parts.append("Empreinte")
	return ", ".join(parts)
