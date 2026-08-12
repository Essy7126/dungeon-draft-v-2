class_name ArenaTerrainStatusTimingService
extends RefCounted

## Autorité unique de l'ordre activation/statut/terrain. Les statuts portés par
## un terrain vieillissent au début de l'activation, avant leur éventuel
## rafraîchissement par la cellule occupée. Les autres statuts gardent leur
## contrat historique de vieillissement en fin d'activation.
const TERRAIN_STATUS_IDS: Array[StringName] = [
	&"poison", &"burn", &"wet", &"mouille", &"gele", &"frozen", &"shock",
]


static func resolve_activation_start(unit: Unit, terrain_effects: TerrainEffects) -> bool:
	if unit == null:
		return false
	var skip := unit.process_statuses()
	unit.tick_statuses_for_ids(TERRAIN_STATUS_IDS)
	if unit.is_alive and terrain_effects != null:
		terrain_effects.on_turn_start(unit)
	return skip


static func resolve_activation_end(unit: Unit) -> void:
	if unit != null:
		unit.tick_statuses(TERRAIN_STATUS_IDS)
