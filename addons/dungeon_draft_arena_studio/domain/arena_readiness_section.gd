@tool
class_name ArenaReadinessSection
extends Resource

## Etat explicite d'un domaine de readiness. Un rapport absent reste NOT_RUN :
## il n'est jamais promu implicitement en succes.
enum State {
	NOT_RUN,
	PASS,
	PASS_WITH_WARNINGS,
	FAIL,
	BLOCKED,
}

const STATE_NAMES := [
	"NOT_RUN",
	"PASS",
	"PASS_WITH_WARNINGS",
	"FAIL",
	"BLOCKED",
]

@export_enum("NOT_RUN", "PASS", "PASS_WITH_WARNINGS", "FAIL", "BLOCKED")
var state: int = State.NOT_RUN
@export var code: StringName = &"NOT_RUN"
@export_multiline var summary := ""
@export var errors: Array[String] = []
@export var warnings: Array[String] = []
@export var information: Array[String] = []
@export var details: Dictionary = {}
@export var duration_ms := 0.0


func passed() -> bool:
	return state == State.PASS or state == State.PASS_WITH_WARNINGS


func blocks_readiness() -> bool:
	return state == State.FAIL or state == State.BLOCKED


func was_run() -> bool:
	return state != State.NOT_RUN


func state_name() -> String:
	return state_name_for(state)


static func state_name_for(value: int) -> String:
	if value < 0 or value >= STATE_NAMES.size():
		return "UNKNOWN"
	return str(STATE_NAMES[value])


func to_dict() -> Dictionary:
	return {
		"state": state,
		"state_name": state_name(),
		"code": str(code),
		"summary": summary,
		"errors": errors.duplicate(),
		"warnings": warnings.duplicate(),
		"information": information.duplicate(),
		"details": details.duplicate(true),
		"duration_ms": duration_ms,
	}
