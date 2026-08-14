@tool
class_name VFXFlipbookModuleData
extends VFXModuleData

const SUPPORTED_ANCHORS: Array[StringName] = [
	&"TARGET_WORLD", &"ORIGIN_WORLD", &"FIRST_IMPACT_WORLD",
]

@export var asset: VFXFlipbookAsset
@export var scale_multiplier := Vector2.ONE
@export var rotation_degrees := 0.0
@export_range(0.0, 1.0, 0.01) var opacity := 1.0
@export var color_modulate := Color.WHITE
@export var frame_offset := 0


func _init() -> void:
	module_type = &"FlipbookModule"
	anchor = &"TARGET_WORLD"
