extends RefCounted
## Constant visual calibration. Never fit an individual frame to its bounding box.
const Stance := preload("res://characters/achilles/2d/passe_rive_s22_registration.gd")
const Data := preload("res://characters/achilles/2d/passe_rive_registration_data.gd")
const Directions := preload("res://characters/achilles/2d/passe_rive_s20_directions.gd")


static func factor(clip: String, facing: String) -> float:
	var source := Directions.source(clip, facing)
	return float(Data.FACTORS.get(clip if source.is_empty() else source, 1.0))


static func stance_scale(clip: String, facing: String) -> float:
	return Stance.stance_scale(clip) * factor(clip, facing)
