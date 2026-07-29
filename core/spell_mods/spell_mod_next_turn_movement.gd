class_name SpellModNextTurnMovement
extends SpellModifier

enum Recipient {
	CASTER,
	PRIMARY_TARGET,
}

@export var recipient: Recipient = Recipient.PRIMARY_TARGET
@export_range(-99, 99) var movement_points: int = 0


func on_cast_complete(ctx) -> void:
	if movement_points == 0 or ctx == null or ctx.caster == null:
		return
	var recipient_unit := ctx.caster as Unit
	if recipient == Recipient.PRIMARY_TARGET:
		recipient_unit = ctx.primary_target as Unit
		if recipient_unit == null or recipient_unit.team == ctx.caster.team:
			return
		var result = ctx.damage_result_by_unit.get(recipient_unit)
		if result == null or result.dodged:
			return
	if recipient_unit == null or not recipient_unit.is_alive:
		return
	recipient_unit.queue_next_turn_mp_modifier(movement_points)
