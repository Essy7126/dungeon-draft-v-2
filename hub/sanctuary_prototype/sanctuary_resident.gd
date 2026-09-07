extends RefCounted

## The Meshy RGB original is kept intact; a separate connected-background mask
## supplies alpha at rendering time. Both residents share one texture/material.
const SHEET := preload("res://asset/hub/sanctuary_prototype/residents.png")
const MASK := preload("res://asset/hub/sanctuary_prototype/residents_mask.png")
const ALPHA_SHADER := preload("res://hub/sanctuary_prototype/resident_alpha.gdshader")

static func attach_to(entity: Node2D, id: StringName) -> bool:
	if id not in [&"merchant", &"oracle"]:
		return false
	var factor := 0.11
	var region := Rect2(0, 0, 768, 1024) if id == &"merchant" else Rect2(768, 0, 768, 1024)
	var foot := Vector2(454, 954) if id == &"merchant" else Vector2(1068 - 768, 965)
	var shadow := Polygon2D.new()
	shadow.name = "ResidentContactShadow"
	shadow.color = Color(0.025, 0.022, 0.027, 0.28)
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(Vector2(cos(angle) * 16.0, sin(angle) * 5.0))
	shadow.polygon = points
	entity.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.name = "ResidentSprite"
	sprite.texture = SHEET
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.region_filter_clip_enabled = true
	sprite.centered = false
	sprite.scale = Vector2.ONE * factor
	sprite.position = -foot * factor
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = ALPHA_SHADER
	material.set_shader_parameter("silhouette_mask", MASK)
	sprite.material = material
	entity.add_child(sprite)
	return true
