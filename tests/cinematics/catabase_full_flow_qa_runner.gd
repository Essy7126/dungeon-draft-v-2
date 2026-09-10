extends "res://tests/cinematics/catabase_threshold_flow_qa.gd"
## Preserve the full natural introduction, then exercise its playable continuation.


func _init() -> void:
	_ending = "natural"
	_output = "res://artifacts/dev/catabase-full-flow-%d" % int(Time.get_unix_time_from_system())
