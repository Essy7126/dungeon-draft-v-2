extends GutTest

const TEMP_ROOT := "user://skill_tree_studio_hardening"
var _files: PackedStringArray = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func after_each() -> void:
	for path in _files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_files.clear()


func _node(id: StringName, rank: int, discipline_id := &"fixture") -> SkillTreeNodeData:
	var node := SkillTreeNodeData.new()
	node.upgrade_id = id
	node.display_name = str(id)
	node.description = "Fixture"
	node.rank = rank
	node.discipline_id = discipline_id
	node.target_spell_id = &"fixture_spell"
	return node


func _discipline(rank_count := 4, choices_per_rank := 2) -> DisciplineData:
	var discipline := DisciplineData.new()
	discipline.discipline_id = &"fixture"
	discipline.display_name = "Fixture"
	var ranks: Array[DisciplineRankData] = []
	for rank_number in range(1, rank_count + 1):
		var rank_data := DisciplineRankData.new()
		rank_data.rank = rank_number
		rank_data.required_total_xp = (rank_number - 1) * 5
		var choices: Array[SkillUpgradeData] = []
		if rank_number > 1:
			for choice_index in range(choices_per_rank):
				choices.append(_node(
					StringName("node_%d_%d" % [rank_number, choice_index]),
					rank_number
				))
		rank_data.choices = choices
		ranks.append(rank_data)
	discipline.ranks = ranks
	return discipline


func _unit(rank_count := 4, choices_per_rank := 2) -> UnitData:
	var unit := UnitData.new()
	unit.unit_id = &"fixture_hero"
	unit.unit_name = "Fixture Hero"
	var discipline := _discipline(rank_count, choices_per_rank)
	var disciplines: Array[DisciplineData] = [discipline]
	unit.disciplines = disciplines
	var spell := Spell.new()
	spell.spell_id = &"fixture_spell"
	spell.discipline_id = discipline.discipline_id
	spell.spell_name = "Fixture Spell"
	spell.damage = 10
	var spells: Array[Spell] = [spell]
	unit.spells = spells
	return unit


func _save_fixture(unit: UnitData, stem: String) -> UnitData:
	var path := TEMP_ROOT.path_join("%s_%d.tres" % [stem, Time.get_ticks_usec()])
	_files.append(path)
	assert_eq(ResourceSaver.save(unit, path), OK)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as UnitData


func _handle_known_production_uid_warning() -> void:
	for tracked_error in get_errors():
		if tracked_error.contains_text("frappe_lourde.tres") and tracked_error.contains_text("invalid UID"):
			tracked_error.handled = true


func test_skill_studio_uses_local_document_undo_history() -> void:
	var session := SkillTreeEditSession.new()
	var foreign := UndoRedo.new()
	session.setup(foreign)
	assert_true(session.open(_unit()))
	assert_true(session.change_property(session.working_unit, &"max_hp", 123, "HP"))
	assert_true(session.history_can_undo())
	assert_false(foreign.has_undo())


func test_document_switch_clears_undo_and_redo() -> void:
	var session := SkillTreeEditSession.new()
	assert_true(session.open(_unit()))
	assert_true(session.change_property(session.working_unit, &"max_hp", 123, "HP"))
	assert_true(session.history_undo())
	assert_true(session.history_can_redo())
	assert_true(session.open(_unit()))
	assert_false(session.history_can_undo())
	assert_false(session.history_can_redo())


func test_undo_after_save_marks_document_dirty() -> void:
	var session := SkillTreeEditSession.new()
	assert_true(session.open(_unit()))
	assert_true(session.change_property(session.working_unit, &"max_hp", 123, "HP"))
	session.mark_saved()
	assert_false(session.is_dirty())
	assert_true(session.history_undo())
	assert_true(session.is_dirty())


func test_redo_back_to_saved_state_can_clear_dirty() -> void:
	var session := SkillTreeEditSession.new()
	assert_true(session.open(_unit()))
	assert_true(session.change_property(session.working_unit, &"max_hp", 123, "HP"))
	session.mark_saved()
	assert_true(session.history_undo())
	assert_true(session.history_redo())
	assert_false(session.is_dirty())


func test_forced_close_writes_recoverable_draft() -> void:
	var source := _save_fixture(_unit(), "draft_source")
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.change_property(session.working_unit, &"max_hp", 124, "HP"))
	var report := SkillTreeDraftService.write_draft(session)
	assert_true(report.get("ok", false))
	assert_true(FileAccess.file_exists(str(report.get("content_path", ""))))
	assert_false(SkillTreeDraftService.latest_for_source(source.resource_path).is_empty())
	assert_true(SkillTreeDraftService.clear_for_source(source.resource_path))


func test_draft_restore_never_modifies_source_before_save() -> void:
	var source := _save_fixture(_unit(), "draft_restore")
	var original_hp := source.max_hp
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.change_property(session.working_unit, &"max_hp", original_hp + 11, "HP"))
	var written := SkillTreeDraftService.write_draft(session)
	assert_true(written.get("ok", false))
	var restored_session := SkillTreeEditSession.new()
	var restored := SkillTreeDraftService.restore(restored_session, written.get("metadata", {}))
	assert_true(restored.get("ok", false))
	assert_eq(restored_session.working_unit.max_hp, original_hp + 11)
	assert_eq((ResourceLoader.load(source.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as UnitData).max_hp, original_hp)
	assert_true(SkillTreeDraftService.clear_for_source(source.resource_path))


func test_new_resource_path_collision_never_overwrites() -> void:
	var path := TEMP_ROOT.path_join("collision_%d.tres" % Time.get_ticks_usec())
	_files.append(path)
	assert_eq(ResourceSaver.save(Resource.new(), path), OK)
	var reservations := SkillTreePathReservationService.new(PackedStringArray([TEMP_ROOT + "/"]))
	assert_eq(int(reservations.inspect(path).status), SkillTreePathReservationService.Status.EXISTS_ON_DISK)
	assert_ne(reservations.generate_unique_path(path), path)


func test_cache_only_path_collision_is_detected() -> void:
	var path := TEMP_ROOT.path_join("cache_only_%d.tres" % Time.get_ticks_usec())
	var cached := Resource.new()
	cached.take_over_path(path)
	var reservations := SkillTreePathReservationService.new(PackedStringArray([TEMP_ROOT + "/"]))
	assert_eq(int(reservations.inspect(path).status), SkillTreePathReservationService.Status.EXISTS_IN_RESOURCE_CACHE_ONLY)


func test_generate_unique_path_avoids_disk_cache_and_session_reservations() -> void:
	var path := TEMP_ROOT.path_join("reserved_%d.tres" % Time.get_ticks_usec())
	var reservations := SkillTreePathReservationService.new(PackedStringArray([TEMP_ROOT + "/"]))
	assert_eq(int(reservations.reserve(path).status), SkillTreePathReservationService.Status.FREE)
	var disk_candidate := reservations.generate_unique_path(path)
	assert_ne(disk_candidate, path)
	_files.append(disk_candidate)
	assert_eq(ResourceSaver.save(Resource.new(), disk_candidate), OK)
	var next := reservations.generate_unique_path(path)
	assert_ne(next, path)
	assert_ne(next, disk_candidate)


func test_external_conflict_uses_deep_uncached_reload() -> void:
	var source := _save_fixture(_unit(), "external_conflict")
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.change_property(session.working_unit, &"max_hp", 111, "HP"))
	var external := ResourceLoader.load(source.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as UnitData
	external.max_hp = 222
	assert_eq(ResourceSaver.save(external, source.resource_path), OK)
	var plan := SkillTreeSaveTransactionService.build_plan(session, {
		"allowed_roots": PackedStringArray([TEMP_ROOT + "/"]),
	})
	assert_true(plan.has_blocking_conflicts())
	assert_true(plan.conflicts.any(func(conflict):
		return bool(conflict.details.get("deep_uncached_reload", false))
	))


func test_removed_external_resource_is_excluded_from_save_plan() -> void:
	var unit := _unit()
	var discipline_path := TEMP_ROOT.path_join("external_discipline_%d.tres" % Time.get_ticks_usec())
	_files.append(discipline_path)
	assert_eq(ResourceSaver.save(unit.disciplines[0], discipline_path), OK)
	var external_discipline := ResourceLoader.load(
		discipline_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as DisciplineData
	var external_disciplines: Array[DisciplineData] = [external_discipline]
	unit.disciplines = external_disciplines
	var source := _save_fixture(unit, "removed_external")
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.detach_current_discipline())
	var plan := SkillTreeSaveTransactionService.build_plan(session, {
		"allowed_roots": PackedStringArray([TEMP_ROOT + "/"]),
	})
	var external_entries := plan.entries.filter(func(entry):
		return entry.target_path == discipline_path and entry.operation == SkillTreeSavePlanEntry.Operation.ORPHANED
	)
	assert_eq(external_entries.size(), 1, str(plan.entries.map(func(entry): return [entry.target_path, entry.operation])))
	if not external_entries.is_empty():
		assert_false(external_entries[0].is_writable())
	assert_true(plan.entries.any(func(entry):
		return entry.target_path == discipline_path and entry.operation == SkillTreeSavePlanEntry.Operation.DETACH_REFERENCE
	))


func test_reload_failure_rolls_back_and_keeps_document_dirty() -> void:
	var source := _save_fixture(_unit(), "rollback_reload")
	var original_bytes := FileAccess.get_file_as_bytes(source.resource_path)
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.change_property(session.working_unit, &"max_hp", 333, "HP"))
	var report := SkillTreeSaveTransactionService.save(session, null, {
		"allowed_roots": PackedStringArray([TEMP_ROOT + "/"]),
		"fail_step": &"final_reload",
	})
	_handle_known_production_uid_warning()
	assert_false(report.get("ok", true))
	assert_eq(str(report.get("step", "")), "FINAL_RELOAD")
	assert_true(report.get("rolled_back", false))
	assert_eq(FileAccess.get_file_as_bytes(source.resource_path), original_bytes)
	assert_true(session.is_dirty())


func test_manifest_failure_aborts_before_production_write() -> void:
	var source := _save_fixture(_unit(), "manifest_failure")
	var original_bytes := FileAccess.get_file_as_bytes(source.resource_path)
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.change_property(session.working_unit, &"max_hp", 444, "HP"))
	var report := SkillTreeSaveTransactionService.save(session, null, {
		"allowed_roots": PackedStringArray([TEMP_ROOT + "/"]),
		"fail_step": &"manifest",
	})
	_handle_known_production_uid_warning()
	assert_false(report.get("ok", true))
	assert_eq(str(report.get("step", "")), "MANIFEST_PLANNED")
	assert_eq(FileAccess.get_file_as_bytes(source.resource_path), original_bytes)


func test_save_transaction_fixture_completes_and_reloads() -> void:
	var source := _save_fixture(_unit(), "save_success")
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.change_property(session.working_unit, &"max_hp", 666, "HP"))
	var report := SkillTreeSaveTransactionService.save(session, null, {
		"allowed_roots": PackedStringArray([TEMP_ROOT + "/"]),
	})
	_handle_known_production_uid_warning()
	assert_true(report.get("ok", false), str(report))
	assert_eq(str(report.get("step", "")), "COMPLETED")
	assert_eq((ResourceLoader.load(source.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as UnitData).max_hp, 666)
	assert_false(session.is_dirty())


func test_catalog_keeps_hero_with_zero_disciplines() -> void:
	var unit := UnitData.new()
	unit.unit_id = &"zero"
	unit.unit_name = "Zero"
	var path := TEMP_ROOT.path_join("zero_%d.tres" % Time.get_ticks_usec())
	_files.append(path)
	assert_eq(ResourceSaver.save(unit, path), OK)
	var heroes := SkillTreeCatalogService.discover_heroes(TEMP_ROOT, [&"zero"])
	assert_eq(heroes.size(), 1)
	assert_eq(int(heroes[0].discipline_count), 0)


func test_detach_archive_delete_are_distinct_operations() -> void:
	var session := SkillTreeEditSession.new()
	assert_true(session.open(_unit()))
	assert_eq(str(SkillTreeLifecycleService.detach_current(session).operation), "DETACH_REFERENCE")
	var archive_resource := DisciplineData.new()
	archive_resource.discipline_id = &"archive_me"
	var archive_path := TEMP_ROOT.path_join("archive_%d.tres" % Time.get_ticks_usec())
	assert_eq(ResourceSaver.save(archive_resource, archive_path), OK)
	archive_resource = ResourceLoader.load(
		archive_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as DisciplineData
	var archive_index := SkillTreeReferenceIndex.new().build(_unit(), [archive_resource])
	var archived := SkillTreeLifecycleService.archive_resource(archive_resource, archive_index, {
		"allowed_roots": PackedStringArray([TEMP_ROOT + "/"]),
	})
	assert_true(archived.get("ok", false), str(archived))
	assert_eq(str(archived.operation), "ARCHIVE")
	var delete_resource := DisciplineData.new()
	delete_resource.discipline_id = &"delete_me"
	var delete_path := TEMP_ROOT.path_join("delete_%d.tres" % Time.get_ticks_usec())
	assert_eq(ResourceSaver.save(delete_resource, delete_path), OK)
	delete_resource = ResourceLoader.load(
		delete_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as DisciplineData
	var delete_index := SkillTreeReferenceIndex.new().build(_unit(), [delete_resource])
	var deleted := SkillTreeLifecycleService.delete_permanently(delete_resource, delete_index, "delete_me", {
		"allowed_roots": PackedStringArray([TEMP_ROOT + "/"]),
	})
	assert_true(deleted.get("ok", false), str(deleted))
	assert_eq(str(deleted.operation), "DELETE")


func test_orphan_index_reports_unreferenced_resources() -> void:
	var orphan := SpellModSkillTreeEffect.new()
	orphan.set_path_cache(TEMP_ROOT.path_join("orphan.tres"))
	var index := SkillTreeReferenceIndex.new().build(_unit(), [orphan])
	assert_eq(index.orphaned_resources().size(), 1)
	assert_eq(index.orphaned_resources()[0].resource, orphan)


func test_delete_refuses_resource_with_incoming_references() -> void:
	var unit := _unit()
	var discipline := unit.disciplines[0]
	var index := SkillTreeReferenceIndex.new().build(unit)
	assert_false(index.can_delete(discipline).allowed)
	assert_gt(int(index.can_delete(discipline).count), 0)


func test_multi_node_delete_reconnects_descendants_transitively() -> void:
	var unit := _unit(4, 1)
	var a := unit.disciplines[0].ranks[1].choices[0] as SkillTreeNodeData
	var b := unit.disciplines[0].ranks[2].choices[0] as SkillTreeNodeData
	var c := unit.disciplines[0].ranks[3].choices[0] as SkillTreeNodeData
	b.prerequisite_node_ids = [a.upgrade_id]
	c.prerequisite_node_ids = [b.upgrade_id]
	var session := SkillTreeEditSession.new()
	assert_true(session.open(unit))
	var wa := session.find_node(a.upgrade_id)
	var wb := session.find_node(b.upgrade_id)
	var wc := session.find_node(c.upgrade_id) as SkillTreeNodeData
	assert_true(session.remove_nodes([wa, wb]))
	assert_true(wc.prerequisite_node_ids.is_empty())
	assert_eq((session.last_operation_report.get("removed_node_ids", []) as Array).size(), 2)


func test_every_production_storage_property_has_editor_contract() -> void:
	var audit := SkillTreePropertyRegistry.audit(_unit())
	assert_true((audit.get("unsupported", []) as Array).is_empty(), str(audit.get("unsupported", [])))
	assert_gt(int(audit.get("property_count", 0)), 0)


func test_spell_permanent_modifiers_are_editable() -> void:
	var contract := SkillTreePropertyRegistry.contract_for(Spell.new(), &"modifiers")
	assert_eq(int(contract.classification), SkillTreePropertyRegistry.Classification.EDITABLE)
	assert_eq(str(contract.editor), "ordered_resource_list")


func test_complex_dictionary_editor_round_trip() -> void:
	var session := SkillTreeEditSession.new()
	assert_true(session.open(_unit()))
	var spell := session.current_spell()
	assert_true(session.change_property(spell, &"summon_initial_cooldowns", {&"summon_hit": 3}, "Dictionary"))
	assert_eq(int(spell.summon_initial_cooldowns.get(&"summon_hit", -1)), 3)
	assert_true(session.history_undo())
	assert_true(spell.summon_initial_cooldowns.is_empty())


func test_shared_modifier_identity_is_preserved() -> void:
	var unit := _unit(2, 2)
	var shared := SpellModSkillTreeEffect.new()
	var shared_array: Array[SpellModifier] = [shared]
	unit.disciplines[0].ranks[1].choices[0].spell_modifiers = shared_array
	unit.disciplines[0].ranks[1].choices[1].spell_modifiers = shared_array
	var session := SkillTreeEditSession.new()
	assert_true(session.open(unit))
	var nodes := session.all_nodes()
	assert_eq(nodes[0].spell_modifiers[0], nodes[1].spell_modifiers[0])


func test_make_unique_breaks_only_requested_share() -> void:
	var unit := _unit(2, 2)
	var shared := SpellModSkillTreeEffect.new()
	var shared_array: Array[SpellModifier] = [shared]
	unit.disciplines[0].ranks[1].choices[0].spell_modifiers = shared_array
	unit.disciplines[0].ranks[1].choices[1].spell_modifiers = shared_array
	var session := SkillTreeEditSession.new()
	assert_true(session.open(unit))
	var nodes := session.all_nodes()
	var original_work := nodes[0].spell_modifiers[0]
	var unique := session.make_modifier_unique(nodes[0], original_work)
	assert_not_null(unique)
	assert_ne(nodes[0].spell_modifiers[0], nodes[1].spell_modifiers[0])
	assert_eq(nodes[1].spell_modifiers[0], original_work)


func test_path_enumeration_reports_truncation() -> void:
	var result := SkillTreePathService.enumeration_result(_discipline(6, 3), 10)
	assert_true(result.truncated)
	assert_false(result.complete)
	assert_eq(int(result.count), 10)
	assert_eq(str(result.stop_reason), "LIMIT_REACHED")


func test_truncated_enumeration_is_never_reported_as_exact() -> void:
	var result := SkillTreePathService.enumeration_result(_discipline(6, 3), 5, false)
	assert_true(result.truncated)
	assert_eq(int(result.limit), 5)
	assert_true((result.configurations as Array).is_empty())


func test_reachability_does_not_depend_on_full_leaf_enumeration() -> void:
	var discipline := _discipline(8, 5)
	var enumeration := SkillTreePathService.enumeration_result(discipline, 2, false)
	var reachability := SkillTreePathService.reachability_analysis(discipline)
	assert_true(enumeration.truncated)
	assert_true(reachability.complete)
	assert_eq((reachability.reachable_node_ids as Array).size(), 35)


func test_strict_dominance_fixture_is_detected() -> void:
	var discipline := _discipline(2, 2)
	var weaker := discipline.ranks[1].choices[0]
	var stronger := discipline.ranks[1].choices[1]
	var conditional := SpellModSkillTreeEffect.new()
	conditional.amount = 10
	conditional.require_backstab = true
	var unconditional := SpellModSkillTreeEffect.new()
	unconditional.amount = 10
	weaker.spell_modifiers = [conditional]
	stronger.spell_modifiers = [unconditional]
	var result := SkillTreeDesignAnalysisService.analyze_dominance(discipline)
	assert_true(result.any(func(item):
		return item.dominated_node_id == weaker.upgrade_id and item.dominant_node_id == stronger.upgrade_id
	))


func test_incomparable_nodes_are_not_reported_as_dominated() -> void:
	var discipline := _discipline(2, 2)
	var first := SpellModSkillTreeEffect.new()
	first.effect_type = SpellModSkillTreeEffect.EffectType.DAMAGE_ALL
	first.amount = 10
	var second := SpellModSkillTreeEffect.new()
	second.effect_type = SpellModSkillTreeEffect.EffectType.RANGE
	second.amount = 10
	discipline.ranks[1].choices[0].spell_modifiers = [first]
	discipline.ranks[1].choices[1].spell_modifiers = [second]
	assert_true(SkillTreeDesignAnalysisService.analyze_dominance(discipline).is_empty())


func test_capstone_numeric_only_is_warning_not_error() -> void:
	var discipline := _discipline(2, 1)
	var effect := SpellModSkillTreeEffect.new()
	effect.effect_type = SpellModSkillTreeEffect.EffectType.DAMAGE_ALL
	effect.amount = 5
	discipline.ranks[1].choices[0].spell_modifiers = [effect]
	var result := SkillTreeDesignAnalysisService.analyze_capstones(discipline)
	assert_eq(result.size(), 1)
	assert_eq(str(result[0].severity), "WARNING")
	assert_false(result[0].blocking)


func test_every_current_effect_type_has_label_fields_summary_and_preview() -> void:
	var spell := _unit().spells[0]
	for effect_type in SpellModSkillTreeEffect.EffectType.values():
		var effect := SpellModSkillTreeEffect.new()
		effect.effect_type = effect_type
		assert_false(SkillTreeEffectSummaryService.effect_type_label(effect_type).is_empty())
		assert_false(SkillTreeEffectSummaryService.summarize_modifier(effect).is_empty())
		assert_false(SkillTreeRuntimePreviewService.modifier_capability(effect, spell).unsupported)


func test_preview_base_vs_path_trace_is_deterministic() -> void:
	var spell := _unit().spells[0]
	var effect := SpellModSkillTreeEffect.new()
	effect.modifier_name = "Bonus"
	effect.target_spell_id = spell.spell_id
	effect.effect_type = SpellModSkillTreeEffect.EffectType.DAMAGE_ALL
	effect.amount = 5
	var modifiers: Array[SpellModifier] = [effect]
	var scenarios := [{"id": "enemy_defense_0", "target_team": 1, "defense": 0}]
	var first := SkillTreeRuntimePreviewService.preview(spell, modifiers, scenarios)
	var second := SkillTreeRuntimePreviewService.preview(spell, modifiers, scenarios)
	assert_true(first.ok)
	assert_true(first.deterministic)
	assert_eq(first.trace[0].summary, second.trace[0].summary)
	assert_eq(first.scenarios[0].delta, second.scenarios[0].delta)


func test_preview_sandbox_never_changes_run_progression() -> void:
	var spell := _unit().spells[0]
	var report := SkillTreeRuntimePreviewService.preview(spell, [], [{"id": "free", "free_cell": true}])
	assert_true(report.ok)
	assert_false(report.writes_run_progression)
	assert_eq(str(report.runtime_authority), "SpellCaster")


func test_graph_copy_preserves_internal_relations_only() -> void:
	var unit := _unit(3, 2)
	var first := unit.disciplines[0].ranks[1].choices[0] as SkillTreeNodeData
	var second := unit.disciplines[0].ranks[2].choices[0] as SkillTreeNodeData
	var external := unit.disciplines[0].ranks[1].choices[1] as SkillTreeNodeData
	second.prerequisite_node_ids = [first.upgrade_id, external.upgrade_id]
	first.excluded_node_ids = [second.upgrade_id, external.upgrade_id]
	var session := SkillTreeEditSession.new()
	assert_true(session.open(unit))
	var copies := session.duplicate_nodes([
		session.find_node(first.upgrade_id), session.find_node(second.upgrade_id),
	])
	assert_eq(copies.size(), 2)
	var copy_first := copies[0] as SkillTreeNodeData
	var copy_second := copies[1] as SkillTreeNodeData
	assert_eq(copy_second.prerequisite_node_ids, [copy_first.upgrade_id])
	assert_eq(copy_first.excluded_node_ids, [copy_second.upgrade_id])


func test_save_commits_current_focused_field() -> void:
	var session := SkillTreeEditSession.new()
	assert_true(session.open(_unit()))
	var panel := SkillTreeInspectorPanel.new()
	panel.property_change_requested.connect(func(target, property_name, value, action_name):
		session.change_property(target, property_name, value, action_name)
	)
	add_child_autofree(panel)
	await get_tree().process_frame
	panel.set_context(
		session.working_unit, session.current_discipline(), session.current_spell(),
		session.working_unit, [], true
	)
	await get_tree().process_frame
	var name_edit: LineEdit = null
	for child in panel.find_children("*", "LineEdit", true, false):
		var edit := child as LineEdit
		if edit != null and edit.text == "Fixture Hero":
			name_edit = edit
			break
	assert_not_null(name_edit)
	name_edit.grab_focus()
	name_edit.text = "Visible Pending Value"
	panel.commit_pending_edits()
	await get_tree().process_frame
	assert_eq(session.working_unit.unit_name, "Visible Pending Value")


func test_injected_failure_restores_every_written_file() -> void:
	var unit := _unit()
	var spell_path := TEMP_ROOT.path_join("external_spell_%d.tres" % Time.get_ticks_usec())
	_files.append(spell_path)
	assert_eq(ResourceSaver.save(unit.spells[0], spell_path), OK)
	var external_spell := ResourceLoader.load(
		spell_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as Spell
	var spells: Array[Spell] = [external_spell]
	unit.spells = spells
	var source := _save_fixture(unit, "rollback_every_file")
	var source_bytes := FileAccess.get_file_as_bytes(source.resource_path)
	var spell_bytes := FileAccess.get_file_as_bytes(spell_path)
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.change_property(session.working_unit, &"max_hp", 555, "HP"))
	assert_true(session.change_property(session.current_spell(), &"damage", 77, "Damage"))
	var report := SkillTreeSaveTransactionService.save(session, null, {
		"allowed_roots": PackedStringArray([TEMP_ROOT + "/"]),
		"fail_step": &"apply_1",
	})
	_handle_known_production_uid_warning()
	assert_false(report.get("ok", true))
	assert_true(report.get("rolled_back", false), str(report))
	assert_eq(FileAccess.get_file_as_bytes(source.resource_path), source_bytes)
	assert_eq(FileAccess.get_file_as_bytes(spell_path), spell_bytes)
	assert_true(session.is_dirty())


func test_preview_matches_runtime_for_current_production_modifier_types() -> void:
	var hero := ResourceLoader.load(
		"res://data/units/alliés/elfe.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	assert_not_null(hero)
	var checked := 0
	for discipline in hero.disciplines:
		for rank_data in discipline.ranks:
			for node in rank_data.choices:
				for modifier in node.spell_modifiers:
					var capability := SkillTreeRuntimePreviewService.modifier_capability(
						modifier, SkillTreeCatalogService.spell_for_discipline(hero, discipline.discipline_id)
					)
					assert_false(capability.unsupported, modifier.modifier_name)
					assert_true(capability.sandbox, modifier.modifier_name)
					checked += 1
	assert_gt(checked, 0)


func test_graph_escape_cancels_active_gesture() -> void:
	var graph := SkillTreeStudioGraphEdit.new()
	add_child_autofree(graph)
	await get_tree().process_frame
	assert_true(graph.cancel_active_gesture())
	assert_true(graph.last_gesture_cancelled)


func test_global_search_opens_correct_document_and_node() -> void:
	var unit := _unit()
	var target := unit.disciplines[0].ranks[1].choices[0]
	target.display_name = "Needle Search Target"
	var heroes: Array[Dictionary] = [{
		"resource": unit,
		"path": "res://fixtures/search_hero.tres",
	}]
	var results := SkillTreeGlobalSearchService.search(heroes, "needle search")
	assert_eq(results.size(), 1)
	assert_eq(str(results[0].character_path), "res://fixtures/search_hero.tres")
	assert_eq(StringName(results[0].discipline_id), unit.disciplines[0].discipline_id)
	assert_eq(StringName(results[0].node_id), target.upgrade_id)


func test_keyboard_focus_path_reaches_all_primary_actions() -> void:
	var studio := SkillTreeStudioMain.new()
	studio.setup(null, null)
	add_child_autofree(studio)
	for _frame in range(12):
		await get_tree().process_frame
	_handle_known_production_uid_warning()
	var required := ["Annuler", "Rétablir", "Rechercher", "Valider", "Tester", "Prévisualiser", "Analyse complète", "Sauvegarder"]
	for label in required:
		var matched := false
		for child in studio.find_children("*", "Button", true, false):
			var button := child as Button
			if button != null and button.text == label:
				matched = button.focus_mode != Control.FOCUS_NONE
				break
		assert_true(matched, "Action clavier inaccessible : %s" % label)
