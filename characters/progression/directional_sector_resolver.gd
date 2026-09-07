class_name DirectionalSectorResolver
extends RefCounted

const SECTOR_FRONT: StringName = &"FRONT"
const SECTOR_SIDE: StringName = &"SIDE"
const SECTOR_REAR: StringName = &"REAR"


static func classify(
		defender_cell: Vector2i,
		defender_facing: Vector2i,
		attacker_cell: Vector2i
	) -> StringName:
	var facing := _cardinal(defender_facing)
	var incoming := _cardinal(attacker_cell - defender_cell)
	if facing == Vector2i.ZERO or incoming == Vector2i.ZERO:
		return SECTOR_SIDE
	var dot: int = facing.x * incoming.x + facing.y * incoming.y
	if dot > 0:
		return SECTOR_FRONT
	if dot < 0:
		return SECTOR_REAR
	return SECTOR_SIDE


static func damage_multiplier(
		data: DirectionalGuardData,
		defender_cell: Vector2i,
		defender_facing: Vector2i,
		attacker_cell: Vector2i
	) -> float:
	if data == null or not data.is_valid():
		return 1.0
	match classify(defender_cell, defender_facing, attacker_cell):
		SECTOR_FRONT:
			return data.front_damage_multiplier
		SECTOR_REAR:
			return data.rear_damage_multiplier
	return data.side_damage_multiplier


static func _cardinal(direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(direction.x) >= abs(direction.y):
		return Vector2i(signi(direction.x), 0)
	return Vector2i(0, signi(direction.y))
