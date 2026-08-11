class_name VFXModuleRegistry
extends RefCounted

const MODULE_TYPES: Array[StringName] = [
	&"ShieldSurfaceModule",
	&"ShieldRippleModule",
	&"LightningModule",
	&"PathRibbonModule",
	&"CellOverlayModule",
	&"ParticleBurstModule",
	&"FlashModule",
]


static func knows(module_type: StringName) -> bool:
	return module_type in MODULE_TYPES


static func create_visual(
		module_data: VFXModuleData,
		context: VFXExecutionContext,
		seed: int
	) -> VFXModuleVisual:
	if module_data == null or not knows(module_data.module_type):
		return null
	var visual := VFXModuleVisual.new()
	visual.name = str(module_data.module_id)
	visual.configure(module_data, context, seed)
	return visual
