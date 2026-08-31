@tool
class_name EncounterPresentation
extends RefCounted

## Présentation uniquement : aucune règle ni mesure n'est recalculée ici.
const FORMATION_LABELS := {
	&"line": "Ligne", &"double_line": "Double ligne",
	&"left_flank": "Flanc gauche", &"right_flank": "Flanc droit",
	&"chief_forward": "Chefs en première ligne",
	&"centurion_rear": "Centurions à l'arrière", &"split": "Deux groupes",
}
const FORMATION_DESCRIPTIONS := {
	&"line": "Favorise des rangs à distance régulière de la zone alliée, selon les cases disponibles.",
	&"double_line": "Décale les rangs des ennemis selon leur ordre de placement et les cases disponibles.",
	&"left_flank": "Privilégie les cases du côté gauche du terrain.",
	&"right_flank": "Privilégie les cases du côté droit du terrain.",
	&"chief_forward": "Place de préférence les chefs plus près de la zone alliée.",
	&"centurion_rear": "Place de préférence les centurions plus loin de la zone alliée.",
	&"split": "Favorise les deux côtés du terrain pour répartir les ennemis en deux groupes.",
}
const ROLE_LABELS := {
	&"skeleton_normal": "Soldat squelette", &"skeleton_chief": "Chef squelette",
	&"skeleton_centurion": "Centurion squelette", &"odyssey_guard": "Garde",
	&"odyssey_skirmisher": "Tirailleur", &"odyssey_champion": "Champion",
}
const FAILURE_LABELS := {
	"definition_invalid": "La composition ou ses réglages sont invalides.",
	"hero_spawn_missing": "La zone alliée ne contient aucune case praticable.",
	"formation_unavailable": "Aucune formation ne peut être proposée.",
	"formation_invalid": "La formation ne respecte pas les contraintes de placement.",
	"incomplete_roster": "Tous les ennemis ne trouvent pas de place avec ces contraintes.",
	"invalid_or_overlapping_cell": "Une case est interdite, bloquée ou occupée plusieurs fois.",
	"role_too_close": "Un ennemi est trop proche de la zone alliée.",
	"normal_adjacent_to_hero": "Un soldat squelette est adjacent à la zone alliée.",
	"centurion_without_summon_cell": "Un centurion manque de cases libres pour invoquer.",
	"grid_or_encounter_missing": "Le terrain ou la rencontre est absent.",
}
const METRIC_LABELS := {
	"enemy_count": "Ennemis au début", "total_base_hp_after_multiplier": "Total de PV après multiplicateur",
	"total_base_attack_after_multiplier": "Total d'attaque après multiplicateur",
	"total_armor": "Total d'armure", "total_magic_resistance": "Total de résistance magique",
	"initiative_average": "Initiative moyenne", "movement_average": "Déplacement moyen",
	"living_enemy_cap": "Plafond simultané", "normal_summon_budget": "Budget d'invocations normales",
	"chief_summon_budget": "Budget d'invocations de chef", "theoretical_total_appeared": "Total théorique apparu",
	"initial_density_percent": "Densité initiale (%)", "health_multiplier": "Multiplicateur de PV",
	"attack_multiplier": "Multiplicateur d'attaque", "reward_multiplier": "Multiplicateur de récompense",
}
const PROJECTION_LABELS := {
	"room_count": "Salles", "seed_count": "Valeurs de départ analysées",
	"theoretical_minimum": "Affrontements minimum théorique", "theoretical_maximum": "Affrontements maximum théorique",
	"observed_minimum": "Affrontements minimum observé", "observed_maximum": "Affrontements maximum observé",
	"average": "Moyenne", "median": "Médiane", "quartile_1": "Premier quartile", "quartile_3": "Troisième quartile",
}

## Glossaire visuel de la carte de rencontre (G4) — vocabulaire partagé, sans
## identifiant interne de GridData ni chemin de fichier dans le parcours normal.
const TERRAIN_TYPE_LABELS := {
	GridData.CellType.NORMAL: "Sol praticable",
	GridData.CellType.WALL: "Mur (bloqué)",
	GridData.CellType.HOLE: "Trou (bloqué, mais visible au loin)",
	GridData.CellType.LAVA: "Lave",
	GridData.CellType.ICE: "Glace",
	GridData.CellType.SHADOW: "Ombre (bloque la vue)",
	GridData.CellType.RUNE: "Rune",
}


static func terrain_type_name(type: GridData.CellType) -> String:
	return TERRAIN_TYPE_LABELS.get(type, "Terrain non reconnu")


static func formation_name(id: StringName) -> String:
	return FORMATION_LABELS.get(id, "Formation non reconnue (voir les détails techniques)")


static func role_name(id: StringName, units: Array = []) -> String:
	if ROLE_LABELS.has(id):
		return ROLE_LABELS[id]
	if id == &"" or id == &"inconnu":
		return "Rôle non renseigné"
	var names := PackedStringArray()
	for unit in units:
		if unit != null and unit.tactical_role_id == id and not names.has(unit.unit_name):
			names.append(unit.unit_name)
	return "Rôle de %s" % ", ".join(names) if not names.is_empty() else "Rôle non reconnu (voir les détails techniques)"


static func faction_name(id: StringName) -> String:
	match id:
		&"skeleton_legion": return "Légion squelette"
		&"odyssey_opposition": return "Adversaires de l'Odyssée"
		&"": return "Faction non renseignée"
	return "Faction non reconnue (voir les détails techniques)"


static func failure_text(reason: String) -> String:
	return FAILURE_LABELS.get(reason, "Le placement a échoué ; consultez les détails techniques.")


static func value_text(value: Variant) -> String:
	return "Non disponible" if value == null else str(value)


static func progression(current: Dictionary, comparison: Dictionary, projection: Dictionary, walkable: int, units: Array) -> String:
	var lines := PackedStringArray(["MESURES STRUCTURELLES — pas de note de difficulté", "", "Cases praticables : %d" % walkable])
	for key in METRIC_LABELS:
		if current.has(key):
			lines.append("%s : %s" % [METRIC_LABELS[key], value_text(current[key])])
	for role in current.get("roles", {}):
		lines.append("%s : %s" % [role_name(StringName(role), units), current.roles[role]])
	lines.append("\nÉVOLUTION DEPUIS L'AFFRONTEMENT PRÉCÉDENT")
	if comparison.get("changes", {}).is_empty():
		lines.append("Aucun affrontement précédent à comparer.")
	for key in comparison.get("changes", {}):
		lines.append("%s : %s%s" % [METRIC_LABELS.get(key, "Mesure complémentaire"),
			value_text(comparison.changes[key]), " %" if comparison.changes[key] != null else ""])
	for warning in comparison.get("warnings", []):
		lines.append(warning)
	lines.append("\nPROJECTION DE LA PARTIE")
	lines.append("Déroulement : %s" % ("Un affrontement par salle" if not projection.get("waves_enabled", false) else "Plusieurs affrontements par salle"))
	for key in PROJECTION_LABELS:
		if projection.has(key):
			lines.append("%s : %s" % [PROJECTION_LABELS[key], value_text(projection[key])])
	for count in projection.get("distribution", {}):
		lines.append("%s affrontements : %s valeurs de départ" % [count, projection.distribution[count]])
	lines.append("Durée non estimée : données insuffisantes.")
	return "\n".join(lines)


static func analysis(report: Dictionary) -> String:
	if report.is_empty():
		return "Aucune analyse. Choisissez le nombre de valeurs de départ à tester."
	var lines := PackedStringArray([
		"%d valeurs de départ analysées • succès %.1f %% • %d échec(s)%s" % [
			report.completed, report.success_rate_percent, report.failures, " • ANNULÉE" if report.cancelled else ""],
		"", "FORMATIONS RETENUES",
	])
	if report.formations.is_empty():
		lines.append("Aucune formation retenue.")
	for id in report.formations:
		lines.append("%s : %s" % [formation_name(StringName(id)), report.formations[id]])
	lines.append("\nFORMATIONS JAMAIS RETENUES")
	if report.formations_never_selected.is_empty():
		lines.append("Aucune.")
	for id in report.formations_never_selected:
		lines.append(formation_name(StringName(id)))
	lines.append("\nTentatives moyennes : %.2f" % report.average_attempts)
	lines.append("Distances min / moy / max : %s / %s / %s" % [value_text(report.distance_minimum), value_text(report.distance_average), value_text(report.distance_maximum)])
	lines.append("Dans la zone préférée : %.1f %%" % report.preferred_percent)
	lines.append("\nRAISONS D'ÉCHEC")
	if report.failure_reasons.is_empty():
		lines.append("Aucun échec.")
	for reason in report.failure_reasons:
		lines.append("%s : %s" % [failure_text(str(reason)), report.failure_reasons[reason]])
	lines.append("\nVALEURS DE DÉPART PROBLÉMATIQUES")
	if report.problem_seeds.is_empty():
		lines.append("Aucune.")
	for problem in report.problem_seeds:
		lines.append("Valeur %s (effective %s) : %s" % [problem.run_seed, problem.effective_seed, failure_text(str(problem.reason))])
	return "\n".join(lines)


static func validation_explanation(message: StudioValidationMessage) -> String:
	# Les messages originaux restent intacts pour le rapport et le diagnostic.
	match message.code:
		&"run_flow_mode":
			return "Un affrontement par salle." if message.explanation == "SINGLE_ENCOUNTER" else "Plusieurs affrontements peuvent se succéder dans chaque salle."
		&"allowed_spawn_groups_unused":
			return "Ce réglage est conservé dans le fichier, mais il n'est pas encore utilisé pendant les combats."
		&"formation_unknown":
			return "Une formation enregistrée n'est pas reconnue. Choisissez une formation proposée dans Placement."
		&"role_unknown":
			return "Cet ennemi utilise le placement générique ; aucune règle spéciale n'est définie pour son rôle."
		&"required_seed_placement_failed":
			return "Impossible de placer tous les ennemis pour cette valeur de départ. Vérifiez les cases autorisées et les distances dans Placement."
		&"external_conflict":
			return "Des fichiers ont changé depuis leur ouverture. Résolvez ce conflit avant d'enregistrer."
		&"living_cap_too_low":
			return "Le plafond simultané est inférieur au nombre d'ennemis au début."
	return message.explanation


static func validation_title(message: StudioValidationMessage) -> String:
	match message.code:
		&"wave_missing": return "Affrontement absent"
		&"encounter_missing": return "Rencontre absente"
		&"layout_invalid": return "Carte invalide"
	return message.title


## G5 — répond à « qu'est-ce que cela empêche ou risque de provoquer ? ».
## Les informations ne bloquent jamais rien ; les avertissements n'empêchent
## pas de tester mais peuvent fausser le résultat ; les erreurs bloquent le
## test et l'intégration tant qu'elles ne sont pas corrigées.
static func validation_consequence(message: StudioValidationMessage) -> String:
	match message.code:
		&"external_conflict":
			return "Empêche d'enregistrer tant que le conflit n'est pas résolu."
		&"encounter_shared":
			return "Une correction ici affecterait aussi les autres affrontements qui partagent cette rencontre, sauf si vous dupliquez d'abord."
	match message.severity:
		StudioValidationMessage.Severity.ERROR:
			return "Empêche de tester et d'intégrer cet affrontement tant que ce n'est pas corrigé."
		StudioValidationMessage.Severity.WARNING:
			return "N'empêche pas de tester, mais peut donner un résultat inattendu en jeu."
	return "Information seulement : aucune action n'est requise."


## G5 — répond à « que dois-je faire maintenant ? ». Une correction proposée
## via fix_id passe toujours par le bouton « Corriger » ; sinon, l'action
## manuelle attendue est décrite ici en français simple.
static func validation_action(message: StudioValidationMessage) -> String:
	match message.fix_id:
		&"fit_living_cap":
			return "Le bouton « Corriger » relève automatiquement le plafond simultané au nombre d'ennemis au début."
		&"use_actual_room_index":
			return "Le bouton « Corriger » remplace le numéro de salle enregistré par le numéro réel."
		&"deduplicate_forbidden":
			return "Le bouton « Corriger » retire les doublons de cette liste de cases interdites."
	match message.code:
		&"roster_empty":
			return "Ouvrez Composition et ajoutez au moins une unité ennemie."
		&"encounter_missing":
			return "Assignez une rencontre à cet affrontement dans Composition."
		&"unit_duplicate":
			return "Dans Composition, regroupez les lignes de cet ennemi en une seule quantité."
		&"quantity_invalid":
			return "Dans Composition, donnez une quantité positive à cette unité."
		&"formations_empty":
			return "Dans Placement, activez au moins une formation."
		&"formation_unknown":
			return "Dans Placement, remplacez cette formation par une formation proposée."
		&"ally_zone_empty", &"ally_zone_unwalkable":
			return "Dans le Studio d'arène, ajoutez ou débloquez au moins une case de zone alliée praticable."
		&"forbidden_cell_outside":
			return "Dans Placement, retirez cette case ou corrigez la carte dans le Studio d'arène."
		&"wave_range_inverted", &"wave_range_exceeds_profiles":
			return "Ajustez le minimum et le maximum d'affrontements de cette salle dans la Chronologie."
		&"wave_name_empty":
			return "Donnez un nom à cet affrontement dans la Chronologie."
		&"health_multiplier_invalid", &"attack_multiplier_invalid", &"reward_multiplier_invalid":
			return "Corrigez ce multiplicateur dans la Chronologie."
		&"external_conflict":
			return "Rouvrez ce document pour reprendre la version la plus récente avant d'enregistrer."
	if message.severity == StudioValidationMessage.Severity.INFO:
		return "Aucune action requise."
	return "Corrigez ce point dans le Studio, puis relancez la validation."
