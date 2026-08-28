@tool
class_name RoomDraftAuthority
extends RefCounted

## AUTORITÉ UNIQUE DU BROUILLON DE SALLE.
##
## Un brouillon de salle complet est **une seule ressource** : l'ArenaDefinition
## de la working copy de Terrain. Elle hérite de RoomData, donc elle porte déjà
## les deux moitiés du brouillon :
##
##   ArenaDefinition (working copy Terrain)
##   ├── données Terrain    → ses propres @export (grille, cases, décor…)
##   └── données Rencontres → les champs hérités de RoomData classés
##                            GAMEPLAY_OWNED par RoomIntegrationFieldPolicy
##                            (encounter_definition, waves, plage de vagues,
##                             récompense ultime)
##
## Aucun second format persistant n'est créé. La RunData construite ici est un
## simple **porteur en mémoire** : elle n'est jamais sauvegardée, jamais
## canonique, et ne devient jamais l'autorité. Elle sert uniquement à présenter
## le brouillon aux services Rencontres, qui raisonnent en « partie → salle ».
##
## Le porteur ne recopie pas la salle : `rooms[0]` est **exactement l'instance**
## du brouillon. Terrain et Rencontres écrivent donc dans le même objet, et
## aucune synchronisation implicite n'est nécessaire lors d'un changement
## d'onglet. Les seuls échanges explicites restants sont fingerprintés par
## `fingerprint()` et bornés par l'ownership de champs de
## RoomIntegrationFieldPolicy.

const DRAFT_ROOT := "user://dungeon_draft_studio/room_draft"
const DRAFT_BANNER := "Brouillon de salle — pas encore intégré à une partie"
const ENCOUNTERS_ACTION_LABEL := "Créer les combats de la salle"
## Même action, même sens : seule la place disponible change en 1280 de large.
const ENCOUNTERS_ACTION_LABEL_COMPACT := "Créer les combats"
const ENCOUNTERS_ACTION_LABELS := [
	ENCOUNTERS_ACTION_LABEL, ENCOUNTERS_ACTION_LABEL_COMPACT,
]
const ENCOUNTERS_ACTION_HELP := (
	"Choisissez les ennemis, organisez les vagues et vérifiez leur placement "
	+ "sur ce terrain."
)


## Champs du brouillon possédés par le domaine Rencontres. La liste est
## demandée à la politique d'intégration plutôt que recopiée ici : un futur
## champ de gameplay ajouté à RoomData est donc couvert sans nouvelle édition.
static func gameplay_property_names(room: RoomData) -> Array[StringName]:
	var result: Array[StringName] = []
	if room == null:
		return result
	for property_name in RoomIntegrationFieldPolicy.stored_property_names(room):
		if RoomIntegrationFieldPolicy.classification_for(property_name, room) \
				== RoomIntegrationFieldPolicy.GAMEPLAY_OWNED:
			result.append(property_name)
	return result


## Capture la moitié « Rencontres » du brouillon. Utilisée pour que
## l'historique de Terrain n'écrase pas le travail de Rencontres — et
## réciproquement — sans jamais fusionner les deux historiques.
static func gameplay_state(room: RoomData) -> Dictionary:
	var result := {}
	if room == null:
		return result
	for property_name in gameplay_property_names(room):
		var value: Variant = room.get(property_name)
		result[property_name] = value.duplicate() if value is Array else value
	return result


static func restore_gameplay_state(room: RoomData, state: Dictionary) -> bool:
	if room == null or state.is_empty():
		return false
	for property_name in state:
		room.set(StringName(property_name), state[property_name])
	return true


## Recopie la moitié Rencontres d'une salle source dans le brouillon, en
## **isolant profondément** les Resources : les EncounterDefinition et les
## RoomWaveData canoniques ne sont jamais partagées avec la working copy.
## Retourne les tables de correspondance source ↔ copie, seules capables de
## distinguer plus tard « rencontre existante » de « nouvelle rencontre ».
static func isolate_gameplay_into(
		draft_room: RoomData,
		source_room: RoomData
	) -> Dictionary:
	var source_to_work := {}
	var work_to_source := {}
	if draft_room == null or source_room == null:
		return {"source_to_work": source_to_work, "work_to_source": work_to_source}
	var encounter_copies := {}
	draft_room.minimum_wave_count = source_room.minimum_wave_count
	draft_room.maximum_wave_count = source_room.maximum_wave_count
	draft_room.ultimate_reward_base_chance = source_room.ultimate_reward_base_chance
	draft_room.ultimate_reward_min_gain_per_wave = (
		source_room.ultimate_reward_min_gain_per_wave
	)
	draft_room.ultimate_reward_max_gain_per_wave = (
		source_room.ultimate_reward_max_gain_per_wave
	)
	draft_room.encounter_definition = EncounterCopyService.copy_encounter(
		source_room.encounter_definition
	)
	if source_room.encounter_definition != null:
		encounter_copies[source_room.encounter_definition] = draft_room.encounter_definition
	var waves: Array[RoomWaveData] = []
	for source_wave in source_room.waves:
		var wave := EncounterCopyService.copy_wave(source_wave, encounter_copies)
		if wave != null:
			waves.append(wave)
			source_to_work[source_wave] = wave
			work_to_source[wave] = source_wave
	draft_room.waves = waves
	for source_encounter in encounter_copies:
		source_to_work[source_encounter] = encounter_copies[source_encounter]
		work_to_source[encounter_copies[source_encounter]] = source_encounter
	return {"source_to_work": source_to_work, "work_to_source": work_to_source}


## Empreinte de la moitié Rencontres du brouillon. Elle sert aux échanges
## explicites entre les deux sous-sessions et aux vérifications d'obsolescence.
static func gameplay_fingerprint(room: RoomData) -> String:
	if room == null:
		return ""
	return JSON.stringify(
		RoomIntegrationFieldPolicy.stable_value(gameplay_state(room))
	).sha256_text()


## Empreinte du brouillon complet : terrain + rencontres.
static func fingerprint(room: RoomData) -> String:
	if room == null:
		return ""
	var terrain := ""
	if room is ArenaDefinition:
		terrain = ArenaEditSession.fingerprint((room as ArenaDefinition).to_snapshot())
	return "%s|%s" % [terrain, gameplay_fingerprint(room)]


## Projection runtime d'un **brouillon complet**.
##
## La working copy de Terrain est un document d'auteur : ses projections
## dérivées (RoomGridLayout, PaintedMapVisualData, scène de combat) ne sont
## volontairement pas écrites dedans. Les services Rencontres — grille, aperçu,
## validation, test direct — en ont pourtant besoin. Cette projection les
## reconstruit à la lecture, et y replace la moitié Rencontres du brouillon
## **sans jamais recopier ses Resources** : ce sont les mêmes instances, donc
## l'autorité reste unique.
static func runtime_projection(draft_room: RoomData) -> RoomData:
	if draft_room == null:
		return null
	if not draft_room is ArenaDefinition \
			or not (draft_room as ArenaDefinition).authoring_document:
		return draft_room
	var projection := ArenaRuntimeBridge.build_runtime_projection(
		draft_room as ArenaDefinition
	)
	if projection == null:
		return null
	projection.authoring_document = false
	return projection


## Porteur en mémoire présentant le brouillon aux services Rencontres.
## `context_run` n'est lu que pour ses règles de partie : rien n'y est écrit et
## la Resource retournée n'est jamais sauvegardée sous res://.
static func build_context_run(
		draft_room: RoomData,
		context_run: RunData
	) -> RunData:
	if draft_room == null:
		return null
	var carrier := RunData.new()
	carrier.resource_path = ""
	if context_run != null:
		# Le porteur ne doit pas se faire passer pour la partie : l'arbre des
		# salles annonce d'abord qu'il s'agit d'un brouillon.
		# La bannière porte déjà la phrase complète : l'arbre des salles, étroit,
		# se contente du rappel court.
		carrier.run_name = "Brouillon de salle — contexte : %s" % context_run.run_name
		carrier.default_seed = context_run.default_seed
		carrier.randomize_seed_each_run = context_run.randomize_seed_each_run
		carrier.target_duration_minutes = context_run.target_duration_minutes
		carrier.extended_duration_minutes = context_run.extended_duration_minutes
		carrier.room_flow_mode = context_run.room_flow_mode
		carrier.maximum_waves_per_room = context_run.maximum_waves_per_room
		carrier.content_profile = context_run.content_profile
		carrier.economy_profile = context_run.economy_profile
	else:
		carrier.run_name = "Aucune partie de contexte"
	var rooms: Array[RoomData] = []
	rooms.append(draft_room)
	carrier.rooms = rooms
	return carrier


## Vrai seulement pour le porteur : il n'a pas de chemin de ressource et ne doit
## jamais être proposé à une sauvegarde canonique.
static func is_context_carrier(run: RunData) -> bool:
	return run != null and run.resource_path.is_empty()


static func context_summary(context_run: RunData) -> String:
	if context_run == null:
		return "Aucune partie de contexte : les règles par défaut s'appliquent."
	return "Contexte en lecture seule : %s • %s • %d affrontement(s) maximum par salle." % [
		context_run.run_name,
		"vagues enchaînées" if context_run.uses_wave_chain() else "un seul affrontement",
		context_run.maximum_waves_per_room,
	]


static func draft_directory() -> String:
	return DRAFT_ROOT


static func draft_path_for(session_key: String) -> String:
	var identity := session_key.sha256_text().left(16) if not session_key.is_empty() \
		else "brouillon"
	return DRAFT_ROOT.path_join("%s.tres" % identity)
