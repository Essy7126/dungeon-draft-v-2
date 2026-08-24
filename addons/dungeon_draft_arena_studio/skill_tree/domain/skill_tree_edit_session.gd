@tool
class_name SkillTreeEditSession
extends RefCounted

signal document_changed
signal selection_changed(subject)
signal history_changed

const HISTORY_LIMIT := 256
const PROGRESSION_UNIT_PROPERTIES: Array[StringName] = [
	&"active_spell_slots", &"spells",
]
## Modeles de depart proposes par la popup de creation d'un sort. Ils vivent au
## niveau du Studio uniquement : aucune sous-classe de Spell, aucun champ ajoute
## a data/spell.gd, et aucun verrouillage une fois la fiche ouverte.
const SPELL_TEMPLATE_SIMPLE_ATTACK: StringName = &"simple_attack"
const SPELL_TEMPLATE_HEAL: StringName = &"heal"
const SPELL_TEMPLATE_PUSH_AREA: StringName = &"push_area"
const SPELL_TEMPLATE_STATUS: StringName = &"status"
const SPELL_TEMPLATE_SUMMON: StringName = &"summon"

## Historique strictement local au document. Le Studio ne doit jamais publier
## ses actions dans l'historique global de l'editeur Godot.
var document_history := UndoRedo.new()
var source_unit: UnitData = null
var working_unit: UnitData = null
var source_run: RunData = null
var source_hero_profile: RunHeroProfile = null
var source_progression_profile: CharacterProgressionProfile = null
var working_progression_profile: CharacterProgressionProfile = null
## Autorite du personnage pour les donnees hors progression (notamment les
## animations). Dans une session de run, working_unit reste un adaptateur non
## sauvegardable tandis que cette paire porte la vraie mise a jour UnitData.
var source_character_unit: UnitData = null
var working_character_unit: UnitData = null
var unit_view_is_adapter := false
var source_to_work := {}
var work_to_source := {}
var new_resource_paths := {}
## Sorts crees comme partages : ils n'appartiennent a aucune liste du
## personnage ouvert. Sans cette trace, le document paraitrait propre et le plan
## de sauvegarde les declarerait « non rattaches », donc ne les ecrirait jamais.
var standalone_spells: Array[Spell] = []
var path_reservations := SkillTreePathReservationService.new()
var selected_discipline_id: StringName = &""
var selected_subject: Resource = null
var saved_fingerprint := ""
var last_operation_report := {}


func setup(_undo_manager = null) -> void:
	# Signature conservee pour les hotes existants. Le manager fourni par
	# EditorPlugin est volontairement ignore : l'historique appartient a cette
	# session et a ce document uniquement.
	_reset_history()


func open(source: UnitData) -> bool:
	if source == null:
		return false
	release_document(false)
	var copied := SkillTreeCopyService.copy_unit(source)
	if copied.is_empty():
		return false
	source_unit = source
	working_unit = copied.get("work") as UnitData
	source_to_work = copied.get("source_to_work", {})
	work_to_source = copied.get("work_to_source", {})
	new_resource_paths.clear()
	standalone_spells.clear()
	path_reservations.clear()
	selected_discipline_id = (
		working_unit.disciplines[0].discipline_id
		if not working_unit.disciplines.is_empty() \
			and working_unit.disciplines[0] != null else &""
	)
	selected_subject = current_discipline()
	_reset_history()
	saved_fingerprint = current_fingerprint()
	last_operation_report.clear()
	document_changed.emit()
	selection_changed.emit(selected_subject)
	history_changed.emit()
	return true


func open_progression(run_data: RunData, hero_profile: RunHeroProfile) -> bool:
	if run_data == null or hero_profile == null \
			or hero_profile.base_unit_data == null \
			or hero_profile.progression_profile == null:
		return false
	var canonical_character := _load_canonical_unit(hero_profile.base_unit_data)
	var canonical_profile := _load_canonical_progression_profile(
		hero_profile.progression_profile
	)
	if canonical_character == null or canonical_profile == null:
		return false
	var unit_view := RunContentCatalogService.as_editable_unit_view(
		canonical_character, canonical_profile
	)
	if unit_view == null or not open(unit_view):
		return false
	source_run = run_data
	source_hero_profile = hero_profile
	# Le contexte partagé peut encore référencer une ancienne copie de travail
	# laissée dans le cache par une session antérieure. La remplacer localement
	# par la relecture canonique empêche cette contamination de se propager aux
	# autres outils sans écrire la RunData.
	hero_profile.base_unit_data = canonical_character
	hero_profile.progression_profile = canonical_profile
	source_progression_profile = canonical_profile
	working_progression_profile = _copy_progression_profile_shell(
		source_progression_profile
	)
	working_progression_profile.set_path_cache(source_progression_profile.resource_path)
	_sync_profile_from_unit()
	source_to_work[source_progression_profile] = working_progression_profile
	work_to_source[working_progression_profile] = source_progression_profile
	if not _configure_character_authority(canonical_character):
		release_document(false)
		return false
	unit_view_is_adapter = true
	saved_fingerprint = current_fingerprint()
	last_operation_report = {
		"operation": "OPEN_RUN_PROGRESSION",
		"run_path": run_data.resource_path,
		"character_id": hero_profile.character_id,
		"profile_path": source_progression_profile.resource_path,
	}
	document_changed.emit()
	history_changed.emit()
	return true


func release_document(emit_change := true) -> void:
	# clear_history libere les objets conserves par les Callables et les valeurs
	# d'UndoRedo avant d'abandonner la copie de travail.
	if document_history != null:
		document_history.clear_history(false)
	source_to_work.clear()
	work_to_source.clear()
	new_resource_paths.clear()
	standalone_spells.clear()
	path_reservations.clear()
	source_unit = null
	working_unit = null
	source_run = null
	source_hero_profile = null
	source_progression_profile = null
	working_progression_profile = null
	source_character_unit = null
	working_character_unit = null
	unit_view_is_adapter = false
	selected_discipline_id = &""
	selected_subject = null
	saved_fingerprint = ""
	last_operation_report.clear()
	_reset_history()
	if emit_change:
		document_changed.emit()
		selection_changed.emit(null)
		history_changed.emit()


func reopen_from_disk() -> bool:
	if unit_view_is_adapter and source_run != null and source_hero_profile != null \
			and source_progression_profile != null:
		var run_path := source_run.resource_path
		var character_id := source_hero_profile.character_id
		var reloaded_run := ResourceLoader.load(
			run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as RunData
		if reloaded_run == null:
			return false
		for hero in RunContentCatalogService.heroes_for_run(reloaded_run):
			if hero != null and hero.character_id == character_id:
				return open_progression(reloaded_run, hero)
		return false
	if source_unit == null or source_unit.resource_path.is_empty():
		return false
	var reloaded := ResourceLoader.load(
		source_unit.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	return open(reloaded)


func restore_draft(
		source: UnitData,
		draft: UnitData,
		source_keys_by_work_key: Dictionary = {},
		new_paths_by_work_key: Dictionary = {}
	) -> bool:
	if source == null or draft == null:
		return false
	release_document(false)
	var copied := SkillTreeCopyService.copy_unit(draft)
	if copied.is_empty():
		return false
	source_unit = source
	working_unit = copied.get("work") as UnitData
	var source_by_key := SkillTreeCopyService.resources_by_key(source)
	var work_by_key := SkillTreeCopyService.resources_by_key(working_unit)
	for work_key_value in work_by_key:
		var work_key := str(work_key_value)
		var source_key := str(source_keys_by_work_key.get(work_key, work_key))
		var source_resource := source_by_key.get(source_key) as Resource
		var work_resource := work_by_key[work_key_value] as Resource
		if source_resource != null and work_resource != null:
			source_to_work[source_resource] = work_resource
			work_to_source[work_resource] = source_resource
		elif work_resource != null and new_paths_by_work_key.has(work_key):
			var path := str(new_paths_by_work_key[work_key])
			new_resource_paths[work_resource] = path
			work_resource.set_path_cache(path)
	selected_discipline_id = (
		working_unit.disciplines[0].discipline_id
		if not working_unit.disciplines.is_empty() \
			and working_unit.disciplines[0] != null else &""
	)
	selected_subject = current_discipline()
	_reset_history()
	saved_fingerprint = SkillTreeSnapshotService.fingerprint(source)
	last_operation_report = {"operation": "RESTORE_DRAFT"}
	document_changed.emit()
	selection_changed.emit(selected_subject)
	history_changed.emit()
	return true


func current_discipline() -> DisciplineData:
	if working_unit == null:
		return null
	for discipline in working_unit.disciplines:
		if discipline != null and discipline.discipline_id == selected_discipline_id:
			return discipline
	return null


func current_spell() -> Spell:
	return SkillTreeCatalogService.spell_for_discipline(
		working_unit, selected_discipline_id
	)


func select_discipline(discipline_id: StringName) -> bool:
	if working_unit == null:
		return false
	for discipline in working_unit.disciplines:
		if discipline != null and discipline.discipline_id == discipline_id:
			selected_discipline_id = discipline_id
			select_subject(discipline)
			return true
	return false


func select_subject(subject: Resource) -> void:
	selected_subject = subject
	selection_changed.emit(subject)


func is_dirty() -> bool:
	if working_unit == null:
		return false
	# Un sort cree comme partage ne change aucun champ du personnage : sans ce
	# second motif, le document se dirait propre et la sauvegarde refuserait
	# d'ecrire son nouveau fichier.
	return current_fingerprint() != saved_fingerprint \
		or not standalone_spells.is_empty()


func current_fingerprint() -> String:
	if unit_view_is_adapter and working_progression_profile != null:
		_sync_profile_from_unit()
		# Les champs communs et la fiche d'animations appartiennent au personnage,
		# pas au profil. Leur vraie copie de travail participe donc aussi à
		# l'empreinte du document éditorial.
		return _adapter_fingerprint(
			working_progression_profile,
			working_character_unit
		)
	return SkillTreeSnapshotService.fingerprint(working_unit) \
		if working_unit != null else ""


func _adapter_fingerprint(
		profile: CharacterProgressionProfile,
		character: UnitData
	) -> String:
	return "%s|%s" % [
		SkillTreeSnapshotService.storage_fingerprint(profile),
		SkillTreeSnapshotService.storage_fingerprint(character) \
			if character != null else "aucun_chassis",
	]


func canonical_source_path() -> String:
	if source_progression_profile != null:
		return source_progression_profile.resource_path
	return source_unit.resource_path if source_unit != null else ""


func canonical_source() -> Resource:
	return source_progression_profile if source_progression_profile != null else source_unit


func canonical_working() -> Resource:
	if working_progression_profile != null:
		_sync_profile_from_unit()
		return working_progression_profile
	return working_unit


func is_profile_authoritative() -> bool:
	return unit_view_is_adapter and source_progression_profile != null


func is_resource_reachable(resource: Resource) -> bool:
	if resource == null:
		return false
	# Un sort partage n'est atteignable depuis aucune liste du personnage. Il
	# n'est pourtant pas detache : il vient d'etre cree et attend son ecriture.
	# Le test de type precede volontairement le has() : sur un Array[Spell],
	# chercher une Resource d'un autre type declenche une erreur du moteur.
	if resource is Spell and standalone_spells.has(resource):
		return true
	if is_profile_authoritative():
		_sync_profile_from_unit()
		if resource == working_progression_profile:
			return true
	return SkillTreeSaveService._is_reachable(working_unit, resource) \
		or SkillTreeSaveService._is_reachable(working_character_unit, resource)


func restore_profile_draft(
		draft: UnitData,
		source_keys_by_work_key: Dictionary = {},
		new_paths_by_work_key: Dictionary = {}
	) -> bool:
	if source_run == null or source_hero_profile == null \
			or source_progression_profile == null or draft == null:
		return false
	var run_data := source_run
	var hero := source_hero_profile
	var profile := source_progression_profile
	var character := source_character_unit
	if character == null:
		character = _load_canonical_unit(hero.base_unit_data)
	if character == null:
		return false
	var source_view := RunContentCatalogService.as_editable_unit_view(
		character, profile
	)
	if not restore_draft(
			source_view, draft, source_keys_by_work_key, new_paths_by_work_key
		):
		return false
	source_run = run_data
	source_hero_profile = hero
	source_progression_profile = profile
	working_progression_profile = _copy_progression_profile_shell(profile)
	working_progression_profile.set_path_cache(profile.resource_path)
	_sync_profile_from_unit()
	source_to_work[profile] = working_progression_profile
	work_to_source[working_progression_profile] = profile
	if not _configure_character_authority(character):
		release_document(false)
		return false
	unit_view_is_adapter = true
	saved_fingerprint = _adapter_fingerprint(
		profile, working_character_unit
	)
	document_changed.emit()
	return true


func _sync_profile_from_unit() -> void:
	if working_progression_profile == null or working_unit == null:
		return
	# Une session créée avant le correctif pouvait avoir remplacé en mémoire les
	# tableaux du profil source. La vue d'ouverture conserve les vraies
	# sous-Resources canoniques et permet de réparer cet alias sans perdre la
	# copie de travail courante.
	var source_is_aliased := source_progression_profile != null and (
		source_progression_profile.spells.any(
			func(spell: Spell): return work_to_source.has(spell)
		)
	)
	if source_is_aliased and source_unit != null:
		var source_spells: Array[Spell] = []
		source_spells.assign(source_unit.spells)
		source_progression_profile.spells = source_spells
	working_progression_profile.character_id = source_progression_profile.character_id \
		if source_progression_profile != null else working_unit.get_effective_unit_id()
	working_progression_profile.active_spell_slots = working_unit.active_spell_slots
	var working_spells: Array[Spell] = []
	working_spells.assign(working_unit.spells)
	working_progression_profile.spells = working_spells


func _copy_progression_profile_shell(
		source: CharacterProgressionProfile
	) -> CharacterProgressionProfile:
	if source == null:
		return null
	var copied := source.duplicate(false) as CharacterProgressionProfile
	var copied_spells: Array[Spell] = []
	copied_spells.assign(source.spells)
	copied.spells = copied_spells
	return copied


func _load_canonical_progression_profile(
		source: CharacterProgressionProfile
	) -> CharacterProgressionProfile:
	if source == null:
		return null
	if source.resource_path.is_empty() or source.is_built_in():
		return source
	return ResourceLoader.load(
		source.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as CharacterProgressionProfile


func _load_canonical_unit(source: UnitData) -> UnitData:
	if source == null:
		return null
	if source.resource_path.is_empty() or source.is_built_in():
		return source
	return ResourceLoader.load(
		source.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData


func _configure_character_authority(source: UnitData) -> bool:
	if source == null or working_unit == null:
		return false
	source_character_unit = source
	working_character_unit = source.duplicate(false) as UnitData
	if working_character_unit == null:
		return false
	if not source.resource_path.is_empty() and not source.is_built_in():
		working_character_unit.set_path_cache(source.resource_path)
	# Ne jamais recopier les tableaux de progression de l'adaptateur dans le
	# UnitData canonique. Les champs communs seront routés individuellement par
	# change_property ; l'animation est la seule sous-Resource initialement liée.
	working_character_unit.animation_set = working_unit.animation_set
	source_to_work[source_character_unit] = working_character_unit
	work_to_source[working_character_unit] = source_character_unit
	return true


func mark_saved() -> void:
	saved_fingerprint = current_fingerprint()
	document_changed.emit()
	history_changed.emit()


func change_property(
		target: Object,
		property_name: StringName,
		value: Variant,
		action_name: String
	) -> bool:
	if target == null:
		return false
	var before: Variant = target.get(property_name)
	if before == value:
		return false
	var changes: Array[Dictionary] = [{
		"target": target,
		"property": property_name,
		"before": _copy_value(before),
		"after": _copy_value(value),
	}]
	# La vue UnitData d'une progression est un adaptateur d'edition. Les champs
	# du chassis doivent donc rejoindre, dans la meme action UndoRedo, la vraie
	# copie de travail sauvegardable du UnitData canonique. Les trois champs de
	# progression restent exclusivement routes vers CharacterProgressionProfile.
	if unit_view_is_adapter and target == working_unit \
			and working_character_unit != null \
			and property_name not in PROGRESSION_UNIT_PROPERTIES:
		changes.append(_change(working_character_unit, property_name, value))
	return commit_changes(action_name, changes)


func commit_changes(action_name: String, changes: Array[Dictionary]) -> bool:
	if action_name.strip_edges().is_empty() or changes.is_empty():
		return false
	var effective: Array[Dictionary] = []
	for change in changes:
		var candidate_target := change.get("target") as Object
		var candidate_property := StringName(change.get("property", &""))
		if candidate_target == null or candidate_property == &"":
			continue
		var candidate_before: Variant = change.get(
			"before", candidate_target.get(candidate_property)
		)
		var candidate_after: Variant = change.get("after")
		if candidate_before != candidate_after:
			effective.append(change)
	if effective.is_empty():
		return false
	_begin_action(action_name)
	for change in effective:
		var target := change.get("target") as Object
		var property_name := StringName(change.get("property", &""))
		var before: Variant = change.get("before", target.get(property_name))
		var after: Variant = change.get("after")
		_add_do_property(target, property_name, _copy_value(after))
		_add_undo_property(target, property_name, _copy_value(before))
	_add_do_method(Callable(self, "_after_history_change"))
	_add_undo_method(Callable(self, "_after_history_change"))
	_commit_action()
	return true


func rename_discipline_id(new_id: StringName) -> bool:
	var discipline := current_discipline()
	if discipline == null or new_id == &"" or new_id == discipline.discipline_id:
		return false
	var reference_index := SkillTreeReferenceIndex.new().build(working_unit)
	if reference_index.id_exists("discipline", new_id):
		return false
	var old_id := discipline.discipline_id
	var changes: Array[Dictionary] = [_change(discipline, &"discipline_id", new_id)]
	for reference in reference_index.incoming_to_id("discipline", old_id):
		changes.append(_change_for_id_reference(reference, old_id, new_id))
	var changed := commit_changes(
		"Renommer l’identifiant %s en %s" % [old_id, new_id], changes
	)
	if changed:
		selected_discipline_id = new_id
		last_operation_report = reference_index.impact_report("discipline", old_id)
		last_operation_report["operation"] = "RENAME_DISCIPLINE_ID"
		last_operation_report["new_id"] = new_id
	return changed


func rename_node_id(node: SkillUpgradeData, new_id: StringName) -> bool:
	if node == null or new_id == &"" or node.upgrade_id == new_id:
		return false
	var reference_index := SkillTreeReferenceIndex.new().build(working_unit)
	if reference_index.id_exists("node", new_id):
		return false
	var old_id := node.upgrade_id
	var changes: Array[Dictionary] = [_change(node, &"upgrade_id", new_id)]
	for reference in reference_index.incoming_to_id("node", old_id):
		changes.append(_change_for_id_reference(reference, old_id, new_id))
	var changed := commit_changes(
		"Renommer l’identifiant %s en %s" % [old_id, new_id], changes
	)
	if changed:
		last_operation_report = reference_index.impact_report("node", old_id)
		last_operation_report["operation"] = "RENAME_NODE_ID"
		last_operation_report["new_id"] = new_id
	return changed


func rename_spell_id(spell: Spell, new_id: StringName) -> bool:
	if spell == null or new_id == &"" or working_unit == null:
		return false
	var old_id := spell.get_effective_spell_id()
	if old_id == new_id:
		return false
	var reference_index := SkillTreeReferenceIndex.new().build(working_unit)
	if reference_index.id_exists("spell", new_id):
		return false
	var changes: Array[Dictionary] = [_change(spell, &"spell_id", new_id)]
	for reference in reference_index.incoming_to_id("spell", old_id):
		changes.append(_change_for_id_reference(reference, old_id, new_id))
	var changed := commit_changes(
		"Renommer le sort %s en %s" % [old_id, new_id], changes
	)
	if changed:
		last_operation_report = reference_index.impact_report("spell", old_id)
		last_operation_report["operation"] = "RENAME_SPELL_ID"
		last_operation_report["new_id"] = new_id
	return changed


func change_node_target_spell(
		node: SkillUpgradeData,
		new_spell_id: StringName
	) -> bool:
	if node == null or new_spell_id == &"" or node.target_spell_id == new_spell_id:
		return false
	var old_spell_id := node.target_spell_id
	var changes: Array[Dictionary] = [_change(node, &"target_spell_id", new_spell_id)]
	for modifier in node.spell_modifiers:
		if modifier != null and modifier.target_spell_id == old_spell_id:
			changes.append(_change(modifier, &"target_spell_id", new_spell_id))
	return commit_changes(
		"Changer le sort ciblé par %s" % node.display_name, changes
	)


func move_node(node: SkillUpgradeData, new_rank: int) -> bool:
	var discipline := current_discipline()
	var old_owner := _rank_data(discipline, node.rank) if node != null else null
	var new_owner := _rank_data(discipline, new_rank)
	if node == null or old_owner == null or new_owner == null \
			or new_rank <= 1 or new_rank == node.rank:
		return false
	if node is SkillTreeNodeData:
		for prerequisite_id in node.prerequisite_node_ids:
			var prerequisite := find_node(prerequisite_id)
			if prerequisite != null and prerequisite.rank >= new_rank:
				return false
	for candidate in all_nodes(discipline):
		if candidate is SkillTreeNodeData \
				and candidate.prerequisite_node_ids.has(node.upgrade_id) \
				and candidate.rank <= new_rank:
			return false
	var old_choices: Array[SkillUpgradeData] = old_owner.choices.duplicate()
	old_choices.erase(node)
	var new_choices: Array[SkillUpgradeData] = new_owner.choices.duplicate()
	new_choices.append(node)
	return commit_changes("Déplacer %s au rang %d" % [node.display_name, new_rank], [
		_change(old_owner, &"choices", old_choices),
		_change(new_owner, &"choices", new_choices),
		_change(node, &"rank", new_rank),
	])


func add_rank() -> DisciplineRankData:
	var discipline := current_discipline()
	if discipline == null:
		return null
	var maximum_rank := 0
	var maximum_xp := 0
	var previous_xp := 0
	for rank_data in discipline.ranks:
		if rank_data != null and rank_data.rank > maximum_rank:
			previous_xp = maximum_xp
			maximum_rank = rank_data.rank
			maximum_xp = rank_data.required_total_xp
	var new_rank := DisciplineRankData.new()
	new_rank.rank = maximum_rank + 1
	new_rank.required_total_xp = maximum_xp + maxi(1, maximum_xp - previous_xp)
	if _uses_external_children(discipline):
		var path := _suggest_child_path("ranks", "rank_%d" % new_rank.rank)
		new_resource_paths[new_rank] = path
		new_rank.set_path_cache(path)
	var ranks: Array[DisciplineRankData] = discipline.ranks.duplicate()
	ranks.append(new_rank)
	if not change_property(
		discipline, &"ranks", ranks, "Ajouter le rang %d" % new_rank.rank
	):
		return null
	select_subject(new_rank)
	return new_rank


func remove_last_rank() -> bool:
	var discipline := current_discipline()
	if discipline == null or discipline.ranks.size() <= 1:
		return false
	var last_rank: DisciplineRankData = null
	for rank_data in discipline.ranks:
		if rank_data != null and (last_rank == null or rank_data.rank > last_rank.rank):
			last_rank = rank_data
	if last_rank == null:
		return false
	var removed_ids: Array[StringName] = []
	for node in last_rank.choices:
		if node != null:
			removed_ids.append(node.upgrade_id)
	var changes: Array[Dictionary] = []
	var ranks: Array[DisciplineRankData] = discipline.ranks.duplicate()
	ranks.erase(last_rank)
	changes.append(_change(discipline, &"ranks", ranks))
	for node in all_nodes(discipline):
		if not node is SkillTreeNodeData or last_rank.choices.has(node):
			continue
		var tree_node := node as SkillTreeNodeData
		var exclusions := tree_node.excluded_node_ids.duplicate()
		for removed_id in removed_ids:
			exclusions.erase(removed_id)
		if exclusions != tree_node.excluded_node_ids:
			changes.append(_change(tree_node, &"excluded_node_ids", exclusions))
	var changed := commit_changes("Supprimer le rang %d" % last_rank.rank, changes)
	if changed:
		select_subject(discipline)
	return changed


func apply_current_xp_preset() -> bool:
	var discipline := current_discipline()
	if discipline == null or discipline.ranks.size() != 5:
		return false
	return _apply_rank_thresholds([0, 5, 12, 21, 30], "Appliquer le preset XP Dungeon Draft")


func distribute_xp_automatically() -> bool:
	var discipline := current_discipline()
	if discipline == null or discipline.ranks.is_empty():
		return false
	var sorted := discipline.ranks.duplicate()
	sorted.sort_custom(func(a, b): return a != null and (b == null or a.rank < b.rank))
	var final_xp := 0
	for rank_data in sorted:
		if rank_data != null:
			final_xp = maxi(final_xp, rank_data.required_total_xp)
	final_xp = maxi(final_xp, maxi(1, sorted.size() - 1) * 5)
	var thresholds: Array[int] = []
	for index in range(sorted.size()):
		var ratio := float(index) / float(maxi(1, sorted.size() - 1))
		thresholds.append(roundi(final_xp * ratio))
	return _apply_rank_thresholds(thresholds, "Répartir automatiquement les seuils d’XP")


func _apply_rank_thresholds(thresholds: Array[int], action_name: String) -> bool:
	var discipline := current_discipline()
	if discipline == null or discipline.ranks.size() != thresholds.size():
		return false
	var sorted := discipline.ranks.duplicate()
	sorted.sort_custom(func(a, b): return a != null and (b == null or a.rank < b.rank))
	var changes: Array[Dictionary] = []
	for index in range(sorted.size()):
		var rank_data := sorted[index] as DisciplineRankData
		if rank_data != null:
			changes.append(_change(rank_data, &"required_total_xp", thresholds[index]))
	return commit_changes(action_name, changes)


func add_discipline(display_name: String, discipline_id: StringName) -> DisciplineData:
	if working_unit == null or discipline_id == &"":
		return null
	for candidate in working_unit.disciplines:
		if candidate != null and candidate.discipline_id == discipline_id:
			return null
	var discipline := DisciplineData.new()
	discipline.display_name = display_name.strip_edges() \
		if not display_name.strip_edges().is_empty() else "Nouvelle discipline"
	discipline.discipline_id = discipline_id
	discipline.description = "Décrivez le style de jeu proposé par cette discipline."
	var thresholds := [0, 5, 12, 21, 30]
	var ranks: Array[DisciplineRankData] = []
	for index in range(thresholds.size()):
		var rank_data := DisciplineRankData.new()
		rank_data.rank = index + 1
		rank_data.required_total_xp = thresholds[index]
		ranks.append(rank_data)
	discipline.ranks = ranks
	var path := "res://data/characters/%s/disciplines/%s.tres" % [
		_slug(str(working_unit.get_effective_unit_id())), _slug(str(discipline_id)),
	]
	new_resource_paths[discipline] = path
	discipline.set_path_cache(path)
	var spell := Spell.new()
	spell.spell_id = StringName("%s_%s_base_spell" % [
		_slug(str(working_unit.get_effective_unit_id())), _slug(str(discipline_id)),
	])
	spell.skill_tree = discipline
	spell.spell_name = "Sort de base — %s" % discipline.display_name
	spell.description = "Décrivez l’action disponible avant les améliorations."
	var spell_path := "res://data/characters/%s/spells/%s.tres" % [
		_slug(str(working_unit.get_effective_unit_id())), _slug(str(spell.spell_id)),
	]
	new_resource_paths[spell] = spell_path
	spell.set_path_cache(spell_path)
	var spells: Array[Spell] = working_unit.spells.duplicate()
	spells.append(spell)
	if not commit_changes("Créer l'arbre %s et son sort" % discipline.display_name, [
		_change(working_unit, &"spells", spells),
	]):
		new_resource_paths.erase(discipline)
		new_resource_paths.erase(spell)
		return null
	selected_discipline_id = discipline.discipline_id
	select_subject(discipline)
	return discipline


## Cree un Spell autonome et le range selon le contexte de creation. L'attache a
## un personnage est une consequence de ce contexte, jamais une propriete
## exclusive du sort : un sort cree « pour ce personnage » pourra etre reference
## plus tard par un autre sans etre duplique.
##
## `heroes` est le catalogue du projet. Vide, la verification d'unicite se limite
## au personnage ouvert et aux sorts deja crees dans cette session.
func create_spell(
		template: StringName,
		display_name: String,
		attach_to_character: bool,
		heroes: Array[Dictionary] = []
	) -> Spell:
	if working_unit == null:
		return null
	var spell := Spell.new()
	var trimmed := display_name.strip_edges()
	spell.spell_name = trimmed if not trimmed.is_empty() else "Nouveau sort"
	spell.description = "Decrivez ce que fait ce sort, sans vocabulaire technique."
	_apply_spell_template(spell, template)
	var path_service := SpellIdPathService.new()
	spell.spell_id = path_service.suggest_spell_id(
		spell.spell_name, heroes, canonical_source_path(), known_spell_ids()
	)
	var path := path_service.character_draft_path(working_unit, spell.spell_id) \
		if attach_to_character else path_service.shared_draft_path(spell.spell_id)
	path = path_reservations.generate_unique_path(path, "Spell")
	if path.is_empty():
		return null
	new_resource_paths[spell] = path
	spell.set_path_cache(path)
	if attach_to_character:
		var spells: Array[Spell] = working_unit.spells.duplicate()
		spells.append(spell)
		if not commit_changes("Creer le sort %s" % spell.spell_name, [
			_change(working_unit, &"spells", spells),
		]):
			new_resource_paths.erase(spell)
			return null
	else:
		standalone_spells.append(spell)
	path_reservations.reserve(path, spell, "Spell")
	select_subject(spell)
	return spell


## Ajoute une reference vers un Spell deja ecrit ailleurs dans le projet. La
## Resource n'est jamais recopiee sur le disque : le meme fichier .tres sert aux
## deux personnages, et une correction profite a tous ceux qui le referencent.
func attach_existing_spell(spell: Spell) -> bool:
	if working_unit == null or spell == null:
		return false
	var target_id := spell.get_effective_spell_id()
	for candidate in working_unit.spells:
		if candidate != null and candidate.get_effective_spell_id() == target_id:
			return false
	# Le sort choisi vient du disque, et le Studio n'edite jamais une Resource
	# source. On lui associe donc une copie de travail qui garde son chemin.
	var work := spell
	if not standalone_spells.has(spell) and not work_to_source.has(spell):
		work = SkillTreeCopyService.copy_spell(
			spell, source_to_work, work_to_source
		)
	if work == null:
		return false
	var spells: Array[Spell] = working_unit.spells.duplicate()
	spells.append(work)
	if not commit_changes("Ajouter le sort %s" % work.spell_name, [
		_change(working_unit, &"spells", spells),
	]):
		return false
	standalone_spells.erase(spell)
	select_subject(work)
	return true


## Retire uniquement la reference. Le fichier .tres n'est jamais supprime, et
## les autres personnages qui le referencent ne changent pas.
##
func detach_spell(spell: Spell) -> bool:
	if working_unit == null or spell == null:
		return false
	var spells: Array[Spell] = working_unit.spells.duplicate()
	var index := spells.find(spell)
	if index < 0:
		return false
	spells.remove_at(index)
	if not commit_changes("Retirer le sort %s" % spell.spell_name, [
		_change(working_unit, &"spells", spells),
	]):
		return false
	if selected_subject == spell:
		select_subject(working_unit)
	return true


## Discipline dont ce sort est la racine, ou null. C'est ce lien qui interdit le
## retrait : sans sort de base, l'arbre de la discipline n'a plus de depart.
func base_spell_discipline(spell: Spell) -> DisciplineData:
	return spell.skill_tree if working_unit != null and spell != null else null


## Identifiants deja pris dans le document en cours, disque compris ou non : le
## disque ne connait pas encore les sorts crees pendant cette session.
func known_spell_ids() -> Array:
	var result: Array = []
	if working_unit != null:
		for spell in working_unit.spells:
			if spell != null:
				result.append(spell.get_effective_spell_id())
	for spell in standalone_spells:
		if spell != null:
			result.append(spell.get_effective_spell_id())
	return result


## Un modele n'initialise que des champs sans ambiguite de conception. Aucune
## valeur d'equilibrage — degats, cout, portee — n'est devinee : ce sont des
## decisions d'auteur, pas des valeurs par defaut d'un assistant. Aucun de ces
## prereglages ne verrouille ni ne masque les autres groupes ensuite.
static func _apply_spell_template(spell: Spell, template: StringName) -> void:
	match template:
		SPELL_TEMPLATE_SIMPLE_ATTACK:
			spell.can_target_enemy = true
		SPELL_TEMPLATE_HEAL:
			spell.can_target_ally = true
			spell.can_target_self = true
			spell.can_target_enemy = false
		SPELL_TEMPLATE_SUMMON:
			spell.delayed_resolution = Spell.DelayedResolution.SUMMON
		_:
			# Poussee / Zone et Statut n'imposent rien : ils orientent seulement
			# l'onglet sur lequel la fiche s'ouvre.
			pass


func duplicate_current_discipline() -> DisciplineData:
	var source := current_discipline()
	if source == null or working_unit == null:
		return null
	var source_spell := current_spell()
	var base_id := "%s_copy" % source.discipline_id
	var candidate := base_id
	var suffix := 2
	while _discipline_id_exists(StringName(candidate)):
		candidate = "%s_%d" % [base_id, suffix]
		suffix += 1
	var copy := source.duplicate(false) as DisciplineData
	copy.discipline_id = StringName(candidate)
	copy.display_name = "%s — copie" % source.display_name
	var path := "res://data/characters/%s/disciplines/%s.tres" % [
		_slug(str(working_unit.get_effective_unit_id())), _slug(candidate),
	]
	new_resource_paths[copy] = path
	copy.set_path_cache(path)
	var new_spell: Spell = null
	var new_spell_id: StringName = &""
	if source_spell != null:
		new_spell = source_spell.duplicate(false) as Spell
		new_spell_id = StringName("%s_%s_base_spell" % [
			_slug(str(working_unit.get_effective_unit_id())), _slug(candidate),
		])
		new_spell.spell_id = new_spell_id
		new_spell.skill_tree = copy
		new_spell.spell_name = "%s — copie" % source_spell.spell_name
		var permanent_modifiers: Array[SpellModifier] = []
		for modifier in source_spell.modifiers:
			var permanent_copy := modifier.duplicate(true) as SpellModifier \
				if modifier != null else null
			if permanent_copy != null \
					and permanent_copy.target_spell_id == source_spell.get_effective_spell_id():
				permanent_copy.target_spell_id = new_spell_id
			if permanent_copy != null and modifier != null \
					and not modifier.resource_path.is_empty() and not modifier.is_built_in():
				var permanent_path := _suggest_child_path(
					"modifiers", "%s_permanent_%d" % [new_spell_id, permanent_modifiers.size() + 1]
				)
				new_resource_paths[permanent_copy] = permanent_path
				permanent_copy.set_path_cache(permanent_path)
			permanent_modifiers.append(permanent_copy)
		new_spell.modifiers = permanent_modifiers
		if not source_spell.resource_path.is_empty() and not source_spell.is_built_in():
			var spell_path := "res://data/characters/%s/spells/%s.tres" % [
				_slug(str(working_unit.get_effective_unit_id())), _slug(str(new_spell_id)),
			]
			new_resource_paths[new_spell] = spell_path
			new_spell.set_path_cache(spell_path)
	var id_map := {}
	var copied_ranks: Array[DisciplineRankData] = []
	for source_rank in source.ranks:
		if source_rank == null:
			copied_ranks.append(null)
			continue
		var copied_rank := source_rank.duplicate(false) as DisciplineRankData
		var copied_choices: Array[SkillUpgradeData] = []
		for source_node in source_rank.choices:
			if source_node == null:
				copied_choices.append(null)
				continue
			var copied_node := source_node.duplicate(false) as SkillUpgradeData
			copied_node.upgrade_id = StringName(
				"%s_%s" % [candidate, _slug(str(source_node.upgrade_id))]
			)
			id_map[source_node.upgrade_id] = copied_node.upgrade_id
			copied_node.discipline_id = copy.discipline_id
			if new_spell != null and source_node.target_spell_id == source_spell.get_effective_spell_id():
				copied_node.target_spell_id = &""
			var copied_modifiers: Array[SpellModifier] = []
			for source_modifier in source_node.spell_modifiers:
				var copied_modifier := source_modifier.duplicate(true) as SpellModifier \
					if source_modifier != null else null
				if copied_modifier != null and source_spell != null \
						and copied_modifier.target_spell_id == source_spell.get_effective_spell_id():
					copied_modifier.target_spell_id = &""
				copied_modifiers.append(copied_modifier)
				if copied_modifier != null and source_modifier != null \
						and not source_modifier.resource_path.is_empty() \
						and not source_modifier.is_built_in():
					var modifier_path := _suggest_child_path(
						"modifiers", "%s_%d" % [copied_node.upgrade_id, copied_modifiers.size()]
					)
					new_resource_paths[copied_modifier] = modifier_path
					copied_modifier.set_path_cache(modifier_path)
			copied_node.spell_modifiers = copied_modifiers
			if not source_node.resource_path.is_empty() and not source_node.is_built_in():
				var node_path := _suggest_child_path("upgrades", str(copied_node.upgrade_id))
				new_resource_paths[copied_node] = node_path
				copied_node.set_path_cache(node_path)
			copied_choices.append(copied_node)
		copied_rank.choices = copied_choices
		if not source_rank.resource_path.is_empty() and not source_rank.is_built_in():
			var rank_path := _suggest_child_path(
				"ranks", "%s_rank_%d" % [candidate, copied_rank.rank]
			)
			new_resource_paths[copied_rank] = rank_path
			copied_rank.set_path_cache(rank_path)
		copied_ranks.append(copied_rank)
	copy.ranks = copied_ranks
	for copied_rank in copy.ranks:
		if copied_rank == null:
			continue
		for copied_node in copied_rank.choices:
			if not copied_node is SkillTreeNodeData:
				continue
			var tree_node := copied_node as SkillTreeNodeData
			for index in range(tree_node.prerequisite_node_ids.size()):
				tree_node.prerequisite_node_ids[index] = StringName(
					id_map.get(tree_node.prerequisite_node_ids[index], tree_node.prerequisite_node_ids[index])
				)
			for index in range(tree_node.excluded_node_ids.size()):
				tree_node.excluded_node_ids[index] = StringName(
					id_map.get(tree_node.excluded_node_ids[index], tree_node.excluded_node_ids[index])
				)
	var spells: Array[Spell] = working_unit.spells.duplicate()
	if new_spell != null:
		spells.append(new_spell)
	if not commit_changes("Dupliquer l'arbre %s et son sort" % source.display_name, [
		_change(working_unit, &"spells", spells),
	]):
		return null
	selected_discipline_id = copy.discipline_id
	select_subject(copy)
	return copy


func detach_current_discipline() -> bool:
	var discipline := current_discipline()
	if discipline == null or working_unit == null:
		return false
	var spells: Array[Spell] = []
	for spell in working_unit.spells:
		if spell != null and spell.skill_tree != discipline:
			spells.append(spell)
	var changed := commit_changes(
		"Retirer le sort et l'arbre %s du personnage" % discipline.display_name,
		[
			_change(working_unit, &"spells", spells),
		]
	)
	if changed:
		var remaining := working_unit.get_skill_trees()
		selected_discipline_id = (
			remaining[0].discipline_id
			if not remaining.is_empty() and remaining[0] != null else &""
		)
		select_subject(current_discipline())
	return changed


func add_node(
		rank_number: int,
		display_name: String,
		parent: SkillUpgradeData = null
	) -> SkillTreeNodeData:
	var discipline := current_discipline()
	var rank_data := _rank_data(discipline, rank_number)
	if discipline == null or rank_data == null or rank_number <= 1:
		return null
	var node := SkillTreeNodeData.new()
	node.display_name = display_name.strip_edges() \
		if not display_name.strip_edges().is_empty() \
		else _unique_display_name(discipline, "Nouvelle amélioration")
	node.upgrade_id = _unique_node_id(node.display_name)
	node.description = "Décrivez clairement ce que cette amélioration apporte."
	node.discipline_id = discipline.discipline_id
	node.rank = rank_number
	var spell := current_spell()
	node.target_spell_id = &""
	if parent != null and parent.rank < rank_number:
		node.prerequisite_node_ids.append(parent.upgrade_id)
	if _uses_external_children(discipline):
		var path := _suggest_child_path("upgrades", str(node.upgrade_id))
		new_resource_paths[node] = path
		node.set_path_cache(path)
	var choices: Array[SkillUpgradeData] = rank_data.choices.duplicate()
	choices.append(node)
	if not change_property(
		rank_data, &"choices", choices, "Ajouter l'amélioration %s" % node.display_name
	):
		return null
	select_subject(node)
	return node


func duplicate_node(source: SkillUpgradeData) -> SkillUpgradeData:
	var discipline := current_discipline()
	var rank_data := _rank_data(discipline, source.rank) if source != null else null
	if source == null or discipline == null or rank_data == null:
		return null
	var copy := source.duplicate(true) as SkillUpgradeData
	copy.display_name = "%s — copie" % source.display_name
	copy.upgrade_id = _unique_node_id(copy.display_name)
	if copy is SkillTreeNodeData:
		(copy as SkillTreeNodeData).excluded_node_ids = []
	if _uses_external_children(discipline):
		var node_path := _suggest_child_path("upgrades", str(copy.upgrade_id))
		new_resource_paths[copy] = node_path
		copy.set_path_cache(node_path)
		for index in range(copy.spell_modifiers.size()):
			var modifier := copy.spell_modifiers[index]
			var source_modifier := source.spell_modifiers[index] \
				if index < source.spell_modifiers.size() else null
			if modifier != null and source_modifier != null \
					and not source_modifier.resource_path.is_empty() \
					and not source_modifier.is_built_in():
				var modifier_path := _suggest_child_path(
					"modifiers", "%s_%d" % [copy.upgrade_id, index + 1]
				)
				new_resource_paths[modifier] = modifier_path
				modifier.set_path_cache(modifier_path)
	var choices: Array[SkillUpgradeData] = rank_data.choices.duplicate()
	choices.append(copy)
	if not change_property(
		rank_data, &"choices", choices, "Dupliquer %s" % source.display_name
	):
		return null
	select_subject(copy)
	return copy


func duplicate_nodes(
		sources: Array[SkillUpgradeData],
		preserve_external_relations := false
	) -> Array[SkillUpgradeData]:
	var discipline := current_discipline()
	var created: Array[SkillUpgradeData] = []
	if discipline == null or sources.is_empty():
		return created
	var valid: Array[SkillUpgradeData] = []
	for source in sources:
		if source != null and all_nodes(discipline).has(source) and not valid.has(source):
			valid.append(source)
	if valid.is_empty():
		return created
	var old_to_new_id := {}
	var reserved_ids: Array[StringName] = []
	for source in valid:
		var copy := source.duplicate(true) as SkillUpgradeData
		var candidate := _unique_node_id(source.display_name + " copie")
		var suffix := 2
		while reserved_ids.has(candidate):
			candidate = StringName("%s_%d" % [candidate, suffix])
			suffix += 1
		copy.upgrade_id = candidate
		copy.display_name = source.display_name + " (copie)"
		old_to_new_id[source.upgrade_id] = candidate
		reserved_ids.append(candidate)
		created.append(copy)
	for index in range(valid.size()):
		var source := valid[index]
		var copy := created[index]
		if source is SkillTreeNodeData and copy is SkillTreeNodeData:
			var prerequisites: Array[StringName] = []
			for prerequisite_id in source.prerequisite_node_ids:
				if old_to_new_id.has(prerequisite_id):
					prerequisites.append(StringName(old_to_new_id[prerequisite_id]))
				elif preserve_external_relations:
					prerequisites.append(prerequisite_id)
			copy.prerequisite_node_ids = prerequisites
			var exclusions: Array[StringName] = []
			for excluded_id in source.excluded_node_ids:
				if old_to_new_id.has(excluded_id):
					exclusions.append(StringName(old_to_new_id[excluded_id]))
				elif preserve_external_relations:
					exclusions.append(excluded_id)
			copy.excluded_node_ids = exclusions
	var changes: Array[Dictionary] = []
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		var choices: Array[SkillUpgradeData] = rank_data.choices.duplicate()
		for copy in created:
			if copy.rank == rank_data.rank:
				choices.append(copy)
				if _uses_external_children(discipline):
					var path := _suggest_child_path("upgrades", str(copy.upgrade_id))
					new_resource_paths[copy] = path
					copy.set_path_cache(path)
		if choices != rank_data.choices:
			changes.append(_change(rank_data, &"choices", choices))
	if not commit_changes("Dupliquer %d amélioration(s)" % created.size(), changes):
		return []
	select_subject(created[-1])
	return created


func add_linear_branch(display_name: String, start_rank := 2) -> Array[SkillUpgradeData]:
	var discipline := current_discipline()
	if discipline == null:
		return []
	var ranks: Array[DisciplineRankData] = []
	for rank_data in discipline.ranks:
		if rank_data != null and rank_data.rank >= maxi(2, start_rank):
			ranks.append(rank_data)
	ranks.sort_custom(func(a: DisciplineRankData, b: DisciplineRankData) -> bool:
		return a.rank < b.rank
	)
	if ranks.is_empty():
		return []
	var branch_name := display_name.strip_edges() \
		if not display_name.strip_edges().is_empty() else "Nouvelle branche"
	var created: Array[SkillUpgradeData] = []
	var changes: Array[Dictionary] = []
	var previous: SkillUpgradeData = null
	if selected_subject is SkillUpgradeData \
			and selected_subject.rank < ranks[0].rank:
		previous = selected_subject as SkillUpgradeData
	for rank_data in ranks:
		var node := SkillTreeNodeData.new()
		node.display_name = "%s — rang %d" % [branch_name, rank_data.rank]
		node.description = "Décrivez le rôle de cette étape dans la branche %s." % branch_name
		node.upgrade_id = _unique_node_id("%s_rang_%d" % [branch_name, rank_data.rank])
		node.discipline_id = discipline.discipline_id
		node.rank = rank_data.rank
		var spell := current_spell()
		node.target_spell_id = &""
		if previous != null:
			node.prerequisite_node_ids.append(previous.upgrade_id)
		if _uses_external_children(discipline):
			var path := _suggest_child_path("upgrades", str(node.upgrade_id))
			new_resource_paths[node] = path
			node.set_path_cache(path)
		var choices: Array[SkillUpgradeData] = rank_data.choices.duplicate()
		choices.append(node)
		changes.append(_change(rank_data, &"choices", choices))
		created.append(node)
		previous = node
	if not commit_changes("Créer la branche %s" % branch_name, changes):
		return []
	select_subject(created[-1])
	return created


func remove_node(node: SkillUpgradeData) -> bool:
	return remove_nodes([node])


func remove_nodes(nodes: Array[SkillUpgradeData]) -> bool:
	var discipline := current_discipline()
	if discipline == null or nodes.is_empty():
		return false
	var changes: Array[Dictionary] = []
	var removed_ids: Array[StringName] = []
	var removed_by_id := {}
	for node in nodes:
		if node != null and all_nodes(discipline).has(node):
			removed_ids.append(node.upgrade_id)
			removed_by_id[node.upgrade_id] = node
	if removed_ids.is_empty():
		return false
	var descendants: Array[StringName] = []
	var inherited_by_descendant := {}
	var removed_exclusions := 0
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		var choices: Array[SkillUpgradeData] = rank_data.choices.duplicate()
		for node in nodes:
			choices.erase(node)
		if choices != rank_data.choices:
			changes.append(_change(rank_data, &"choices", choices))
	for candidate in all_nodes(discipline):
		if not candidate is SkillTreeNodeData or nodes.has(candidate):
			continue
		var tree_node := candidate as SkillTreeNodeData
		var prerequisites := tree_node.prerequisite_node_ids.duplicate()
		var exclusions := tree_node.excluded_node_ids.duplicate()
		for removed_id in removed_ids:
			if prerequisites.has(removed_id):
				prerequisites.erase(removed_id)
				if not descendants.has(tree_node.upgrade_id):
					descendants.append(tree_node.upgrade_id)
				for inherited_id in _surviving_prerequisites(
						removed_id, removed_by_id, removed_ids, tree_node.rank, {}
					):
					if not prerequisites.has(inherited_id):
						prerequisites.append(inherited_id)
						var inherited_ids: Array = inherited_by_descendant.get(
							tree_node.upgrade_id, []
						)
						inherited_ids.append(inherited_id)
						inherited_by_descendant[tree_node.upgrade_id] = inherited_ids
			if exclusions.has(removed_id):
				removed_exclusions += 1
			exclusions.erase(removed_id)
		if prerequisites != tree_node.prerequisite_node_ids:
			changes.append(_change(tree_node, &"prerequisite_node_ids", prerequisites))
		if exclusions != tree_node.excluded_node_ids:
			changes.append(_change(tree_node, &"excluded_node_ids", exclusions))
	var changed := commit_changes(
		"Supprimer %d amélioration(s) et reconnecter les descendants" % removed_ids.size(),
		changes
	)
	if changed:
		last_operation_report = {
			"operation": "DELETE_NODES",
			"removed_node_ids": removed_ids.duplicate(),
			"affected_descendant_ids": descendants,
			"inherited_prerequisites": inherited_by_descendant,
			"removed_exclusion_count": removed_exclusions,
			"potentially_lost_paths": descendants.size(),
		}
		select_subject(discipline)
	return changed


func add_prerequisite(child: SkillTreeNodeData, parent: SkillUpgradeData) -> bool:
	if child == null or parent == null or parent.rank >= child.rank \
			or child.upgrade_id == parent.upgrade_id:
		return false
	var prerequisites := child.prerequisite_node_ids.duplicate()
	if prerequisites.has(parent.upgrade_id):
		return false
	prerequisites.append(parent.upgrade_id)
	return change_property(
		child,
		&"prerequisite_node_ids",
		prerequisites,
		"Relier %s à %s" % [child.display_name, parent.display_name]
	)


func remove_prerequisite(child: SkillTreeNodeData, parent_id: StringName) -> bool:
	if child == null or not child.prerequisite_node_ids.has(parent_id):
		return false
	var prerequisites := child.prerequisite_node_ids.duplicate()
	prerequisites.erase(parent_id)
	return change_property(
		child, &"prerequisite_node_ids", prerequisites,
		"Retirer un prérequis de %s" % child.display_name
	)


func set_exclusion(
		first: SkillTreeNodeData,
		second: SkillTreeNodeData,
		enabled: bool,
		symmetric := true
	) -> bool:
	if first == null or second == null or first == second:
		return false
	var changes: Array[Dictionary] = []
	var first_ids := first.excluded_node_ids.duplicate()
	_set_id_membership(first_ids, second.upgrade_id, enabled)
	changes.append(_change(first, &"excluded_node_ids", first_ids))
	if symmetric:
		var second_ids := second.excluded_node_ids.duplicate()
		_set_id_membership(second_ids, first.upgrade_id, enabled)
		changes.append(_change(second, &"excluded_node_ids", second_ids))
	return commit_changes(
		("Exclure" if enabled else "Autoriser") + " %s et %s" % [
			first.display_name, second.display_name,
		],
		changes
	)


func add_default_modifier(node: SkillUpgradeData) -> SpellModifier:
	if node == null:
		return null
	var modifier := SpellModSkillTreeEffect.new()
	modifier.modifier_name = "Effet de %s" % node.display_name
	modifier.target_spell_id = node.target_spell_id
	if _uses_external_children(current_discipline()):
		var path := _suggest_child_path("modifiers", str(node.upgrade_id))
		new_resource_paths[modifier] = path
		modifier.set_path_cache(path)
	var modifiers: Array[SpellModifier] = node.spell_modifiers.duplicate()
	modifiers.append(modifier)
	if not change_property(
		node, &"spell_modifiers", modifiers,
		"Ajouter un effet à %s" % node.display_name
	):
		return null
	select_subject(modifier)
	return modifier


func remove_modifier(node: SkillUpgradeData, modifier: SpellModifier) -> bool:
	if node == null or modifier == null or not node.spell_modifiers.has(modifier):
		return false
	var modifiers: Array[SpellModifier] = node.spell_modifiers.duplicate()
	modifiers.erase(modifier)
	var changed := change_property(
		node, &"spell_modifiers", modifiers,
		"Retirer un effet de %s" % node.display_name
	)
	return changed


func add_existing_modifier(
		node: SkillUpgradeData,
		source_modifier: SpellModifier
	) -> SpellModifier:
	if node == null or source_modifier == null:
		return null
	var work := source_to_work.get(source_modifier) as SpellModifier
	if work == null:
		work = source_modifier.duplicate(true) as SpellModifier
		source_to_work[source_modifier] = work
		work_to_source[work] = source_modifier
		if not source_modifier.resource_path.is_empty() \
				and not source_modifier.is_built_in():
			work.set_path_cache(source_modifier.resource_path)
	var modifiers: Array[SpellModifier] = node.spell_modifiers.duplicate()
	if modifiers.has(work):
		return work
	modifiers.append(work)
	if not change_property(
		node, &"spell_modifiers", modifiers,
		"Partager l’effet %s" % source_modifier.modifier_name
	):
		return null
	select_subject(work)
	return work


func duplicate_modifier(
		node: SkillUpgradeData,
		modifier: SpellModifier
	) -> SpellModifier:
	if node == null or modifier == null or not node.spell_modifiers.has(modifier):
		return null
	var copy := modifier.duplicate(true) as SpellModifier
	copy.modifier_name = "%s — copie" % (
		modifier.modifier_name if not modifier.modifier_name.is_empty() else "Effet"
	)
	if _uses_external_children(current_discipline()) \
			and not modifier.resource_path.is_empty() and not modifier.is_built_in():
		var path := _suggest_child_path("modifiers", str(node.upgrade_id))
		new_resource_paths[copy] = path
		copy.set_path_cache(path)
	var modifiers: Array[SpellModifier] = node.spell_modifiers.duplicate()
	modifiers.insert(modifiers.find(modifier) + 1, copy)
	if not change_property(
		node, &"spell_modifiers", modifiers, "Dupliquer un effet"
	):
		return null
	select_subject(copy)
	return copy


func make_modifier_unique(
		node: SkillUpgradeData,
		modifier: SpellModifier
	) -> SpellModifier:
	if node == null or modifier == null or not node.spell_modifiers.has(modifier):
		return null
	var copy := modifier.duplicate(true) as SpellModifier
	if not modifier.resource_path.is_empty() and not modifier.is_built_in():
		var path := _suggest_child_path("modifiers", str(node.upgrade_id))
		new_resource_paths[copy] = path
		copy.set_path_cache(path)
	var modifiers: Array[SpellModifier] = node.spell_modifiers.duplicate()
	modifiers[modifiers.find(modifier)] = copy
	if not change_property(
		node, &"spell_modifiers", modifiers, "Rendre un effet unique"
	):
		return null
	select_subject(copy)
	return copy


func move_modifier(
		node: SkillUpgradeData,
		modifier: SpellModifier,
		offset: int
	) -> bool:
	if node == null or modifier == null or not node.spell_modifiers.has(modifier):
		return false
	var modifiers: Array[SpellModifier] = node.spell_modifiers.duplicate()
	var old_index := modifiers.find(modifier)
	var new_index := clampi(old_index + offset, 0, modifiers.size() - 1)
	if old_index == new_index:
		return false
	modifiers.remove_at(old_index)
	modifiers.insert(new_index, modifier)
	return change_property(
		node, &"spell_modifiers", modifiers, "Réordonner les effets"
	)


## Regle le clip joue par un evenement d'animation du personnage ouvert.
## La fiche d'animations est creee au premier reglage si le personnage n'en a
## pas encore : elle rejoint alors le plan de sauvegarde comme nouveau fichier.
func set_animation_clip(
		action_id: StringName,
		clip_name: StringName,
		event_label: String
	) -> bool:
	if working_unit == null or action_id == &"":
		return false
	var animation_set := working_unit.animation_set
	if animation_set != null:
		return change_property(
			animation_set,
			&"animation_names",
			animation_set.names_with(action_id, clip_name),
			"Modifier l’animation « %s »" % event_label
		)
	if clip_name == &"":
		return false
	animation_set = CharacterAnimationSetData.new()
	animation_set.animation_names = {action_id: clip_name}
	var path := "res://data/characters/%s/animations.tres" % _slug(
		str(working_unit.get_effective_unit_id())
	)
	new_resource_paths[animation_set] = path
	animation_set.set_path_cache(path)
	var changes: Array[Dictionary] = [
		_change(working_unit, &"animation_set", animation_set),
	]
	if working_character_unit != null and working_character_unit != working_unit:
		changes.append(_change(
			working_character_unit, &"animation_set", animation_set
		))
	if not commit_changes(
			"Créer la fiche d’animations et régler « %s »" % event_label,
			changes
		):
		new_resource_paths.erase(animation_set)
		return false
	return true


func current_animation_set() -> CharacterAnimationSetData:
	return working_unit.animation_set if working_unit != null else null


func all_nodes(discipline: DisciplineData = null) -> Array[SkillUpgradeData]:
	var result: Array[SkillUpgradeData] = []
	var target := discipline if discipline != null else current_discipline()
	if target == null:
		return result
	for rank_data in target.ranks:
		if rank_data == null:
			continue
		for node in rank_data.choices:
			if node != null:
				result.append(node)
	return result


func find_node(node_id: StringName) -> SkillUpgradeData:
	for node in all_nodes():
		if node.upgrade_id == node_id:
			return node
	return null


func history_can_undo() -> bool:
	return _undo_redo().has_undo()


func history_can_redo() -> bool:
	return _undo_redo().has_redo()


func history_undo() -> bool:
	return _undo_redo().undo() if history_can_undo() else false


func history_redo() -> bool:
	return _undo_redo().redo() if history_can_redo() else false


func history_undo_name() -> String:
	return _undo_redo().get_current_action_name() if history_can_undo() else ""


func _undo_redo() -> UndoRedo:
	return document_history


func _begin_action(action_name: String) -> void:
	document_history.create_action(action_name, UndoRedo.MERGE_DISABLE)


func _add_do_property(target: Object, property_name: StringName, value: Variant) -> void:
	document_history.add_do_property(target, property_name, value)


func _add_undo_property(target: Object, property_name: StringName, value: Variant) -> void:
	document_history.add_undo_property(target, property_name, value)


func _add_do_method(callable: Callable) -> void:
	document_history.add_do_method(callable)


func _add_undo_method(callable: Callable) -> void:
	document_history.add_undo_method(callable)


func _commit_action() -> void:
	document_history.commit_action()


func _after_history_change() -> void:
	if working_unit != null and current_discipline() == null:
		selected_discipline_id = (
			working_unit.disciplines[0].discipline_id
			if not working_unit.disciplines.is_empty() \
				and working_unit.disciplines[0] != null else &""
		)
		selected_subject = current_discipline()
		selection_changed.emit(selected_subject)
	document_changed.emit()
	history_changed.emit()


func _reset_history() -> void:
	if document_history != null:
		document_history.clear_history(false)
	document_history = UndoRedo.new()
	document_history.max_steps = HISTORY_LIMIT


func _surviving_prerequisites(
		removed_id: StringName,
		removed_by_id: Dictionary,
		removed_ids: Array[StringName],
		target_rank: int,
		visited: Dictionary
	) -> Array[StringName]:
	var result: Array[StringName] = []
	if visited.has(removed_id):
		return result
	visited[removed_id] = true
	var removed := removed_by_id.get(removed_id) as SkillTreeNodeData
	if removed == null:
		return result
	for prerequisite_id in removed.prerequisite_node_ids:
		if removed_ids.has(prerequisite_id):
			for ancestor_id in _surviving_prerequisites(
					prerequisite_id, removed_by_id, removed_ids, target_rank, visited
				):
				if not result.has(ancestor_id):
					result.append(ancestor_id)
			continue
		var prerequisite := find_node(prerequisite_id)
		if prerequisite != null and prerequisite.rank < target_rank \
				and not result.has(prerequisite_id):
			result.append(prerequisite_id)
	return result


func _rank_data(
		discipline: DisciplineData,
		rank_number: int
	) -> DisciplineRankData:
	if discipline == null:
		return null
	for rank_data in discipline.ranks:
		if rank_data != null and rank_data.rank == rank_number:
			return rank_data
	return null


func _unique_node_id(display_name: String) -> StringName:
	var character := str(working_unit.get_effective_unit_id()) \
		if working_unit != null else "personnage"
	var discipline := str(selected_discipline_id) if selected_discipline_id != &"" \
		else "discipline"
	var base := "%s_%s_%s" % [character, discipline, _slug(display_name)]
	var candidate := base
	var suffix := 2
	while find_node(StringName(candidate)) != null:
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	return StringName(candidate)


## Nom temporaire lisible mais deja distinct : deux creations rapides sans
## saisie donnaient auparavant deux « Nouvelle amélioration » identiques a
## l'ecran, que le validateur ne signalait pas.
func _unique_display_name(discipline: DisciplineData, base: String) -> String:
	var taken := {}
	if discipline != null:
		for rank_data in discipline.ranks:
			if rank_data == null:
				continue
			for node in rank_data.choices:
				if node != null:
					taken[str(node.display_name).strip_edges().to_lower()] = true
	if not taken.has(base.to_lower()):
		return base
	var suffix := 2
	while taken.has("%s %d" % [base.to_lower(), suffix]):
		suffix += 1
	return "%s %d" % [base, suffix]


func _uses_external_children(discipline: DisciplineData) -> bool:
	if discipline == null:
		return false
	for rank_data in discipline.ranks:
		if rank_data != null and not rank_data.resource_path.is_empty() \
				and not rank_data.is_built_in():
			return true
	return false


func _discipline_id_exists(discipline_id: StringName) -> bool:
	for discipline in working_unit.disciplines if working_unit != null else []:
		if discipline != null and discipline.discipline_id == discipline_id:
			return true
	return false


func _suggest_child_path(folder: String, file_stem: String) -> String:
	var source_discipline := work_to_source.get(current_discipline()) as DisciplineData
	var source_path := source_discipline.resource_path \
		if source_discipline != null else ""
	var character_root := source_path.get_base_dir().get_base_dir() \
		if not source_path.is_empty() else "res://data/characters"
	var candidate := character_root.path_join(folder).path_join(_slug(file_stem) + ".tres")
	var unique := path_reservations.generate_unique_path(candidate)
	if not unique.is_empty():
		path_reservations.reserve(unique, file_stem)
	return unique


static func _slug(value: String) -> String:
	var normalized := value.to_lower().strip_edges()
	var result := ""
	for character in normalized:
		if character >= "a" and character <= "z" or character >= "0" and character <= "9":
			result += character
		elif not result.ends_with("_"):
			result += "_"
	return result.trim_prefix("_").trim_suffix("_") if not result.is_empty() else "nouveau"


static func _change(target: Object, property_name: StringName, after: Variant) -> Dictionary:
	return {
		"target": target,
		"property": property_name,
		"before": _copy_value(target.get(property_name)),
		"after": _copy_value(after),
	}


static func _change_for_id_reference(
		reference: Dictionary, old_id: StringName, new_id: StringName
	) -> Dictionary:
	var owner := reference.get("owner") as Resource
	var property_name := StringName(reference.get("property", &""))
	var current: Variant = owner.get(property_name)
	if current is Array:
		var replaced := (current as Array).duplicate()
		for index in range(replaced.size()):
			if StringName(replaced[index]) == old_id:
				replaced[index] = new_id
		return _change(owner, property_name, replaced)
	return _change(owner, property_name, new_id)


static func _copy_value(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


static func _set_id_membership(
		values: Array[StringName],
		value: StringName,
		enabled: bool
	) -> void:
	if enabled and not values.has(value):
		values.append(value)
	elif not enabled:
		values.erase(value)
