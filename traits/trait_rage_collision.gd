# traits/trait_rage_collision.gd
# ============================================================
# IMPACT BERSERKER — payoff de l'école Rage (placement).
#
# « Quand la jauge est haute, les collisions font mal. »
# Pendant l'Éveil d'un porteur de Rage, lorsqu'une de ses poussées encastre un
# ennemi (dans un mur, un bord, ou un autre ennemi), la cible percutée — et le
# bloqueur s'il s'agit d'un ennemi — subissent des dégâts.
#
# Trait autonome : écoute EventBus.unit_collided, ne touche jamais battle.gd.
# Le montant des dégâts est data-driven (energy_type.awakening_collision_damage,
# réglé dans rage.tres), donc aucun effet hors Rage / hors Éveil.
# ============================================================

class_name TraitRageCollision
extends Trait

func _trait_name() -> String:
	return "trait_rage_collision"

func _activate() -> void:
	EventBus.unit_collided.connect(_on_unit_collided)

func _deactivate() -> void:
	if EventBus.unit_collided.is_connected(_on_unit_collided):
		EventBus.unit_collided.disconnect(_on_unit_collided)

func _on_unit_collided(pusher, pushed, blocker) -> void:
	if pusher != owner or owner == null or not owner.is_alive or not owner.has_energy():
		return
	# Gate école + état : uniquement Rage, et uniquement pendant l'Éveil.
	if owner.energy_type.energy_id != "rage" or not owner.has_charge_threshold():
		return
	var dmg: int = int(owner.energy_type.awakening_collision_damage)
	if dmg <= 0:
		return
	_apply(pushed, dmg)
	_apply(blocker, dmg)

# Inflige les dégâts de collision à une victime ennemie (jamais d'allié/soi).
func _apply(victim, dmg: int) -> void:
	if victim == null or not is_instance_valid(victim) or not victim.is_alive:
		return
	if victim.team == owner.team:
		return
	victim.take_damage(dmg, owner, Spell.DamageType.PHYSICAL, Spell.Element.NONE)
	DebugLogger.debug(DebugLogger.LogCategory.STATS,
		"%s : collision Berserker inflige %d a %s" % [owner.unit_name, dmg, victim.unit_name])
