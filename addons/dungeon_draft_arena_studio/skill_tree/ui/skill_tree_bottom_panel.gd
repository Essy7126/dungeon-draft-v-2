@tool
class_name SkillTreeBottomPanel
extends TabContainer

signal diagnostic_selected(message: SkillTreeValidationMessage)
signal simulated_node_selected(node_id: StringName)

var _discipline: DisciplineData
var _messages: Array[SkillTreeValidationMessage] = []
var _selected_simulation_ids: Array[StringName] = []
var _xp_slider: HSlider
var _simulation_box: VBoxContainer
var _error_tree: Tree
var _stats_label: Label
var _paths_label: Label
var _xp_curve: SkillTreeXpCurve
var _path_test_label: Label
var _preview_text: RichTextLabel
var _analysis_text: RichTextLabel


func _ready() -> void:
	custom_minimum_size.y = 215
	_build_errors_tab()
	_build_stats_tab()
	_build_simulator_tab()
	_build_preview_tab()
	_build_analysis_tab()
	_build_help_tab()


func set_context(
		discipline: DisciplineData,
		messages: Array[SkillTreeValidationMessage]
	) -> void:
	_discipline = discipline
	_messages = messages
	_selected_simulation_ids.clear()
	_refresh_errors()
	_refresh_stats()
	_configure_xp_slider()
	_refresh_simulator()


func select_simulator_tab() -> void:
	current_tab = 2


func set_preview(report: Dictionary) -> void:
	current_tab = 3
	if _preview_text == null:
		return
	if not report.get("ok", false):
		_preview_text.text = "[b]Prévisualisation impossible[/b]\n%s" % report.get("error", "Erreur inconnue")
		return
	var lines := PackedStringArray([
		"[b]SORT DE BASE[/b]  %s" % JSON.stringify(report.get("base_spell", {})),
		"[b]SORT RÉSULTANT[/b]  %s" % JSON.stringify(report.get("resulting_spell", {})),
		"[b]TRACE DES MODIFICATEURS[/b]",
	])
	for trace_value in report.get("trace", []):
		var trace := trace_value as Dictionary
		lines.append("• %s — %s [%s]" % [
			trace.get("modifier_name", "Effet"), trace.get("summary", ""),
			"appliqué" if trace.get("applies", false) else "hors cible",
		])
	lines.append("[b]DELTA PAR SCÉNARIO (autorité runtime)[/b]")
	for scenario_value in report.get("scenarios", []):
		var scenario := scenario_value as Dictionary
		lines.append("• %s : %s" % [
			(scenario.get("scenario", {}) as Dictionary).get("id", "scenario"),
			JSON.stringify(scenario.get("delta", {})),
		])
	lines.append("[b]AVERTISSEMENTS[/b]")
	var warnings := report.get("warnings", PackedStringArray()) as PackedStringArray
	lines.append("Aucun" if warnings.is_empty() else "\n".join(warnings))
	_preview_text.text = "\n".join(lines)


func set_analysis(report: Dictionary) -> void:
	current_tab = 4
	if _analysis_text == null:
		return
	var enumeration := report.get("enumeration", {}) as Dictionary
	var reachability := report.get("reachability", {}) as Dictionary
	var count_text := "au moins %d (limite atteinte)" % enumeration.get("count", 0) \
		if enumeration.get("truncated", false) else "%d (exact)" % enumeration.get("count", 0)
	_analysis_text.text = """[b]ANALYSE COMPLÈTE[/b]
Configurations : %s
Durée : %.2f ms

[b]ACCESSIBILITÉ INDÉPENDANTE[/b]
Atteignables : %d
Bloqués : %s
Impossibles : %s
Rangs morts : %s

[b]DOMINANCE PRUDENTE[/b]
%s

[b]CAPSTONES CONSULTATIVES[/b]
%s""" % [
		count_text, float(report.get("duration_usec", 0)) / 1000.0,
		(reachability.get("reachable_node_ids", []) as Array).size(),
		str(reachability.get("blocked_node_ids", [])),
		str(reachability.get("impossible_node_ids", [])),
		str(reachability.get("dead_ranks", [])),
		JSON.stringify(report.get("dominance", []), "  "),
		JSON.stringify(report.get("capstones", []), "  "),
	]


func _build_errors_tab() -> void:
	_error_tree = Tree.new()
	_error_tree.name = "Erreurs et avertissements"
	_error_tree.hide_root = true
	_error_tree.columns = 2
	_error_tree.set_column_title(0, "Niveau")
	_error_tree.set_column_title(1, "Explication et correction")
	_error_tree.set_column_custom_minimum_width(0, 130)
	_error_tree.item_activated.connect(_on_error_activated)
	add_child(_error_tree)


func _build_stats_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Statistiques et chemins"
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_stats_label)
	_xp_curve = SkillTreeXpCurve.new()
	_xp_curve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_xp_curve)
	_paths_label = Label.new()
	_paths_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_paths_label)
	var test_paths := Button.new()
	test_paths.text = "Tester automatiquement tous les chemins"
	test_paths.tooltip_text = "Rejoue chaque configuration avec DisciplineProgressState et SkillTreeResolver. Le contrôle est limité à 1 000 chemins pour préserver les performances."
	test_paths.pressed.connect(_test_all_paths)
	box.add_child(test_paths)
	_path_test_label = Label.new()
	_path_test_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_path_test_label)


func _build_simulator_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Simulateur"
	add_child(scroll)
	_simulation_box = VBoxContainer.new()
	_simulation_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_simulation_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_simulation_box)
	var explanation := Label.new()
	explanation.text = "Cette simulation utilise les règles runtime et ne modifie jamais la progression réelle."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_simulation_box.add_child(explanation)
	var xp_row := HBoxContainer.new()
	_simulation_box.add_child(xp_row)
	var xp_label := Label.new()
	xp_label.text = "XP simulée"
	xp_row.add_child(xp_label)
	_xp_slider = HSlider.new()
	_xp_slider.min_value = 0
	_xp_slider.max_value = 30
	_xp_slider.step = 1
	_xp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_slider.value_changed.connect(func(_value): _refresh_simulator())
	xp_row.add_child(_xp_slider)
	var reset := Button.new()
	reset.text = "Remise à zéro"
	reset.pressed.connect(func():
		_selected_simulation_ids.clear()
		_xp_slider.value = 0
		_refresh_simulator()
	)
	xp_row.add_child(reset)
	var first_path := Button.new()
	first_path.text = "Essayer un chemin valide"
	first_path.tooltip_text = "Charge automatiquement la première configuration finale valide."
	first_path.pressed.connect(_select_first_valid_path)
	xp_row.add_child(first_path)


func _build_preview_tab() -> void:
	_preview_text = RichTextLabel.new()
	_preview_text.name = "Prévisualisation runtime"
	_preview_text.bbcode_enabled = true
	_preview_text.fit_content = false
	_preview_text.text = "Sélectionnez un nœud puis utilisez Prévisualiser."
	add_child(_preview_text)


func _build_analysis_tab() -> void:
	_analysis_text = RichTextLabel.new()
	_analysis_text.name = "Analyse complète"
	_analysis_text.bbcode_enabled = true
	_analysis_text.fit_content = false
	_analysis_text.text = "Utilisez Analyse complète pour lancer l’énumération, l’accessibilité, la dominance et les capstones."
	add_child(_analysis_text)


func _build_help_tab() -> void:
	var help := RichTextLabel.new()
	help.name = "Aide"
	help.bbcode_enabled = true
	help.fit_content = false
	help.text = """[b]Discipline[/b] — chemin de progression associé à un sort.

[b]Rang[/b] — étape débloquée quand le seuil total d’XP est atteint.

[b]Branche[/b] — suite d’améliorations reliées par des prérequis.

[b]Prérequis[/b] — amélioration qui doit déjà être acquise. Plusieurs prérequis signifient que tous sont obligatoires.

[b]Exclusion[/b] — empêche deux améliorations d’être acquises dans la même progression.

[b]Sort ciblé[/b] — sort réellement transformé par l’amélioration.

[b]Modificateur[/b] — Resource qui décrit une transformation du sort.

[b]Identifiant stable[/b] — nom technique utilisé par les sauvegardes. Changer le nom affiché ne doit pas le modifier."""
	add_child(help)


func _refresh_errors() -> void:
	if _error_tree == null:
		return
	_error_tree.clear()
	var root := _error_tree.create_item()
	if _messages.is_empty():
		var item := _error_tree.create_item(root)
		item.set_text(0, "VALIDE")
		item.set_text(1, "Aucun problème détecté par la validation technique.")
		return
	for message in _messages:
		var item := _error_tree.create_item(root)
		item.set_text(0, message.severity_label())
		item.set_text(1, "%s — %s%s" % [
			message.title,
			message.explanation,
			" Correction : " + message.suggestion if not message.suggestion.is_empty() else "",
		])
		item.set_metadata(0, message)
		item.set_custom_color(
			0,
			Color(1.0, 0.45, 0.4) if message.is_error() else Color(1.0, 0.72, 0.3)
		)


func _refresh_stats() -> void:
	if _discipline == null:
		_stats_label.text = "Aucune discipline sélectionnée."
		_paths_label.text = ""
		_xp_curve.set_discipline(null)
		_path_test_label.text = ""
		return
	var stats := SkillTreePathService.statistics(_discipline)
	_stats_label.text = "%d rangs · %d améliorations · %d prérequis · %d exclusions" % [
		stats.get("rank_count", 0), stats.get("node_count", 0),
		stats.get("prerequisite_count", 0), stats.get("exclusion_count", 0),
	]
	var threshold_parts := PackedStringArray()
	for rank_data in _sorted_ranks():
		threshold_parts.append("R%d : %d XP" % [rank_data.rank, rank_data.required_total_xp])
	var enumeration := stats.get("enumeration", {}) as Dictionary
	var count_text := "au moins %d (limite atteinte)" % enumeration.get("count", 0) \
		if enumeration.get("truncated", false) else "%d (exact)" % enumeration.get("count", 0)
	_paths_label.text = "Courbe d’XP : %s\nConfigurations finales valides : %s" % [
		"  →  ".join(threshold_parts), count_text,
	]
	_xp_curve.set_discipline(_discipline)
	_path_test_label.text = ""


func _configure_xp_slider() -> void:
	if _xp_slider == null:
		return
	var maximum := 30
	for rank_data in _sorted_ranks():
		maximum = maxi(maximum, rank_data.required_total_xp)
	_xp_slider.max_value = maximum
	_xp_slider.value = 0


func _refresh_simulator() -> void:
	if _simulation_box == null:
		return
	for child in _simulation_box.get_children():
		if child.has_meta("simulation_result"):
			_simulation_box.remove_child(child)
			child.queue_free()
	if _discipline == null:
		return
	var result := SkillTreeSimulationService.simulate(
		_discipline, int(_xp_slider.value), _selected_simulation_ids
	)
	var summary := Label.new()
	summary.set_meta("simulation_result", true)
	var pending_parts := PackedStringArray()
	for pending_rank in result.get("pending_ranks", []):
		pending_parts.append("R%d" % int(pending_rank))
	summary.text = "%d XP · Rang %d · %d choix acquis · Rangs en attente : %s" % [
		int(result.get("xp", 0)), int(result.get("rank", 1)),
		(result.get("selected_ids", []) as Array).size(),
		", ".join(pending_parts) if not pending_parts.is_empty() else "aucun",
	]
	_simulation_box.add_child(summary)
	var nodes_row := HFlowContainer.new()
	nodes_row.set_meta("simulation_result", true)
	_simulation_box.add_child(nodes_row)
	var states := result.get("states", {}) as Dictionary
	for rank_data in _sorted_ranks():
		for node in rank_data.choices:
			if node == null:
				continue
			var state := states.get(str(node.upgrade_id), {}) as Dictionary
			var button := Button.new()
			button.text = "R%d · %s — %s" % [
				node.rank, node.display_name, state.get("state", "VERROUILLÉ"),
			]
			button.tooltip_text = str(state.get("reason", ""))
			button.disabled = state.get("state") != "DISPONIBLE"
			button.pressed.connect(_select_simulated_node.bind(node.upgrade_id))
			nodes_row.add_child(button)
	var modifiers := result.get("active_modifiers", []) as Array
	var modifier_label := Label.new()
	modifier_label.set_meta("simulation_result", true)
	var modifier_lines := PackedStringArray()
	for entry_value in modifiers:
		var entry := entry_value as Dictionary
		modifier_lines.append("• %s : %s" % [entry.get("node_name", ""), entry.get("summary", "")])
	modifier_label.text = "Effets actifs :\n%s" % (
		"\n".join(modifier_lines) if not modifier_lines.is_empty() else "Aucun"
	)
	modifier_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_simulation_box.add_child(modifier_label)


func _select_simulated_node(node_id: StringName) -> void:
	var result := SkillTreeSimulationService.try_select(
		_discipline, int(_xp_slider.value), _selected_simulation_ids, node_id
	)
	if result.get("ok", false):
		_selected_simulation_ids = _typed_ids(result.get("selected_ids", []))
		simulated_node_selected.emit(node_id)
	_refresh_simulator()


func _select_first_valid_path() -> void:
	if _discipline == null:
		return
	var configurations := SkillTreePathService.final_configurations(_discipline, 1)
	if configurations.is_empty():
		return
	_selected_simulation_ids = _typed_ids(configurations[0])
	_xp_slider.value = _maximum_xp()
	_refresh_simulator()


func _test_all_paths() -> void:
	if _discipline == null:
		return
	var enumeration := SkillTreePathService.enumeration_result(_discipline, 1000)
	var configurations := enumeration.get("configurations", []) as Array
	if configurations.is_empty():
		_path_test_label.text = "Échec : aucun chemin final valide."
		return
	var tested := configurations.size()
	var failures := 0
	var maximum_xp := _maximum_xp()
	for index in range(tested):
		var selected: Array[StringName] = []
		for node_id_value in configurations[index]:
			var result := SkillTreeSimulationService.try_select(
				_discipline, maximum_xp, selected, StringName(node_id_value)
			)
			if not result.get("ok", false):
				failures += 1
				break
			selected = _typed_ids(result.get("selected_ids", []))
	_path_test_label.text = (
		"Succès : %d chemin(s) rejoué(s) avec les règles runtime." % tested
		if failures == 0 else
		"Échec : %d chemin(s) impossible(s) sur %d testé(s)." % [failures, tested]
	)
	if enumeration.get("truncated", false):
		_path_test_label.text += " Contrôle limité aux 1 000 premiers chemins ; le total affiché est au moins 1 000."


func _on_error_activated() -> void:
	var item := _error_tree.get_selected()
	if item == null:
		return
	var message := item.get_metadata(0) as SkillTreeValidationMessage
	if message != null:
		diagnostic_selected.emit(message)


func _sorted_ranks() -> Array[DisciplineRankData]:
	var result: Array[DisciplineRankData] = []
	if _discipline != null:
		for rank_data in _discipline.ranks:
			if rank_data != null:
				result.append(rank_data)
	result.sort_custom(func(a: DisciplineRankData, b: DisciplineRankData) -> bool:
		return a.rank < b.rank
	)
	return result


func _maximum_xp() -> int:
	var result := 0
	for rank_data in _sorted_ranks():
		result = maxi(result, rank_data.required_total_xp)
	return result


static func _typed_ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result
