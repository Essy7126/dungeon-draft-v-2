@tool
class_name VFXFlipbookVariant
extends Resource

@export var variant_id: StringName = &""
@export var texture_low: Texture2D
@export var texture_medium: Texture2D
@export var texture_high: Texture2D


func texture_for_quality(quality_tier: int) -> Dictionary:
	match clampi(quality_tier, 0, 2):
		0:
			return {"texture": texture_low, "quality_tier": 0}
		1:
			if texture_medium != null:
				return {"texture": texture_medium, "quality_tier": 1}
			return {"texture": texture_low, "quality_tier": 0}
		_:
			if texture_high != null:
				return {"texture": texture_high, "quality_tier": 2}
			if texture_medium != null:
				return {"texture": texture_medium, "quality_tier": 1}
			return {"texture": texture_low, "quality_tier": 0}
