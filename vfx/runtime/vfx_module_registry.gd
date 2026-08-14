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
	&"FlipbookModule",
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
	if module_data.module_type == &"FlipbookModule":
		if not module_data is VFXFlipbookModuleData:
			return null
		var flipbook := module_data as VFXFlipbookModuleData
		if flipbook.asset == null or not flipbook.asset.validate_structure().is_empty():
			return null
		var flipbook_visual := VFXFlipbookVisual.new()
		flipbook_visual.name = str(module_data.module_id)
		flipbook_visual.configure(module_data, context, seed)
		if flipbook_visual.sprite == null:
			flipbook_visual.free()
			return null
		return flipbook_visual
	var visual := VFXModuleVisual.new()
	visual.name = str(module_data.module_id)
	visual.configure(module_data, context, seed)
	return visual
