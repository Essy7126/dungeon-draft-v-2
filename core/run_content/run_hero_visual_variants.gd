class_name RunHeroVisualVariants
extends RefCounted
## Presentation choices only. Gameplay remains owned by the run's hero profile.

const PAINTED_G: StringName = &"painted_g"
const PASSE_RIVE: StringName = &"passe_rive"
const PAINTED_SCENE_PATH := "res://characters/achilles/AchillesPaintedGUnitView.tscn"
const PAINTED_FRAMES_PATH := "res://assets/characters/Achilles/sprites_painted_g/achilles_sprite_frames.tres"
const PAINTED_PORTRAIT_PATH := "res://assets/characters/Achilles/sprites_painted_g/achilles_portrait.tres"
const PASSE_RIVE_SCENE_PATH := "res://characters/achilles/PasseRiveIsoUnitView.tscn"
const PASSE_RIVE_FRAMES_PATH := "res://assets/characters/Achilles/passe_rive_iso_v1/sprite_frames.tres"
const PASSE_RIVE_PORTRAIT_PATH := "res://assets/characters/Achilles/passe_rive_iso_v1/portrait.tres"


static func validation_errors(variants: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for character_id in variants:
		if not (character_id is String or character_id is StringName) \
				or str(character_id) != "achilles" \
				or not (variants[character_id] is String or variants[character_id] is StringName) \
				or str(variants[character_id]) not in [str(PAINTED_G), str(PASSE_RIVE)]:
			errors.append("Variante visuelle de héros inconnue : %s." % str(character_id))
	return errors


static func apply_to_runtime(runtime: UnitData, variants: Dictionary) -> bool:
	var variant := StringName(variants.get(str(runtime.get_effective_unit_id()), &""))
	if variant == &"":
		return true
	if runtime.get_effective_unit_id() != &"achilles" or variant not in [PAINTED_G, PASSE_RIVE]:
		return false
	var scene_path := PASSE_RIVE_SCENE_PATH if variant == PASSE_RIVE else PAINTED_SCENE_PATH
	var frames_path := PASSE_RIVE_FRAMES_PATH if variant == PASSE_RIVE else PAINTED_FRAMES_PATH
	var portrait_path := PASSE_RIVE_PORTRAIT_PATH if variant == PASSE_RIVE else PAINTED_PORTRAIT_PATH
	if not ResourceLoader.exists(scene_path, "PackedScene") \
			or not ResourceLoader.exists(frames_path, "SpriteFrames") \
			or not ResourceLoader.exists(portrait_path, "Texture2D"):
		return false
	runtime.visual_scene = load(scene_path) as PackedScene
	runtime.preview_visual_scene = null
	runtime.portrait_texture_override = load(portrait_path) as Texture2D
	runtime.preview_sprite_frames = null
	runtime.preview_sprite_frames_path = frames_path
	runtime.preview_sprite_animation = &"idle_E"
	return runtime.visual_scene != null and runtime.preview_sprite_frames != null and runtime.portrait_texture_override != null
