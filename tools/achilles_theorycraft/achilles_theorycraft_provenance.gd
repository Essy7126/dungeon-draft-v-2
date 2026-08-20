class_name AchillesTheorycraftProvenance
extends RefCounted

const OBSERVED_RUNTIME_DATA := "OBSERVED_RUNTIME_DATA"
const DERIVED_EXACT := "DERIVED_EXACT"
const DRAFT_DESIGN_INPUT := "DRAFT_DESIGN_INPUT"
const MANUAL_ASSUMPTION := "MANUAL_ASSUMPTION"
const NOT_MEASURED := "NOT_MEASURED"

const ALL := [
	OBSERVED_RUNTIME_DATA,
	DERIVED_EXACT,
	DRAFT_DESIGN_INPUT,
	MANUAL_ASSUMPTION,
	NOT_MEASURED,
]


static func observed(source: String) -> Dictionary:
	return {
		"kind": OBSERVED_RUNTIME_DATA,
		"source": source,
	}


static func derived(calculation: String, sources: Array = []) -> Dictionary:
	return {
		"kind": DERIVED_EXACT,
		"calculation": calculation,
		"sources": sources.duplicate(true),
	}


static func draft(note := "Owner-editable theorycraft input") -> Dictionary:
	return {
		"kind": DRAFT_DESIGN_INPUT,
		"source": note,
	}


static func assumption(note: String) -> Dictionary:
	return {
		"kind": MANUAL_ASSUMPTION,
		"source": note,
	}


static func not_measured(reason: String) -> Dictionary:
	return {
		"kind": NOT_MEASURED,
		"reason": reason,
	}


static func not_measured_value(reason: String) -> Dictionary:
	return {
		"value": null,
		"provenance": not_measured(reason),
	}


static func is_valid(record: Dictionary) -> bool:
	return str(record.get("kind", "")) in ALL
