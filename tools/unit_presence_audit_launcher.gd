extends Node

const ObserverScript := preload("res://tools/unit_presence_audit_observer.gd")


func _ready() -> void:
	var previous := GameManager.get_node_or_null("UnitPresenceAuditObserver")
	if is_instance_valid(previous):
		previous.free()
	var observer := ObserverScript.new()
	observer.name = "UnitPresenceAuditObserver"
	GameManager.add_child(observer)
	observer.begin()
