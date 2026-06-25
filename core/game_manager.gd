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
]

const ENERGY_DATA_PATHS = [
	"res://data/energy/rage.tres",
	"res://data/energy/foi.tres",
	"res://data/energy/nature.tres",
]

const STARTING_TRAIT_PATHS = [
	"res://data/traits/vengeance.tres",
	"res://data/traits/fureur.tres",
]

const DEFAULT_DRAFT = [
	{ "hero_path": "res://data/units/alliés/Gardien.tres", "energy_path": "res://data/energy/foi.tres", "trait_path": "" },
	{ "hero_path": "res://data/units/alliés/Guerrier.tres", "energy_path": "res://data/energy/rage.tres", "trait_path": "" },
	{ "hero_path": "res://data/units/alliés/healer.tres", "energy_path": "res://data/energy/nature.tres", "trait_path": "" },
]

const RUN_DRAFT_SCREEN_PATH := "res://ui/RunDraftScreen.tscn"
const FIRST_REWARD_PATH := "res://data/rewards/reward_marteau_jugement.tres"

# Nombre de récompenses proposées après chaque salle.
const REWARDS_OFFERED := 3

# --- État du run (vivant pendant tout le run) ---
var heroes: Array = []          # Array[Unit] — persistent, HP conservés
var rooms: Array = []           # Array[RoomData]
var reward_pool: Array = []     # Array[RewardData]
var current_room_index: int = -1
var run_active: bool = false
var _pending_run_data: RunData = null

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

func confirm_run_draft(hero_paths: Array, energy_paths: Array, trait_paths: Array = []) -> void:
	if _pending_run_data == null:
		push_error("Aucun RunData en attente pour le draft.")
		return
	var run_data := _pending_run_data
	_pending_run_data = null
	_build_heroes_from_draft(hero_paths, energy_paths, trait_paths)
	rooms = run_data.rooms.duplicate()
	reward_pool = run_data.reward_pool.duplicate()
	current_room_index = -1
	run_active = true
	_go_to_next_room()

func cancel_run_draft() -> void:
	_pending_run_data = null
	get_tree().change_scene_to_file.call_deferred("res://ui/TitreEcran.tscn")

func get_default_draft() -> Array:
	return DEFAULT_DRAFT.duplicate(true)

func get_draft_hero_options() -> Array:
	return _load_draft_options(HERO_DATA_PATHS)

func get_draft_energy_options() -> Array:
	return _load_draft_options(ENERGY_DATA_PATHS)

func get_draft_trait_options() -> Array:
	var options: Array = [
		{ "path": "", "data": null, "name": "Aucun trait", "description": "Garde seulement le chassis du heros." },
	]
	options.append_array(_load_draft_options(STARTING_TRAIT_PATHS))
	return options

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
	for hero in heroes:
		if hero != null and hero.has_method("clear_traits"):
			hero.clear_traits()
	heroes.clear()
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
		heroes.append(hero)

# ============================================================
# PROGRESSION ENTRE LES SALLES
# ============================================================

# Passe à la salle suivante, ou termine le run s'il n'y en a plus.
func _go_to_next_room() -> void:
	current_room_index += 1
	# Plus de salle = run gagné.
	if current_room_index >= rooms.size():
		run_active = false
		run_won.emit()
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

	var forced_reward = _get_forced_reward_for_room(current_room_index)
	if forced_reward != null:
		_offered_rewards = [forced_reward]
	elif reward_pool.size() > 0:
		_offered_rewards = _draw_rewards(REWARDS_OFFERED)
	else:
		_go_to_next_room()
		return

	get_tree().change_scene_to_file.call_deferred("res://ui/RewardScreen.tscn")

# Appelé par battle quand le joueur PERD le combat.
func on_battle_lost() -> void:
	run_active = false
	run_lost.emit()

# ============================================================
# RÉCOMPENSES
# ============================================================

# Tire `count` récompenses au hasard dans le pool (sans doublon).
func _draw_rewards(count: int) -> Array:
	var pool = reward_pool.duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

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

# Détermine quels héros reçoivent la récompense selon sa cible.
func _resolve_reward_targets(reward: RewardData, chosen_hero: Unit) -> Array:
	var living = get_living_heroes()
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
