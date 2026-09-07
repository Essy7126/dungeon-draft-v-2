@tool
# data/spell.gd
class_name Spell
extends Resource

enum AoeShape { SINGLE, CROSS, SQUARE, LINE }
enum DamageType { PHYSICAL, MAGICAL }
enum Element { NONE, FIRE, ICE, LIGHTNING, SHADOW, HOLY, EARTH }
enum VfxPlacement { FROM_CASTER_TO_TARGET, TARGET_CELL }
enum DelayedResolution { NONE, STRIKE_AND_PUSH, SUMMON, RANGED_STRIKE }
enum VisualAction { DEFAULT, PRIMARY, HEAVY }
enum CasterMovement { NONE, TARGET_CELL }

@export var spell_id: StringName = &""
## Arbre de competences apporte par ce sort. Cette reference est l'unique
## source de verite de l'appartenance d'un arbre a un personnage : un UnitData
## ne maintient pas une seconde liste en parallele.
@export var skill_tree: DisciplineData = null
## Champ de lecture legacy uniquement. Le runtime de progression ne l'utilise
## plus ; il reste serialisable le temps de convertir les anciennes Resources.
@export var discipline_id: StringName = &""
@export var spell_name: String = "Sort sans nom"
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export_group("Presentation")
@export var vfx_scene: PackedScene = null
@export var vfx_placement: VfxPlacement = VfxPlacement.FROM_CASTER_TO_TARGET
@export var sound_cast: AudioStream = null
@export var visual_action: VisualAction = VisualAction.DEFAULT

@export_group("Timing")
@export_range(0.0, 10.0, 0.01) var impact_delay_seconds: float = 0.0

@export_group("Cout et portee")
# Cout en Points d'Action (entier). La colonne vertebrale du tour.
@export var ap_cost: int = 1
@export var minimum_range: int = 0
@export var spell_range: int = 3
@export var needs_line_of_sight: bool = true

@export_group("Disponibilite")
## Empty permits every form. Old queued actions cannot execute after a transition.
@export var required_combat_form: StringName = &""
## Convention : utilise a l'activation N avec 3 -> indisponible N+1/N+2,
## de nouveau disponible a N+3.
@export var cooldown_activations: int = 0
@export var initial_cooldown: int = 0
@export var max_uses_per_combat: int = 0
@export var once_per_activation: bool = false

@export_group("Cibles autorisees")
@export var can_target_enemy: bool = true
@export var can_target_ally: bool = false
@export var can_target_free_cell: bool = false
@export var can_target_self: bool = false

@export_group("Zone d'effet")
@export var aoe_shape: AoeShape = AoeShape.SINGLE
@export var aoe_size: int = 1
@export var line_from_caster: bool = false
## Opt-in pour les zones centrees sur le lanceur qui utilisent sa case comme
## point de ciblage sans devoir lui appliquer les impacts de la zone.
@export var exclude_caster_from_area_effects: bool = false
## Opt-in for enemy-only area impacts. Ground hazards still affect every team.
@export var exclude_allies_from_area_effects: bool = false

@export_group("Effet de combat")
@export var damage: int = 0
@export var heal: int = 0
@export var damage_type: DamageType = DamageType.MAGICAL
@export var element: Element = Element.NONE
@export_range(0.0, 1.0) var crit_chance: float = 0.0
## Scaling optionnel commun au runtime, aux tooltips, aux Studios et aux
## simulations. `damage` reste la valeur plate legacy quand cette Resource est
## absente.
@export var damage_scaling: SpellScalingData = null

@export_group("Effet de terrain")
@export var terrain_effect: TerrainEffectData = null

@export_group("Statut applique")
@export var applied_status: StatusData = null
@export var status_source_scoped: bool = false
@export var replaces_same_source_status: bool = false

@export_group("Mecanique speciale")
@export var push_distance: int = 0
@export var push_all_adjacent: bool = false
@export var push_affected_units: bool = false
# Collision en chaine : si > 0, une unite poussee qui en percute une autre (ou un
# mur/hasard) inflige ces degats aux deux, et transmet la poussee a la percutee.
@export var collision_damage: int = 0
# Attire la cible de N cases VERS le lanceur (le "pull" du Crochet). Genere de
# l'energie comme une poussee (deplacement force).
@export var pull_distance: int = 0
# Souffle de zone (Onde de choc) : degats infliges a CHAQUE ennemi adjacent,
# multiplies par le nombre d'ennemis entasses autour. Recompense le regroupement
# avant de detoner. N'a de sens qu'avec push_all_adjacent.
@export var cluster_bonus_damage: int = 0
@export var shield_grant: int = 0
## Scaling optionnel du bouclier. La valeur plate legacy reste autoritaire si
## cette Resource est absente.
@export var shield_scaling: SpellScalingData = null
## Tags sémantiques de la source créée (par exemple `guard`). Ils permettent
## aux réactions et équipements de distinguer une Garde d'un autre bouclier
## sans tester l'identifiant ou le nom du sort.
@export var shield_tags: Array[StringName] = []
## Zéro conserve le comportement historique. Une valeur positive décrit le
## nombre d'activations après lequel une future architecture de boucliers
## sourcés doit expirer cette source.
@export_range(0, 99, 1) var shield_duration_activations: int = 0
@export var bonus_damage_if_marked: int = 0
@export var bonus_damage_status_id: StringName = &""
@export var bonus_requires_linked_status_source: bool = false
@export var forces_taunt: bool = false
@export var taunt_duration: int = 1
# Draine des PA a la cible : ampute son budget du PROCHAIN tour (drain du
# Disruptor, hurlements gobelins).
@export var ap_drain: int = 0
@export var teleport_behind_target: bool = false
@export var heal_bonus_effect_name: String = ""
@export var heal_bonus_multiplier: float = 1.0

@export_group("Deplacement volontaire")
## Déplacement produit par le sort lui-même. NONE préserve strictement le
## comportement de toutes les Resources existantes.
@export var caster_movement: CasterMovement = CasterMovement.NONE
## Pour TARGET_CELL, vérifie chaque case intermédiaire auprès de GridData.
@export var movement_requires_clear_path: bool = false

@export_group("Resolution differee")
@export var delayed_resolution: DelayedResolution = DelayedResolution.NONE
@export var consumes_activation_on_resolution: bool = false
@export var telegraph_label: String = "Prochaine activation"
@export var telegraph_color: Color = Color(0.9, 0.2, 0.2, 0.85)

@export_group("Invocation")
@export var summon_unit_data: UnitData = null
@export var summon_type: StringName = &""
@export var summon_starting_hp: int = 0
@export var summon_max_living_team: int = 0
@export var summon_initial_cooldowns: Dictionary = {}
@export var condition_hp_at_or_below: int = -1
@export var requires_absent_unit_id: StringName = &""

@export_group("Transformations")
# Modificateurs attaches au sort en donnee : chaque SpellModifier recoit les
# hooks du pipeline de SpellCaster (on_costs_resolved, on_movement_resolved...).
@export var modifiers: Array[SpellModifier] = []

func deals_damage() -> bool:
	return damage > 0 or (
		damage_scaling != null and damage_scaling.has_effect()
	)


func get_scaled_damage(caster: Unit, level: int = 1) -> int:
	return SpellScalingResolver.resolve(
		damage_scaling,
		caster,
		damage,
		level,
	)


func get_scaled_shield(caster: Unit, level: int = 1) -> int:
	return SpellScalingResolver.resolve(
		shield_scaling,
		caster,
		shield_grant,
		level,
	)

func is_healing() -> bool:
	return heal > 0

func has_terrain_effect() -> bool:
	return terrain_effect != null

func is_self_only() -> bool:
	return can_target_self and not can_target_enemy \
		and not can_target_ally and not can_target_free_cell


func is_delayed() -> bool:
	return delayed_resolution != DelayedResolution.NONE


func is_summon() -> bool:
	return delayed_resolution == DelayedResolution.SUMMON

func get_effective_spell_id() -> StringName:
	if spell_id != &"":
		return spell_id
	if resource_path != "":
		return StringName(resource_path)
	return &"spell:unassigned"


func has_skill_tree() -> bool:
	return skill_tree != null


func get_skill_tree_id() -> StringName:
	return skill_tree.discipline_id if skill_tree != null else &""
