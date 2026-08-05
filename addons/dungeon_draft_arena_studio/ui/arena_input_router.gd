@tool
class_name ArenaInputRouter
extends RefCounted

## Autorité unique des événements d'un viewport d'arène. Il déduplique un même
## InputEvent et ne délègue qu'au contrôleur/canvas qui possède le document.

enum ArenaInputMode {
	IDLE,
	PAN,
	PAINT_CELL,
	PAINT_TERRAIN,
	PLACE_WALL,
	PLACE_SPAWN,
	TRANSFORM_GRID,
	DRAG_ANCHOR,
}

var mode := ArenaInputMode.IDLE
var active_tool := -1
var gesture_active := false
var processed_event_count := 0
var consumed_event_count := 0
var last_consumer := ""
var _last_event_instance_id := 0


func set_active_tool(tool: int, input_mode: int) -> void:
	active_tool = tool
	if not gesture_active:
		mode = input_mode


func begin_gesture(input_mode: int, consumer: String) -> void:
	gesture_active = true
	mode = input_mode
	last_consumer = consumer


func finish_gesture(idle_mode := ArenaInputMode.IDLE) -> void:
	gesture_active = false
	mode = idle_mode
	last_consumer = ""


func cancel_gesture(idle_mode := ArenaInputMode.IDLE) -> void:
	finish_gesture(idle_mode)


func route_canvas_event(event: InputEvent, canvas: Object) -> bool:
	return _route_once(event, canvas, &"_route_canvas_input", "studio_canvas")


func route_standalone_event(event: InputEvent, controller: Object) -> bool:
	return _route_once(event, controller, &"_route_standalone_input", "standalone_lab")


func _route_once(
		event: InputEvent,
		target: Object,
		method: StringName,
		consumer: String
	) -> bool:
	if event == null or target == null or not target.has_method(method):
		return false
	var event_id := event.get_instance_id()
	if event_id == _last_event_instance_id:
		return false
	_last_event_instance_id = event_id
	processed_event_count += 1
	var consumed := bool(target.call(method, event))
	if consumed:
		consumed_event_count += 1
		last_consumer = consumer
	return consumed


func debug_snapshot() -> Dictionary:
	return {
		"mode": mode,
		"active_tool": active_tool,
		"gesture_active": gesture_active,
		"processed_event_count": processed_event_count,
		"consumed_event_count": consumed_event_count,
		"last_consumer": last_consumer,
	}
