# units/unit.gd
# ============================================================
# UNIT â€” Un combattant (hÃ©ros ou ennemi). Logique pure.
#
# Ã‰met des logs de COMBAT (dÃ©gÃ¢ts, soins, mort) et de STATS (statuts),
# pour que la console de debug serve de vrai suivi de combat.
# ============================================================

class_name Unit
extends RefCounted

const LogDefinitions = preload("res://debug/log_definitions.gd")

# --- Identite ---
var unit_id: StringName = &""
var unit_name: String = "Sans nom"
var team: int = 0
var ai_behavior: int = 0
var combat_style: int = 0
var preferred_range: int = 1
var minimum_range: int = 1
var maximum_range: int = 1
var keep_distance: bool = false
var ai_profile: EnemyAIProfile = null
var faction_id: StringName = &""
var tactical_role_id: StringName = &""
var linked_commander_role_id: StringName = &""
var linked_commander: Unit = null
var combat_order: int = -1
var control_level: UnitData.ControlLevel = UnitData.ControlLevel.NONE

# --- Stats max (modifiables) ---
var max_hp: Stat
var initiative: Stat
var max_ap: Stat
var max_mp: Stat
var attack_power: Stat

# --- Stats defensives ---
var armure: Stat
var resist_magique: Stat
var esquive: Stat

# --- Stats de critique ---
var crit_chance: Stat
var crit_multi: Stat

# --- Placement force ---
# Force module uniquement les poussees, attractions et collisions.
var force: Stat

# --- Resistances elementaires ---
var resistances: Dictionary = {}

const RESIST_MIN := -0.75
const RESIST_MAX := 0.75
const ESQUIVE_MAX := 0.50
const DEFENSE_MAX := 1000.0

# --- Etat courant ---
var current_hp: int = 0
var current_ap: int = 0
var current_mp: int = 0
const LEGACY_SHIELD_SOURCE_ID: StringName = &"legacy_aggregate"
var _shield_instances: Array[ShieldInstance] = []
var current_shield: int:
	get:
		return get_total_shield()
	set(value):
		_set_legacy_aggregate_shield(value)
var shield_creation_multiplier: float = 1.0
var created_shield_multiplier: float:
	get:
		return shield_creation_multiplier
	set(value):
		shield_creation_multiplier = maxf(0.0, value)
var is_alive: bool = true
var _grid_pos: Vector2i = Vector2i(-1, -1)
var grid_context = null
var proximity_armor_source: StringName = &""
var proximity_armor_per_living_neighbor: int = 0
var proximity_armor_max_neighbors: int = 0
var first_forced_movement_reduction_per_activation: int = 0
var _forced_movement_reduction_used: bool = false
# Direction LOGIQUE (pas visuelle) vers laquelle l'unite est orientee. Utilisee
# par les mecaniques de boss type "durcit de face" (ex: Le Colosse). Mise a
# jour automatiquement a chaque deplacement reel ; sinon garde sa derniere
# valeur (position de spawn si l'unite ne bouge jamais).
var facing_dir: Vector2i = Vector2i(0, 1)
var grid_pos: Vector2i:
	get: return _grid_pos
	set(value):
		var old := _grid_pos
		_grid_pos = value
		# La sentinelle hors-grille sert au retrait (notamment a la mort) : ce
		# n'est pas un deplacement et elle ne doit ni tourner ni animer l'unite.
		if old != Vector2i(-1, -1) \
				and value != Vector2i(-1, -1) \
				and old != value:
			facing_dir = _snap_to_cardinal(value - old)
			moved.emit(old, value)

# Reduit un vecteur de deplacement a l'une des 4 directions cardinales (meme
# motif que _push_unit/_pull_unit dans SpellCaster), pour rester robuste a un
# relocate non-adjacent (teleportation).
func _snap_to_cardinal(delta: Vector2i) -> Vector2i:
	if delta == Vector2i.ZERO:
		return facing_dir
	if abs(delta.x) >= abs(delta.y):
		return Vector2i(sign(delta.x), 0)
	return Vector2i(0, sign(delta.y))


# La case logique situee exactement derriere l'unite, a l'oppose de son regard.
# Ce helper ne depend d'aucune projection visuelle/isometrique.
func get_behind_grid_cell() -> Vector2i:
	return grid_pos - _snap_to_cardinal(facing_dir)


func is_grid_position_behind(position: Vector2i) -> bool:
	return position == get_behind_grid_cell()
# --- Ressources de combat ---
# Les PA paient les actions du tour (colonne vertebrale, entiers, reviennent
# chaque tour). Les PM paient les deplacements et reviennent egalement.
const BASIC_ATTACK_AP_COST := 1

# Modificateur de PA applique au PROCHAIN tour puis remis a zero : positif
# ou negatif selon les effets de combat.
var next_turn_ap_modifier: int = 0
var next_turn_mp_bonus: int = 0
var next_turn_mp_penalty: int = 0
var taunt_source = null
var taunt_turns: int = 0

# --- Apparence ---
# Ressource d'origine commune aux ecrans de presentation et au HUD. Elle reste
# en lecture seule cote combat : les statistiques runtime continuent de vivre
# sur Unit, tandis que les visuels de presentation gardent une source unique.
var character_data: UnitData = null
var combat_form_change: CombatFormChangeData = null
var combat_form_id: StringName = &""
var _combat_form_changed: bool = false
var _combat_form_base_hp: int = 0
var sprite_frames: SpriteFrames = null
var sprite_scale: float = 3.0
var idle_animation: String = "default"
var visual_scene: PackedScene = null
var preview_visual_scene: PackedScene = null

# --- Sorts ---
var basic_attack_enabled: bool = true
var spells: Array = []
var mastery_runtime: MasteryReactiveRuntimeService = null
var mastery_nodes: Array[SkillTreeNodeData] = []
# Borrowed from the active battle; detached at shutdown.
var mastery_combat_adapter = null
var _progression_spell_modifiers: Array[SpellModifier] = []
var _progression_spell_modifiers_by_spell: Dictionary = {}
var _equipment_spell_modifiers_by_source: Dictionary = {}
var _equipment_guard_effectiveness_by_source: Dictionary = {}
var activation_index: int = 0
var activation_consumed: bool = false
var _ability_states: Dictionary = {}
var pending_ability: Dictionary = {}
var _moved_cells_this_activation := 0
var _mp_spent_this_activation := 0
var _last_hp_loss_activation_index := -1000000
var _last_guard_destroyed_activation_index := -1000000
var _moved_or_collided_targets_this_activation: Dictionary = {}

# --- Statuts actifs ---
# Liste de dictionnaires : { "data": StatusData, "remaining": int }
var active_statuses: Array = []
var _resolved_combat_effects: Dictionary = {}

# --- Signaux ---
signal died(unit)
signal moved(from_pos: Vector2i, to_pos: Vector2i)
signal hp_changed(unit)
signal stats_changed(unit)
signal shield_changed(unit)
signal combat_form_changed(unit, old_form, new_form)
## Rupture d'une source individuelle. Le signal global EventBus.shield_broken
## reste reserve a la disparition du total agrege pour compatibilite.
signal shield_source_broken(unit, source_id)

# Raccourcis de catÃ©gories de log (combat = vu par le joueur).
const CAT_COMBAT: LogDefinitions.LogCategory = LogDefinitions.LogCategory.COMBAT
const CAT_STATS: LogDefinitions.LogCategory = LogDefinitions.LogCategory.STATS

# ============================================================
# CONSTRUCTION
# ============================================================

func _init(
		p_name: String = "Sans nom",
		p_team: int = 0,
		p_hp: float = 100,
		p_initiative: float = 10,
		p_ap: float = 6,
		p_mp: float = 3,
		p_attack: float = 20
	) -> void:
	unit_name = p_name
	team = p_team
	max_hp       = Stat.new(p_hp)
	initiative   = Stat.new(p_initiative)
	max_ap       = Stat.new(p_ap)
	max_mp       = Stat.new(p_mp)
	attack_power = Stat.new(p_attack)
	# Stats dÃ©fensives : neutres par dÃ©faut (renseignÃ©es via from_data).
	# Bornes posÃ©es dÃ¨s la construction = garde-fou permanent.
	armure         = Stat.new(0.0).set_bounds(0.0, DEFENSE_MAX)
	resist_magique = Stat.new(0.0).set_bounds(0.0, DEFENSE_MAX)
	esquive        = Stat.new(0.0).set_bounds(0.0, ESQUIVE_MAX)
	crit_chance    = Stat.new(0.0).set_bounds(0.0, 1.0)
	crit_multi     = Stat.new(1.5).set_min(1.0)
	force          = Stat.new(0.0).set_min(0.0)
	current_hp = max_hp.get_int()
	current_ap = max_ap.get_int()
	current_mp = max_mp.get_int()
	max_hp.changed.connect(_on_max_hp_changed)

static func from_data(data: UnitData) -> Unit:
	var u = Unit.new(
		data.unit_name, data.team, data.max_hp, data.initiative,
		data.max_ap, data.max_mp, data.attack_power
	)
	u.unit_id = data.get_effective_unit_id()
	u.character_data = data
	u.combat_form_change = data.combat_form_change
	u._combat_form_base_hp = maxi(1, data.max_hp)
	if u.combat_form_change != null and u.combat_form_change.is_valid():
		u.combat_form_id = u.combat_form_change.initial_form
	u.sprite_frames = data.sprite_frames
	u.sprite_scale = data.sprite_scale
	u.idle_animation = data.idle_animation
	u.visual_scene = data.visual_scene
	u.preview_visual_scene = data.preview_visual_scene
	u.basic_attack_enabled = data.basic_attack_enabled
	u.ai_behavior = data.ai_behavior
	u.combat_style = data.combat_style
	u.preferred_range = data.preferred_range
	u.minimum_range = data.minimum_range
	u.maximum_range = data.maximum_range
	u.keep_distance = data.keep_distance
	u.ai_profile = data.ai_profile
	u.faction_id = data.faction_id
	u.tactical_role_id = data.tactical_role_id
	u.linked_commander_role_id = data.linked_commander_role_id
	u.control_level = data.control_level
	u.proximity_armor_source = data.proximity_armor_source
	u.proximity_armor_per_living_neighbor = data.proximity_armor_per_living_neighbor
	u.proximity_armor_max_neighbors = data.proximity_armor_max_neighbors
	u.first_forced_movement_reduction_per_activation = (
		data.first_forced_movement_reduction_per_activation
	)
	u.facing_dir = data.facing_dir
	# Stats dÃ©fensives : on rÃ¨gle la valeur de BASE de chaque Stat.
	u.armure.base_value = data.armure
	u.resist_magique.base_value = data.resist_magique
	u.esquive.base_value = data.esquive
	u.crit_chance.base_value = data.crit_chance
	u.crit_multi.base_value = data.crit_multi
	u.force.base_value = data.force
	# RÃ©sistances Ã©lÃ©mentaires : le .tres porte des float simples
	# { Element â†’ float }. On les convertit en Stat clampÃ©es via le helper,
	# pour que designer = nombres simples, runtime = stats modifiables.
	for element in data.resistances:
		var stat := u.get_resistance(element)   # crÃ©e le Stat (clampÃ©) si absent
		stat.base_value = data.resistances[element]
	# Ã‰nergie : on rÃ©cupÃ¨re le type dÃ©fini sur l'UnitData (ex: Rage) et on
	# On DUPLIQUE le comportement : chaque boss a son propre Ã©tat (compteur
	# de tours, enrage...), sinon deux boss partageraient le mÃªme.
	for spell in data.spells:
		u.add_spell(spell)
	return u


func _on_max_hp_changed() -> void:
	var capped_hp := mini(current_hp, maxi(0, max_hp.get_int()))
	if capped_hp != current_hp:
		current_hp = capped_hp
		hp_changed.emit(self)
	stats_changed.emit(self)

func add_spell(spell: Spell) -> void:
	spells.append(spell)
	_ensure_ability_state(spell)


func _ensure_ability_state(spell: Spell) -> Dictionary:
	if spell == null:
		return {}
	var spell_id := spell.get_effective_spell_id()
	if not _ability_states.has(spell_id):
		var initial_ready := 0
		if spell.initial_cooldown > 0:
			initial_ready = activation_index + spell.initial_cooldown + 1
		_ability_states[spell_id] = {
			"ready_activation": initial_ready,
			"uses_this_combat": 0,
			"used_activation": -1,
		}
	return _ability_states[spell_id]


func get_spell_availability_reason(spell: Spell) -> StringName:
	if spell == null:
		return &"spell"
	if not is_alive:
		return &"caster_dead"
	if spell.required_combat_form != &"" and spell.required_combat_form != combat_form_id:
		return &"combat_form"
	var state := _ensure_ability_state(spell)
	if activation_index < int(state.get("ready_activation", 0)):
		return &"cooldown"
	if spell.max_uses_per_combat > 0 \
			and int(state.get("uses_this_combat", 0)) >= spell.max_uses_per_combat:
		return &"max_uses"
	if spell.once_per_activation \
			and int(state.get("used_activation", -1)) == activation_index:
		return &"once_per_activation"
	if not can_afford_spell_resources(spell):
		return &"pa"
	return &""


func can_use_spell(spell: Spell) -> bool:
	return get_spell_availability_reason(spell) == &""


func mark_spell_used(spell: Spell) -> void:
	if spell == null:
		return
	var state := _ensure_ability_state(spell)
	state["uses_this_combat"] = int(state.get("uses_this_combat", 0)) + 1
	state["used_activation"] = activation_index
	if spell.cooldown_activations > 0:
		state["ready_activation"] = activation_index + spell.cooldown_activations


func get_spell_cooldown_remaining(spell: Spell) -> int:
	if spell == null:
		return 0
	var state := _ensure_ability_state(spell)
	return maxi(0, int(state.get("ready_activation", 0)) - activation_index)


func get_spell_uses(spell: Spell) -> int:
	if spell == null:
		return 0
	return int(_ensure_ability_state(spell).get("uses_this_combat", 0))


func set_initial_spell_cooldown(spell_id: StringName, blocked_activations: int) -> void:
	for spell_value in spells:
		var spell := spell_value as Spell
		if spell == null or spell.get_effective_spell_id() != spell_id:
			continue
		var state := _ensure_ability_state(spell)
		state["ready_activation"] = maxi(
			int(state.get("ready_activation", 0)),
			activation_index + maxi(0, blocked_activations) + 1
		)


func reset_ability_runtime() -> void:
	activation_index = 0
	activation_consumed = false
	_ability_states.clear()
	pending_ability.clear()
	_moved_cells_this_activation = 0
	_mp_spent_this_activation = 0
	_last_hp_loss_activation_index = -1000000
	_last_guard_destroyed_activation_index = -1000000
	_moved_or_collided_targets_this_activation.clear()
	for spell_value in spells:
		_ensure_ability_state(spell_value as Spell)


func set_progression_spell_modifiers(modifiers: Array[SpellModifier]) -> void:
	_progression_spell_modifiers.clear()
	_progression_spell_modifiers_by_spell.clear()
	for modifier in modifiers:
		if modifier != null and not _progression_spell_modifiers.has(modifier):
			_progression_spell_modifiers.append(modifier)


func clear_progression_spell_modifiers() -> void:
	_progression_spell_modifiers.clear()
	_progression_spell_modifiers_by_spell.clear()


func get_progression_spell_modifiers() -> Array[SpellModifier]:
	return _progression_spell_modifiers.duplicate()


func set_progression_spell_modifiers_by_spell(modifiers_by_spell: Dictionary) -> void:
	_progression_spell_modifiers.clear()
	_progression_spell_modifiers_by_spell.clear()
	for spell_id_value in modifiers_by_spell:
		var spell_id := StringName(spell_id_value)
		if spell_id == &"":
			continue
		var valid: Array[SpellModifier] = []
		for modifier in modifiers_by_spell[spell_id_value]:
			if modifier != null and not valid.has(modifier):
				valid.append(modifier)
				if not _progression_spell_modifiers.has(modifier):
					_progression_spell_modifiers.append(modifier)
		_progression_spell_modifiers_by_spell[spell_id] = valid


func get_progression_spell_modifiers_for(spell_id: StringName) -> Array[SpellModifier]:
	var result: Array[SpellModifier] = []
	result.assign(_progression_spell_modifiers_by_spell.get(spell_id, []))
	return result


func set_equipment_spell_modifiers(
		source_id: StringName,
		modifiers: Array[SpellModifier]
	) -> void:
	if source_id == &"":
		return
	var valid: Array[SpellModifier] = []
	for modifier in modifiers:
		if modifier != null and not valid.has(modifier):
			valid.append(modifier)
	if valid.is_empty():
		_equipment_spell_modifiers_by_source.erase(source_id)
	else:
		_equipment_spell_modifiers_by_source[source_id] = valid


func clear_equipment_spell_modifiers(source_id: StringName) -> void:
	_equipment_spell_modifiers_by_source.erase(source_id)


func get_equipment_spell_modifiers() -> Array[SpellModifier]:
	var result: Array[SpellModifier] = []
	for values in _equipment_spell_modifiers_by_source.values():
		for modifier_value in values:
			var modifier := modifier_value as SpellModifier
			if modifier != null and not result.has(modifier):
				result.append(modifier)
	return result


func set_equipment_guard_effectiveness(
		source_id: StringName,
		melee_multiplier: float,
		projectile_multiplier: float
	) -> void:
	if source_id == &"":
		return
	var melee := maxf(0.01, melee_multiplier)
	var projectile := maxf(0.01, projectile_multiplier)
	if is_equal_approx(melee, 1.0) and is_equal_approx(projectile, 1.0):
		_equipment_guard_effectiveness_by_source.erase(source_id)
		return
	_equipment_guard_effectiveness_by_source[source_id] = {
		"MELEE": melee,
		"PROJECTILE": projectile,
	}


func clear_equipment_guard_effectiveness(source_id: StringName) -> void:
	_equipment_guard_effectiveness_by_source.erase(source_id)


func get_guard_effectiveness(attack_classification: StringName) -> float:
	if attack_classification not in [&"MELEE", &"PROJECTILE"]:
		return 1.0
	var result := 1.0
	var source_ids := _equipment_guard_effectiveness_by_source.keys()
	source_ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(a) < str(b)
	)
	for source_id in source_ids:
		var values := _equipment_guard_effectiveness_by_source[source_id] as Dictionary
		result *= float(values.get(str(attack_classification), 1.0))
	return maxf(0.01, result)


func record_runtime_movement(cells: int) -> void:
	_moved_cells_this_activation += maxi(0, cells)


func record_target_moved_or_collided(target: Unit) -> void:
	if target == null:
		return
	var target_id := target.get_runtime_stable_id()
	if target_id != &"":
		_moved_or_collided_targets_this_activation[target_id] = activation_index


func get_equipment_condition_facts(target: Unit = null) -> Dictionary:
	var target_moved_or_collided := false
	if target != null:
		var target_id := target.get_runtime_stable_id()
		target_moved_or_collided = int(
			_moved_or_collided_targets_this_activation.get(target_id, -1)
		) == activation_index
	return {
		"prior_moved_cells": _moved_cells_this_activation,
		"mp_spent": _mp_spent_this_activation,
		"hp_lost_since_previous_activation": (
			activation_index - _last_hp_loss_activation_index <= 1
		),
		"target_moved_or_collided": target_moved_or_collided,
		"guard_destroyed": (
			activation_index - _last_guard_destroyed_activation_index <= 1
		),
	}

# ============================================================
# ACCÃˆS AUX STATS
# ============================================================

# Renvoie le Stat de rÃ©sistance pour un Ã©lÃ©ment donnÃ©, en le CRÃ‰ANT
# paresseusement (clampÃ©) s'il n'existe pas encore. Toujours non-null.
# C'est par ici que reliques/Ã©quipement modifient une rÃ©sistance :
#   unit.get_resistance(Spell.Element.FIRE).add_modifier(0.3, FLAT, "relique_x")
func get_resistance(element: int) -> Stat:
	if not resistances.has(element):
		resistances[element] = Stat.new(0.0).set_bounds(RESIST_MIN, RESIST_MAX)
	return resistances[element]

# Renvoie la valeur effective d'une rÃ©sistance (0.0 si l'Ã©lÃ©ment n'est pas gÃ©rÃ©).
# Lecture seule : ne crÃ©e PAS de Stat (utilisÃ© en boucle par le resolver).
func get_resistance_value(element: int) -> float:
	if resistances.has(element):
		return resistances[element].get_value()
	return 0.0


func get_runtime_stable_id() -> String:
	if combat_order >= 0:
		return "%s:%06d" % [String(unit_id), combat_order]
	return "%s:%020d" % [String(unit_id), get_instance_id()]


func is_hostile_to(other: Unit) -> bool:
	return other != null and other != self and team != other.team


func can_exert_control() -> bool:
	return is_alive and control_level != UnitData.ControlLevel.NONE


func get_control_cost() -> int:
	match control_level:
		UnitData.ControlLevel.CONTROL:
			return 1
		UnitData.ControlLevel.HEAVY_CONTROL:
			return 2
		_:
			return 0


func target_has_linked_source_status(target: Unit, status_id: StringName) -> bool:
	if target == null:
		return false
	if linked_commander != null and linked_commander.is_alive \
			and target.has_status(status_id, linked_commander):
		return true
	for entry_value in target.get_active_statuses():
		var entry := entry_value as Dictionary
		var data := entry.get("data") as StatusData
		var source := entry.get("source") as Unit
		if data == null or data.get_effective_status_id() != status_id \
				or source == null or not source.is_alive or source.team != team:
			continue
		if faction_id != &"" and source.faction_id != faction_id:
			continue
		if linked_commander_role_id == &"" \
				or source.tactical_role_id == linked_commander_role_id:
			return true
	return false


func refresh_proximity_passive(grid: GridData) -> void:
	var source := String(proximity_armor_source)
	if source.is_empty():
		return
	armure.remove_modifiers_from(source)
	if not is_alive or grid == null or not grid.is_valid(grid_pos):
		stats_changed.emit(self)
		return
	var living_neighbors := 0
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var neighbor := grid.get_unit(grid_pos + direction) as Unit
		if neighbor != null and neighbor != self and neighbor.is_alive:
			living_neighbors += 1
	var counted := mini(living_neighbors, proximity_armor_max_neighbors)
	if counted > 0:
		armure.add_modifier(
			float(counted * proximity_armor_per_living_neighbor),
			Stat.ModType.FLAT,
			source
		)
	stats_changed.emit(self)


func on_actor_activation_started(_actor: Unit) -> void:
	_forced_movement_reduction_used = false


func reduce_forced_movement(cells: int) -> int:
	if cells <= 0 or first_forced_movement_reduction_per_activation <= 0 \
			or _forced_movement_reduction_used:
		return maxi(0, cells)
	_forced_movement_reduction_used = true
	return maxi(0, cells - first_forced_movement_reduction_per_activation)

# Liste centralisÃ©e de TOUTES les stats Ã  durÃ©e (hors rÃ©sistances, ajoutÃ©es
# dynamiquement). Source unique de vÃ©ritÃ© : tout ce qui doit "tick" est ici.
# Ajouter une stat future = l'ajouter Ã  cette liste, et tick_durations
# la couvrira automatiquement. Plus aucun oubli possible.
func _all_durational_stats() -> Array:
	var list := [
		max_hp, initiative, max_ap, max_mp, attack_power,
		armure, resist_magique, esquive, crit_chance, crit_multi, force,
	]
	# Les rÃ©sistances sont des Stat Ã  part entiÃ¨re : elles ticktent aussi.
	for element in resistances:
		list.append(resistances[element])
	return list

# ============================================================
# STATUTS
# ============================================================

# Applique un statut (StatusData) Ã  l'unitÃ©.
# Si le statut est dÃ©jÃ  prÃ©sent, on rafraÃ®chit sa durÃ©e (pas de cumul).
func _status_modifier_key(status_data: StatusData, source: Unit = null) -> String:
	var key := String(status_data.modifier_source)
	if key.is_empty():
		key = String(status_data.get_effective_status_id())
	if status_data.unique_per_source and source != null:
		key += ":" + source.get_runtime_stable_id()
	return key


func _status_matches(entry: Dictionary, status_data: StatusData, source: Unit) -> bool:
	var current_data := entry.get("data") as StatusData
	if current_data == null \
			or current_data.get_effective_status_id() != status_data.get_effective_status_id():
		return false
	return not status_data.unique_per_source or entry.get("source") == source


func _stat_for_status_name(stat_name: StringName) -> Stat:
	return get(String(stat_name)) as Stat


func _apply_status_stat_modifiers(status_data: StatusData, source: Unit) -> void:
	var modifier_key := _status_modifier_key(status_data, source)
	for stat_name_value in status_data.stat_modifiers:
		var stat := _stat_for_status_name(StringName(stat_name_value))
		if stat == null:
			continue
		stat.remove_modifiers_from(modifier_key)
		stat.add_modifier(
			float(status_data.stat_modifiers[stat_name_value]),
			Stat.ModType.FLAT,
			modifier_key
		)


func _remove_status_stat_modifiers(entry: Dictionary) -> void:
	var status_data := entry.get("data") as StatusData
	if status_data == null:
		return
	var modifier_key := _status_modifier_key(status_data, entry.get("source") as Unit)
	for stat_name_value in status_data.stat_modifiers:
		var stat := _stat_for_status_name(StringName(stat_name_value))
		if stat != null:
			stat.remove_modifiers_from(modifier_key)


func apply_status(
		status_data: StatusData,
		source: Unit = null,
		metadata: Dictionary = {}
	) -> void:
	if status_data == null:
		return
	# Cherche si ce statut est dÃ©jÃ  actif.
	for entry in active_statuses:
		if _status_matches(entry, status_data, source):
			# DÃ©jÃ  prÃ©sent : on rafraÃ®chit la durÃ©e (la plus longue gagne).
			entry["remaining"] = max(entry["remaining"], status_data.duration)
			if not metadata.is_empty():
				entry["metadata"] = metadata.duplicate(true)
			if status_data is ChargedDamageVulnerabilityData:
				var charged := status_data as ChargedDamageVulnerabilityData
				var current_charged_data := (
					entry["data"] as ChargedDamageVulnerabilityData
				)
				entry["charges"] = maxi(
					int(entry.get("charges", 0)),
					charged.max_charges
				)
				if current_charged_data == null \
						or charged.max_charges >= current_charged_data.max_charges:
					entry["data"] = charged
			elif status_data is ChargedOutgoingDamageData:
				var outgoing := status_data as ChargedOutgoingDamageData
				var current_outgoing := entry["data"] as ChargedOutgoingDamageData
				entry["charges"] = maxi(
					int(entry.get("charges", 0)),
					outgoing.max_charges
				)
				if current_outgoing == null \
						or outgoing.bonus_damage >= current_outgoing.bonus_damage:
					entry["data"] = outgoing
			DebugLogger.debug(CAT_STATS, "%s : %s rafraîchi (%d tours)" % [
				unit_name, status_data.status_name, entry["remaining"]])
			EventBus.status_refreshed.emit(self, status_data)
			EventBus.combat_status_refreshed.emit(CombatEventFact.create(
				&"status_refreshed", self, source, {
					"status_id": status_data.get_effective_status_id(),
				}
			))
			return
	# Nouveau statut.
	var new_entry := {
		"data": status_data,
		"remaining": status_data.duration,
		"source": source,
		"metadata": metadata.duplicate(true),
	}
	if status_data is ChargedDamageVulnerabilityData:
		new_entry["charges"] = (
			status_data as ChargedDamageVulnerabilityData
		).max_charges
	elif status_data is ChargedOutgoingDamageData:
		new_entry["charges"] = (
			status_data as ChargedOutgoingDamageData
		).max_charges
	active_statuses.append(new_entry)
	_apply_status_stat_modifiers(status_data, source)
	# Le CombatLogger Ã©coute status_applied et produit la ligne de log.
	EventBus.status_applied.emit(self, status_data)
	EventBus.status_added.emit(CombatEventFact.create(
		&"status_added", self, source, {
			"status_id": status_data.get_effective_status_id(),
		}
	))


func has_status(status_id: StringName, source: Unit = null) -> bool:
	for entry in active_statuses:
		var data := entry.get("data") as StatusData
		if data != null and data.get_effective_status_id() == status_id \
				and (source == null or entry.get("source") == source):
			return true
	return false


func get_status_remaining(status_id: StringName, source: Unit = null) -> int:
	for entry in active_statuses:
		var data := entry.get("data") as StatusData
		if data != null and data.get_effective_status_id() == status_id \
				and (source == null or entry.get("source") == source):
			return int(entry.get("remaining", 0))
	return 0


func remove_status(status_id: StringName, source: Unit = null, forced := true) -> int:
	var removed := 0
	for index in range(active_statuses.size() - 1, -1, -1):
		var entry: Dictionary = active_statuses[index]
		var data := entry.get("data") as StatusData
		if data == null or data.get_effective_status_id() != status_id:
			continue
		if source != null and entry.get("source") != source:
			continue
		_remove_status_stat_modifiers(entry)
		active_statuses.remove_at(index)
		if forced:
			EventBus.status_removed.emit(self, status_id, source)
		else:
			EventBus.status_expired.emit(self, status_id)
			EventBus.combat_status_expired.emit(CombatEventFact.create(
				&"status_expired", self, source, {"status_id": status_id}
			))
		removed += 1
	return removed


func remove_statuses_from_source(source: Unit) -> int:
	if source == null:
		return 0
	var removed := 0
	for index in range(active_statuses.size() - 1, -1, -1):
		var entry: Dictionary = active_statuses[index]
		var data := entry.get("data") as StatusData
		if data == null or not data.remove_when_source_dies or entry.get("source") != source:
			continue
		_remove_status_stat_modifiers(entry)
		active_statuses.remove_at(index)
		EventBus.status_removed.emit(self, data.get_effective_status_id(), source)
		removed += 1
	return removed

# L'unitÃ© a-t-elle un statut qui la fait sauter son tour ?
func is_stunned() -> bool:
	for entry in active_statuses:
		if entry["data"].skips_turn:
			return true
	return false

# Applique les effets de tous les statuts en dÃ©but de tour.
# Retourne true si l'unitÃ© doit sauter son tour (stun).
# (Ã  appeler APRÃˆS start_turn qui recharge PA/PM)
func apply_taunt(source, duration: int = 1) -> void:
	taunt_source = source
	taunt_turns = maxi(1, duration)
	var source_name: String = source.unit_name if source != null else "une force inconnue"
	DebugLogger.info(CAT_STATS, "%s est provoque par %s" % [unit_name, source_name])

func get_forced_target():
	if taunt_source != null and taunt_turns > 0 and taunt_source.is_alive:
		return taunt_source
	return null

func process_statuses() -> bool:
	var skip = false

	for entry in active_statuses:
		var data: StatusData = entry["data"]

		# DÃ©gÃ¢ts par tour (poison, saignement, brÃ»lure).
		# DÃ©gÃ¢ts "vrais" : un poison ignore l'armure et ne s'esquive pas.
		# (quand StatusData portera un Ã©lÃ©ment, on le passera ici)
		if data.damage_per_turn > 0 \
				and data.damage_timing == StatusData.PeriodicTiming.TURN_START:
			take_damage(
				data.damage_per_turn,
				null,
				data.damage_type,
				data.element,
				{
					"ignore_defense": data.ignores_defense,
					"cannot_be_dodged": not data.can_be_dodged,
					"is_periodic": true,
					"status_id": data.get_effective_status_id(),
					"action_id": StringName("status_%s_%d" % [
						data.get_effective_status_id(), activation_index,
					]),
				}
			)
			DebugLogger.info(CAT_STATS, "[STATUT] %s subit %d dÃ©gÃ¢ts de %s" % [
				unit_name, data.damage_per_turn, data.status_name], {
				"PV_restants": current_hp,
			})

		# Soin par tour (rÃ©gÃ©nÃ©ration).
		if data.heal_per_turn > 0:
			heal(data.heal_per_turn, null, {
				"is_periodic": true,
				"status_id": data.get_effective_status_id(),
				"action_id": StringName("status_heal_%s_%d" % [
					data.get_effective_status_id(), activation_index,
				]),
			})
			DebugLogger.info(CAT_STATS, "%s rÃ©cupÃ¨re %d PV de %s" % [
				unit_name, data.heal_per_turn, data.status_name], {
				"PV": current_hp,
			})

		# RÃ©duction de PM / PA (slow).
		if data.mp_reduction > 0:
			current_mp = max(0, current_mp - data.mp_reduction)
			DebugLogger.debug(CAT_STATS, "%s : -%d PM (%s)" % [
				unit_name, data.mp_reduction, data.status_name])
		if data.ap_reduction > 0:
			current_ap = max(0, current_ap - data.ap_reduction)
			DebugLogger.debug(CAT_STATS, "%s : -%d PA (%s)" % [
				unit_name, data.ap_reduction, data.status_name])

		# Stun.
		if data.skips_turn:
			skip = true
			DebugLogger.info(CAT_STATS, "%s est neutralisÃ© par %s (passe son tour)" % [
				unit_name, data.status_name])

	if taunt_turns > 0:
		taunt_turns -= 1
		if taunt_turns <= 0:
			taunt_source = null
	stats_changed.emit(self)
	return skip

# Fait vieillir les statuts d'un tour, retire les expirÃ©s.
# (Ã  appeler en FIN de tour de l'unitÃ©)
func tick_statuses(excluded_ids: Array[StringName] = []) -> void:
	_tick_statuses_filtered([], excluded_ids)


func tick_statuses_for_ids(included_ids: Array[StringName]) -> void:
	_tick_statuses_filtered(included_ids, [])


func _tick_statuses_filtered(
		included_ids: Array[StringName],
		excluded_ids: Array[StringName]
	) -> void:
	for i in range(active_statuses.size() - 1, -1, -1):
		var data := active_statuses[i]["data"] as StatusData
		if data == null:
			continue
		var status_id := data.get_effective_status_id()
		if excluded_ids.has(status_id) \
				or (not included_ids.is_empty() and not included_ids.has(status_id)):
			continue
		if data != null \
				and data.damage_per_turn > 0 \
				and data.damage_timing == StatusData.PeriodicTiming.TURN_END:
			take_damage(
				data.damage_per_turn,
				null,
				data.damage_type,
				data.element,
				{
					"ignore_defense": data.ignores_defense,
					"cannot_be_dodged": not data.can_be_dodged,
					"is_periodic": true,
					"status_id": data.get_effective_status_id(),
					"action_id": StringName("status_%s_%d" % [
						data.get_effective_status_id(), activation_index,
					]),
				}
			)
			DebugLogger.info(CAT_STATS, "[STATUT] %s subit %d degats de %s" % [
				unit_name,
				data.damage_per_turn,
				data.status_name,
			], {
				"PV_restants": current_hp,
			})
		active_statuses[i]["remaining"] -= 1
		if active_statuses[i]["remaining"] <= 0:
			var ended := status_id
			_remove_status_stat_modifiers(active_statuses[i])
			active_statuses.remove_at(i)
			# Le CombatLogger Ã©coute status_expired et produit la ligne de log.
			EventBus.status_expired.emit(self, ended)
			EventBus.combat_status_expired.emit(CombatEventFact.create(
				&"status_expired", self, null, {"status_id": ended}
			))

# Retourne la liste des statuts actifs (pour l'UI).
func get_active_statuses() -> Array:
	return active_statuses


# Retire les altérations simples utilisées par les arbres (DoT, entrave,
# affaiblissement et vulnérabilité chargée), dans l'ordre le plus récent.
func cleanse_simple_negative_statuses(maximum: int = 1) -> int:
	var removed := 0
	for index in range(active_statuses.size() - 1, -1, -1):
		var data := active_statuses[index].get("data") as StatusData
		if data == null or not (
			data.damage_per_turn > 0
			or data.mp_reduction > 0
			or data.outgoing_damage_modifier < 0
			or data is ChargedDamageVulnerabilityData
		):
			continue
		var status_id := data.get_effective_status_id()
		_remove_status_stat_modifiers(active_statuses[index])
		active_statuses.remove_at(index)
		EventBus.status_expired.emit(self, status_id)
		EventBus.combat_status_expired.emit(CombatEventFact.create(
			&"status_expired", self, null, {"status_id": status_id}
		))
		removed += 1
		if removed >= maximum:
			break
	return removed

# ============================================================
# GESTION DU TOUR
# ============================================================

func start_turn() -> void:
	if mastery_combat_adapter != null:
		mastery_combat_adapter.before_activation_start(self)
	activation_index += 1
	activation_consumed = false
	_moved_cells_this_activation = 0
	_mp_spent_this_activation = 0
	_moved_or_collided_targets_this_activation.clear()
	_expire_shields_at_activation_start()
	# Tick TOUTES les stats Ã  durÃ©e d'un coup (dÃ©fenses et rÃ©sistances
	# comprises). Avant, seules 5 stats Ã©taient tickÃ©es â†’ un buff temporaire
	# "+20 armure 2 tours" ne expirait jamais. CorrigÃ© : liste centralisÃ©e.
	for stat in _all_durational_stats():
		stat.tick_durations()
	# PA du tour : budget de base + modificateur "prochain tour" (bonus de
	# reaction, drain du Disruptor...), consomme puis remis a zero. Jamais < 0.
	current_ap = maxi(0, max_ap.get_int() + next_turn_ap_modifier)
	next_turn_ap_modifier = 0
	current_mp = maxi(
		0,
		max_mp.get_int() + next_turn_mp_bonus - next_turn_mp_penalty
	)
	next_turn_mp_bonus = 0
	next_turn_mp_penalty = 0
	EventBus.ap_changed.emit(self, current_ap, max_ap.get_int())
	EventBus.turn_started.emit(self)
	stats_changed.emit(self)

# ============================================================
# DÃ‰PENSE DE RESSOURCES
# ============================================================

func spend_mp(amount: int) -> bool:
	if amount < 0 or amount > current_mp:
		return false
	current_mp -= amount
	_mp_spent_this_activation += amount
	stats_changed.emit(self)
	return true


func grant_current_activation_mp_bonus(amount: int) -> int:
	var granted := maxi(0, amount)
	current_mp += granted
	stats_changed.emit(self)
	return granted


func consume_current_activation() -> void:
	activation_consumed = true
	current_ap = 0
	current_mp = 0
	stats_changed.emit(self)


func queue_next_turn_mp_modifier(amount: int) -> void:
	if amount > 0:
		next_turn_mp_bonus += amount
	elif amount < 0:
		next_turn_mp_penalty = maxi(next_turn_mp_penalty, -amount)

func spend_ap(amount: int) -> bool:
	if amount > current_ap:
		return false
	current_ap -= amount
	EventBus.ap_changed.emit(self, current_ap, max_ap.get_int())
	stats_changed.emit(self)
	return true

# ============================================================
# ============================================================

func reset_combat_resources() -> void:
	# SpellCaster impact IDs restart in each battle; keep deduplication combat-local.
	_resolved_combat_effects.clear()
	reset_ability_runtime()
	next_turn_ap_modifier = 0
	next_turn_mp_bonus = 0
	next_turn_mp_penalty = 0
	current_ap = max_ap.get_int()
	current_mp = max_mp.get_int()
	EventBus.ap_changed.emit(self, current_ap, max_ap.get_int())
	stats_changed.emit(self)

func get_basic_attack_ap_cost() -> int:
	return BASIC_ATTACK_AP_COST

func get_basic_attack_cost() -> int:
	return get_basic_attack_ap_cost()

func can_use_basic_attack() -> bool:
	return basic_attack_enabled and is_alive and current_ap >= get_basic_attack_ap_cost()

# Cout PA effectif d'un sort.
func get_spell_ap_cost(spell: Spell) -> int:
	if spell == null:
		return 0
	if spell.ap_cost <= 0:
		return 0
	return spell.ap_cost

func can_afford_spell_resources(spell: Spell) -> bool:
	if spell == null:
		return false
	return current_ap >= get_spell_ap_cost(spell)

# Multiplicateur de placement de la Force. 1.0 si Force est nulle.
func get_force_multiplier() -> float:
	return 1.0 + force.get_value() / 100.0

# ============================================================
# Les boucliers absorbent les degats AVANT les PV. Chaque source conserve sa
# valeur et sa propre expiration ; current_shield reste une vue agregee pour
# le HUD et les anciens consommateurs.
# ============================================================

func add_shield(
		amount: int,
		source: Unit = null,
		options: Dictionary = {}
	) -> CombatEventFact:
	var created_amount := amount
	if source != null:
		created_amount = int(round(
			float(amount) * source.shield_creation_multiplier
		))
	return add_sourced_shield(
		_resolve_shield_source_id(source, options),
		created_amount,
		source,
		options,
	)


func add_sourced_shield(
		source_id: StringName,
		amount: int,
		source: Unit = null,
		options: Dictionary = {}
	) -> CombatEventFact:
	if not is_alive or amount <= 0:
		return null
	var effect_key := _combat_effect_key(&"shield", options)
	if effect_key != &"" and _resolved_combat_effects.has(effect_key):
		return _resolved_combat_effects[effect_key] as CombatEventFact
	if source_id == &"":
		return null
	var existing := _find_shield_instance(source_id)
	if existing != null and amount <= existing.value:
		return null
	var previous_source_value := existing.value if existing != null else 0
	var expiry_policy := _shield_expiry_policy_from_options(options)
	var created_at := maxi(0, int(options.get("created_activation", activation_index)))
	var expires_at := created_at + int(options.get("expires_after_activations", 0)) \
		if expiry_policy == ShieldInstance.ExpiryPolicy.START_OF_ACTIVATION else -1
	var priority := int(options.get("priority", 0))
	var tags := _shield_tags_from_options(options)
	if existing == null:
		existing = ShieldInstance.new()
		_shield_instances.append(existing)
	if not existing.configure(
			source_id, amount, created_at, expiry_policy, priority, tags, expires_at
		):
		_shield_instances.erase(existing)
		return null
	var applied := amount - previous_source_value
	EventBus.shield_gained.emit(self, applied)
	EventBus.shield_applied.emit(self, source, applied)
	shield_changed.emit(self)
	var fact := CombatEventFact.create(
		&"shield_granted", self, source,
		_combat_fact_metadata(options, {
			"amount_applied": applied,
			"source_id": source_id,
			"shield_value": amount,
			"shield_total": current_shield,
		})
	)
	EventBus.shield_granted.emit(fact)
	if effect_key != &"":
		_resolved_combat_effects[effect_key] = fact
	DebugLogger.debug(CAT_STATS,
		"%s reçoit %d bouclier de %s (total %d)" % [
			unit_name, applied, source_id, current_shield,
		])
	return fact


func get_total_shield() -> int:
	var total := 0
	for instance in _shield_instances:
		if instance != null:
			total += maxi(0, instance.value)
	return total


func get_shield_value(source_id: StringName) -> int:
	var instance := _find_shield_instance(source_id)
	return instance.value if instance != null else 0


func get_shield_instances() -> Array[ShieldInstance]:
	var result: Array[ShieldInstance] = []
	for instance in _ordered_shield_instances():
		result.append(instance.duplicate(true) as ShieldInstance)
	return result


func get_shield_instances_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in _ordered_shield_instances():
		result.append(instance.to_snapshot())
	return result


func restore_shield_instances_snapshot(snapshot: Variant) -> bool:
	if not snapshot is Array:
		return false
	var candidates: Array[ShieldInstance] = []
	var seen_sources := {}
	for value in snapshot:
		if not value is Dictionary:
			return false
		var data := value as Dictionary
		var source_id := StringName(data.get("source_id", &""))
		var shield_value := int(data.get("value", -1))
		var initial_value := int(data.get("initial_value", -1))
		var created_at := int(data.get("created_activation", -1))
		var expiry_policy := int(data.get(
			"expiry_policy", ShieldInstance.ExpiryPolicy.NEVER
		))
		if source_id == &"" \
				or seen_sources.has(source_id) \
				or shield_value <= 0 \
				or initial_value < shield_value \
				or created_at < 0 \
				or expiry_policy not in [
					ShieldInstance.ExpiryPolicy.NEVER,
					ShieldInstance.ExpiryPolicy.START_OF_NEXT_ACTIVATION,
					ShieldInstance.ExpiryPolicy.START_OF_ACTIVATION,
				]:
			return false
		var expires_at := int(data.get("expires_activation", -1))
		if expiry_policy == ShieldInstance.ExpiryPolicy.START_OF_ACTIVATION and expires_at <= created_at:
			return false
		var tags := _shield_tags_from_options({"tags": data.get("tags", [])})
		var instance := ShieldInstance.new()
		if not instance.configure(
				source_id,
				initial_value,
				created_at,
				expiry_policy,
				int(data.get("priority", 0)),
				tags,
				expires_at,
			):
			return false
		instance.value = shield_value
		candidates.append(instance)
		seen_sources[source_id] = true
	var before := get_shield_instances_snapshot()
	_shield_instances.assign(candidates)
	if before != get_shield_instances_snapshot():
		shield_changed.emit(self)
	return true


## Explicit consumption preserves collateral sources and never reports an enemy break.
func consume_shield_source(source_id: StringName, amount: int) -> int:
	var instance := _find_shield_instance(source_id)
	if instance == null or amount <= 0:
		return 0
	var spent := mini(amount, instance.value)
	instance.value -= spent
	if instance.value <= 0:
		_shield_instances.erase(instance)
	shield_changed.emit(self)
	return spent


func clear_shield_source(source_id: StringName) -> bool:
	var instance := _find_shield_instance(source_id)
	if instance == null:
		return false
	_shield_instances.erase(instance)
	shield_changed.emit(self)
	return true


# Compatibilite : cet appel historique signifie explicitement « tout retirer ».
func clear_shield() -> void:
	if current_shield <= 0:
		return
	_shield_instances.clear()
	shield_changed.emit(self)


func _set_legacy_aggregate_shield(value: int) -> void:
	_shield_instances.clear()
	var safe_value := maxi(0, value)
	if safe_value <= 0:
		return
	var legacy := ShieldInstance.new()
	legacy.configure(
		LEGACY_SHIELD_SOURCE_ID,
		safe_value,
		maxi(0, activation_index),
	)
	_shield_instances.append(legacy)


func _find_shield_instance(source_id: StringName) -> ShieldInstance:
	for instance in _shield_instances:
		if instance != null and instance.source_id == source_id:
			return instance
	return null


func _resolve_shield_source_id(source: Unit, options: Dictionary) -> StringName:
	for key in [&"shield_source_id", &"source_id", &"ability_id"]:
		var candidate := StringName(options.get(key, &""))
		if candidate != &"":
			return candidate
	if source != null:
		return StringName("unit:%s" % source.get_runtime_stable_id())
	return LEGACY_SHIELD_SOURCE_ID


func _shield_expiry_policy_from_options(
		options: Dictionary
	) -> int:
	if bool(options.get("expires_next_activation", false)):
		return ShieldInstance.ExpiryPolicy.START_OF_NEXT_ACTIVATION
	if int(options.get("expires_after_activations", 0)) > 1:
		return ShieldInstance.ExpiryPolicy.START_OF_ACTIVATION
	if int(options.get("expires_after_activations", 0)) == 1:
		return ShieldInstance.ExpiryPolicy.START_OF_NEXT_ACTIVATION
	var policy := int(options.get(
		"expiry_policy", ShieldInstance.ExpiryPolicy.NEVER
	))
	if policy == ShieldInstance.ExpiryPolicy.START_OF_NEXT_ACTIVATION:
		return ShieldInstance.ExpiryPolicy.START_OF_NEXT_ACTIVATION
	return ShieldInstance.ExpiryPolicy.NEVER


func _shield_tags_from_options(options: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var values: Variant = options.get("tags", [])
	if values is Array:
		for value in values:
			var tag := StringName(value)
			if tag != &"" and not result.has(tag):
				result.append(tag)
	return result


func _ordered_shield_instances() -> Array[ShieldInstance]:
	var result: Array[ShieldInstance] = []
	for instance in _shield_instances:
		if instance != null and instance.value > 0:
			result.append(instance)
	result.sort_custom(func(a: ShieldInstance, b: ShieldInstance) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		if a.created_activation != b.created_activation:
			return a.created_activation < b.created_activation
		return str(a.source_id) < str(b.source_id)
	)
	return result


func _expire_shields_at_activation_start() -> void:
	var expired := false
	for index in range(_shield_instances.size() - 1, -1, -1):
		var instance := _shield_instances[index]
		if instance == null \
				or instance.should_expire_at_activation_start(activation_index):
			_shield_instances.remove_at(index)
			expired = true
	if expired:
		shield_changed.emit(self)


func _absorb_with_shield_instances(
		amount: int,
		attack_classification: StringName = &"",
		guard_damage_multiplier: float = 1.0
	) -> Dictionary:
	var remaining := maxi(0, amount)
	var absorbed := 0
	var breakdown: Array[Dictionary] = []
	var broken_source_ids: Array[StringName] = []
	var broken_guard_source_ids: Array[StringName] = []
	for instance in _ordered_shield_instances():
		if remaining <= 0:
			break
		var effectiveness := (
			get_guard_effectiveness(attack_classification) / maxf(0.01, guard_damage_multiplier)
			if instance.tags.has(&"guard") else 1.0
		)
		var effective_capacity := maxi(
			1,
			int(round(float(instance.value) * effectiveness)),
		)
		var damage_absorbed := mini(effective_capacity, remaining)
		if damage_absorbed <= 0:
			continue
		var shield_points_spent := mini(
			instance.value,
			maxi(1, int(ceil(float(damage_absorbed) / effectiveness - 0.000001))),
		)
		instance.value -= shield_points_spent
		remaining -= damage_absorbed
		absorbed += damage_absorbed
		breakdown.append({
			"source_id": instance.source_id,
			"amount_absorbed": damage_absorbed,
			"shield_points_spent": shield_points_spent,
			"remaining_value": instance.value,
			"effectiveness": effectiveness,
			"tags": instance.tags.duplicate(),
		})
		if instance.value <= 0:
			broken_source_ids.append(instance.source_id)
			if instance.tags.has(&"guard"):
				broken_guard_source_ids.append(instance.source_id)
	for index in range(_shield_instances.size() - 1, -1, -1):
		var instance := _shield_instances[index]
		if instance == null or instance.value <= 0:
			_shield_instances.remove_at(index)
	return {
		"absorbed": absorbed,
		"remaining_damage": remaining,
		"breakdown": breakdown,
		"broken_source_ids": broken_source_ids,
		"broken_guard_source_ids": broken_guard_source_ids,
	}

# ============================================================
# COMBAT
# ============================================================

# take_damage INTELLIGENT (Couche 1).
# Toute la mitigation (esquive, rÃ©sist, armure, crit) vit ICI : c'est la
# loi physique du combat, aucune source ne peut y Ã©chapper.
#
# RÃ©trocompatible : take_damage(15) marche toujours (coup brut, sans
# attaquant, traitÃ© comme physique sans dÃ©fense calculÃ©e â†’ dÃ©gÃ¢ts pleins).
# Les nouveaux appels passent un HitContext complet via take_hit().
#
# Renvoie le DamageResult (montant rÃ©el, crit, esquive) pour que
# l'appelant puisse afficher les retours visuels.
func take_damage(
		amount: int,
		attacker = null,
		category: int = Spell.DamageType.PHYSICAL,
		element: int = Spell.Element.NONE,
		options: Dictionary = {}
	) -> DamageResolver.DamageResult:
	if not is_alive:
		return null

	var uses_vulnerability := not bool(options.get("skip_vulnerability", false))
	var uses_outgoing := not bool(options.get("skip_outgoing", false))
	var charged_bonus := _get_charged_damage_bonus(category) if uses_vulnerability else 0
	var splash_spec := (
		_get_charged_vulnerability_splash(category)
		if uses_vulnerability and not bool(options.get("skip_splash", false))
		else {}
	)
	var outgoing_bonus := 0
	if attacker is Unit and uses_outgoing:
		outgoing_bonus = (attacker as Unit)._get_outgoing_damage_bonus(category)
	# Construit le contexte du coup.
	var ctx := DamageResolver.HitContext.new()
	ctx.attacker = attacker
	ctx.raw_damage = amount + charged_bonus + outgoing_bonus
	ctx.category = category
	ctx.element = element
	# Options éventuelles (terrain et sorts spéciaux).
	ctx.ignore_defense = options.get("ignore_defense", false)
	ctx.cannot_be_dodged = options.get("cannot_be_dodged", false)
	ctx.bonus_crit_chance = options.get("bonus_crit_chance", 0.0)
	ctx.force_crit = options.get("force_crit", false)
	ctx.pen_pct = options.get("pen_pct", 0.0)
	ctx.pen_flat = options.get("pen_flat", 0.0)
	ctx.action_id = StringName(options.get("action_id", &""))
	ctx.cast_id = StringName(options.get("cast_id", &""))
	ctx.impact_id = StringName(options.get("impact_id", &""))
	ctx.sequence_index = maxi(0, int(options.get("sequence_index", 0)))
	ctx.ability_id = StringName(options.get("ability_id", &""))
	ctx.attack_classification = StringName(options.get(
		"attack_classification", &""
	))
	ctx.status_id = StringName(options.get("status_id", &""))
	ctx.is_periodic = bool(options.get("is_periodic", false))

	var effect_key := _combat_effect_key(&"damage", options)
	if effect_key != &"" and _resolved_combat_effects.has(effect_key):
		return _resolved_combat_effects[effect_key] as DamageResolver.DamageResult

	if mastery_combat_adapter != null:
		mastery_combat_adapter.before_hit(self, ctx)
	var result := DamageResolver.compute(self, ctx)
	if result != null and not result.dodged and charged_bonus > 0:
		_consume_charged_damage_vulnerabilities(category)
	if result != null and not result.dodged and attacker is Unit and uses_outgoing:
		(attacker as Unit)._consume_charged_outgoing_damage(category)
	_apply_damage_result(
		result,
		ctx.attacker,
		ctx,
		_resolve_hit_origin_cell(attacker, options),
	)
	if effect_key != &"":
		_resolved_combat_effects[effect_key] = result
	if result != null and not result.dodged and not splash_spec.is_empty():
		_apply_adjacent_vulnerability_splash(splash_spec, attacker)
	return result

# take_hit : variante explicite quand on a dÃ©jÃ  un HitContext construit
# (utile pour les modificateurs de sorts qui ajoutent des crochets).
func take_hit(ctx: DamageResolver.HitContext) -> DamageResolver.DamageResult:
	if not is_alive:
		return null
	var effect_key := _combat_effect_key(&"damage", {
		"impact_id": ctx.impact_id,
	})
	if effect_key != &"" and _resolved_combat_effects.has(effect_key):
		return _resolved_combat_effects[effect_key] as DamageResolver.DamageResult
	var charged_bonus := _get_charged_damage_bonus(ctx.category)
	var outgoing_bonus := 0
	if ctx.attacker is Unit:
		outgoing_bonus = (ctx.attacker as Unit)._get_outgoing_damage_bonus(ctx.category)
	ctx.raw_damage += charged_bonus + outgoing_bonus
	if mastery_combat_adapter != null:
		mastery_combat_adapter.before_hit(self, ctx)
	var result := DamageResolver.compute(self, ctx)
	if result != null and not result.dodged and charged_bonus > 0:
		_consume_charged_damage_vulnerabilities(ctx.category)
	if result != null and not result.dodged and ctx.attacker is Unit:
		(ctx.attacker as Unit)._consume_charged_outgoing_damage(ctx.category)
	_apply_damage_result(
		result,
		ctx.attacker,
		ctx,
		_resolve_hit_origin_cell(ctx.attacker, {}),
	)
	if effect_key != &"":
		_resolved_combat_effects[effect_key] = result
	return result


func _get_charged_damage_bonus(category: int) -> int:
	var bonus := 0
	for entry in active_statuses:
		var data := entry.get("data") as ChargedDamageVulnerabilityData
		if data == null \
				or data.trigger_damage_type != category \
				or int(entry.get("charges", 0)) <= 0:
			continue
		bonus += data.bonus_damage
	return bonus


func _get_charged_vulnerability_splash(category: int) -> Dictionary:
	var result := {}
	for entry in active_statuses:
		var data := entry.get("data") as ChargedDamageVulnerabilityData
		if data == null \
				or data.trigger_damage_type != category \
				or int(entry.get("charges", 0)) <= 0 \
				or data.adjacent_splash_damage <= 0:
			continue
		if data.adjacent_splash_damage > int(result.get("damage", 0)):
			result = {
				"damage": data.adjacent_splash_damage,
				"damage_type": data.adjacent_splash_damage_type,
				"element": data.adjacent_splash_element,
			}
	return result


func _apply_adjacent_vulnerability_splash(spec: Dictionary, attacker) -> void:
	if grid_context == null or grid_pos == Vector2i(-1, -1):
		return
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var adjacent := grid_context.get_unit(grid_pos + direction) as Unit
		if adjacent == null or adjacent == self or adjacent.team != team:
			continue
		adjacent.take_damage(
			int(spec.get("damage", 0)),
			attacker,
			int(spec.get("damage_type", Spell.DamageType.MAGICAL)),
			int(spec.get("element", Spell.Element.LIGHTNING)),
			{
				"skip_vulnerability": true,
				"skip_outgoing": true,
				"skip_splash": true,
			}
		)
		return


func _consume_charged_damage_vulnerabilities(category: int) -> void:
	for index in range(active_statuses.size() - 1, -1, -1):
		var entry: Dictionary = active_statuses[index]
		var data := entry.get("data") as ChargedDamageVulnerabilityData
		if data == null \
				or data.trigger_damage_type != category \
				or int(entry.get("charges", 0)) <= 0:
			continue
		var remaining_charges := int(entry["charges"]) - 1
		if remaining_charges <= 0:
			active_statuses.remove_at(index)
			var status_id := data.get_effective_status_id()
			EventBus.status_expired.emit(self, status_id)
			EventBus.combat_status_expired.emit(CombatEventFact.create(
				&"status_expired", self, null, {"status_id": status_id}
			))
		else:
			active_statuses[index]["charges"] = remaining_charges


func _get_outgoing_damage_bonus(category: int) -> int:
	var bonus := 0
	for entry in active_statuses:
		var status := entry.get("data") as StatusData
		if status != null:
			bonus += status.outgoing_damage_modifier
		var charged := entry.get("data") as ChargedOutgoingDamageData
		if charged == null \
				or int(entry.get("charges", 0)) <= 0 \
				or (charged.trigger_damage_type >= 0 \
				and charged.trigger_damage_type != category):
			continue
		bonus += charged.bonus_damage
	return bonus


func _consume_charged_outgoing_damage(category: int) -> void:
	for index in range(active_statuses.size() - 1, -1, -1):
		var entry: Dictionary = active_statuses[index]
		var data := entry.get("data") as ChargedOutgoingDamageData
		if data == null \
				or int(entry.get("charges", 0)) <= 0 \
				or (data.trigger_damage_type >= 0 \
				and data.trigger_damage_type != category):
			continue
		var remaining_charges := int(entry["charges"]) - 1
		if remaining_charges <= 0:
			active_statuses.remove_at(index)
			var status_id := data.get_effective_status_id()
			EventBus.status_expired.emit(self, status_id)
			EventBus.combat_status_expired.emit(CombatEventFact.create(
				&"status_expired", self, null, {"status_id": status_id}
			))
		else:
			active_statuses[index]["charges"] = remaining_charges

# Applique le rÃ©sultat calculÃ© aux PV, en absorbant d'abord le bouclier.
# POINT D'Ã‰MISSION UNIQUE du flux de dÃ©gÃ¢ts.
func _apply_damage_result(
		result: DamageResolver.DamageResult,
		attacker = null,
		ctx: DamageResolver.HitContext = null,
		impact_origin_cell: Vector2i = Vector2i(-1, -1)
	) -> void:
	if result == null:
		return
	var metadata := _hit_context_metadata(ctx)
	if result.dodged:
		EventBus.attack_dodged.emit(self, attacker)
		EventBus.attack_dodge_resolved.emit(CombatEventFact.create(
			&"attack_dodged", self, attacker, metadata
		))
		hp_changed.emit(self)
		return

	# --- Absorption par le bouclier ---
	# Le bouclier prend les dÃ©gÃ¢ts en premier. Si tout est absorbÃ©, les PV ne bougent pas.
	var damage_to_hp := result.amount
	var absorbed := 0
	var shield_resolution: Dictionary = {}
	if current_shield > 0 and damage_to_hp > 0:
		shield_resolution = _absorb_with_shield_instances(
			damage_to_hp,
			ctx.attack_classification if ctx != null else &"",
			ctx.guard_damage_multiplier if ctx != null else 1.0,
		)
		absorbed = int(shield_resolution.get("absorbed", 0))
		damage_to_hp = int(shield_resolution.get(
			"remaining_damage", damage_to_hp
		))
		EventBus.shield_absorbed.emit(self, absorbed)
		EventBus.shield_absorption_resolved.emit(CombatEventFact.create(
			&"shield_absorbed", self, attacker,
			_combat_fact_metadata(metadata, {
				"amount_absorbed": absorbed,
				"is_critical": result.is_crit,
				"damage_type": result.category,
				"element": result.element,
				"source_absorption": shield_resolution.get("breakdown", []),
				"broken_source_ids": shield_resolution.get(
					"broken_source_ids", []
				),
				"guard_absorbed": _shield_resolution_used_guard(
					shield_resolution
				),
			})
		))
		if attacker is Unit and (attacker as Unit).team != team \
				and not (shield_resolution.get(
					"broken_guard_source_ids", []
				) as Array).is_empty():
			_last_guard_destroyed_activation_index = activation_index
		for broken_source_id in shield_resolution.get("broken_source_ids", []):
			shield_source_broken.emit(self, StringName(broken_source_id))
		if current_shield <= 0:
			EventBus.shield_broken.emit(self)
		shield_changed.emit(self)
		DebugLogger.debug(CAT_STATS,
			"%s : bouclier absorbe %d (reste %d)" % [unit_name, absorbed, current_shield])

	# Annonce la frappe sur le bus (montant aprÃ¨s mitigation armure/rÃ©sist, avant bouclier).
	# shield_absorbed est émis séparément pour les consommateurs du journal/UI.
	# --- Application aux PV ---
	var health_loss := 0
	if damage_to_hp > 0:
		health_loss = mini(current_hp, damage_to_hp)
		current_hp -= health_loss
		result.hp_damage_applied = health_loss
		result.shield_damage_absorbed = absorbed
		if health_loss > 0:
			_last_hp_loss_activation_index = activation_index
		if current_hp <= 0 and impact_origin_cell != Vector2i(-1, -1):
			EventBus.lethal_hit_resolved.emit(self, attacker, impact_origin_cell)
		var health_fact := CombatEventFact.create(
			&"hp_damage_taken", self, attacker,
			_combat_fact_metadata(metadata, {
				"amount_applied": health_loss,
				"amount_absorbed": absorbed,
				"is_critical": result.is_crit,
				"damage_type": result.category,
				"element": result.element,
			})
		)
		EventBus.hp_damage_taken.emit(health_fact)
		EventBus.health_damage_taken.emit(
			self,
			attacker,
			health_loss,
			result.category,
			result.element,
			result.is_crit
		)
		if bool(metadata.get("is_periodic", false)):
			EventBus.status_tick.emit(health_fact)
		hp_changed.emit(self)
	else:
		result.hp_damage_applied = 0
		result.shield_damage_absorbed = absorbed
		# Tout absorbÃ© : les PV n'ont pas bougÃ©, mais on notifie pour l'UI.
		hp_changed.emit(self)

	EventBus.hit_resolved.emit(CombatEventFact.create(
		&"hit_resolved", self, attacker,
		_combat_fact_metadata(metadata, {
			"amount_resolved": result.amount,
			"amount_applied": health_loss,
			"amount_absorbed": absorbed,
			"source_absorption": shield_resolution.get("breakdown", []),
			"broken_source_ids": shield_resolution.get(
				"broken_source_ids", []
			),
			"guard_absorbed": _shield_resolution_used_guard(
				shield_resolution
			),
			"is_critical": result.is_crit,
			"damage_type": result.category,
			"element": result.element,
		})
	))
	# Deprecated compatibility: mitigated hit amount before shield absorption.
	EventBus.damage_dealt.emit(
		self, attacker, result.amount, result.category, result.element, result.is_crit)
	if result.is_crit:
		EventBus.critical_hit.emit(self, attacker, result.amount)
	if current_hp <= 0:
		current_hp = 0
		_die(attacker)
	elif health_loss > 0:
		_try_combat_form_change()


func _try_combat_form_change() -> bool:
	var change := combat_form_change
	if not is_alive or current_hp <= 0 or _combat_form_changed or change == null \
			or not change.is_valid() or combat_form_id != change.initial_form:
		return false
	# Integer comparison makes exactly 20% unambiguous. Temporary max-HP
	# modifiers never move the original encounter threshold.
	if current_hp * 100 >= _combat_form_base_hp * change.below_hp_percent:
		return false
	_combat_form_changed = true
	var old_form := combat_form_id
	combat_form_id = change.target_form
	if not pending_ability.is_empty():
		var cancelled := pending_ability.duplicate()
		pending_ability.clear()
		EventBus.pending_ability_cancelled.emit(self, cancelled, &"combat_form")
	spells.clear()
	for spell in change.spells:
		add_spell(spell)
	preferred_range = change.preferred_range
	minimum_range = change.minimum_range
	maximum_range = change.maximum_range
	keep_distance = change.keep_distance
	if change.shield_grant > 0:
		add_sourced_shield(change.shield_source_id, change.shield_grant, self, {
			"spell_id": change.ability_id, "tags": [&"transformation"],
		})
	stats_changed.emit(self)
	combat_form_changed.emit(self, old_form, combat_form_id)
	DebugLogger.info(CAT_COMBAT, "%s : métamorphose en %s (%d PV, %d bouclier)" % [
		unit_name, combat_form_id, current_hp, current_shield])
	return true


func _resolve_hit_origin_cell(attacker, options: Dictionary) -> Vector2i:
	var configured = options.get("impact_origin_cell", null)
	if configured is Vector2i:
		return configured as Vector2i
	if attacker is Unit:
		return (attacker as Unit).grid_pos
	return Vector2i(-1, -1)

	# Data-driven via gain_table[TAKE_DAMAGE] : nul pour Rage/Ombre (0), paie pour
	# Foi (montÃ©e en puissance) et Nature. result.amount est le coup mitigÃ© (avant
	# bouclier), donc absorber compte aussi comme "tenir bon". Point unique du flux.
func heal(
		amount: int,
		source: Unit = null,
		options: Dictionary = {}
	) -> CombatEventFact:
	if not is_alive:
		return null
	var effect_key := _combat_effect_key(&"heal", options)
	if effect_key != &"" and _resolved_combat_effects.has(effect_key):
		return _resolved_combat_effects[effect_key] as CombatEventFact
	var max_value := max_hp.get_int()
	var before := current_hp
	current_hp = mini(current_hp + amount, max_value)
	var real := current_hp - before
	var fact := CombatEventFact.create(
		&"heal_received", self, source,
		_combat_fact_metadata(options, {
			"amount_applied": real,
			"overheal": maxi(0, amount - real),
		})
	)
	EventBus.heal_received.emit(fact)
	EventBus.unit_healed.emit(self, real)
	if real > 0:
		EventBus.healing_applied.emit(self, source, real)
	hp_changed.emit(self)
	if effect_key != &"":
		_resolved_combat_effects[effect_key] = fact
	return fact


func _combat_effect_key(effect_type: StringName, metadata: Dictionary) -> StringName:
	var impact_id := StringName(metadata.get("impact_id", &""))
	if impact_id == &"":
		return &""
	return StringName("%s:%s" % [effect_type, impact_id])


func _combat_fact_metadata(base: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"action_id": base.get("action_id", &""),
		"cast_id": base.get("cast_id", &""),
		"impact_id": base.get("impact_id", &""),
		"sequence_index": base.get("sequence_index", 0),
		"ability_id": base.get("ability_id", &""),
		"attack_classification": base.get("attack_classification", &""),
		"status_id": base.get("status_id", &""),
		"is_periodic": base.get("is_periodic", false),
	}
	for key in extra:
		result[key] = extra[key]
	return result


func _hit_context_metadata(ctx: DamageResolver.HitContext) -> Dictionary:
	if ctx == null:
		return {}
	return {
		"action_id": ctx.action_id,
		"cast_id": ctx.cast_id,
		"impact_id": ctx.impact_id,
		"sequence_index": ctx.sequence_index,
		"ability_id": ctx.ability_id,
		"attack_classification": ctx.attack_classification,
		"status_id": ctx.status_id,
		"is_periodic": ctx.is_periodic,
	}


func _shield_resolution_used_guard(resolution: Dictionary) -> bool:
	for entry_value in resolution.get("breakdown", []):
		var entry := entry_value as Dictionary
		var tags: Variant = entry.get("tags", [])
		if tags is Array and (tags as Array).has(&"guard"):
			return true
	return false


func _die(killer: Unit = null) -> void:
	# Garde d'idempotence : une unitÃ© ne peut mourir qu'UNE fois.
	# Sans Ã§a, si _die est atteint deux fois (deux sources de dÃ©gÃ¢ts dans le
	# mÃªme cycle, double appel...), unit_died serait Ã©mis deux fois â†’ log et
	# rÃ©actions en double. C'est ce qui causait le doublon "est vaincu".
	if not is_alive:
		return
	is_alive = false
	if not pending_ability.is_empty():
		var cancelled_pending := pending_ability.duplicate()
		var cancelled_spell := cancelled_pending.get("spell") as Spell
		EventBus.pending_ability_cancelled.emit(self, cancelled_pending, &"caster_dead")
		if cancelled_spell != null and cancelled_spell.is_summon():
			EventBus.summon_cancelled.emit(
				self,
				cancelled_spell,
				cancelled_pending.get("cell", Vector2i(-1, -1)),
				&"caster_dead"
			)
		EventBus.telegraph_cleared.emit(self)
		pending_ability.clear()
	if grid_context != null and grid_context.has_method("on_unit_became_dead"):
		grid_context.on_unit_became_dead(self)
	# Le CombatLogger Ã©coute unit_died et produit la ligne "est vaincu".
	EventBus.unit_died.emit(self)
	EventBus.unit_killed.emit(self, killer)
	died.emit(self)

# ============================================================
# LECTURE
# ============================================================

func get_initiative() -> int:
	return initiative.get_int()

func get_attack() -> int:
	return attack_power.get_int()

func get_hp_ratio() -> float:
	var max_val = max_hp.get_int()
	if max_val <= 0:
		return 0.0
	return float(current_hp) / float(max_val)
