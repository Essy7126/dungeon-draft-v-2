# core/game_manager.gd
# ============================================================
# GAME MANAGER — Chef d'orchestre du RUN (autoload/singleton).
#
# RESPONSABILITÉ : transporter l'état du run d'une salle à l'autre.
#   - possède les héros (et donc leurs HP qui persistent : pas de regen)
#   - connaît la liste des salles et l'avancement
#   - enchaîne les combats
#   - distribue les récompenses entre les salles
#
# CE QU'IL NE FAIT PAS (volontairement) :
#   - il ne calcule aucun combat (ça reste dans battle.gd)
#   - il ne stocke aucun état local de combat (turn_queue, highlights...)
# On garde ce manager "boring" : il transporte, il ne joue pas.
# ============================================================
extends Node

# --- Configuration du run ---
# Options disponibles dans l'ecran de draft. Le build appartient au run,
# pas au combat : les batailles recoivent des heros deja configures.
const HERO_DATA_PATHS = [
	"res://data/units/alliés/Gardien.tres",
	"res://data/units/alliés/Guerrier.tres",
	"res://data/units/alliés/healer.tres",
	"res://data/units/alliés/Assassin.tres",
	"res://data/units/alliés/Necromant.tres",
	"res://data/units/alliés/Hoplite.tres",
	"res://data/units/alliés/elfe.tres",
]

const ENERGY_DATA_PATHS = [
	"res://data/energy/rage.tres",
	"res://data/energy/foi.tres",
	"res://data/energy/nature.tres",
	"res://data/energy/ombre.tres",
]

const STARTING_TRAIT_PATHS = [
	"res://data/traits/depart_etincelle_flux.tres",
	"res://data/traits/depart_posture_defensive.tres",
	"res://data/traits/depart_sang_vif.tres",
	"res://data/traits/depart_instinct_tactique.tres",
]

const DEFAULT_DRAFT = [
	{ "hero_path": "res://data/units/alliés/Gardien.tres", "energy_path": "res://data/energy/foi.tres", "trait_path": "res://data/traits/depart_posture_defensive.tres" },
	{ "hero_path": "res://data/units/alliés/Guerrier.tres", "energy_path": "res://data/energy/rage.tres", "trait_path": "res://data/traits/depart_etincelle_flux.tres" },
	{ "hero_path": "res://data/units/alliés/healer.tres", "energy_path": "res://data/energy/nature.tres", "trait_path": "res://data/traits/depart_instinct_tactique.tres" },
]

const RUN_DRAFT_SCREEN_PATH := "res://ui/RunDraftScreen.tscn"
const RUN_RESULT_SCREEN_PATH := "res://ui/RunResultScreen.tscn"
const TITLE_SCREEN_PATH := "res://ui/TitreEcran.tscn"
const FIRST_REWARD_PATH := "res://data/rewards/reward_marteau_jugement.tres"

# Nombre de récompenses proposées après chaque salle.
const REWARDS_OFFERED := 3

# --- État du run (vivant pendant tout le run) ---
var heroes: Array = []          # Array[Unit] — persistent, HP conservés
var character_states: Dictionary = {} # StringName -> CharacterRunState
var rooms: Array = []           # Array[RoomData]
var reward_pool: Array = []     # Array[RewardData]
var current_room_index: int = -1
var run_active: bool = false
var _pending_run_data: RunData = null
var _active_run_name: String = ""
var _last_run_result: Dictionary = {}

# Récompenses actuellement proposées (lues par l'écran de récompense).
var _offered_rewards: Array = []

# --- Signaux (pour que l'UI réagisse sans couplage direct) ---
signal run_won
signal run_lost
signal room_cleared(index)

# ============================================================
# DÉMARRAGE D'UN RUN
# ============================================================

func start_run(run_data: RunData) -> void:
	if run_data == null:
		push_error("Aucun RunData fourni.")
		return
	_pending_run_data = run_data
	get_tree().change_scene_to_file.call_deferred(RUN_DRAFT_SCREEN_PATH)

## Lance un run deja configure sans passer par le draft historique.
## `hero_sources` accepte des chemins res:// vers des UnitData ou des UnitData.
func start_preconfigured_run(run_data: RunData, hero_sources: Array) -> void:
	if not _prepare_preconfigured_run(run_data, hero_sources):
		return
	_go_to_next_room()

func confirm_run_draft(hero_paths: Array, energy_paths: Array, trait_paths: Array = []) -> void:
	if _pending_run_data == null:
		push_error("Aucun RunData en attente pour le draft.")
		return
	var run_data := _pending_run_data
	_pending_run_data = null
	_build_heroes_from_draft(hero_paths, energy_paths, trait_paths)
	_initialize_run_state(run_data)
	_go_to_next_room()

## Prepare l'etat sans changer de scene. Separe de start_preconfigured_run pour
## garder la construction testable sans dependre d'une transition graphique.
func _prepare_preconfigured_run(run_data: RunData, hero_sources: Array) -> bool:
	if run_data == null:
		push_error("Aucun RunData fourni pour le run preconfigure.")
		return false
	if hero_sources.is_empty():
		push_error("Aucun heros fourni pour le run preconfigure.")
		return false

	var hero_data_list: Array[UnitData] = []
	var requested_ids := {}
	for source in hero_sources:
		var data := _resolve_unit_data(source)
		if data == null:
			push_error("UnitData preconfigure invalide : %s" % str(source))
			return false
		var character_id := data.get_effective_unit_id()
		if requested_ids.has(character_id):
			push_error("Identifiant de personnage duplique : %s" % character_id)
			return false
		requested_ids[character_id] = true
		hero_data_list.append(data)

	_pending_run_data = null
	_clear_heroes()
	for data in hero_data_list:
		var hero := Unit.from_data(data)
		# Unit.from_data conserve l'energy_type et les traits propres au UnitData.
		# Aucun choix d'ecole ou trait de draft n'est applique sur cette voie.
		hero.reset_combat_resources()
		heroes.append(hero)
		var character_state := CharacterRunState.new()
		if not character_state.initialize(hero, data):
			push_error("Impossible d'initialiser l'etat du personnage : %s" % hero.unit_id)
			_clear_heroes()
			return false
		character_states[character_state.character_id] = character_state
	_initialize_run_state(run_data)
	return true

func _resolve_unit_data(source) -> UnitData:
	if source is UnitData:
		return source
	if source is String or source is StringName:
		return load(str(source)) as UnitData
	return null

func _initialize_run_state(run_data: RunData) -> void:
	rooms = run_data.rooms.duplicate()
	reward_pool = run_data.reward_pool.duplicate()
	current_room_index = -1
	run_active = true
	_active_run_name = run_data.run_name
	_last_run_result = {}
	_offered_rewards = []

func cancel_run_draft() -> void:
	_pending_run_data = null
	get_tree().change_scene_to_file.call_deferred(TITLE_SCREEN_PATH)

func get_fervor_multiplier() -> float:
	return 1.0

func get_charge_multiplier() -> float:
	return get_fervor_multiplier()

func get_default_draft() -> Array:
	return DEFAULT_DRAFT.duplicate(true)

func get_draft_hero_options() -> Array:
	return _load_draft_options(HERO_DATA_PATHS)

func get_draft_energy_options() -> Array:
	return _load_draft_options(ENERGY_DATA_PATHS)

func get_draft_trait_options() -> Array:
	return _load_draft_options(STARTING_TRAIT_PATHS)

func _load_draft_options(paths: Array) -> Array:
	var options: Array = []
	for path in paths:
		var data = load(path)
		if data == null:
			push_warning("Option de draft introuvable : %s" % path)
			continue
		options.append({ "path": path, "data": data })
	return options

# Cree les heros UNE fois pour tout le run, depuis le draft.
func _build_heroes_from_draft(hero_paths: Array, energy_paths: Array, trait_paths: Array = []) -> void:
	_clear_heroes()
	for i in range(hero_paths.size()):
		var path: String = hero_paths[i]
		var data = load(path)
		if data == null:
			push_error("Heros introuvable : %s" % path)
			continue
		var hero := Unit.from_data(data)
		if i < energy_paths.size():
			var energy = load(energy_paths[i]) as EnergyTypeData
			if energy != null:
				hero.energy_type = energy
				hero.current_energy = energy.start_energy
		if i < trait_paths.size():
			var trait_path: String = trait_paths[i]
			if trait_path != "":
				var starting_trait = load(trait_path) as TraitData
				if starting_trait != null:
					hero.add_trait_from_data(starting_trait)
				else:
					push_warning("Trait de depart introuvable : %s" % trait_path)
		hero.ensure_energy_traits()
		hero.reset_combat_resources()
		heroes.append(hero)

func _clear_heroes() -> void:
	for hero in heroes:
		if hero != null and hero.has_method("clear_traits"):
			hero.clear_traits()
	heroes.clear()
	character_states.clear()

func get_character_state(character_id: StringName) -> CharacterRunState:
	return character_states.get(character_id) as CharacterRunState

# ============================================================
# PROGRESSION ENTRE LES SALLES
# ============================================================

# Passe à la salle suivante, ou termine le run s'il n'y en a plus.
func _go_to_next_room() -> void:
	current_room_index += 1
	# Plus de salle = run gagné.
	if current_room_index >= rooms.size():
		_finish_run(true)
		return
	# On (re)charge l'écran de transition pour la nouvelle salle.
	get_tree().change_scene_to_file.call_deferred("res://ui/Transitionsalle.tscn")

# Appelé par Transitionsalle au clic sur "Continuer".
func start_next_battle() -> void:
	var room = get_current_room()
	if room == null or room.battle_scene == null:
		push_error("Aucune battle_scene assignée dans RoomData index %d" % current_room_index)
		return
	get_tree().change_scene_to_packed.call_deferred(room.battle_scene)

# La salle en cours (lue par battle au démarrage).
func get_current_room() -> RoomData:
	if current_room_index < 0 or current_room_index >= rooms.size():
		return null
	return rooms[current_room_index]

# ============================================================
# FIN DE COMBAT
# ============================================================

# Appelé par battle quand le joueur GAGNE le combat.
func on_battle_won() -> void:
	room_cleared.emit(current_room_index)
	# Récompense seulement s'il reste au moins une salle APRÈS celle-ci
	# (pas de récompense après la dernière salle : le run se termine).
	var has_next = current_room_index + 1 < rooms.size()
	if not has_next:
		_go_to_next_room()
		return

	_offered_rewards = _build_reward_offer()
	if _offered_rewards.is_empty():
		_go_to_next_room()
		return

	get_tree().change_scene_to_file.call_deferred("res://ui/RewardScreen.tscn")

# Appelé par battle quand le joueur PERD le combat.
func on_battle_lost() -> void:
	_finish_run(false)

# ============================================================
# RÉCOMPENSES
# ============================================================

func _build_reward_offer() -> Array:
	# Un run sans pool de récompenses ne doit jamais ouvrir RewardScreen,
	# y compris dans la première salle qui possède une récompense forcée.
	if reward_pool.is_empty():
		return []
	var forced_reward = _get_forced_reward_for_room(current_room_index)
	if forced_reward != null:
		var offer: Array = [forced_reward]
		offer.append_array(_draw_rewards(REWARDS_OFFERED - 1, [forced_reward]))
		return offer
	return _draw_rewards(REWARDS_OFFERED)

# Tire `count` récompenses au hasard dans le pool (sans doublon).
func _draw_rewards(count: int, excluded: Array = []) -> Array:
	var excluded_paths := {}
	for reward in excluded:
		if reward != null:
			excluded_paths[_resource_path_key(reward)] = true

	var pool: Array = []
	for reward in reward_pool:
		if reward == null:
			continue
		if excluded_paths.has(_resource_path_key(reward)):
			continue
		pool.append(reward)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

func _resource_path_key(resource: Resource) -> String:
	if resource == null:
		return ""
	if resource.resource_path != "":
		return resource.resource_path
	return str(resource.get_instance_id())

func _get_forced_reward_for_room(room_index: int) -> RewardData:
	if room_index != 0:
		return null
	return load(FIRST_REWARD_PATH) as RewardData

# Lu par l'écran de récompense pour afficher les choix.
func get_offered_rewards() -> Array:
	return _offered_rewards

# Appelé par l'écran de récompense quand le joueur a choisi.
# `chosen_hero` n'est utilisé que pour les récompenses à cible CHOICE.
func choose_reward(reward: RewardData, chosen_hero: Unit = null) -> void:
	if reward != null:
		var targets = _resolve_reward_targets(reward, chosen_hero)
		_apply_reward(reward, targets)
	_offered_rewards = []
	_go_to_next_room()

func _finish_run(victory: bool) -> void:
	run_active = false
	_offered_rewards = []
	_record_run_result(victory)
	if victory:
		run_won.emit()
	else:
		run_lost.emit()
	get_tree().change_scene_to_file.call_deferred(RUN_RESULT_SCREEN_PATH)

func _record_run_result(victory: bool) -> void:
	_last_run_result = {
		"victory": victory,
		"run_name": _active_run_name,
	}

func get_last_run_result() -> Dictionary:
	return _last_run_result.duplicate(true)

func return_to_title() -> void:
	_pending_run_data = null
	_offered_rewards = []
	run_active = false
	current_room_index = -1
	_clear_heroes()
	rooms.clear()
	reward_pool.clear()
	get_tree().change_scene_to_file.call_deferred(TITLE_SCREEN_PATH)

# Détermine quels héros reçoivent la récompense selon sa cible.
func _resolve_reward_targets(reward: RewardData, chosen_hero: Unit) -> Array:
	var living = get_living_heroes()
	if reward.forced_unit_name.strip_edges() != "":
		var forced = _hero_by_name(living, reward.forced_unit_name)
		return [forced] if forced != null else []
	match reward.target:
		RewardData.Target.ALL:
			return living
		RewardData.Target.LOWEST_HP:
			var u = _hero_by_hp(living, true)
			return [u] if u != null else []
		RewardData.Target.HIGHEST_HP:
			var u = _hero_by_hp(living, false)
			return [u] if u != null else []
		RewardData.Target.CHOICE:
			return [chosen_hero] if chosen_hero != null else []
	return []

# Applique tous les effets d'une récompense aux cibles.
func _apply_reward(reward: RewardData, targets: Array) -> void:
	for hero in targets:
		if hero == null:
			continue
		# 1. Soin immédiat.
		if reward.heal_amount > 0:
			hero.heal(reward.heal_amount)
		# 2. Bonus de stat principal.
		if reward.stat != RewardData.StatKind.NONE:
			_apply_stat_mod(hero, reward.stat, reward.stat_amount, reward.stat_is_percent)
		# 3. Malus de stat (malédiction).
		if reward.malus_stat != RewardData.StatKind.NONE:
			_apply_stat_mod(hero, reward.malus_stat, reward.malus_amount, reward.malus_is_percent)
		# 4. Nouveau sort.
		if reward.spell != null:
			var character_state := get_character_state(hero.unit_id)
			if character_state != null:
				character_state.loadout.learn_spell(reward.spell)
			else:
				hero.add_spell(reward.spell)
		if reward.trait_data != null:
			hero.add_trait_from_data(reward.trait_data)
		# 5. Statut permanent (saignement de malédiction, etc.).
		if reward.status_effect != null:
			hero.apply_status(reward.status_effect)
		print("Récompense « %s » appliquée à %s." % [reward.reward_name, hero.unit_name])

# Applique un modificateur permanent à une stat du héros.
# Gère le cas spécial des PV max : un gain de max soigne d'autant,
# et on garde current_hp dans [1, max] (une malédiction ne tue pas).
func _apply_stat_mod(hero: Unit, stat_kind: int, amount: float, is_percent: bool) -> void:
	var stat = _get_stat(hero, stat_kind)
	if stat == null:
		return
	var before_max = hero.max_hp.get_int()
	var mtype = Stat.ModType.PERCENT if is_percent else Stat.ModType.FLAT
	stat.add_modifier(amount, mtype, "reward", -1)

	if stat_kind == RewardData.StatKind.MAX_HP:
		var after_max = hero.max_hp.get_int()
		var delta = after_max - before_max
		if delta > 0:
			hero.current_hp += delta   # un gain de PV max soigne d'autant
		hero.current_hp = clampi(hero.current_hp, 1, after_max)
	hero.stats_changed.emit(hero)

# Renvoie l'objet Stat correspondant à un StatKind.
func _get_stat(hero: Unit, stat_kind: int):
	match stat_kind:
		RewardData.StatKind.MAX_HP:     return hero.max_hp
		RewardData.StatKind.ATTACK:     return hero.attack_power
		RewardData.StatKind.MAX_MP:     return hero.max_mp
		RewardData.StatKind.MAX_AP:     return hero.max_ap
		RewardData.StatKind.INITIATIVE: return hero.initiative
	return null

# Héros vivant avec le moins (ou le plus) de PV.
func _hero_by_name(living: Array, unit_name: String) -> Unit:
	var wanted := unit_name.strip_edges().to_lower()
	for u in living:
		if u != null and u.unit_name.to_lower() == wanted:
			return u
	for u in living:
		if u != null and wanted in u.unit_name.to_lower():
			return u
	return null
func _hero_by_hp(living: Array, lowest: bool) -> Unit:
	var best: Unit = null
	for u in living:
		if best == null:
			best = u
			continue
		if lowest and u.current_hp < best.current_hp:
			best = u
		elif not lowest and u.current_hp > best.current_hp:
			best = u
	return best

# ============================================================
# LECTURE DES HÉROS (par battle, par l'UI)
# ============================================================

# Les héros encore vivants, à déployer dans la salle.
func get_living_heroes() -> Array:
	return heroes.filter(func(u): return u.is_alive)
