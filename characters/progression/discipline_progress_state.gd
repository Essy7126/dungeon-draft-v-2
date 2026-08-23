class_name DisciplineProgressState
extends RefCounted

## Le nom de classe reste provisoirement compatible avec les consommateurs
## historiques, mais l'identite de cet etat est desormais celle du sort.
var spell_id: StringName = &""
var xp: int = 0
var rank: int = 1

var discipline_id: StringName:
	get:
		return spell_id

var _skill_tree: DisciplineData = null
var _selected_upgrade_ids: Array[StringName] = []
var _pending_rank_choices: Array[int] = []

var selected_upgrade_ids: Array[StringName]:
	get:
		return _selected_upgrade_ids.duplicate()

var pending_rank_choices: Array[int]:
	get:
		return _pending_rank_choices.duplicate()


func initialize(skill_tree: DisciplineData, owner_spell_id: StringName = &"") -> bool:
	if owner_spell_id == &"" and skill_tree != null:
		owner_spell_id = skill_tree.discipline_id
	if skill_tree == null or skill_tree.discipline_id == &"" \
			or owner_spell_id == &"" or owner_spell_id == &"spell:unassigned":
		return false
	_skill_tree = skill_tree
	spell_id = owner_spell_id
	xp = 0
	rank = 1
	_selected_upgrade_ids.clear()
	_pending_rank_choices.clear()
	return true


func get_skill_tree() -> DisciplineData:
	return _skill_tree


func add_xp(amount: int) -> Array[int]:
	var reached_ranks: Array[int] = []
	if amount <= 0 or _skill_tree == null:
		return reached_ranks
	xp += amount
	for rank_data in _get_sorted_rank_data():
		if rank_data.rank <= rank:
			continue
		if rank_data.rank != rank + 1 or xp < rank_data.required_total_xp:
			break
		rank = rank_data.rank
		reached_ranks.append(rank)
		if not rank_data.choices.is_empty() \
				and not _pending_rank_choices.has(rank) \
				and not _has_selected_upgrade_for_rank(rank):
			_pending_rank_choices.append(rank)
	return reached_ranks


func select_upgrade(upgrade_id: StringName, choice_rank: int = -1) -> SkillUpgradeData:
	if upgrade_id == &"" or _skill_tree == null:
		return null
	var rank_to_resolve := choice_rank
	if rank_to_resolve < 1:
		if _pending_rank_choices.is_empty():
			return null
		rank_to_resolve = _pending_rank_choices[0]
	var decision := SkillTreeResolver.evaluate_selection(
		_skill_tree, rank_to_resolve, upgrade_id, rank,
		get_pending_rank_choices(), get_selected_upgrade_ids()
	)
	if not decision.get("allowed", false):
		return null
	var selected := decision.get("node") as SkillUpgradeData
	if selected == null:
		return null
	_selected_upgrade_ids.append(selected.upgrade_id)
	_pending_rank_choices.erase(rank_to_resolve)
	return selected


func get_selected_upgrade_ids() -> Array[StringName]:
	return _selected_upgrade_ids.duplicate()


func get_pending_rank_choices() -> Array[int]:
	return _pending_rank_choices.duplicate()


func get_rank_data(wanted_rank: int) -> DisciplineRankData:
	if _skill_tree == null:
		return null
	for rank_data in _skill_tree.ranks:
		if rank_data != null and rank_data.rank == wanted_rank:
			return rank_data
	return null


func get_next_rank_data() -> DisciplineRankData:
	for rank_data in _get_sorted_rank_data():
		if rank_data.rank > rank:
			return rank_data
	return null


func get_selected_upgrades() -> Array[SkillUpgradeData]:
	var selected: Array[SkillUpgradeData] = []
	if _skill_tree == null:
		return selected
	for rank_data in _get_sorted_rank_data():
		for upgrade in rank_data.choices:
			if upgrade != null and _selected_upgrade_ids.has(upgrade.upgrade_id):
				selected.append(upgrade)
	return selected


func get_snapshot() -> Dictionary:
	var next_rank_data := get_next_rank_data()
	return {
		"spell_id": spell_id,
		"xp": xp,
		"rank": rank,
		"selected_upgrade_ids": get_selected_upgrade_ids(),
		"pending_rank_choices": get_pending_rank_choices(),
		"next_required_total_xp": next_rank_data.required_total_xp if next_rank_data != null else -1,
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if _skill_tree == null or StringName(snapshot.get("spell_id", &"")) != spell_id:
		return false
	var wanted_xp := maxi(0, int(snapshot.get("xp", 0)))
	var wanted_rank := int(snapshot.get("rank", 1))
	var wanted_selected: Array[StringName] = []
	for value in snapshot.get("selected_upgrade_ids", []):
		wanted_selected.append(StringName(value))
	var wanted_pending: Array[int] = []
	for value in snapshot.get("pending_rank_choices", []):
		wanted_pending.append(int(value))
	xp = 0
	rank = 1
	_selected_upgrade_ids.clear()
	_pending_rank_choices.clear()
	add_xp(wanted_xp)
	for rank_data in _get_sorted_rank_data():
		if rank_data.rank <= 1:
			continue
		var selected_for_rank: StringName = &""
		for candidate in rank_data.choices:
			if candidate != null and wanted_selected.has(candidate.upgrade_id):
				if selected_for_rank != &"":
					return false
				selected_for_rank = candidate.upgrade_id
		if selected_for_rank != &"" \
				and select_upgrade(selected_for_rank, rank_data.rank) == null:
			return false
	return rank == wanted_rank \
		and get_selected_upgrade_ids() == wanted_selected \
		and get_pending_rank_choices() == wanted_pending


func _has_selected_upgrade_for_rank(wanted_rank: int) -> bool:
	var rank_data := get_rank_data(wanted_rank)
	if rank_data == null:
		return false
	for upgrade in rank_data.choices:
		if upgrade != null and _selected_upgrade_ids.has(upgrade.upgrade_id):
			return true
	return false


func _get_sorted_rank_data() -> Array[DisciplineRankData]:
	var sorted: Array[DisciplineRankData] = []
	if _skill_tree != null:
		for rank_data in _skill_tree.ranks:
			if rank_data != null:
				sorted.append(rank_data)
	sorted.sort_custom(func(a: DisciplineRankData, b: DisciplineRankData): return a.rank < b.rank)
	return sorted
