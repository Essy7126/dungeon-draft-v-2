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
var current_shield: int = 0
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
		if old != Vector2i(-1, -1) and old != value:
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
var sprite_frames: SpriteFrames = null
var sprite_scale: float = 3.0
var idle_animation: String = "default"
var visual_scene: PackedScene = null
var preview_visual_scene: PackedScene = null

# --- Sorts ---
var basic_attack_enabled: bool = true
var spells: Array = []
var _progression_spell_modifiers: Array[SpellModifier] = []
var _equipment_spell_modifiers_by_source: Dictionary = {}
var activation_index: int = 0
var activation_consumed: bool = false
var _ability_states: Dictionary = {}
var pending_ability: Dictionary = {}

# --- Statuts actifs ---
# Liste de dictionnaires : { "data": StatusData, "remaining": int }
var active_statuses: Array = []

# --- Signaux ---
signal died(unit)
signal moved(from_pos: Vector2i, to_pos: Vector2i)
signal hp_changed(unit)
signal stats_changed(unit)
signal shield_changed(unit)

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


func can_use_spell(spell: Spell) -> bool:
	if spell == null or not is_alive or not can_afford_spell_resources(spell):
		return false
	var state := _ensure_ability_state(spell)
	if activation_index < int(state.get("ready_activation", 0)):
		return false
	if spell.max_uses_per_combat > 0 \
			and int(state.get("uses_this_combat", 0)) >= spell.max_uses_per_combat:
		return false
	if spell.once_per_activation \
			and int(state.get("used_activation", -1)) == activation_index:
		return false
	return true


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
	for spell_value in spells:
		_ensure_ability_state(spell_value as Spell)


func set_progression_spell_modifiers(modifiers: Array[SpellModifier]) -> void:
	_progression_spell_modifiers.clear()
	for modifier in modifiers:
		if modifier != null and not _progression_spell_modifiers.has(modifier):
			_progression_spell_modifiers.append(modifier)


func clear_progression_spell_modifiers() -> void:
	_progression_spell_modifiers.clear()


func get_progression_spell_modifiers() -> Array[SpellModifier]:
	return _progression_spell_modifiers.duplicate()


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


func apply_status(status_data: StatusData, source: Unit = null) -> void:
	if status_data == null:
		return
	# Cherche si ce statut est dÃ©jÃ  actif.
	for entry in active_statuses:
		if _status_matches(entry, status_data, source):
			# DÃ©jÃ  prÃ©sent : on rafraÃ®chit la durÃ©e (la plus longue gagne).
			entry["remaining"] = max(entry["remaining"], status_data.duration)
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
			return
	# Nouveau statut.
	var new_entry := {
		"data": status_data,
		"remaining": status_data.duration,
		"source": source,
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
				}
			)
			DebugLogger.info(CAT_STATS, "%s subit %d dÃ©gÃ¢ts de %s" % [
				unit_name, data.damage_per_turn, data.status_name], {
				"PV_restants": current_hp,
			})

		# Soin par tour (rÃ©gÃ©nÃ©ration).
		if data.heal_per_turn > 0:
			heal(data.heal_per_turn)
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
func tick_statuses() -> void:
	for i in range(active_statuses.size() - 1, -1, -1):
		var data := active_statuses[i]["data"] as StatusData
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
				}
			)
			DebugLogger.info(CAT_STATS, "%s subit %d degats de %s" % [
				unit_name,
				data.damage_per_turn,
				data.status_name,
			], {
				"PV_restants": current_hp,
			})
		active_statuses[i]["remaining"] -= 1
		if active_statuses[i]["remaining"] <= 0:
			var ended := data.get_effective_status_id()
			_remove_status_stat_modifiers(active_statuses[i])
			active_statuses.remove_at(i)
			# Le CombatLogger Ã©coute status_expired et produit la ligne de log.
			EventBus.status_expired.emit(self, ended)

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
		removed += 1
		if removed >= maximum:
			break
	return removed

# ============================================================
# GESTION DU TOUR
# ============================================================

func start_turn() -> void:
	activation_index += 1
	activation_consumed = false
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
	if amount > current_mp:
		return false
	current_mp -= amount
	stats_changed.emit(self)
	return true


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
# Le bouclier absorbe les dÃ©gÃ¢ts AVANT les PV. Il n'expire pas
# naturellement : il tient jusqu'Ã  Ãªtre Ã©puisÃ© ou remplacÃ©.
# Design : on ne cumule pas les boucliers â€” un nouveau remplace
# l'ancien s'il est plus Ã©levÃ©, sinon il est ignorÃ©. Ã‰vite le
# spam de boucliers qui empilement indÃ©finiment.
# ============================================================

# Accorde un bouclier. Remplace l'ancien s'il est plus faible.
# Un bouclier plus faible est ignorÃ© : on ne perd jamais son bouclier
# parce qu'un sort de soutien a donnÃ© moins que ce qu'on a dÃ©jÃ .
func add_shield(amount: int, source: Unit = null) -> void:
	if not is_alive or amount <= 0:
		return
	if amount <= current_shield:
		return                           # bouclier actuel dÃ©jÃ  plus fort : ignorÃ©
	var before := current_shield
	current_shield = amount
	EventBus.shield_gained.emit(self, amount)
	EventBus.shield_applied.emit(self, source, current_shield - before)
	shield_changed.emit(self)
	DebugLogger.debug(CAT_STATS,
		"%s reÃ§oit un bouclier de %d" % [unit_name, amount])

# Retire le bouclier complÃ¨tement (fin de tour, sort ennemi...).
func clear_shield() -> void:
	if current_shield <= 0:
		return
	current_shield = 0
	shield_changed.emit(self)

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

	var result := DamageResolver.compute(self, ctx)
	if result != null and not result.dodged and charged_bonus > 0:
		_consume_charged_damage_vulnerabilities(category)
	if result != null and not result.dodged and attacker is Unit and uses_outgoing:
		(attacker as Unit)._consume_charged_outgoing_damage(category)
	_apply_damage_result(result, ctx.attacker)
	if result != null and not result.dodged and not splash_spec.is_empty():
		_apply_adjacent_vulnerability_splash(splash_spec, attacker)
	return result

# take_hit : variante explicite quand on a dÃ©jÃ  un HitContext construit
# (utile pour les modificateurs de sorts qui ajoutent des crochets).
func take_hit(ctx: DamageResolver.HitContext) -> DamageResolver.DamageResult:
	if not is_alive:
		return null
	var charged_bonus := _get_charged_damage_bonus(ctx.category)
	var outgoing_bonus := 0
	if ctx.attacker is Unit:
		outgoing_bonus = (ctx.attacker as Unit)._get_outgoing_damage_bonus(ctx.category)
	ctx.raw_damage += charged_bonus + outgoing_bonus
	var result := DamageResolver.compute(self, ctx)
	if result != null and not result.dodged and charged_bonus > 0:
		_consume_charged_damage_vulnerabilities(ctx.category)
	if result != null and not result.dodged and ctx.attacker is Unit:
		(ctx.attacker as Unit)._consume_charged_outgoing_damage(ctx.category)
	_apply_damage_result(result, ctx.attacker)
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
			EventBus.status_expired.emit(self, data.get_effective_status_id())
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
			EventBus.status_expired.emit(self, data.get_effective_status_id())
		else:
			active_statuses[index]["charges"] = remaining_charges

# Applique le rÃ©sultat calculÃ© aux PV, en absorbant d'abord le bouclier.
# POINT D'Ã‰MISSION UNIQUE du flux de dÃ©gÃ¢ts.
func _apply_damage_result(result: DamageResolver.DamageResult, attacker = null) -> void:
	if result.dodged:
		EventBus.attack_dodged.emit(self, attacker)
		hp_changed.emit(self)
		return

	# --- Absorption par le bouclier ---
	# Le bouclier prend les dÃ©gÃ¢ts en premier. Si tout est absorbÃ©, les PV ne bougent pas.
	var damage_to_hp := result.amount
	if current_shield > 0 and damage_to_hp > 0:
		var absorbed := mini(current_shield, damage_to_hp)
		current_shield -= absorbed
		damage_to_hp -= absorbed
		EventBus.shield_absorbed.emit(self, absorbed)
		if current_shield <= 0:
			EventBus.shield_broken.emit(self)
		shield_changed.emit(self)
		DebugLogger.debug(CAT_STATS,
			"%s : bouclier absorbe %d (reste %d)" % [unit_name, absorbed, current_shield])

	# Annonce la frappe sur le bus (montant aprÃ¨s mitigation armure/rÃ©sist, avant bouclier).
	# shield_absorbed est émis séparément pour les consommateurs du journal/UI.
	EventBus.damage_dealt.emit(
		self, attacker, result.amount, result.category, result.element, result.is_crit)
	if result.is_crit:
		EventBus.critical_hit.emit(self, attacker, result.amount)

	# --- Application aux PV ---
	if damage_to_hp > 0:
		var health_loss := mini(current_hp, damage_to_hp)
		current_hp -= health_loss
		EventBus.health_damage_taken.emit(
			self,
			attacker,
			health_loss,
			result.category,
			result.element,
			result.is_crit
		)
		hp_changed.emit(self)
		if current_hp <= 0:
			current_hp = 0
			_die(attacker)
	else:
		# Tout absorbÃ© : les PV n'ont pas bougÃ©, mais on notifie pour l'UI.
		hp_changed.emit(self)

	# Data-driven via gain_table[TAKE_DAMAGE] : nul pour Rage/Ombre (0), paie pour
	# Foi (montÃ©e en puissance) et Nature. result.amount est le coup mitigÃ© (avant
	# bouclier), donc absorber compte aussi comme "tenir bon". Point unique du flux.
func heal(amount: int, source: Unit = null) -> void:
	if not is_alive:
		return
	var max_value := max_hp.get_int()
	var before := current_hp
	current_hp = mini(current_hp + amount, max_value)
	var real := current_hp - before
	EventBus.unit_healed.emit(self, real)
	if real > 0:
		EventBus.healing_applied.emit(self, source, real)
	hp_changed.emit(self)
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
