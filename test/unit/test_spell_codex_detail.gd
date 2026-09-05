extends GutTest

const SCREEN_SCENE := preload("res://ui/progression/screens/skill_tree_screen.tscn")
const MAIN_CONTENT: RunContentProfile = preload("res://data/runs/profiles/main_content_profile.tres")
const CHAMPION_CONTENT: RunContentProfile = preload("res://data/runs/profiles/odyssey_content_profile.tres")
const STRIKE_ID: StringName = &"warrior_heavy_strike"
const GUARD_ID: StringName = &"warrior_guard"
const BASE_ID: StringName = &"__base_rank_1"

var screen: SkillTreeScreen
var state: CharacterRunState


func before_each() -> void:
	screen = SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(screen)


func after_each() -> void:
	if is_instance_valid(screen):
		screen.close_for_run_cleanup()
	if state != null:
		state.dispose()
		state = null
	await wait_process_frames(2)


func test_champion_techniques_show_scaled_values_costs_ranges_and_casting_rules() -> void:
	await _open_hero(CHAMPION_CONTENT, &"achilles")
	var codex := screen.get_champion_codex() as ChampionCodex
	var expected := ["10 dégâts · PO 1", "PO 1–3", "9 dégâts · PO 2–6", "10 bouclier · Personnel"]
	var strip := codex.get("_spells") as HBoxContainer
	for index in range(4):
		(strip.get_child(index) as Button).pressed.emit()
		var spell := state.unit.spells[index] as Spell
		var detail := _champion_detail_text()
		assert_true(detail.contains(spell.spell_name))
		assert_true(detail.contains(expected[index]), detail)
		assert_true(detail.contains("%d PA" % spell.ap_cost))
		assert_true(detail.contains("Une fois par activation"))
		assert_true(codex.get_action_button().disabled)
	var guard_detail := _champion_detail_text().replace(".0 %", " %")
	assert_true(guard_detail.contains("25 % Prouesse"), guard_detail)
	assert_true(guard_detail.contains("5 % PV maximum"), guard_detail)
	assert_true(guard_detail.contains("Expire au début de votre prochaine activation"))
	assert_true(guard_detail.contains("les autres sources de bouclier sont conservées"))


func test_champion_mastery_preview_shows_named_prerequisites_and_range_delta_without_investing() -> void:
	await _open_hero(CHAMPION_CONTENT, &"achilles")
	var codex := screen.get_champion_codex() as ChampionCodex
	var snapshot := state.get_progression_snapshot()
	codex.select_section(&"achilles_lesson_of_chiron")
	codex.inspect_node(&"achilles_chiron_pelion_reach")
	var detail := _champion_detail_text()
	assert_true(detail.contains("Allonge du Pélion"))
	assert_true(detail.contains("Œil du centaure"))
	assert_true(detail.contains("Exclusif avec : Tir rapproché"))
	assert_true(detail.contains("9 dégâts · PO 2–6  →  9 dégâts · PO 3–8"), detail)
	assert_true(detail.contains("Les bonus conditionnels s’appliquent"))
	assert_true(codex.get_action_button().disabled)
	assert_eq(state.get_progression_snapshot(), snapshot)
	var shot := _spell(&"achilles_pelion_shot")
	assert_eq([shot.minimum_range, shot.spell_range], [2, 6])


func test_champion_switching_from_mastery_to_technique_recomputes_live_stats_and_clears_preview() -> void:
	await _open_hero(CHAMPION_CONTENT, &"achilles")
	state.unit.attack_power.base_value = 200.0
	state.unit.max_hp.base_value = 400.0
	var codex := screen.get_champion_codex() as ChampionCodex
	codex.inspect_node(&"achilles_chiron_pelion_reach")
	assert_true(_champion_detail_text().contains("PO 3–8"))
	codex._inspect_spell(_spell(&"achilles_pelion_shot"))
	assert_true(_champion_detail_text().contains("100 dégâts · PO 2–6"))
	assert_false(_champion_detail_text().contains("PO 3–8"))
	codex._inspect_spell(_spell(&"achilles_peleid_strike"))
	assert_true(_champion_detail_text().contains("110 dégâts · PO 1"))
	codex._inspect_spell(_spell(&"achilles_bronze_guard"))
	var guard_detail := _champion_detail_text()
	assert_true(guard_detail.contains("70 bouclier · Personnel"), guard_detail)
	assert_false(guard_detail.contains("110 dégâts"))
	assert_false(guard_detail.contains("CONDITIONS D’ACCÈS"))
	assert_true(state.get_selected_mastery_nodes().is_empty())


func test_legacy_strike_and_guard_keep_base_metrics_and_targeting_context() -> void:
	await _open_hero(MAIN_CONTENT, &"warrior")
	var strike := _spell(STRIKE_ID)
	var guard := _spell(GUARD_ID)
	screen._show_discipline(strike.skill_tree.discipline_id)
	var detail := screen.get_detail_panel()
	var metrics := detail.get_spell_metrics_text()
	assert_true(metrics.contains("%d PA" % strike.ap_cost))
	assert_true(metrics.contains("%d dégâts physiques" % strike.damage))
	assert_true(metrics.contains("Cibles : ennemis"))
	assert_true(metrics.contains("Ligne de vue requise"))
	screen._show_discipline(guard.skill_tree.discipline_id)
	metrics = detail.get_spell_metrics_text()
	assert_true(metrics.contains("%d points de bouclier" % guard.shield_grant))
	assert_true(metrics.contains("Cibles : alliés, soi-même"))
	assert_false(metrics.contains("dégâts physiques"))
	assert_false((detail.get_node("%PrerequisitesLabel") as Label).visible)


func test_legacy_inspecting_a_masked_future_upgrade_removes_previous_spell_mechanics() -> void:
	await _open_hero(MAIN_CONTENT, &"warrior")
	var spear := _spell(STRIKE_ID)
	assert_true(screen.open_for_state(state, spear.skill_tree.discipline_id))
	await wait_process_frames(3)
	var detail := screen.get_detail_panel()
	assert_false(detail.get_spell_metrics_text().is_empty())
	var upgrade := spear.skill_tree.ranks[1].choices[0] as SkillUpgradeData
	var future := screen.get_graph().get_node_view(upgrade.upgrade_id)
	assert_not_null(future)
	assert_false(future.is_content_revealed())
	assert_true(screen.get_graph().inspect_node_by_id(upgrade.upgrade_id))
	assert_eq(detail.get_spell_metrics_text(), "")
	assert_eq(detail.current_presentation_id, &"__locked_rank_2")
	assert_false(detail.get_detail_text().contains(upgrade.display_name))
	assert_false(detail.get_detail_text().contains(upgrade.description))
	assert_false(detail.get_detail_text().contains("dégâts physiques"))
	assert_true(detail.get_action_button().disabled)


func test_legacy_returning_to_base_restores_the_correct_context_after_a_masked_node_and_tab_change() -> void:
	await _open_hero(MAIN_CONTENT, &"warrior")
	var spear := _spell(STRIKE_ID)
	var guard := _spell(GUARD_ID)
	assert_true(screen.open_for_state(state, spear.skill_tree.discipline_id))
	await wait_process_frames(3)
	var detail := screen.get_detail_panel()
	var spear_metrics := detail.get_spell_metrics_text()
	var spear_upgrade := spear.skill_tree.ranks[1].choices[0] as SkillUpgradeData
	assert_true(screen.get_graph().inspect_node_by_id(spear_upgrade.upgrade_id))
	assert_eq(detail.get_spell_metrics_text(), "")
	assert_true(screen.get_graph().inspect_node_by_id(BASE_ID))
	assert_eq(detail.get_spell_metrics_text(), spear_metrics)

	screen._show_discipline(guard.skill_tree.discipline_id)
	await wait_process_frames(3)
	var guard_metrics := detail.get_spell_metrics_text()
	assert_ne(guard_metrics, spear_metrics)
	var guard_upgrade := guard.skill_tree.ranks[1].choices[0] as SkillUpgradeData
	assert_true(screen.get_graph().inspect_node_by_id(guard_upgrade.upgrade_id))
	assert_eq(detail.get_spell_metrics_text(), "")
	assert_true(screen.get_graph().inspect_node_by_id(BASE_ID))
	assert_eq(detail.get_spell_metrics_text(), guard_metrics)
	assert_true(detail.get_spell_metrics_text().contains("%d points de bouclier" % guard.shield_grant))
	assert_false(detail.get_spell_metrics_text().contains("dégâts physiques"))
	assert_eq(detail.current_presentation_id, BASE_ID)


func test_legacy_revealed_upgrade_keeps_its_authored_effect_separate_from_base_spell_values() -> void:
	await _open_hero(MAIN_CONTENT, &"warrior")
	var spear := _spell(STRIKE_ID)
	var upgrade := spear.skill_tree.ranks[1].choices[0] as SkillUpgradeData
	var progress := state.get_spell_progress(STRIKE_ID)
	progress.add_xp(spear.skill_tree.ranks[1].required_total_xp)
	assert_true(screen.open_for_state(state, spear.skill_tree.discipline_id))
	await wait_process_frames(3)
	var view := screen.get_graph().get_node_view(upgrade.upgrade_id)
	assert_true(view.is_content_revealed())
	assert_true(screen.get_graph().inspect_node_by_id(upgrade.upgrade_id))
	var detail := screen.get_detail_panel()
	var metrics := detail.get_spell_metrics_text()
	assert_eq((detail.get_node("%DescriptionLabel") as Label).text, upgrade.description)
	assert_true(detail.get_section_labels().has("SORT CONCERNÉ"))
	assert_eq(detail.get("_spell_context"), spear, "The metrics remain tied to the inspected spell")
	assert_true(metrics.contains("VALEURS DE BASE"))
	assert_true(metrics.contains("%d dégâts physiques" % spear.damage))
	# Coup brutal describes +5; the base remains 8 until the upgrade is chosen.
	assert_true(upgrade.description.contains("+5 dégâts"))
	assert_eq(spear.damage, 8)
	assert_false(metrics.contains("13 dégâts"))
	assert_true(progress.get_selected_upgrade_ids().is_empty())
	assert_true(detail.get_action_button().disabled)


func _spell(spell_id: StringName) -> Spell:
	for value in state.unit.spells:
		var spell := value as Spell
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null


func _champion_detail_text() -> String:
	var codex := screen.get_champion_codex() as ChampionCodex
	return _label_text(codex.get("_detail") as VBoxContainer)


func _label_text(node: Node) -> String:
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	for child in node.get_children():
		parts.append(_label_text(child))
	return "\n".join(parts)


func _open_hero(content: RunContentProfile, hero_id: StringName) -> void:
	var fixture := RunData.new()
	fixture.content_profile = content
	var resolution := RunHeroResolver.resolve_runtime_hero_data(fixture, false)
	assert_true(resolution.is_valid(), str(resolution.errors))
	var hero_data: UnitData = null
	for candidate in resolution.heroes:
		if candidate.get_effective_unit_id() == hero_id:
			hero_data = candidate
	assert_not_null(hero_data)
	state = CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(hero_data), hero_data))
	assert_true(screen.open_for_state(state))
	await wait_process_frames(3)


func test_scourge_preview_shows_each_target_damage_from_the_combat_profile() -> void:
	await _open_hero(CHAMPION_CONTENT, &"achilles")
	state.unit.attack_power.base_value = 200.0
	var snapshot := state.get_progression_snapshot()
	var codex := screen.get_champion_codex() as ChampionCodex
	codex.inspect_node(&"achilles_wrath_scourge_of_troy")
	var detail := _champion_detail_text()
	assert_true(detail.contains("110 dégâts · PO 1  →  132 / 77 dégâts · PO 1 · 2 cibles"), detail)
	assert_eq(state.get_progression_snapshot(), snapshot)
	assert_true(state.get_selected_mastery_nodes().is_empty())


func test_purchased_pelion_reach_uses_one_consistent_range_in_detail_strip_and_tooltip() -> void:
	await _open_hero(CHAMPION_CONTENT, &"achilles")
	state.begin_encounter()
	assert_true(state.award_encounter_xp(&"codex_reach_victory", 220, true).granted)
	assert_true(state.purchase_mastery_node(&"achilles_chiron_centaur_eye").purchased)
	assert_true(state.purchase_mastery_node(&"achilles_chiron_pelion_reach").purchased)
	var codex := screen.get_champion_codex() as ChampionCodex
	var shot := _spell(&"achilles_pelion_shot")
	codex._inspect_spell(shot)
	var detail := _champion_detail_text()
	assert_true(detail.contains("3 PA · PO 3–8 · Une fois par activation"), detail)
	assert_false(detail.contains("PO 2–6"), detail)
	var strip := codex.get("_spells") as HBoxContainer
	var button := strip.get_child(2) as Button
	assert_true(_label_text(button).contains("3 PA · PO 3–8"))
	assert_true(button.tooltip_text.contains("PO 3–8"))
	assert_false(button.tooltip_text.contains("2–6"))
	assert_eq([shot.minimum_range, shot.spell_range], [2, 6], "The authored spell stays unchanged")


func test_attribute_panel_shows_each_scourge_target_current_and_next_damage() -> void:
	await _open_hero(CHAMPION_CONTENT, &"achilles")
	state.unit.attack_power.base_value = 200.0
	state.champion_progression.selected_node_ids.append(&"achilles_wrath_scourge_of_troy")
	var snapshot := state.get_progression_snapshot()
	var codex := screen.get_champion_codex() as ChampionCodex
	codex.select_section(&"attributes")
	var content := _label_text(codex.get("_content") as VBoxContainer)
	assert_true(content.contains("Frappe du Péléide : 132 / 77 → 139 / 81 dégâts"), content)
	assert_eq(state.get_progression_snapshot(), snapshot)
