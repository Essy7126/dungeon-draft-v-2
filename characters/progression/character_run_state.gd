class_name CharacterRunState
extends RefCounted

var character_id: StringName = &""
var unit: Unit = null
var loadout: SpellLoadoutState = null
var disciplines: Array[DisciplineData] = []


func initialize(
		p_unit: Unit,
		unit_data: UnitData,
		slot_count: int = SpellLoadoutState.DEFAULT_ACTIVE_SLOT_COUNT
	) -> bool:
	if p_unit == null or unit_data == null:
		return false
	character_id = unit_data.get_effective_unit_id()
	unit = p_unit
	disciplines = unit_data.disciplines.duplicate()
	loadout = SpellLoadoutState.new()
	loadout.changed.connect(sync_loadout_to_unit)
	loadout.initialize(unit_data.spells, slot_count)
	sync_loadout_to_unit()
	return true


func sync_loadout_to_unit() -> void:
	if unit == null or loadout == null:
		return
	unit.spells = loadout.get_equipped_spells()


func get_disciplines() -> Array[DisciplineData]:
	return disciplines.duplicate()
