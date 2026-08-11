@tool
class_name VFXProfile
extends Resource

const RENDER_POLICIES := [
	&"SYSTEM_PROCEDURAL", &"HYBRID_CAPABLE", &"HYBRID_RECOMMENDED", &"SIGNATURE_ASSET",
]
const ART_STATUSES := [
	&"TECHNICAL_PLACEHOLDER", &"READY_FOR_HUMAN_REVIEW", &"ART_APPROVED",
	&"ART_REJECTED", &"HISTORICAL",
]

@export var schema_version := 1
@export var profile_id: StringName = &""
@export var display_name := "VFX Profile"
@export var category: StringName = &"SYSTEM"
@export var render_policy: StringName = &"SYSTEM_PROCEDURAL"
@export var art_status: StringName = &"TECHNICAL_PLACEHOLDER"
@export var tags: Array[StringName] = []
@export var sequences: Array[VFXSequenceData] = []
@export var exposed_parameters: Dictionary = {}
@export var context_requirements: Array[StringName] = []
@export_range(0.05, 30.0, 0.05) var maximum_duration := 3.0
@export var quality_policy: StringName = &"SCALABLE"


func get_sequence(sequence_id: StringName) -> VFXSequenceData:
	for sequence in sequences:
		if sequence != null and sequence.sequence_id == sequence_id:
			return sequence
	return null
