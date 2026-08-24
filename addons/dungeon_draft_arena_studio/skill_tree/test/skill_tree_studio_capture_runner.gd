extends Control

const OUTPUT := "res://artifacts/skill_tree_studio/screenshots"
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const CASES := [
	"01_ouverture",
	"02_catalogue_recherche",
	"03_graphe_complet",
	"04_noeud_selectionne_general",
	"05_noeud_effets",
	"06_noeud_relations",
	"07_erreurs_validation",
	"08_analyse_chemins",
	"09_preview_runtime",
	"10_plan_sauvegarde",
	"11_collision_chemin",
	"12_resources_orphelines",
	"13_mode_guide",
	"14_mode_avance",
	"15_focus_clavier",
	"16_dialogue_suppression",
	"17_brouillon_recuperable",
	"18_effet_cible_fixe",
	"19_effet_cible_configurable",
	"20_menu_outils",
	"21_tiroir_ferme",
	"22_tiroir_ouvert",
]
## Cas qui documentent volontairement l'écran Personnage : ils ne basculent pas
## vers l'arbre de compétences.
const CHARACTER_SCREEN_CASES := ["01_ouverture"]
## Personnage capturé : l'Elfe possède un arbre complet et sert de référence
## visuelle. Le héros par défaut du Studio ne convient pas ici, sa copie de
## travail arrivant sans sort dans ce runner autonome.
const CAPTURE_CHARACTER := "res://data/units/alliés/elfe.tres"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var metrics := {
		"schema_version": 2,
		"created_at": Time.get_datetime_string_from_system(),
		"theme": "project/editor inherited",
		"scale": get_window().content_scale_factor,
		"scale_variants": "L’échelle d’éditeur n’est pas injectable dans ce runner autonome ; métrique réelle enregistrée.",
		"captures": {},
	}
	var succeeded := true
	for requested_size in SIZES:
		get_window().size = requested_size
		for case_name in CASES:
			var studio := SkillTreeStudioMain.new()
			studio.setup(null, null)
			studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(studio)
			for _frame in range(14):
				await get_tree().process_frame
			studio._open_character(CAPTURE_CHARACTER)
			for _frame in range(6):
				await get_tree().process_frame
			# Un brouillon laissé par une exécution précédente ouvre sa fenêtre
			# par-dessus la capture et masquerait l'écran à inspecter.
			if case_name != "17_brouillon_recuperable":
				studio.draft_dialog.hide()
				studio._pending_draft.clear()
			await _configure_case(studio, case_name)
			for _frame in range(3):
				await get_tree().process_frame
			var capture_key := "%s_%dx%d" % [case_name, requested_size.x, requested_size.y]
			var capture_metrics := _measure(studio, requested_size, case_name)
			metrics.captures[capture_key] = capture_metrics
			var image := get_viewport().get_texture().get_image()
			var path := OUTPUT.path_join(capture_key + ".png")
			var saved := false
			if image != null and not image.is_empty():
				saved = image.save_png(ProjectSettings.globalize_path(path)) == OK
			metrics.captures[capture_key].image_path = path
			metrics.captures[capture_key].image_saved = saved
			succeeded = succeeded and saved and bool(capture_metrics.get("bounds_ok", false)) \
				and bool(capture_metrics.get("primary_actions_visible", false)) \
				and bool(capture_metrics.get("mode_visibility_ok", false))
			studio.dispose_document()
			studio.queue_free()
			await get_tree().process_frame
			await get_tree().process_frame
	var report_path := OUTPUT.path_join("capture_metrics.json")
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify(metrics, "  "))
		report.close()
	else:
		succeeded = false
	get_tree().quit(0 if succeeded else 1)


func _configure_case(studio: SkillTreeStudioMain, case_name: String) -> void:
	var node := studio.session.all_nodes()[0] as SkillUpgradeData \
		if not studio.session.all_nodes().is_empty() else null
	# Le Studio ouvre sur l'écran Personnage. Sans bascule explicite, toutes les
	# captures « compétences » montraient en réalité la fiche du personnage :
	# graphe, inspecteur, tiroir et barre d'outils restaient masqués.
	if not CHARACTER_SCREEN_CASES.has(case_name):
		# Les disciplines viennent des sorts du personnage, pas d'un tableau
		# `disciplines` : Achille, héros par défaut, en a zéro de ce côté.
		var discipline_id := studio.session.selected_discipline_id
		if discipline_id == &"" and studio.session.working_unit != null:
			for entry in SkillTreeCatalogService.disciplines_for(studio.session.working_unit):
				if StringName(entry.get("id", &"")) != &"":
					discipline_id = StringName(entry.get("id"))
					break
		studio._open_spell_tree(discipline_id)
		await get_tree().process_frame
	match case_name:
		"02_catalogue_recherche":
			studio.catalog.search_edit.text = "archer"
			studio.catalog.search_edit.grab_focus()
		"03_graphe_complet":
			studio.graph.organize()
		"04_noeud_selectionne_general":
			studio.session.select_subject(node)
			studio.inspector.tabs.current_tab = 0
		"05_noeud_effets":
			studio.session.select_subject(node)
			studio.inspector.tabs.current_tab = 2
		"06_noeud_relations":
			studio.session.select_subject(node)
			studio.inspector.tabs.current_tab = 3
		"07_erreurs_validation":
			studio._validate()
		"08_analyse_chemins":
			studio._run_full_analysis()
		"09_preview_runtime":
			studio.session.select_subject(node)
			studio._preview_runtime()
		"10_plan_sauvegarde":
			studio.session.change_property(studio.session.working_unit, &"max_hp", studio.session.working_unit.max_hp + 1, "Capture plan")
			studio.save_plan_dialog.set_plan(SkillTreeSaveTransactionService.build_plan(studio.session))
			studio.save_plan_dialog.popup_centered_ratio(0.82)
		"11_collision_chemin":
			studio.session.change_property(studio.session.working_unit, &"max_hp", studio.session.working_unit.max_hp + 1, "Capture collision")
			if node != null:
				studio.session.new_resource_paths[node] = studio.session.source_unit.resource_path
			studio.save_plan_dialog.set_plan(SkillTreeSaveTransactionService.build_plan(studio.session))
			studio.save_plan_dialog.popup_centered_ratio(0.82)
		"12_resources_orphelines":
			studio.session.detach_current_discipline()
			studio._show_orphans()
		"13_mode_guide":
			studio._set_guided(true)
		"14_mode_avance":
			studio._set_guided(false)
		"15_focus_clavier":
			studio.save_button.grab_focus()
		"16_dialogue_suppression":
			if node != null:
				var selected: Array[SkillUpgradeData] = [node]
				studio._confirm_delete_nodes(selected)
		"17_brouillon_recuperable":
			studio.draft_dialog.dialog_text = "Un brouillon non sauvegardé a été trouvé.\n\nChoisissez Restaurer, Comparer ou Abandonner. Il ne sera jamais restauré silencieusement."
			studio.draft_dialog.popup_centered()
		"18_effet_cible_fixe":
			# SHIELD_CASTER protège toujours le lanceur : le champ « Cible de
			# l'effet » doit être absent, remplacé par la cible réelle.
			_select_effect(studio, node, SpellModSkillTreeEffect.EffectType.SHIELD_CASTER)
		"19_effet_cible_configurable":
			# SHIELD_TARGET consulte réellement target_scope : le champ reste.
			_select_effect(studio, node, SpellModSkillTreeEffect.EffectType.SHIELD_TARGET)
		"20_menu_outils":
			if studio.tools_menu_button != null:
				studio.tools_menu_button.get_popup().popup_centered()
		"21_tiroir_ferme":
			studio.analysis_drawer.set_expanded(false)
		"22_tiroir_ouvert":
			studio._validate()
			studio.analysis_drawer.open()
	await get_tree().process_frame


## Sélectionne un effet d'un type donné pour capturer l'inspecteur réel plutôt
## qu'un état théorique : c'est la seule façon de vérifier visuellement que la
## visibilité dynamique des champs se voit vraiment à l'écran.
func _select_effect(
		studio: SkillTreeStudioMain,
		node: SkillUpgradeData,
		effect_type: int
	) -> void:
	if node == null:
		return
	var effect: SpellModSkillTreeEffect = null
	for modifier in node.spell_modifiers:
		if modifier is SpellModSkillTreeEffect:
			effect = modifier as SpellModSkillTreeEffect
			break
	if effect == null:
		effect = SpellModSkillTreeEffect.new()
		effect.modifier_name = "Effet de capture"
		node.spell_modifiers = node.spell_modifiers + [effect]
	effect.effect_type = effect_type
	effect.amount = 5
	studio.session.select_subject(effect)
	studio.inspector.tabs.current_tab = studio.inspector.TAB_NAMES.find("Effets")


func _measure(
		studio: SkillTreeStudioMain, requested_size: Vector2i, case_name: String
	) -> Dictionary:
	var negative_controls := PackedStringArray()
	var outside_controls := PackedStringArray()
	var clipped_essential := PackedStringArray()
	for value in studio.find_children("*", "Control", true, false):
		var control := value as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control.size.x < 0.0 or control.size.y < 0.0:
			negative_controls.append(str(control.get_path()))
		var rect := control.get_global_rect()
		if not _inside_scrollable(control) and not _inside_subwindow(control, studio) and (
				rect.position.x < -2.0 or rect.position.y < -2.0
				or rect.end.x > requested_size.x + 2.0
				or rect.end.y > requested_size.y + 2.0
			):
			outside_controls.append(str(control.get_path()))
		if control is Label and (control as Label).clip_text \
				and control.get_combined_minimum_size().x > control.size.x + 1.0:
			clipped_essential.append(str(control.get_path()))
	# Prévisualiser, Analyse complète, Comparer, la fiche générale et Orphelins
	# ont rejoint le menu Outils : la barre ne porte plus que le parcours nominal.
	var primary_labels := ["Annuler", "Rétablir", "Rechercher", "Valider", "Tester", "Sauvegarder"]
	var visible_primary := PackedStringArray()
	for value in studio.find_children("*", "Button", true, false):
		var button := value as Button
		if button == null or not button.is_visible_in_tree():
			continue
		if primary_labels.has(button.text):
			visible_primary.append(button.text)
	var tools_menu_visible := studio.tools_menu_button != null \
		and studio.tools_menu_button.is_visible_in_tree()
	# Les actions de la barre n'existent que sur l'écran Compétences : sur la
	# fiche Personnage, leur absence est le comportement attendu.
	var on_skills := studio.current_screen == SkillTreeStudioMain.SCREEN_SKILLS
	var mode_visibility_ok := true
	if case_name == "13_mode_guide":
		mode_visibility_ok = studio.guided_toggle.button_pressed \
			and not studio.production_toggle.is_visible_in_tree()
	elif case_name == "14_mode_avance":
		mode_visibility_ok = not studio.guided_toggle.button_pressed \
			and studio.production_toggle.is_visible_in_tree()
	var focus := get_viewport().gui_get_focus_owner()
	var dialog_bounds_ok := true
	var visible_dialogs := PackedStringArray()
	for value in studio.find_children("*", "Window", true, false):
		var dialog := value as Window
		if dialog == null or not dialog.visible:
			continue
		visible_dialogs.append("%s %dx%d" % [dialog.get_path(), dialog.size.x, dialog.size.y])
		# La position d'une sous-fenêtre est exprimée en coordonnées écran sous
		# Windows ; sa taille reste comparable au viewport réellement capturé.
		dialog_bounds_ok = dialog_bounds_ok and dialog.size.x <= requested_size.x \
			and dialog.size.y <= requested_size.y
	var selection_visible := false
	for child in studio.graph.get_children():
		if child is GraphNode and (child as GraphNode).selected:
			selection_visible = true
			break
	return {
		"viewport": [requested_size.x, requested_size.y],
		"characters": studio.heroes.size(),
		"discipline": str(studio.session.selected_discipline_id),
		"graph_nodes": studio.graph.get_children().filter(func(child): return child is GraphNode).size(),
		"graph_width": studio.graph.size.x,
		"catalog_width": studio.catalog.size.x,
		"inspector_width": studio.inspector.size.x,
		"bottom_height": studio.bottom.size.y,
		"negative_controls": negative_controls,
		"outside_controls": outside_controls,
		"clipped_essential": clipped_essential,
		"bounds_ok": negative_controls.is_empty() and outside_controls.is_empty() and dialog_bounds_ok,
		"dialog_bounds_ok": dialog_bounds_ok,
		"visible_dialogs": visible_dialogs,
		"graph_minimum_useful": studio.graph.size.x >= 420.0,
		"primary_actions_visible": not on_skills \
			or visible_primary.size() == primary_labels.size(),
		"visible_primary_actions": visible_primary,
		"tools_menu_visible": tools_menu_visible,
		"on_skills_screen": on_skills,
		"mode_visibility_ok": mode_visibility_ok,
		"focus_owner": str(focus.get_path()) if focus != null else "",
		"focus_visible": focus == null or focus.is_visible_in_tree(),
		"selection_visible": selection_visible,
	}


static func _inside_scrollable(control: Control) -> bool:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer or ancestor is GraphEdit:
			return true
		ancestor = ancestor.get_parent()
	return false


static func _inside_subwindow(control: Control, studio: Control) -> bool:
	return control.get_window() != studio.get_window()
