# traits/trait_spell_modifier.gd
# ============================================================
# TRAIT PORTEUR DE SPELL MODIFIER — le pont reward → pipeline.
#
# Un reward/une relique donne un TraitData dont les params contiennent un
# SpellModifier (.tres). Ce trait ne fait RIEN de lui-même : il expose le
# modifier via get_spell_modifiers(), et SpellCaster le ramasse au début de
# chaque cast du porteur. C'est la voie data-driven : transformer un sort
# = un .tres de modifier + un .tres de TraitData, zéro code dans le caster.
# ============================================================

class_name TraitSpellModifier
extends Trait

var _modifier: SpellModifier = null

func _trait_name() -> String:
	return "trait_spell_modifier"

func configure(params: Dictionary) -> void:
	_modifier = params.get("modifier", null)

# Lu par SpellCaster._gather_modifiers à chaque cast du porteur.
func get_spell_modifiers() -> Array:
	return [_modifier] if _modifier != null else []
