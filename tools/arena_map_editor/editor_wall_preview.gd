class_name ArenaEditorWallPreview
extends Node2D

const WALL_TEXTURES := {
	ArenaMapDocument.WallType.BASE: preload("res://tools/labs/dynamic_arena/assets/normalized/wall_base.png"),
	ArenaMapDocument.WallType.FIRE: preload("res://tools/labs/dynamic_arena/assets/normalized/wall_fire.png"),
	ArenaMapDocument.WallType.ICE: preload("res://tools/labs/dynamic_arena/assets/normalized/wall_ice.png"),
}

var wall_type := ArenaMapDocument.WallType.BASE


func configure(type: int) -> void:
	wall_type = clampi(type, ArenaMapDocument.WallType.BASE, ArenaMapDocument.WallType.ICE)
	($VisualRoot/Sprite2D as Sprite2D).texture = WALL_TEXTURES[wall_type]
	name = "Wall_%s" % ArenaMapDocument.WALL_NAMES[wall_type]

