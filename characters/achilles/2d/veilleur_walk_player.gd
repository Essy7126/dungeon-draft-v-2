extends Node2D

## Distance-driven walk prototype. Does not claim an idle or combat animation.
const MANIFEST := "res://assets/characters/Achilles/veilleur_walk_iso_v1/manifest.json"
const FRAMES := preload("res://assets/characters/Achilles/veilleur_walk_iso_v1/walk_frames.tres")
@export_file("*.json") var manifest_path := MANIFEST
var data: Dictionary
var sprite: AnimatedSprite2D
var facing := "E"
var phase := 0.0


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = load(data.get("frame_resource", "")) if data.has("frame_resource") else FRAMES
	sprite.centered = false
	sprite.scale = Vector2.ONE * float(data.display_scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	sample(facing, phase)


func sample(direction: String, cycle_phase: float) -> void:
	assert(data.views.has(direction), "Missing Veilleur view: " + direction)
	facing = direction
	phase = fposmod(cycle_phase, 1.0)
	var anchor: Array = data.views[direction].pivot
	sprite.offset = -Vector2(anchor[0], anchor[1])
	sprite.animation = StringName("walk_" + direction)
	var count := sprite.sprite_frames.get_frame_count(sprite.animation)
	sprite.set_frame_and_progress(floori(phase * count) % count, 0.0)


func cycle_distance(direction: String) -> float:
	var stride: Array = data.views[direction].stride
	return Vector2(stride[0], stride[1]).length() * float(data.display_scale)
