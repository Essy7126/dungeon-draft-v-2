@tool
class_name DynamicWall
extends Node2D

## Objet logique generique. Il ne connait ni GridData ni AStarGrid2D : le
## DynamicBlockerService est l'unique pont vers la grille et le Pathfinder.

signal variant_changed(wall: DynamicWall, previous_variant: int, variant: int)
signal hp_changed(wall: DynamicWall, hp: int, max_hp: int)
signal duration_changed(wall: DynamicWall, remaining_turns: int)
signal state_changed(wall: DynamicWall, state: int)
signal blocking_changed(wall: DynamicWall, blocking: bool)
signal aura_damage_requested(wall: DynamicWall, cell: Vector2i, amount: int, element: StringName)
signal destroyed(wall: DynamicWall)

enum WallVariant {
	BASE,
	FIRE,
	ICE,
}

enum WallState {
	ACTIVE,
	DAMAGED,
	DESTROYING,
	DESTROYED,
}

const INVALID_CELL := Vector2i(-1, -1)
const VARIANT_NAMES := {
	WallVariant.BASE: "BASE",
	WallVariant.FIRE: "FIRE",
	WallVariant.ICE: "ICE",
}

var cell := INVALID_CELL
var variant := WallVariant.BASE
var wall_state := WallState.ACTIVE
var hp := 0
var remaining_turns := -1
var config: WallConfig = null
var source_unit = null
var _variant_configs: Dictionary = {}
var _destroy_signal_emitted := false

@onready var visual_root: Node2D = get_node_or_null("VisualRoot") as Node2D
@onready var sprite: Sprite2D = get_node_or_null("VisualRoot/Sprite2D") as Sprite2D
@onready var contact_shadow: CanvasItem = get_node_or_null("ContactShadow") as CanvasItem
@onready var health_indicator: Range = get_node_or_null("HealthIndicator") as Range
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var vfx_anchor: Node2D = get_node_or_null("VFXAnchor") as Node2D


func _ready() -> void:
	_apply_config_visuals()
	_refresh_state_visuals()


func set_variant_configs(configs: Dictionary) -> void:
	_variant_configs = configs.duplicate()


func setup(target_cell: Vector2i, wall_variant: int, wall_config: WallConfig) -> void:
	assert(WallVariant.values().has(wall_variant), "Variante de mur inconnue.")
	assert(wall_config != null, "DynamicWall requiert un WallConfig.")
	cell = target_cell
	variant = wall_variant
	config = wall_config
	hp = config.max_hp
	remaining_turns = config.duration_turns
	wall_state = WallState.ACTIVE
	_destroy_signal_emitted = false
	_apply_config_visuals()
	_refresh_state_visuals()


func change_variant(new_variant: int, replacement_config: WallConfig = null) -> bool:
	if not WallVariant.values().has(new_variant) or not is_blocking_state():
		return false
	var next_config := replacement_config
	if next_config == null:
		next_config = _variant_configs.get(new_variant) as WallConfig
	if next_config == null:
		return false
	if new_variant == variant and next_config == config:
		return false
	var previous := variant
	var previous_hp := hp
	variant = new_variant
	config = next_config
	hp = clampi(previous_hp, 1, config.max_hp)
	remaining_turns = config.duration_turns
	wall_state = WallState.DAMAGED if hp * 2 <= config.max_hp else WallState.ACTIVE
	_apply_config_visuals()
	_refresh_state_visuals()
	variant_changed.emit(self, previous, variant)
	hp_changed.emit(self, hp, config.max_hp)
	duration_changed.emit(self, remaining_turns)
	state_changed.emit(self, wall_state)
	return true


func apply_damage(amount: int, damage_element: StringName = &"NONE") -> int:
	if amount <= 0 or not is_blocking_state() or config == null:
		return 0
	var multiplier := 1.0
	if config.vulnerable_to.has(damage_element):
		multiplier *= 2.0
	if config.resistant_to.has(damage_element):
		multiplier *= 0.5
	var applied := maxi(1, roundi(float(amount) * multiplier))
	hp = maxi(0, hp - applied)
	hp_changed.emit(self, hp, config.max_hp)
	if hp <= 0:
		destroy()
	elif hp * 2 <= config.max_hp and wall_state != WallState.DAMAGED:
		wall_state = WallState.DAMAGED
		state_changed.emit(self, wall_state)
		_refresh_state_visuals()
	else:
		_refresh_state_visuals()
	return applied


func heal(amount: int) -> int:
	if amount <= 0 or not is_blocking_state() or config == null:
		return 0
	var previous := hp
	hp = mini(config.max_hp, hp + amount)
	if hp * 2 > config.max_hp and wall_state == WallState.DAMAGED:
		wall_state = WallState.ACTIVE
		state_changed.emit(self, wall_state)
	if hp != previous:
		hp_changed.emit(self, hp, config.max_hp)
		_refresh_state_visuals()
	return hp - previous


func extend_duration(turns: int) -> bool:
	if turns <= 0 or remaining_turns < 0 or not is_blocking_state():
		return false
	remaining_turns += turns
	duration_changed.emit(self, remaining_turns)
	return true


func advance_turn() -> bool:
	if not is_blocking_state() or config == null:
		return false
	if config.damage_on_adjacent_turn > 0:
		aura_damage_requested.emit(
			self,
			cell,
			config.damage_on_adjacent_turn,
			config.damage_element
		)
	if remaining_turns > 0:
		remaining_turns -= 1
		duration_changed.emit(self, remaining_turns)
		if remaining_turns == 0:
			destroy()
	return true


func destroy() -> bool:
	if wall_state == WallState.DESTROYING or wall_state == WallState.DESTROYED:
		return false
	wall_state = WallState.DESTROYING
	state_changed.emit(self, wall_state)
	blocking_changed.emit(self, false)
	if animation_player != null and animation_player.has_animation(&"destroy"):
		animation_player.play(&"destroy")
	wall_state = WallState.DESTROYED
	state_changed.emit(self, wall_state)
	_refresh_state_visuals()
	if not _destroy_signal_emitted:
		_destroy_signal_emitted = true
		destroyed.emit(self)
	return true


func get_cell() -> Vector2i:
	return cell


func get_variant_name() -> String:
	return str(VARIANT_NAMES.get(variant, "UNKNOWN"))


func get_state_name() -> String:
	return WallState.keys()[wall_state]


func blocks_movement() -> bool:
	return is_blocking_state() and config != null and config.blocks_movement


func blocks_line_of_sight() -> bool:
	return is_blocking_state() and config != null and config.blocks_line_of_sight


func blocks_projectiles() -> bool:
	return is_blocking_state() and config != null and config.blocks_projectiles


func is_blocking_state() -> bool:
	return wall_state == WallState.ACTIVE or wall_state == WallState.DAMAGED


func _apply_config_visuals() -> void:
	if not is_node_ready() or config == null:
		return
	if sprite != null:
		sprite.texture = config.texture
	if health_indicator != null:
		health_indicator.max_value = config.max_hp
		health_indicator.value = hp


func _refresh_state_visuals() -> void:
	if not is_node_ready():
		return
	var visible_now := wall_state != WallState.DESTROYED
	if visual_root != null:
		visual_root.visible = visible_now
		visual_root.modulate = Color(1.0, 0.68, 0.68, 1.0) \
			if wall_state == WallState.DAMAGED else Color.WHITE
	if contact_shadow != null:
		contact_shadow.visible = visible_now
	if health_indicator != null and config != null:
		health_indicator.visible = visible_now and hp < config.max_hp
		health_indicator.max_value = config.max_hp
		health_indicator.value = hp
