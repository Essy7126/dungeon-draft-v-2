@tool
class_name TerrainWorkflowService
extends RefCounted

## Modèle métier de préparation du Studio Terrain. Le format historique en
## sept étapes reste disponible pour la compatibilité, mais `checklist()` est
## le contrat nominal : il informe sans piloter la navigation ou les outils.

enum Step {
	START,
	SHAPE,
	FLOORS,
	CONTENT,
	SCENERY,
	VERIFY,
	FINALIZE,
}

const STEP_COUNT := 7

const STATE_TODO := &"todo"
const STATE_DOING := &"doing"
const STATE_DONE := &"done"
const STATE_ERROR := &"error"

## Chaque etat porte un glyphe et un mot : aucune information d'etat n'est
## transmise uniquement par la couleur.
const STATE_GLYPHS := {
	STATE_TODO: "○",
	STATE_DOING: "◐",
	STATE_DONE: "✓",
	STATE_ERROR: "!",
}
const STATE_WORDS := {
	STATE_TODO: "à faire",
	STATE_DOING: "en cours",
	STATE_DONE: "terminé",
	STATE_ERROR: "erreur",
}
const STATE_COLORS := {
	STATE_TODO: Color(0.68, 0.73, 0.80),
	STATE_DOING: Color(0.98, 0.78, 0.35),
	STATE_DONE: Color(0.52, 0.85, 0.56),
	STATE_ERROR: Color(1.0, 0.47, 0.40),
}

const READINESS_INCOMPLETE := "Terrain incomplet"
const READINESS_TESTABLE := "Prêt à tester"
const READINESS_INTEGRABLE := "Prêt à intégrer"

const STEP_LABELS := [
	"Départ",
	"Forme",
	"Sols",
	"Obstacles et départs",
	"Décor",
	"Vérifier",
	"Tester et intégrer",
]

const STEP_GOALS := [
	"Choisir le terrain à modifier ou en créer un nouveau.",
	"Décider quelles cases composent la zone jouable.",
	"Peindre le type de sol de chaque case.",
	"Placer les murs, les points de départ et les objectifs.",
	"Choisir l'illustration et ce qui passe devant les personnages.",
	"Corriger ce qui empêcherait la salle de fonctionner.",
	"Lancer un vrai combat, puis publier le terrain dans une salle.",
]

const STEP_ACTIONS := [
	"Ouvrir un terrain",
	"Ajouter des cases",
	"Peindre un sol",
	"Placer un point de départ",
	"Choisir l'illustration",
	"Vérifier le terrain",
	"Tester le combat",
]

## Consigne souris/clavier affichee par le guidage contextuel.
const STEP_HINTS := [
	"Choisissez le terrain de la salle active, ou créez-en un nouveau.",
	"Clic gauche : ajouter une case · clic droit : retirer une case.",
	"Choisissez un sol, puis peignez directement sur la grille.\nClic gauche : peindre · clic droit : restaurer.",
	"Clic gauche : poser l'élément choisi · clic droit : le retirer.",
	"Observez l'illustration, puis ajustez et confirmez la grille dessus.",
	"Cliquez une carte de problème pour voir la case concernée.",
	"Testez d'abord le combat, puis choisissez la salle de destination.",
]

## Codes de validation rattaches a chaque etape. Un code absent de cette table
## est rattache a l'etape Verifier.
const STEP_CODES := {
	Step.SHAPE: [
		"no_playable_cell", "invalid_dimensions", "cell_out_of_bounds",
		"duplicate_cell", "missing_cell_resource", "missing_border",
		"playable_border", "isolated_cells", "camps_disconnected",
		"narrow_passages", "void_cell_coherence", "grid_build_failed",
		"large_grid",
	],
	Step.FLOORS: [
		"unknown_terrain", "terrain_without_visual", "profile_unknown_terrain",
		"theme_surface_configuration_missing", "theme_alias_resolved",
	],
	Step.CONTENT: [
		"missing_heroes", "missing_enemies", "hero_pool_too_small",
		"required_hero_spawn_contract", "spawn_blocked", "spawn_collision",
		"spawn_facing_invalid", "spawn_group_id_missing", "spawn_on_border",
		"spawn_outside", "objective_obstacle_collision", "objective_out_of_bounds",
		"objective_type_unknown", "duplicate_obstacle_cell", "duplicate_obstacle_id",
		"invalid_obstacle", "obstacle_orientation_invalid",
		"obstacle_preset_flag_mismatch", "unknown_wall", "wall_config_mismatch",
		"wall_config_missing", "wall_thumbnail_missing", "profile_unknown_wall",
		"vortex_catalog_missing", "vortex_catalog_uncertified",
		"vortex_endpoint_invalid", "vortex_endpoint_reused",
		"vortex_endpoints_identical", "vortex_network_cell_invalid",
		"vortex_network_cell_reused", "vortex_network_empty",
		"vortex_network_id_invalid", "vortex_network_missing",
		"vortex_pair_id_invalid", "vortex_pair_missing", "vortex_runtime_disabled",
		"vortex_traversal_contract_mismatch", "decoration_layer_unknown",
		"decoration_out_of_bounds",
	],
	Step.SCENERY: [
		"missing_background", "background_not_found", "absolute_background_path",
		"foreground_missing", "hybrid_without_overlays", "modular_profile_missing",
		"grid_outside_image", "grid_mostly_outside_image", "calibration_error",
		"calibration_incomplete", "calibration_max_error", "anchor_distribution",
		"anchor_out_of_bounds", "duplicate_anchor", "non_invertible_grid",
		"prop_without_preview",
	],
}


static func step_label(step: int) -> String:
	return STEP_LABELS[clampi(step, 0, STEP_COUNT - 1)]


static func step_goal(step: int) -> String:
	return STEP_GOALS[clampi(step, 0, STEP_COUNT - 1)]


static func step_action_label(step: int) -> String:
	return STEP_ACTIONS[clampi(step, 0, STEP_COUNT - 1)]


static func step_hint(step: int) -> String:
	return STEP_HINTS[clampi(step, 0, STEP_COUNT - 1)]


static func state_glyph(state: StringName) -> String:
	return str(STATE_GLYPHS.get(state, "○"))


static func state_word(state: StringName) -> String:
	return str(STATE_WORDS.get(state, "à faire"))


static func state_color(state: StringName) -> Color:
	return STATE_COLORS.get(state, STATE_COLORS[STATE_TODO]) as Color


static func step_for_code(code: StringName) -> int:
	var key := str(code)
	for step in STEP_CODES:
		if key in (STEP_CODES[step] as Array):
			return int(step)
	return Step.VERIFY


## Renvoie sept dictionnaires decrivant le parcours complet.
## `context` accepte : tested, dirty, is_new_document, has_report,
## integration_label.
static func evaluate(
		arena: ArenaDefinition,
		report: ArenaValidationReport,
		context := {}
	) -> Array[Dictionary]:
	var errors := _codes_by_step(report, ArenaValidationMessage.Severity.ERROR)
	var warnings := _codes_by_step(report, ArenaValidationMessage.Severity.WARNING)
	var steps: Array[Dictionary] = []
	for index in range(STEP_COUNT):
		steps.append({
			"step": index,
			"label": step_label(index),
			"goal": step_goal(index),
			"action_label": step_action_label(index),
			"hint": step_hint(index),
			"missing": PackedStringArray(),
			"state": STATE_TODO,
			"error_count": int(errors.get(index, 0)),
			"warning_count": int(warnings.get(index, 0)),
		})
	_evaluate_start(arena, steps[Step.START], context)
	_evaluate_shape(arena, steps[Step.SHAPE])
	_evaluate_floors(arena, steps[Step.FLOORS])
	_evaluate_content(arena, steps[Step.CONTENT])
	_evaluate_scenery(arena, steps[Step.SCENERY])
	_evaluate_verify(arena, report, steps[Step.VERIFY], context)
	_evaluate_finalize(arena, report, steps[Step.FINALIZE], context)
	for entry in steps:
		if int(entry.error_count) > 0:
			entry["state"] = STATE_ERROR
		entry["state_word"] = state_word(entry.state)
		entry["state_glyph"] = state_glyph(entry.state)
		entry["next_action"] = _next_action_text(entry)
	return steps


## Checklist courte et non séquentielle affichée à côté du rail d'outils.
## Chaque entrée reprend les preuves déjà calculées par le modèle historique,
## sans créer une seconde logique de préparation.
static func checklist(
		arena: ArenaDefinition,
		report: ArenaValidationReport,
		context := {}
	) -> Array[Dictionary]:
	var steps := evaluate(arena, report, context)
	var result: Array[Dictionary] = []
	for definition in [
		["Forme valide", Step.SHAPE],
		["Sols définis", Step.FLOORS],
		["Départs présents", Step.CONTENT],
		["Décor prêt", Step.SCENERY],
		["Aucun problème bloquant", Step.VERIFY],
	]:
		var source := steps[int(definition[1])] as Dictionary
		result.append({
			"label": str(definition[0]),
			"state": source.get("state", STATE_TODO),
			"detail": source.get("next_action", ""),
			"error_count": source.get("error_count", 0),
			"warning_count": source.get("warning_count", 0),
		})
	return result


static func recommended_step(steps: Array[Dictionary]) -> int:
	for entry in steps:
		if entry.state == STATE_ERROR:
			return int(entry.step)
	for entry in steps:
		if entry.state != STATE_DONE:
			return int(entry.step)
	return Step.FINALIZE


static func readiness(
		steps: Array[Dictionary],
		report: ArenaValidationReport,
		integration_available := false
	) -> String:
	if report == null or not report.is_valid():
		return READINESS_INCOMPLETE
	for entry in steps:
		if int(entry.step) >= Step.VERIFY:
			continue
		if entry.state == STATE_ERROR or entry.state == STATE_TODO:
			return READINESS_INCOMPLETE
	return READINESS_INTEGRABLE if integration_available else READINESS_TESTABLE


## Contrat permanent affiche a cote du nom du terrain. Il distingue toujours
## brouillon, publication et modifications locales.
static func document_state_text(
		dirty: bool,
		integrated_label := "",
		draft_saved := false
	) -> String:
	if not integrated_label.is_empty():
		if dirty:
			return "Modifications locales non publiées — dernière intégration : %s" \
				% integrated_label
		return "Intégré dans %s" % integrated_label
	if dirty:
		return "Brouillon modifié — non intégré"
	if draft_saved:
		return "Brouillon enregistré — non intégré"
	return "Aucune modification en attente — non intégré"


static func _next_action_text(entry: Dictionary) -> String:
	if entry.state == STATE_DONE:
		return "Étape terminée."
	var missing := entry.missing as PackedStringArray
	if missing.is_empty():
		return "%s : %s" % [entry.action_label, entry.goal]
	return "%s — %s" % [entry.action_label, missing[0]]


static func _codes_by_step(report: ArenaValidationReport, severity: int) -> Dictionary:
	var counts := {}
	if report == null:
		return counts
	for message in report.messages:
		if message == null or message.severity != severity:
			continue
		var step := step_for_code(message.code)
		counts[step] = int(counts.get(step, 0)) + 1
	return counts


static func _evaluate_start(
		arena: ArenaDefinition,
		entry: Dictionary,
		context: Dictionary
	) -> void:
	if arena == null:
		entry["missing"] = PackedStringArray(["Aucun terrain n'est ouvert."])
		return
	entry["state"] = STATE_DONE
	entry["goal"] = "Terrain ouvert : %s (%d × %d cases)." % [
		arena.display_name, arena.grid_size.x, arena.grid_size.y,
	]
	if bool(context.get("is_new_document", false)):
		entry["state"] = STATE_DOING
		entry["missing"] = PackedStringArray([
			"Ce terrain n'a jamais été enregistré.",
		])


static func _evaluate_shape(arena: ArenaDefinition, entry: Dictionary) -> void:
	if arena == null:
		return
	var playable := arena.playable_cells().size()
	var border := arena.border_cells().size()
	var missing := PackedStringArray()
	if playable <= 0:
		missing.append("Aucune case jouable : ajoutez des cases sur la grille.")
		entry["missing"] = missing
		return
	entry["state"] = STATE_DOING
	if border <= 0 and arena.border_thickness > 0:
		missing.append("Aucune bordure : elle empêche les personnages de sortir de la zone.")
	if missing.is_empty():
		entry["state"] = STATE_DONE
	entry["missing"] = missing
	entry["goal"] = "%d case(s) jouable(s), %d case(s) de bordure." % [playable, border]


static func _evaluate_floors(arena: ArenaDefinition, entry: Dictionary) -> void:
	if arena == null:
		return
	var playable := arena.playable_cells()
	if playable.is_empty():
		entry["missing"] = PackedStringArray([
			"Définissez d'abord la forme du terrain.",
		])
		return
	var without_floor := 0
	var kinds := {}
	for cell in playable:
		var definition := arena.get_cell_definition(cell)
		if definition == null or str(definition.terrain_id).strip_edges().is_empty():
			without_floor += 1
		else:
			kinds[definition.terrain_id] = true
	var missing := PackedStringArray()
	if without_floor > 0:
		missing.append("%d case(s) sans sol défini." % without_floor)
		entry["state"] = STATE_DOING
	else:
		entry["state"] = STATE_DONE
	entry["missing"] = missing
	entry["goal"] = "%d type(s) de sol utilisé(s) sur %d case(s)." % [
		kinds.size(), playable.size(),
	]


static func _evaluate_content(arena: ArenaDefinition, entry: Dictionary) -> void:
	if arena == null:
		return
	var heroes := 0
	var enemies := 0
	for spawn in arena.spawns:
		if spawn == null:
			continue
		if spawn.is_hero():
			heroes += 1
		elif spawn.is_enemy():
			enemies += 1
	var missing := PackedStringArray()
	if heroes <= 0:
		missing.append("Aucun point de départ de héros.")
	if enemies <= 0:
		missing.append("Aucun point de départ d'ennemi.")
	if heroes > 0 or enemies > 0 or not arena.obstacles.is_empty():
		entry["state"] = STATE_DOING
	if missing.is_empty():
		entry["state"] = STATE_DONE
	entry["missing"] = missing
	entry["goal"] = "%d départ(s) de héros, %d départ(s) d'ennemi, %d obstacle(s)." % [
		heroes, enemies, arena.obstacles.size(),
	]


static func _evaluate_scenery(arena: ArenaDefinition, entry: Dictionary) -> void:
	if arena == null:
		return
	if arena.visual_mode == ArenaDefinition.VisualMode.MODULAR:
		entry["state"] = STATE_DONE
		entry["goal"] = "Ce terrain est dessiné avec des tuiles : aucune illustration n'est requise."
		return
	var missing := PackedStringArray()
	if arena.background_path.strip_edges().is_empty():
		missing.append("Aucune illustration de fond n'est choisie.")
	elif not ResourceLoader.exists(arena.background_path):
		missing.append("L'illustration de fond est introuvable dans le projet.")
	elif arena.calibration_cells.size() < 3:
		missing.append("La grille n'est pas encore alignée sur l'illustration.")
		entry["state"] = STATE_DOING
	if missing.is_empty():
		entry["state"] = STATE_DONE
		entry["goal"] = "Illustration alignée sur %d point(s) de repère." \
			% arena.calibration_cells.size()
	entry["missing"] = missing


static func _evaluate_verify(
		arena: ArenaDefinition,
		report: ArenaValidationReport,
		entry: Dictionary,
		context: Dictionary
	) -> void:
	if arena == null:
		return
	if report == null or not bool(context.get("has_report", report != null)):
		entry["missing"] = PackedStringArray([
			"Le terrain n'a pas encore été vérifié.",
		])
		return
	if not report.is_valid():
		entry["state"] = STATE_ERROR
		entry["missing"] = PackedStringArray([
			"%d problème(s) empêchent la salle de fonctionner." % report.error_count(),
		])
		entry["goal"] = "Corrigez les problèmes listés avant de tester."
		return
	entry["state"] = STATE_DONE
	entry["goal"] = "Aucun problème bloquant. %d point(s) à surveiller." \
		% report.warning_count()


static func _evaluate_finalize(
		arena: ArenaDefinition,
		report: ArenaValidationReport,
		entry: Dictionary,
		context: Dictionary
	) -> void:
	if arena == null:
		return
	var integrated_label := str(context.get("integration_label", ""))
	if not integrated_label.is_empty() and not bool(context.get("dirty", false)):
		entry["state"] = STATE_DONE
		entry["goal"] = "Intégré dans %s." % integrated_label
		return
	var missing := PackedStringArray()
	if report == null or not report.is_valid():
		missing.append("Terminez d'abord l'étape Vérifier.")
	elif bool(context.get("tested", false)):
		entry["state"] = STATE_DOING
	else:
		missing.append("Lancez au moins un combat de test avant d'intégrer.")
		entry["state"] = STATE_DOING
	entry["missing"] = missing
