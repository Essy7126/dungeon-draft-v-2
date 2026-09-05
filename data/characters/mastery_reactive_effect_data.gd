@tool
class_name MasteryReactiveEffectData
extends Resource

## Evenements canoniques publies par l'integration combat. Ils sont stables et
## independants de tout personnage ou nom de node.
const EVENT_ACTIVATION_STARTED: StringName = &"activation_started"
const EVENT_ACTIVATION_ENDED: StringName = &"activation_ended"
const EVENT_SPELL_CAST: StringName = &"spell_cast"
const EVENT_MOVEMENT_RESOLVED: StringName = &"movement_resolved"
const EVENT_DISTANCE_TRAVELLED: StringName = &"distance_travelled"
const EVENT_DAMAGE_DEALT: StringName = &"damage_dealt"
const EVENT_DAMAGE_RECEIVED: StringName = &"damage_received"
const EVENT_DAMAGE_ABSORBED: StringName = &"damage_absorbed"
const EVENT_SHIELD_DESTROYED: StringName = &"shield_destroyed"
const EVENT_PROJECTILE_RECEIVED: StringName = &"projectile_received"
const EVENT_UNIT_MOVED: StringName = &"unit_moved"
const EVENT_COLLISION: StringName = &"collision"
const EVENT_ELIMINATION: StringName = &"elimination"
const EVENT_COMBAT_STARTED: StringName = &"combat_started"
const EVENT_COMBAT_ENDED: StringName = &"combat_ended"

const REQUIRED_EVENTS: Array[StringName] = [
	EVENT_ACTIVATION_STARTED,
	EVENT_ACTIVATION_ENDED,
	EVENT_SPELL_CAST,
	EVENT_MOVEMENT_RESOLVED,
	EVENT_DISTANCE_TRAVELLED,
	EVENT_DAMAGE_DEALT,
	EVENT_DAMAGE_RECEIVED,
	EVENT_DAMAGE_ABSORBED,
	EVENT_SHIELD_DESTROYED,
	EVENT_PROJECTILE_RECEIVED,
	EVENT_UNIT_MOVED,
	EVENT_COLLISION,
	EVENT_ELIMINATION,
	EVENT_COMBAT_STARTED,
	EVENT_COMBAT_ENDED,
]

## Effets generiques enregistres. Aucun de ces IDs ne nomme Achille, une
## doctrine ou un node : les ressources ne peuvent donc pas injecter du code.
const EFFECT_DAMAGE_MULTIPLIER: StringName = &"damage_multiplier"
const EFFECT_APPLY_ARMOR_DELTA: StringName = &"apply_armor_delta"
const EFFECT_IGNORE_ARMOR: StringName = &"ignore_armor"
const EFFECT_SET_FLAG: StringName = &"set_flag"
const EFFECT_CONSUME_FLAG_DAMAGE: StringName = &"consume_flag_damage"
const EFFECT_TRACK_DISTINCT_OFFENSES: StringName = &"track_distinct_offenses"
const EFFECT_TRACK_ABSORPTION: StringName = &"track_absorption"
const EFFECT_QUEUE_FOLLOWUP: StringName = &"queue_followup"
const EFFECT_NEXT_ACTIVATION_MP: StringName = &"next_activation_mp"
const EFFECT_IGNORE_ENGAGEMENT: StringName = &"ignore_engagement"
const EFFECT_MODIFY_RANGE: StringName = &"modify_range"
const EFFECT_MODIFY_SHIELD_DAMAGE: StringName = &"modify_shield_damage"
const EFFECT_GRANT_SHIELD: StringName = &"grant_shield"
const EFFECT_GUARD_AURA: StringName = &"guard_aura"
const EFFECT_BLOCK_CONTROL: StringName = &"block_control"
const EFFECT_BASTION_IMPACT: StringName = &"bastion_impact"
const EFFECT_AUTOMATIC_ATTACK: StringName = &"automatic_attack"
const EFFECT_CREATE_BARRIER: StringName = &"create_temporary_barrier"
const EFFECT_RAW_DAMAGE_BONUS: StringName = &"raw_damage_bonus"
const EFFECT_RESTORE_SHIELD_SOURCE: StringName = &"restore_shield_source"
const EFFECT_MODIFY_MOVEMENT_THRESHOLD: StringName = &"modify_movement_threshold"
const EFFECT_MODIFY_ABSORPTION_THRESHOLD: StringName = &"modify_absorption_threshold"
const EFFECT_MODIFY_CONDITIONAL_BONUS: StringName = &"modify_conditional_bonus"
const EFFECT_CHOOSE_PROJECTILE_ORIGIN: StringName = &"choose_projectile_origin"
const EFFECT_CHOOSE_SHIELD_CONVERSION: StringName = &"choose_shield_conversion"

enum Scope {
	ACTION,
	ACTIVATION,
	UNTIL_NEXT_ACTIVATION,
	COMBAT,
	RUN,
}

enum Frequency {
	UNLIMITED,
	ONCE_PER_ACTION,
	ONCE_PER_ACTIVATION,
	ONCE_UNTIL_NEXT_ACTIVATION,
	ONCE_PER_COMBAT,
	ONCE_PER_RUN,
}

enum AttackClassification {
	ANY,
	MELEE,
	PROJECTILE,
	AREA,
	SELF,
	MOVEMENT,
}

enum FacingSector {
	ANY,
	FRONT,
	SIDE,
	REAR,
	SIDE_OR_REAR,
}

@export_group("Identite et ordre")
@export var source_id: StringName = &""
@export var effect_id: StringName = &""
@export var event_id: StringName = EVENT_SPELL_CAST
@export var scope: Scope = Scope.ACTIVATION
@export var frequency: Frequency = Frequency.UNLIMITED
@export_range(1, 99, 1) var max_triggers: int = 1
@export_range(-1000, 1000, 1) var priority: int = 0
@export var reaction_group: StringName = &""
@export var stackable: bool = true
@export var anti_recursion: bool = true

@export_group("Conditions typées")
@export var valid_spell_ids: Array[StringName] = []
@export var required_flag_id: StringName = &""
@export var requires_guard: bool = false
@export var requires_enemy_source: bool = false
@export var requires_elimination: bool = false
@export var requires_collision_or_forced_move: bool = false
@export var requires_contact_after_move: bool = false
@export var required_attack_classification: AttackClassification = AttackClassification.ANY
@export var required_facing_sector: FacingSector = FacingSector.ANY
@export var minimum_distance: int = 0
@export var maximum_distance: int = -1
@export var minimum_moved_cells: int = 0
@export_range(-1.0, 1.0, 0.01) var caster_hp_ratio_at_most: float = -1.0
@export_range(-1.0, 1.0, 0.01) var target_hp_ratio_at_most: float = -1.0
@export var target_armor_at_most: int = -1
@export_range(0.0, 1.0, 0.01) var minimum_absorbed_max_hp_ratio: float = 0.0
@export_range(0.0, 1.0, 0.01) var minimum_hp_lost_max_hp_ratio: float = 0.0

@export_group("Resultat typé")
@export var target_spell_id: StringName = &""
@export var flag_id: StringName = &""
## Seules les conditions explicitement liees a une victime retiennent sa cible.
@export var flag_target_bound: bool = false
@export var multiplier: float = 1.0
@export var secondary_multiplier: float = 1.0
@export var tertiary_multiplier: float = 1.0
@export var flat_value: int = 0
@export var secondary_value: int = 0
@export var minimum_range_override: int = -1
@export var ratio_value: float = 0.0
@export_range(0.0, 1.0, 0.01) var cap_max_hp_ratio: float = 0.0
@export_range(0, 9, 1) var maximum_cells: int = 0
@export_range(0, 9, 1) var maximum_targets: int = 0
@export var target_multipliers: PackedFloat32Array = PackedFloat32Array()
@export var requires_line_of_sight: bool = true
@export var optional: bool = false
@export var followup_request_type: StringName = &""
@export var valid_option_ids: Array[StringName] = []
@export var directional_guard: DirectionalGuardData = null
@export var temporary_barrier: TemporaryBarrierData = null

@export_group("Action automatique sûre")
@export var automatic_action: bool = false
@export var spends_action_points: bool = false
@export var awards_xp: bool = false
@export var consumes_manual_spell_use: bool = false


func structural_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if source_id == &"":
		errors.append("REACTIVE_SOURCE_EMPTY")
	if effect_id == &"":
		errors.append("REACTIVE_EFFECT_ID_EMPTY")
	if not REQUIRED_EVENTS.has(event_id):
		errors.append("REACTIVE_EVENT_UNKNOWN: %s" % event_id)
	if max_triggers <= 0:
		errors.append("REACTIVE_FREQUENCY_INVALID")
	if maximum_distance >= 0 and maximum_distance < minimum_distance:
		errors.append("REACTIVE_DISTANCE_RANGE_INVALID")
	for value in [multiplier, secondary_multiplier, tertiary_multiplier, ratio_value]:
		if not is_finite(value):
			errors.append("REACTIVE_NUMERIC_VALUE_INVALID")
			break
	if multiplier < 0.0 or secondary_multiplier < 0.0 or tertiary_multiplier < 0.0:
		errors.append("REACTIVE_MULTIPLIER_NEGATIVE")
	if effect_id in [
		EFFECT_SET_FLAG,
		EFFECT_CONSUME_FLAG_DAMAGE,
		EFFECT_TRACK_ABSORPTION,
	] and flag_id == &"":
		errors.append("REACTIVE_FLAG_EMPTY")
	if effect_id in [
		EFFECT_QUEUE_FOLLOWUP,
		EFFECT_CHOOSE_PROJECTILE_ORIGIN,
		EFFECT_CHOOSE_SHIELD_CONVERSION,
	] and followup_request_type == &"":
		errors.append("REACTIVE_FOLLOWUP_TYPE_EMPTY")
	if automatic_action and target_spell_id == &"":
		errors.append("REACTIVE_AUTOMATIC_ACTION_SPELL_EMPTY")
	if effect_id == EFFECT_MODIFY_SHIELD_DAMAGE \
		and directional_guard != null and not directional_guard.is_valid():
		errors.append("REACTIVE_DIRECTIONAL_GUARD_INVALID")
	if effect_id == EFFECT_CREATE_BARRIER \
		and (temporary_barrier == null or not temporary_barrier.is_valid()):
		errors.append("REACTIVE_BARRIER_INVALID")
	if automatic_action and (
		spends_action_points or awards_xp or consumes_manual_spell_use
	):
		errors.append("REACTIVE_AUTOMATIC_ACTION_COST_POLICY_INVALID")
	if automatic_action and not anti_recursion:
		errors.append("REACTIVE_AUTOMATIC_ACTION_RECURSION_UNGUARDED")
	return errors


func is_structurally_valid() -> bool:
	return structural_errors().is_empty()


static func attack_classification_id(value: AttackClassification) -> StringName:
	match value:
		AttackClassification.MELEE:
			return &"MELEE"
		AttackClassification.PROJECTILE:
			return &"PROJECTILE"
		AttackClassification.AREA:
			return &"AREA"
		AttackClassification.SELF:
			return &"SELF"
		AttackClassification.MOVEMENT:
			return &"MOVEMENT"
	return &"ANY"


static func facing_sector_id(value: FacingSector) -> StringName:
	match value:
		FacingSector.FRONT:
			return &"FRONT"
		FacingSector.SIDE:
			return &"SIDE"
		FacingSector.REAR:
			return &"REAR"
		FacingSector.SIDE_OR_REAR:
			return &"SIDE_OR_REAR"
	return &"ANY"


static func scope_id(value: Scope) -> StringName:
	match value:
		Scope.ACTION:
			return &"ACTION"
		Scope.ACTIVATION:
			return &"ACTIVATION"
		Scope.UNTIL_NEXT_ACTIVATION:
			return &"UNTIL_NEXT_ACTIVATION"
		Scope.COMBAT:
			return &"COMBAT"
		Scope.RUN:
			return &"RUN"
	return &"ACTIVATION"
