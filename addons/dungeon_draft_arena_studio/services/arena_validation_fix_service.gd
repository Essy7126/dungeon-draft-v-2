@tool
class_name ArenaValidationFixService
extends RefCounted

## Corrections automatiques du panneau de validation. Une correction n'est
## proposee que si elle est deterministe, sure et annulable : le service se
## contente de modifier la working copy, l'appelant enregistre l'avant/apres
## dans l'historique. Aucune regle de gameplay, aucun equilibrage et aucune
## donnee de rencontre ne sont touches ici.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
]

## Corrections reellement executables. Les autres `suggested_fix` du validateur
## sont des aides de navigation, pas des corrections.
const APPLICABLE_FIXES := {
	&"create_border": {
		"label": "Créer la bordure de sécurité",
		"action": "Créer la bordure de sécurité",
		"explanation": "Le Studio entoure la zone jouable d'une bordure non jouable.",
	},
	&"make_border_non_playable": {
		"label": "Rendre cette bordure non jouable",
		"action": "Rendre la bordure non jouable",
		"explanation": "La case reste dessinée, mais plus personne ne peut s'y arrêter.",
	},
	&"move_spawn_to_nearest_valid": {
		"label": "Déplacer ce point de départ sur la case libre la plus proche",
		"action": "Déplacer le point de départ",
		"explanation": "Le point de départ rejoint la case jouable libre la plus proche.",
	},
	&"remove_empty_vortex_network": {
		"label": "Supprimer ce réseau vide",
		"action": "Supprimer le réseau vide",
		"explanation": "Seul le réseau sans aucune case est retiré de la version en cours.",
	},
}


static func can_fix(message: ArenaValidationMessage) -> bool:
	if message == null:
		return false
	return APPLICABLE_FIXES.has(message.suggested_fix)


static func fix_label(message: ArenaValidationMessage) -> String:
	if message == null or not APPLICABLE_FIXES.has(message.suggested_fix):
		return ""
	return str((APPLICABLE_FIXES[message.suggested_fix] as Dictionary).get("label", ""))


static func fix_explanation(message: ArenaValidationMessage) -> String:
	if message == null or not APPLICABLE_FIXES.has(message.suggested_fix):
		return ""
	return str((APPLICABLE_FIXES[message.suggested_fix] as Dictionary).get("explanation", ""))


static func action_name(message: ArenaValidationMessage) -> String:
	if message == null or not APPLICABLE_FIXES.has(message.suggested_fix):
		return "Corriger automatiquement"
	return str((APPLICABLE_FIXES[message.suggested_fix] as Dictionary).get("action", ""))


## Applique la correction sur `arena`. Retourne {ok, changed, action, message}.
static func apply(
		arena: ArenaDefinition,
		message: ArenaValidationMessage
	) -> Dictionary:
	if arena == null or not can_fix(message):
		return {
			"ok": false, "changed": false, "action": "",
			"message": "Cette anomalie n'a pas de correction automatique sûre.",
		}
	match message.suggested_fix:
		&"create_border":
			return _create_border(arena)
		&"make_border_non_playable":
			return _make_border_non_playable(arena, message.cell)
		&"move_spawn_to_nearest_valid":
			return _move_spawn(arena, message.cell)
		&"remove_empty_vortex_network":
			return _remove_empty_vortex_network(arena, message.subject_id)
	return {
		"ok": false, "changed": false, "action": "",
		"message": "Cette anomalie n'a pas de correction automatique sûre.",
	}


static func _create_border(arena: ArenaDefinition) -> Dictionary:
	var count := ArenaEditingService.apply_safety_border(
		arena, maxi(1, arena.border_thickness), false
	)
	return {
		"ok": count > 0,
		"changed": count > 0,
		"action": "Créer la bordure de sécurité",
		"message": "Bordure créée sur %d case(s)." % count if count > 0 \
			else "Aucune case de bordure n'a pu être créée.",
	}


static func _make_border_non_playable(
		arena: ArenaDefinition,
		cell: Vector2i
	) -> Dictionary:
	var definition := arena.get_cell_definition(cell)
	if definition == null or not definition.border:
		return {
			"ok": false, "changed": false, "action": "",
			"message": "Cette case n'est plus une bordure.",
		}
	if not definition.playable:
		return {
			"ok": true, "changed": false,
			"action": "Rendre la bordure non jouable",
			"message": "Cette bordure était déjà non jouable.",
		}
	definition.playable = false
	return {
		"ok": true, "changed": true,
		"action": "Rendre la bordure non jouable",
		"message": "La case (%d, %d) n'est plus jouable." % [cell.x, cell.y],
	}


static func _move_spawn(arena: ArenaDefinition, cell: Vector2i) -> Dictionary:
	var spawns := arena.spawns_at(cell)
	if spawns.is_empty():
		return {
			"ok": false, "changed": false, "action": "",
			"message": "Aucun point de départ ne se trouve sur cette case.",
		}
	var spawn := spawns[0]
	var target := _nearest_valid_cell(arena, cell)
	if target == GridTransformService.INVALID_CELL:
		return {
			"ok": false, "changed": false, "action": "",
			"message": "Aucune case libre proche : ajoutez ou libérez une case d'abord.",
		}
	spawn.cell = target
	return {
		"ok": true, "changed": true,
		"action": "Déplacer le point de départ",
		"message": "%s déplacé en (%d, %d)." % [
			spawn.display_label(), target.x, target.y,
		],
	}


static func _remove_empty_vortex_network(
		arena: ArenaDefinition,
		network_id: StringName
	) -> Dictionary:
	var before := arena.vortex_networks.size()
	arena.vortex_networks = arena.vortex_networks.filter(func(network):
		return network != null and (
			network.network_id != network_id or not network.cells.is_empty()
		)
	)
	var changed := arena.vortex_networks.size() != before
	return {
		"ok": changed,
		"changed": changed,
		"action": "Supprimer le réseau vide",
		"message": "Réseau vide supprimé." if changed else "Ce réseau n'est plus vide.",
	}


## Parcours en largeur strictement deterministe : les voisins sont explores
## dans l'ordre fixe gauche, droite, haut, bas, donc deux executions sur la
## meme arene donnent toujours la meme case.
static func _nearest_valid_cell(
		arena: ArenaDefinition,
		origin: Vector2i
	) -> Vector2i:
	var occupied := {}
	for spawn in arena.spawns:
		if spawn != null:
			occupied[spawn.cell] = true
	var visited := {origin: true}
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in DIRECTIONS:
			var candidate := current + direction
			if visited.has(candidate) or not arena.is_in_bounds(candidate):
				continue
			visited[candidate] = true
			queue.append(candidate)
			if _is_valid_spawn_cell(arena, candidate) and not occupied.has(candidate):
				return candidate
	return GridTransformService.INVALID_CELL


static func _is_valid_spawn_cell(arena: ArenaDefinition, cell: Vector2i) -> bool:
	var definition := arena.get_cell_definition(cell)
	if definition == null or not definition.defined or definition.border \
			or not definition.playable:
		return false
	var obstacle := arena.obstacle_at(cell)
	return obstacle == null or not obstacle.blocks_movement
