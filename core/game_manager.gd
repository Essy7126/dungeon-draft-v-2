# core/game_manager.gd
# ============================================================
# GAME MANAGER — Chef d'orchestre du RUN (autoload/singleton).
#
# RESPONSABILITÉ : transporter l'état du run d'une salle à l'autre.
#   - possède les héros (et donc leurs HP qui persistent : pas de regen)
#   - connaît la liste des salles et l'avancement
#   - enchaîne les combats
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
	"res://data/units/chevalier.tres",
	"res://data/units/mage.tres",
]

# La liste ordonnée des salles du run.
const ROOM_PATHS = [
	"res://data/rooms/salle_1.tres",
	"res://data/rooms/salle_2.tres",
	"res://data/rooms/salle_3.tres",
]

const BATTLE_SCENES = [
	"res://data/rooms/maps/battle_salle1.tscn",
	"res://data/rooms/maps/battle_salle2.tscn",
	"res://data/rooms/maps/battle_salle3.tscn",
]

# --- État du run (vivant pendant tout le run) ---
var heroes: Array = []          # Array[Unit] — persistent, HP conservés
var rooms: Array = []           # Array[RoomData]
var current_room_index: int = -1
var run_active: bool = false

# --- Signaux (pour que l'UI réagisse sans couplage direct) ---
signal run_won
signal run_lost
signal room_cleared(index)

# ============================================================
# DÉMARRAGE D'UN RUN
# ============================================================

func start_run() -> void:
	_build_heroes()
	_load_rooms()
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

func _load_rooms() -> void:
	rooms.clear()
	for path in ROOM_PATHS:
		var room = load(path)
		if room == null:
			push_error("Salle introuvable : %s" % path)
			continue
		rooms.append(room)

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

	# On (re)charge la scène de combat pour la nouvelle salle.
	get_tree().change_scene_to_file("res://ui/Transitionsalle.tscn")

# Appelé par Transitionsalle au clic sur "Continuer".
func start_next_battle() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENES[current_room_index])
# La salle en cours (lue par battle au démarrage).
func get_current_room() -> RoomData:
	if current_room_index < 0 or current_room_index >= rooms.size():
		return null
	return rooms[current_room_index]

# Appelé par battle quand le joueur GAGNE le combat.
func on_battle_won() -> void:
	room_cleared.emit(current_room_index)
	_go_to_next_room()

# Appelé par battle quand le joueur PERD le combat.
func on_battle_lost() -> void:
	run_active = false
	run_lost.emit()

# ============================================================
# LECTURE DES HÉROS (par battle)
# ============================================================

# Les héros encore vivants, à déployer dans la salle.
func get_living_heroes() -> Array:
	return heroes.filter(func(u): return u.is_alive)
