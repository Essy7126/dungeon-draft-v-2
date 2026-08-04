# data/run_data.gd
# ============================================================
# RUN DATA — Définition d'un run complet.
# Contient la liste ordonnée des salles à traverser.
# Configurable entièrement dans l'inspecteur sans toucher au code.
# ============================================================

class_name RunData
extends Resource

@export var run_name: String = "Run"
@export var default_seed: int = 1337
@export_range(1, 180, 1) var target_duration_minutes: int = 30
@export_range(1, 240, 1) var extended_duration_minutes: int = 45
@export_range(1, 10, 1) var maximum_waves_per_room: int = 10
@export var rooms: Array[RoomData] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if run_name.strip_edges().is_empty():
		errors.append("Le nom de la run ne peut pas etre vide.")
	if extended_duration_minutes < target_duration_minutes:
		errors.append("La duree etendue doit etre superieure a la duree cible.")
	if rooms.is_empty():
		errors.append("La run doit contenir au moins une salle.")
	for room_index in range(rooms.size()):
		var room := rooms[room_index]
		if room == null:
			errors.append("La salle %d est absente." % (room_index + 1))
			continue
		var wave_count := room.get_wave_count()
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


func is_valid() -> bool:
	return validation_errors().is_empty()
