@tool
class_name ArenaReadinessReport
extends Resource

## Rapport agrege. Chaque booleen est derive de son domaine et aucune preuve
## de projection ne peut tenir lieu de preuve de scene runtime.
@export var data_report: ArenaReadinessSection = ArenaReadinessSection.new()
@export var topology_report: ArenaReadinessSection = ArenaReadinessSection.new()
@export var visual_report: ArenaReadinessSection = ArenaReadinessSection.new()
@export var runtime_scene_report: ArenaRuntimeSceneReport = ArenaRuntimeSceneReport.new()
@export var production_report: ArenaReadinessSection = ArenaReadinessSection.new()
@export var integration_report: ArenaReadinessSection = ArenaReadinessSection.new()

@export var data_valid := false
@export var runtime_bootable := false
@export var ready_to_test := false
@export var ready_to_produce := false
@export var ready_to_integrate := false


func recompute() -> ArenaReadinessReport:
	data_valid = data_report != null and data_report.passed()
	runtime_bootable = runtime_scene_report != null \
		and runtime_scene_report.runtime_contract_satisfied()
	ready_to_test = data_valid and runtime_bootable
	ready_to_produce = data_valid \
		and visual_report != null and visual_report.passed() \
		and production_report != null and production_report.passed()
	ready_to_integrate = ready_to_produce \
		and integration_report != null and integration_report.passed() \
		and runtime_bootable
	return self


func to_dict() -> Dictionary:
	return {
		"data_report": data_report.to_dict() if data_report != null else {},
		"topology_report": topology_report.to_dict() if topology_report != null else {},
		"visual_report": visual_report.to_dict() if visual_report != null else {},
		"runtime_scene_report": runtime_scene_report.to_dict() \
			if runtime_scene_report != null else {},
		"production_report": production_report.to_dict() \
			if production_report != null else {},
		"integration_report": integration_report.to_dict() \
			if integration_report != null else {},
		"data_valid": data_valid,
		"runtime_bootable": runtime_bootable,
		"ready_to_test": ready_to_test,
		"ready_to_produce": ready_to_produce,
		"ready_to_integrate": ready_to_integrate,
	}
