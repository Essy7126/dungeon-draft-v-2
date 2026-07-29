class_name DisciplineProgressState
extends RefCounted

var discipline_id: StringName = &""
var xp: int = 0
var rank: int = 1

var _discipline_data: DisciplineData = null
var _selected_upgrade_ids: Array[StringName] = []
var _pending_rank_choices: Array[int] = []

var selected_upgrade_ids: Array[StringName]:
	get:
		return _selected_upgrade_ids.duplicate()

var pending_rank_choices: Array[int]:
	get:
		return _pending_rank_choices.duplicate()


func initialize(discipline_data: DisciplineData) -> bool:
	if discipline_data == null or discipline_data.discipline_id == &"":
		return false
	_discipline_data = discipline_data
	discipline_id = discipline_data.discipline_id
	xp = 0
	rank = 1
	_selected_upgrade_ids.clear()
	_pending_rank_choices.clear()
	return true


func add_xp(amount: int) -> Array[int]:
	var reached_ranks: Array[int] = []
	if amount <= 0 or _discipline_data == null:
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
	if upgrade_id == &"" or _discipline_data == null:
		return null
	var rank_to_resolve := choice_rank
	if rank_to_resolve < 1:
		if _pending_rank_choices.is_empty():
			return null
		rank_to_resolve = _pending_rank_choices[0]
	var decision := SkillTreeResolver.evaluate_selection(
		_discipline_data,
		rank_to_resolve,
		upgrade_id,
		rank,
		get_pending_rank_choices(),
		get_selected_upgrade_ids()
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
	if _discipline_data == null:
		return null
	for rank_data in _discipline_data.ranks:
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
	if _discipline_data == null:
		return selected
	for rank_data in _get_sorted_rank_data():
		for upgrade in rank_data.choices:
			if upgrade != null and _selected_upgrade_ids.has(upgrade.upgrade_id):
				selected.append(upgrade)
	return selected


func get_snapshot() -> Dictionary:
	var next_rank_data := get_next_rank_data()
	return {
		"discipline_id": discipline_id,
		"xp": xp,
		"rank": rank,
		"selected_upgrade_ids": get_selected_upgrade_ids(),
		"pending_rank_choices": get_pending_rank_choices(),
		"next_required_total_xp": next_rank_data.required_total_xp if next_rank_data != null else -1,
	}


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
	if _discipline_data != null:
		for rank_data in _discipline_data.ranks:
			if rank_data != null:
				sorted.append(rank_data)
	sorted.sort_custom(func(a: DisciplineRankData, b: DisciplineRankData): return a.rank < b.rank)
	return sorted
