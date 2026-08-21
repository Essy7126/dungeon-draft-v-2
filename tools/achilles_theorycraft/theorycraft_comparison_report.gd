class_name TheorycraftComparisonReport
extends RefCounted

var schema_version := 1
var builds: Array = []
var contexts: Array = []
var ap_sequences := {}
var unused_ap := {}
var damage := {}
var mobility := {}
var range := {}
var area := {}
var defense := {}
var control := {}
var recovery := {}
var exposure := {}
var reliability := {}
var frequency := {}
var warnings: Array = []
var not_measured: Array = []
var provenance := {}
var deltas: Array = []


func to_dict() -> Dictionary:
	var output_provenance := provenance.duplicate(true)
	for field in [
		"schema_version", "builds", "contexts", "ap_sequences", "unused_ap",
		"damage", "mobility", "range", "area", "defense", "control",
		"recovery", "exposure", "reliability", "frequency", "warnings",
		"not_measured", "deltas",
	]:
		if not output_provenance.has(field) \
				or not output_provenance[field] is Dictionary \
				or not AchillesTheorycraftProvenance.is_valid(output_provenance[field]):
			output_provenance[field] = AchillesTheorycraftProvenance.not_measured(
				"No valid provenance record was supplied for this report field."
			)
	return {
		"schema_version": schema_version,
		"builds": builds.duplicate(true),
		"contexts": contexts.duplicate(true),
		"ap_sequences": ap_sequences.duplicate(true),
		"unused_ap": unused_ap.duplicate(true),
		"damage": damage.duplicate(true),
		"mobility": mobility.duplicate(true),
		"range": range.duplicate(true),
		"area": area.duplicate(true),
		"defense": defense.duplicate(true),
		"control": control.duplicate(true),
		"recovery": recovery.duplicate(true),
		"exposure": exposure.duplicate(true),
		"reliability": reliability.duplicate(true),
		"frequency": frequency.duplicate(true),
		"warnings": warnings.duplicate(true),
		"not_measured": not_measured.duplicate(true),
		"provenance": output_provenance,
		"deltas": deltas.duplicate(true),
	}
