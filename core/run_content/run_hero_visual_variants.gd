class_name RunHeroVisualVariants
extends RefCounted
## Presentation choices only. Gameplay remains owned by the run's hero profile.

const PAINTED_G: StringName = &"painted_g"
const PAINTED_SCENE_PATH := "res://characters/achilles/AchillesPaintedGUnitView.tscn"
const PAINTED_FRAMES_PATH := "res://assets/characters/Achilles/sprites_painted_g/achilles_sprite_frames.tres"
const PAINTED_PORTRAIT_PATH := "res://assets/characters/Achilles/sprites_painted_g/achilles_portrait.tres"


static func validation_errors(variants: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for character_id in variants:
		if not (character_id is String or character_id is StringName) \
				or str(character_id) != "achilles" \
				or not (variants[character_id] is String or variants[character_id] is StringName) \
				or str(variants[character_id]) != str(PAINTED_G):
			errors.append("Variante visuelle de héros inconnue : %s." % str(character_id))
	return errors


static func apply_to_runtime(runtime: UnitData, variants: Dictionary) -> bool:
	var variant := StringName(variants.get(str(runtime.get_effective_unit_id()), &""))
	if variant == &"":
		return true
	if runtime.get_effective_unit_id() != &"achilles" or variant != PAINTED_G:
		return false
	if not ResourceLoader.exists(PAINTED_SCENE_PATH, "PackedScene") \
			or not ResourceLoader.exists(PAINTED_FRAMES_PATH, "SpriteFrames") \
			or not ResourceLoader.exists(PAINTED_PORTRAIT_PATH, "Texture2D"):
		return false
	runtime.visual_scene = load(PAINTED_SCENE_PATH) as PackedScene
	runtime.preview_visual_scene = null
	runtime.portrait_texture_override = load(PAINTED_PORTRAIT_PATH) as Texture2D
	runtime.preview_sprite_frames = null
	runtime.preview_sprite_frames_path = PAINTED_FRAMES_PATH
	runtime.preview_sprite_animation = &"idle_E"
	return runtime.visual_scene != null and runtime.preview_sprite_frames != null and runtime.portrait_texture_override != null
