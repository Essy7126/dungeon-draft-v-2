extends Node

const FLOW_PROBE := preload(
	"res://tools/combat_to_next_room_flow_probe.gd"
)


func _ready() -> void:
	var probe := FLOW_PROBE.new()
	probe.name = "CombatToNextRoomFlowProbe"
	GameManager.add_child(probe)
	probe.start.call_deferred()

