@tool
class_name SkillTreeEffectSummaryService
extends RefCounted


static func summarize_node(node: SkillUpgradeData) -> String:
	if node == null or node.spell_modifiers.is_empty():
		return "Aucun effet configuré."
	var summaries: PackedStringArray = []
	for modifier in node.spell_modifiers:
		if modifier != null:
			summaries.append(summarize_modifier(modifier))
	return "\n".join(summaries) if not summaries.is_empty() \
		else "Aucun effet valide."


static func summarize_modifier(modifier: SpellModifier) -> String:
	if modifier == null:
		return "Modificateur manquant."
	if modifier is SpellModSkillTreeEffect:
		return _skill_tree_effect(modifier as SpellModSkillTreeEffect)
	var name := modifier.modifier_name.strip_edges()
	if name.is_empty():
		name = modifier.get_script().get_global_name() \
			if modifier.get_script() is Script else modifier.get_class()
	return "%s — effet spécialisé." % name


static func effect_type_label(effect_type: int) -> String:
	match effect_type:
		SpellModSkillTreeEffect.EffectType.DAMAGE_ALL:
			return "Dégâts supplémentaires"
		SpellModSkillTreeEffect.EffectType.DAMAGE_CENTER:
			return "Dégâts sur la case centrale"
		SpellModSkillTreeEffect.EffectType.DAMAGE_LOW_HP:
			return "Dégâts sur une cible affaiblie"
		SpellModSkillTreeEffect.EffectType.DAMAGE_BACKSTAB:
			return "Dégâts dans le dos"
		SpellModSkillTreeEffect.EffectType.DAMAGE_BACKSTAB_OR_LOW_HP:
			return "Dégâts dans le dos ou sur cible affaiblie"
		SpellModSkillTreeEffect.EffectType.RANGE:
			return "Portée"
		SpellModSkillTreeEffect.EffectType.HEAL, SpellModSkillTreeEffect.EffectType.HEAL_LOW_HP:
			return "Soin"
		SpellModSkillTreeEffect.EffectType.SHIELD_TARGET, \
				SpellModSkillTreeEffect.EffectType.SHIELD_CASTER_IF_ALLY, \
				SpellModSkillTreeEffect.EffectType.SHIELD_ALLIES_ON_AREA, \
				SpellModSkillTreeEffect.EffectType.ADJACENT_SHIELD, \
				SpellModSkillTreeEffect.EffectType.SHIELD_CASTER:
			return "Bouclier"
		SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_TARGET, \
				SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_CASTER, \
				SpellModSkillTreeEffect.EffectType.MP_ALLIES_ON_AREA:
			return "PM au prochain tour"
		SpellModSkillTreeEffect.EffectType.STATUS_DOT:
			return "Dégâts sur plusieurs tours"
		SpellModSkillTreeEffect.EffectType.STATUS_SLOW:
			return "Ralentissement"
		SpellModSkillTreeEffect.EffectType.STATUS_REGEN:
			return "Régénération"
		SpellModSkillTreeEffect.EffectType.STATUS_VULNERABILITY:
			return "Vulnérabilité"
		SpellModSkillTreeEffect.EffectType.STATUS_OUTGOING_DAMAGE:
			return "Modification des dégâts infligés"
		SpellModSkillTreeEffect.EffectType.AREA_CARDINAL:
			return "Agrandissement de zone"
		SpellModSkillTreeEffect.EffectType.PUSH_BONUS, \
				SpellModSkillTreeEffect.EffectType.PUSH_EXACT:
			return "Poussée"
		SpellModSkillTreeEffect.EffectType.COLLISION_BONUS, \
				SpellModSkillTreeEffect.EffectType.COLLISION_EXACT:
			return "Dégâts de collision"
		SpellModSkillTreeEffect.EffectType.TERRAIN_DURATION:
			return "Durée du terrain"
		SpellModSkillTreeEffect.EffectType.TERRAIN_DAMAGE:
			return "Dégâts du terrain"
		SpellModSkillTreeEffect.EffectType.CLEANSE:
			return "Retrait d’effets négatifs"
		SpellModSkillTreeEffect.EffectType.ADJACENT_HEAL_RATIO:
			return "Soin partagé"
		SpellModSkillTreeEffect.EffectType.ATTACK_BUFF:
			return "Bonus d’attaque"
		SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET:
			return "Déplacement du lanceur"
		SpellModSkillTreeEffect.EffectType.ALLOW_FREE_CELL_TARGET:
			return "Ciblage d’une case libre"
		_:
			return "Effet spécialisé"


static func _skill_tree_effect(effect: SpellModSkillTreeEffect) -> String:
	var target := _target_label(effect.target_scope)
	match effect.effect_type:
		SpellModSkillTreeEffect.EffectType.DAMAGE_ALL, \
				SpellModSkillTreeEffect.EffectType.DAMAGE_CENTER:
			return "Ajoute %d dégâts à %s." % [effect.amount, target]
		SpellModSkillTreeEffect.EffectType.DAMAGE_LOW_HP:
			return "Ajoute %d dégâts si la cible possède moins de %d %% de ses PV." % [
				effect.amount, roundi(effect.threshold_ratio * 100.0),
			]
		SpellModSkillTreeEffect.EffectType.DAMAGE_BACKSTAB:
			return "Ajoute %d dégâts lorsque la cible est attaquée dans le dos." % effect.amount
		SpellModSkillTreeEffect.EffectType.DAMAGE_BACKSTAB_OR_LOW_HP:
			return "Ajoute %d dégâts dans le dos ou sous %d %% de PV." % [
				effect.amount, roundi(effect.threshold_ratio * 100.0),
			]
		SpellModSkillTreeEffect.EffectType.RANGE:
			return "Augmente la portée de %d case(s)." % effect.amount
		SpellModSkillTreeEffect.EffectType.HEAL, \
				SpellModSkillTreeEffect.EffectType.HEAL_LOW_HP:
			return "Ajoute %d points de soin à %s." % [effect.amount, target]
		SpellModSkillTreeEffect.EffectType.SHIELD_TARGET, \
				SpellModSkillTreeEffect.EffectType.SHIELD_CASTER_IF_ALLY, \
				SpellModSkillTreeEffect.EffectType.SHIELD_ALLIES_ON_AREA, \
				SpellModSkillTreeEffect.EffectType.ADJACENT_SHIELD, \
				SpellModSkillTreeEffect.EffectType.SHIELD_CASTER:
			return "Accorde %d points de bouclier à %s." % [effect.amount, target]
		SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_TARGET, \
				SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_CASTER, \
				SpellModSkillTreeEffect.EffectType.MP_ALLIES_ON_AREA:
			return "Ajoute %d PM à %s au prochain tour." % [effect.amount, target]
		SpellModSkillTreeEffect.EffectType.STATUS_DOT:
			return "Applique %s : %d dégâts pendant %d tour(s)." % [
				effect.status_name if not effect.status_name.is_empty() else "un statut",
				effect.amount,
				effect.duration,
			]
		SpellModSkillTreeEffect.EffectType.STATUS_SLOW:
			return "Retire %d PM pendant %d tour(s) à %s." % [
				effect.amount, effect.duration, target,
			]
		SpellModSkillTreeEffect.EffectType.STATUS_REGEN:
			return "Rend %d PV pendant %d tour(s) à %s." % [
				effect.amount, effect.duration, target,
			]
		SpellModSkillTreeEffect.EffectType.PUSH_BONUS, \
				SpellModSkillTreeEffect.EffectType.PUSH_EXACT:
			return "Pousse %s de %d case(s)." % [target, effect.amount]
		SpellModSkillTreeEffect.EffectType.COLLISION_BONUS, \
				SpellModSkillTreeEffect.EffectType.COLLISION_EXACT:
			return "Ajoute %d dégâts de collision." % effect.amount
		SpellModSkillTreeEffect.EffectType.CLEANSE:
			return "Retire jusqu’à %d effet(s) négatif(s) de %s." % [effect.amount, target]
		SpellModSkillTreeEffect.EffectType.ADJACENT_HEAL_RATIO:
			return "Partage %d %% du soin avec les alliés adjacents." % roundi(effect.ratio * 100.0)
		SpellModSkillTreeEffect.EffectType.ALLOW_FREE_CELL_TARGET:
			return "Autorise le sort à cibler une case libre."
		SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET:
			return "Déplace le lanceur près de la cible."
		_:
			return "%s : valeur principale %d." % [
				effect_type_label(effect.effect_type), effect.amount,
			]


static func _target_label(scope: int) -> String:
	match scope:
		SpellModSkillTreeEffect.TargetScope.PRIMARY_ENEMY:
			return "la cible ennemie"
		SpellModSkillTreeEffect.TargetScope.PRIMARY_ALLY:
			return "la cible alliée"
		SpellModSkillTreeEffect.TargetScope.AFFECTED_ALLIES:
			return "les alliés affectés"
		SpellModSkillTreeEffect.TargetScope.CASTER:
			return "le lanceur"
		_:
			return "les ennemis affectés"
