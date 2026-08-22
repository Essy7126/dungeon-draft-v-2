@tool
# data/run_data.gd
# ============================================================
# RUN DATA — Définition d'un run complet.
# Contient la liste ordonnée des salles à traverser.
# Configurable entièrement dans l'inspecteur sans toucher au code.
# ============================================================

class_name RunData
extends Resource

enum RoomFlowMode {
	SINGLE_ENCOUNTER = 0,
	WAVE_CHAIN = 1,
}

@export var run_name: String = "Run"
## Graine de repli, utilisée seulement quand le tirage aléatoire est désactivé
## ci-dessous. Deux parties lancées avec la même graine proposent exactement les
## mêmes reliques et placent les ennemis de la même façon.
@export var default_seed: int = 1337
## Activé : chaque nouvelle partie tire sa propre graine, donc les reliques
## proposées changent d'une partie à l'autre. À désactiver uniquement pour un
## run de test ou de débogage qu'on veut rejouer à l'identique.
@export var randomize_seed_each_run: bool = true
@export_range(1, 180, 1) var target_duration_minutes: int = 30
@export_range(1, 240, 1) var extended_duration_minutes: int = 45
@export_enum("Single Encounter", "Wave Chain") var room_flow_mode: int = (
	RoomFlowMode.SINGLE_ENCOUNTER
)
@export_range(1, 10, 1) var maximum_waves_per_room: int = 1
@export var content_profile: RunContentProfile = null
@export var economy_profile: RunEconomyProfile = null
@export var rooms: Array[RoomData] = []


func uses_wave_chain() -> bool:
	return room_flow_mode == RoomFlowMode.WAVE_CHAIN


func is_single_encounter_flow() -> bool:
	return room_flow_mode == RoomFlowMode.SINGLE_ENCOUNTER


func get_room_flow_mode_name() -> StringName:
	return &"WAVE_CHAIN" if uses_wave_chain() else &"SINGLE_ENCOUNTER"


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if run_name.strip_edges().is_empty():
		errors.append("Le nom de la run ne peut pas etre vide.")
	if extended_duration_minutes < target_duration_minutes:
		errors.append("La duree etendue doit etre superieure a la duree cible.")
	if rooms.is_empty():
		errors.append("La run doit contenir au moins une salle.")
	if content_profile != null:
		errors.append_array(content_profile.validation_errors())
	if economy_profile != null:
		errors.append_array(economy_profile.validation_errors())
	if is_single_encounter_flow() and maximum_waves_per_room != 1:
		errors.append(
			"Une run SINGLE_ENCOUNTER doit limiter les combats par salle a 1."
		)
	for room_index in range(rooms.size()):
		var room := rooms[room_index]
		if room == null:
			errors.append("La salle %d est absente." % (room_index + 1))
			continue
		var wave_count := room.get_wave_count()
		if is_single_encounter_flow():
			if not room.waves.is_empty():
				errors.append(
					"La salle %d ne peut pas contenir de profils de vagues en mode SINGLE_ENCOUNTER." % (
						room_index + 1
					)
				)
			if room.encounter_definition == null and room.enemies.is_empty():
				errors.append(
					"La salle %d doit contenir une rencontre de base valide." % (
						room_index + 1
					)
				)
			elif room.encounter_definition != null \
					and not room.encounter_definition.is_valid():
				errors.append(
					"La rencontre de base de la salle %d est invalide." % (
						room_index + 1
					)
				)
			if room.minimum_wave_count != 1 or room.maximum_wave_count != 1:
				errors.append(
					"La salle %d doit avoir une plage de combats 1-1 en mode SINGLE_ENCOUNTER." % (
						room_index + 1
					)
				)
			continue
		if wave_count <= 0:
			errors.append("La salle %d ne contient aucune vague." % (room_index + 1))
		elif wave_count > maximum_waves_per_room:
			errors.append(
				"La salle %d depasse le plafond de %d vagues." % [
					room_index + 1,
					maximum_waves_per_room,
				]
			)
		if room.minimum_wave_count > room.maximum_wave_count:
			errors.append(
				"La salle %d a une plage de vagues inversee." % (room_index + 1)
			)
		if room.maximum_wave_count > wave_count:
			errors.append(
				"La salle %d demande plus de vagues qu'elle ne possede de profils." % (
					room_index + 1
				)
			)
		if room.ultimate_reward_min_gain_per_wave \
				> room.ultimate_reward_max_gain_per_wave:
			errors.append(
				"La salle %d a une progression de chance inversee." % (
					room_index + 1
				)
			)
		for wave_index in range(room.waves.size()):
			var wave := room.waves[wave_index]
			if wave == null:
				errors.append(
					"La vague %d de la salle %d est absente." % [
						wave_index + 1,
						room_index + 1,
					]
				)
			elif not wave.is_valid():
				errors.append(
					"La vague %d de la salle %d est invalide." % [
						wave_index + 1,
						room_index + 1,
					]
				)
	return errors


## La validation de contenu reste separee pour que les RunData historiques et
## les fixtures de flow puissent encore etre chargees pendant la migration.
func content_validation_errors(require_profile := true) -> PackedStringArray:
	var errors := PackedStringArray()
	if content_profile == null:
		if require_profile:
			errors.append(
				"La RunData %s doit etre migree vers un content_profile." % run_name
			)
		return errors
	errors.append_array(content_profile.validation_errors())
	return errors


func validation_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if content_profile == null:
		warnings.append(
			"RunData legacy sans content_profile : le trio historique sera utilise."
		)
	if economy_profile == null:
		warnings.append(
			"RunData sans economy_profile : l'economie historique sera utilisee."
		)
	return warnings


func is_valid() -> bool:
	return validation_errors().is_empty()
