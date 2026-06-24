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
# Les UnitData des héros du joueur (en dur pour l'instant ;
# viendra de la sélection d'équipe plus tard).
const HERO_DATA_PATHS = [
	"res://data/units/alliés/Gardien.tres",
	"res://data/units/alliés/Guerrier.tres",
	"res://data/units/alliés/Assassin.tres",
]

# Nombre de récompenses proposées après chaque salle.
const REWARDS_OFFERED := 3

# --- État du run (vivant pendant tout le run) ---
var heroes: Array = []          # Array[Unit] — persistent, HP conservés
var rooms: Array = []           # Array[RoomData]
var reward_pool: Array = []     # Array[RewardData]
var current_room_index: int = -1
var run_active: bool = false

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
	_build_heroes()
	rooms = run_data.rooms.duplicate()
	reward_pool = run_data.reward_pool.duplicate()
	current_room_index = -1
	run_active = true
	_go_to_next_room()

# Crée les héros UNE fois pour tout le run.
func _build_heroes() -> void:
	heroes.clear()
	for path in HERO_DATA_PATHS:
		var data = load(path)
		if data == null:
			push_error("Héros introuvable : %s" % path)
			continue
		heroes.append(Unit.from_data(data))

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
	if has_next and reward_pool.size() > 0:
		_offered_rewards = _draw_rewards(REWARDS_OFFERED)
		get_tree().change_scene_to_file.call_deferred("res://ui/RewardScreen.tscn")
	else:
		_go_to_next_room()

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
		# 5. Statut permanent (saignement de malédiction, etc.).
		if reward.status != null:
			hero.apply_status(reward.status)
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
