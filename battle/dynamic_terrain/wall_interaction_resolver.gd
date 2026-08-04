class_name WallInteractionResolver
extends RefCounted

## Point central des reactions elementaires. Les sorts de production pourront
## plus tard ne transmettre que leur element a cette facade.

const NONE := &"NONE"
const FIRE := &"FIRE"
const ICE := &"ICE"
const WATER := &"WATER"


static func resolve(
	wall: DynamicWall,
	incoming_element: StringName,
	allow_base_transform := true
	) -> Dictionary:
	var result := {
		"handled": false,
		"action": &"none",
		"damage": 0,
		"variant": wall.variant if wall != null else -1,
		"destroyed": false,
	}
	if wall == null or not is_instance_valid(wall) or not wall.is_blocking_state():
		return result

	match wall.variant:
		DynamicWall.WallVariant.FIRE:
			if incoming_element == WATER:
				result.damage = wall.apply_damage(10, WATER)
				if wall.is_blocking_state():
					wall.change_variant(DynamicWall.WallVariant.BASE)
				result.action = &"steam_to_base"
				result.handled = true
			elif incoming_element == ICE:
				result.damage = wall.apply_damage(10, ICE)
				if wall.is_blocking_state():
					wall.change_variant(DynamicWall.WallVariant.BASE)
				result.action = &"thermal_shock"
				result.handled = true
		DynamicWall.WallVariant.ICE:
			if incoming_element == FIRE:
				result.damage = wall.apply_damage(12, FIRE)
				result.action = &"melt"
				result.handled = true
			elif incoming_element == WATER:
				wall.heal(3)
				wall.extend_duration(1)
				result.action = &"reinforce_ice"
				result.handled = true
		DynamicWall.WallVariant.BASE:
			if allow_base_transform and incoming_element == FIRE:
				result.handled = wall.change_variant(DynamicWall.WallVariant.FIRE)
				result.action = &"ignite" if result.handled else &"none"
			elif allow_base_transform and incoming_element == ICE:
				result.handled = wall.change_variant(DynamicWall.WallVariant.ICE)
				result.action = &"freeze" if result.handled else &"none"

	result.variant = wall.variant
	result.destroyed = wall.wall_state == DynamicWall.WallState.DESTROYED
	return result
