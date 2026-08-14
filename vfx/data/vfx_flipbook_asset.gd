@tool
class_name VFXFlipbookAsset
extends Resource

const PLAYBACK_MODES: Array[StringName] = [&"FIT_MODULE_DURATION", &"SOURCE_FPS"]
const BLEND_MODES: Array[StringName] = [&"MIX", &"ADD", &"PREMULTIPLIED"]
const ALPHA_MODES: Array[StringName] = [&"STRAIGHT", &"PREMULTIPLIED"]
const ART_STATUSES: Array[StringName] = [
	&"TECHNICAL_PLACEHOLDER", &"READY_FOR_HUMAN_REVIEW", &"ART_APPROVED", &"ART_REJECTED",
]
const LICENSE_STATUSES: Array[StringName] = [
	&"INTERNAL_TEST", &"EVALUATION_ONLY", &"COMMERCIAL_CLEARED",
]

@export var schema_version := 1
@export var asset_id: StringName = &""
@export var display_name := "Flipbook VFX"
@export var variants: Array[VFXFlipbookVariant] = []
@export_range(1, 128, 1) var columns := 1
@export_range(1, 128, 1) var rows := 1
@export_range(1, 16384, 1) var frame_count := 1
@export_range(0.01, 240.0, 0.01) var frames_per_second := 30.0
@export var loop := false
@export var playback_mode: StringName = &"FIT_MODULE_DURATION"
@export var blend_mode: StringName = &"MIX"
@export var alpha_mode: StringName = &"STRAIGHT"
@export var pivot_normalized := Vector2(0.5, 0.5)
@export var nominal_size_in_cells := Vector2.ONE
@export var local_offset := Vector2.ZERO
@export var art_status: StringName = &"TECHNICAL_PLACEHOLDER"
@export var license_status: StringName = &"INTERNAL_TEST"
@export_file("*.json") var manifest_path := ""


func frame_capacity() -> int:
	return maxi(columns, 0) * maxi(rows, 0)


func default_duration() -> float:
	return float(frame_count) / maxf(frames_per_second, 0.01)


func validate_structure() -> Array[String]:
	var errors: Array[String] = []
	if schema_version != 1:
		errors.append("schema_version flipbook non supporté : %d." % schema_version)
	if asset_id == &"":
		errors.append("asset_id flipbook requis.")
	if columns <= 0 or rows <= 0:
		errors.append("columns et rows doivent être positifs.")
	if frame_count <= 0 or frame_count > frame_capacity():
		errors.append("frame_count doit être compris dans la capacité de l’atlas.")
	if frames_per_second <= 0.0:
		errors.append("frames_per_second doit être positif.")
	if variants.is_empty():
		errors.append("Au moins une variante flipbook est requise.")
	var ids := {}
	for variant in variants:
		if variant == null or variant.variant_id == &"":
			errors.append("variant_id non vide requis.")
			continue
		if ids.has(variant.variant_id):
			errors.append("variant_id dupliqué : %s." % variant.variant_id)
		ids[variant.variant_id] = true
		if variant.texture_low == null:
			errors.append("Texture LOW requise pour %s." % variant.variant_id)
	if playback_mode not in PLAYBACK_MODES:
		errors.append("playback_mode inconnu : %s." % playback_mode)
	if blend_mode not in BLEND_MODES:
		errors.append("blend_mode inconnu : %s." % blend_mode)
	if alpha_mode not in ALPHA_MODES:
		errors.append("alpha_mode inconnu : %s." % alpha_mode)
	if pivot_normalized.x < 0.0 or pivot_normalized.x > 1.0 \
			or pivot_normalized.y < 0.0 or pivot_normalized.y > 1.0:
		errors.append("pivot_normalized doit rester dans [0, 1].")
	if nominal_size_in_cells.x <= 0.0 or nominal_size_in_cells.y <= 0.0:
		errors.append("nominal_size_in_cells doit être strictement positive.")
	if art_status not in ART_STATUSES:
		errors.append("art_status flipbook inconnu : %s." % art_status)
	if license_status not in LICENSE_STATUSES:
		errors.append("license_status flipbook inconnu : %s." % license_status)
	return errors


func select_variant(local_seed: int) -> VFXFlipbookVariant:
	if variants.is_empty():
		return null
	return variants[posmod(local_seed, variants.size())]


func select_texture(variant: VFXFlipbookVariant, quality_tier: int) -> Dictionary:
	if variant == null:
		return {"texture": null, "quality_tier": -1}
	return variant.texture_for_quality(quality_tier)
