# traits/trait_hardened_front.gd
# ============================================================
# PEAU DURCIE — le rouage du boss « Le Colosse » (design §12).
#
# « Durcit à chaque coup reçu de face, mais reste vulnérable de dos et de côté. »
# EventBus.damage_dealt est émis APRÈS application des dégâts (point d'émission
# unique, doc dans event_bus.gd) : ce trait ne peut donc pas bloquer le coup en
# cours, seulement faire grandir une résistance qui s'applique aux coups
# SUIVANTS — exactement ce que « durcit à chaque coup » décrit.
#
# Casse une école qui bourrine de face en boucle (Foi qui veut juste taper),
# récompense une école qui repositionne (Rage : le retourner, le pousser de
# côté ; le contourner en marchant dans son dos).
# ============================================================

class_name TraitHardenedFront
extends Trait

var _armure_per_hit: float = 15.0

func _trait_name() -> String:
	return "trait_hardened_front"

func configure(params: Dictionary) -> void:
	_armure_per_hit = params.get("armure_per_hit", _armure_per_hit)

func _activate() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _deactivate() -> void:
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)

func _on_damage_dealt(target, attacker, amount: int, _category, _element, _is_crit) -> void:
	if target != owner or owner == null or not owner.is_alive or amount <= 0:
		return
	if attacker == null or not is_instance_valid(attacker):
		return
	var attack_dir := _snap_to_cardinal(attacker.grid_pos - owner.grid_pos)
	if attack_dir != owner.facing_dir:
		return
	owner.armure.add_modifier(_armure_per_hit, Stat.ModType.FLAT, source_id, -1)
	owner.stats_changed.emit(owner)
	DebugLogger.debug(DebugLogger.LogCategory.STATS,
		"%s durcit : +%.0f armure (coup de face)" % [owner.unit_name, _armure_per_hit])

# Meme motif que SpellCaster._push_unit/_pull_unit et Unit._snap_to_cardinal.
func _snap_to_cardinal(delta: Vector2i) -> Vector2i:
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		return Vector2i(sign(delta.x), 0)
	return Vector2i(0, sign(delta.y))
