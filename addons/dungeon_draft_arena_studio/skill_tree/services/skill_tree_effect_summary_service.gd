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


## Résumé destiné au graphe : la liste des modificateurs est ordonnée, donc le
## premier effet valide constitue l'effet principal. Les suivants restent
## accessibles dans le tooltip et l'Inspecteur sans charger toutes les cartes.
static func summarize_node_compact(node: SkillUpgradeData) -> String:
	if node == null or node.spell_modifiers.is_empty():
		return "Aucun effet configuré."
	var primary: SpellModifier = null
	var valid_count := 0
	for modifier in node.spell_modifiers:
		if modifier == null:
			continue
		valid_count += 1
		if primary == null:
			primary = modifier
	if primary == null:
		return "Aucun effet valide."
	var summary := summarize_modifier(primary).replace("\n", " ").strip_edges()
	const MAX_SUMMARY_LENGTH := 105
	if summary.length() > MAX_SUMMARY_LENGTH:
		summary = summary.substr(0, MAX_SUMMARY_LENGTH - 1).strip_edges() + "…"
	if valid_count > 1:
		summary += "\n+%d autre(s) effet(s)" % (valid_count - 1)
	return summary


static func summarize_modifier(modifier: SpellModifier) -> String:
	if modifier == null:
		return "Modificateur manquant."
	if modifier is SpellModSkillTreeEffect:
		return _skill_tree_effect(modifier as SpellModSkillTreeEffect)
	var descriptor := SkillEffectEditorRegistry.new().descriptor_for(modifier)
	if descriptor != null:
		# Phrase courte : le nœud du graphe et le résumé d'une amélioration ne
		# doivent pas empiler cible, condition, durée, fréquence et empilement
		# sur une seule ligne. Le détail vit dans la section repliable.
		return descriptor.short_sentence(modifier)
	var name := modifier.modifier_name.strip_edges()
	if name.is_empty():
		name = modifier.get_script().get_global_name() \
			if modifier.get_script() is Script else modifier.get_class()
	return "%s — descripteur métier manquant." % name


## 33 libellés distincts (charte d'accessibilité : un même libellé ne doit
## jamais désigner deux comportements différents dans un menu). Regroupés par
## famille avec un préfixe court, plutôt que des synonymes ambigus comme
## "Bouclier" répété cinq fois pour cinq comportements runtime différents.
static func effect_type_label(effect_type: int) -> String:
	match effect_type:
		SpellModSkillTreeEffect.EffectType.DAMAGE_ALL:
			return "Dégâts — cible"
		SpellModSkillTreeEffect.EffectType.DAMAGE_CENTER:
			return "Dégâts — case centrale"
		SpellModSkillTreeEffect.EffectType.DAMAGE_LOW_HP:
			return "Dégâts — cible affaiblie"
		SpellModSkillTreeEffect.EffectType.DAMAGE_BACKSTAB:
			return "Dégâts — dans le dos"
		SpellModSkillTreeEffect.EffectType.DAMAGE_BACKSTAB_OR_LOW_HP:
			return "Dégâts — dos ou affaiblie"
		SpellModSkillTreeEffect.EffectType.RANGE:
			return "Portée — augmentée"
		SpellModSkillTreeEffect.EffectType.HEAL:
			return "Soin — cible"
		SpellModSkillTreeEffect.EffectType.HEAL_LOW_HP:
			return "Soin — cible affaiblie"
		SpellModSkillTreeEffect.EffectType.ADJACENT_HEAL_RATIO:
			return "Soin — partagé aux alliés adjacents"
		SpellModSkillTreeEffect.EffectType.SHIELD_TARGET:
			return "Bouclier — cible"
		SpellModSkillTreeEffect.EffectType.SHIELD_CASTER_IF_ALLY:
			return "Bouclier — lanceur après soutien"
		SpellModSkillTreeEffect.EffectType.SHIELD_ALLIES_ON_AREA:
			return "Bouclier — zone"
		SpellModSkillTreeEffect.EffectType.ADJACENT_SHIELD:
			return "Bouclier — adjacent"
		SpellModSkillTreeEffect.EffectType.SHIELD_CASTER:
			return "Bouclier — lanceur"
		SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_TARGET:
			return "PM — cible, prochain tour"
		SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_CASTER:
			return "PM — lanceur, prochain tour"
		SpellModSkillTreeEffect.EffectType.MP_ALLIES_ON_AREA:
			return "PM — zone, prochain tour"
		SpellModSkillTreeEffect.EffectType.STATUS_DOT:
			return "Statut — dégâts par tour"
		SpellModSkillTreeEffect.EffectType.STATUS_SLOW:
			return "Statut — ralentissement"
		SpellModSkillTreeEffect.EffectType.STATUS_REGEN:
			return "Statut — régénération"
		SpellModSkillTreeEffect.EffectType.STATUS_VULNERABILITY:
			return "Statut — vulnérabilité à charges"
		SpellModSkillTreeEffect.EffectType.STATUS_OUTGOING_DAMAGE:
			return "Statut — dégâts infligés modifiés"
		SpellModSkillTreeEffect.EffectType.AREA_CARDINAL:
			return "Zone — agrandissement cardinal"
		SpellModSkillTreeEffect.EffectType.PUSH_BONUS:
			return "Poussée — bonus"
		SpellModSkillTreeEffect.EffectType.PUSH_EXACT:
			return "Poussée — distance exacte"
		SpellModSkillTreeEffect.EffectType.COLLISION_BONUS:
			return "Collision — bonus"
		SpellModSkillTreeEffect.EffectType.COLLISION_EXACT:
			return "Collision — valeur exacte"
		SpellModSkillTreeEffect.EffectType.TERRAIN_DURATION:
			return "Terrain — durée"
		SpellModSkillTreeEffect.EffectType.TERRAIN_DAMAGE:
			return "Terrain — dégâts"
		SpellModSkillTreeEffect.EffectType.CLEANSE:
			return "Retrait — effets négatifs"
		SpellModSkillTreeEffect.EffectType.ATTACK_BUFF:
			return "Attaque — bonus à charges"
		SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET:
			return "Déplacement — du lanceur"
		SpellModSkillTreeEffect.EffectType.ALLOW_FREE_CELL_TARGET:
			return "Ciblage — case libre"
		_:
			return "Effet non reconnu (%d)" % effect_type


## Phrase courte affichée en tête de « Comment fonctionne cet effet ? ». Décrit
## ce que fait réellement le runtime : une cible fixe (SHIELD_CASTER protège
## toujours le lanceur, jamais "les ennemis affectés") plutôt qu'un texte
## générique recalculé sur le seul champ target_scope, qui ne compte que pour
## les types listés dans SkillEffectEditorRegistry.SCOPE_AWARE_EFFECTS.
static func _skill_tree_effect(effect: SpellModSkillTreeEffect) -> String:
	var target := _target_phrase(effect)
	match effect.effect_type:
		SpellModSkillTreeEffect.EffectType.DAMAGE_ALL:
			return "Ajoute %d dégâts %s." % [effect.amount, _with_preposition("à", target)]
		SpellModSkillTreeEffect.EffectType.DAMAGE_CENTER:
			return "Ajoute %d dégâts sur %s." % [effect.amount, target]
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
			return "Rend %d points de vie %s." % [effect.amount, _with_preposition("à", target)]
		SpellModSkillTreeEffect.EffectType.ADJACENT_HEAL_RATIO:
			return "Partage %d %% du soin principal avec %s." % [
				roundi(effect.ratio * 100.0), target,
			]
		SpellModSkillTreeEffect.EffectType.SHIELD_TARGET, \
				SpellModSkillTreeEffect.EffectType.SHIELD_CASTER_IF_ALLY, \
				SpellModSkillTreeEffect.EffectType.SHIELD_ALLIES_ON_AREA, \
				SpellModSkillTreeEffect.EffectType.ADJACENT_SHIELD, \
				SpellModSkillTreeEffect.EffectType.SHIELD_CASTER:
			return "Accorde %d points de bouclier %s." % [effect.amount, _with_preposition("à", target)]
		SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_TARGET, \
				SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_CASTER, \
				SpellModSkillTreeEffect.EffectType.MP_ALLIES_ON_AREA:
			return "Ajoute %d PM %s au prochain tour." % [effect.amount, _with_preposition("à", target)]
		SpellModSkillTreeEffect.EffectType.STATUS_DOT:
			return "Applique %s %s : %d dégâts pendant %d tour(s)." % [
				effect.status_name if not effect.status_name.is_empty() else "un statut",
				_with_preposition("à", target),
				effect.amount,
				effect.duration,
			]
		SpellModSkillTreeEffect.EffectType.STATUS_SLOW:
			return "Retire %d PM pendant %d tour(s) %s." % [
				effect.amount, effect.duration, _with_preposition("à", target),
			]
		SpellModSkillTreeEffect.EffectType.STATUS_REGEN:
			return "Rend %d PV par tour pendant %d tour(s) %s." % [
				effect.amount, effect.duration, _with_preposition("à", target),
			]
		SpellModSkillTreeEffect.EffectType.STATUS_VULNERABILITY:
			return "La prochaine attaque reçue par %s fait %+d dégâts, jusqu’à %d charge(s)." % [
				target, effect.amount, effect.charges,
			]
		SpellModSkillTreeEffect.EffectType.STATUS_OUTGOING_DAMAGE:
			return "Modifie de %+d les dégâts infligés %s pendant %d tour(s)." % [
				effect.amount, _with_preposition("par", target), effect.duration,
			]
		SpellModSkillTreeEffect.EffectType.AREA_CARDINAL:
			return "Ajoute %d couche(s) de zone dans les quatre directions." % effect.amount
		SpellModSkillTreeEffect.EffectType.PUSH_BONUS:
			return "Ajoute %d case(s) à la poussée %s." % [effect.amount, _with_preposition("de", target)]
		SpellModSkillTreeEffect.EffectType.PUSH_EXACT:
			return "Fixe la distance de poussée %s à %d case(s), quelle que soit la poussée de base." % [
				_with_preposition("de", target), effect.amount,
			]
		SpellModSkillTreeEffect.EffectType.COLLISION_BONUS:
			return "Ajoute %d dégâts lorsque %s percute un obstacle." % [effect.amount, target]
		SpellModSkillTreeEffect.EffectType.COLLISION_EXACT:
			return "Fixe les dégâts de collision %s à %d ; si plusieurs effets fixent une valeur, la plus haute est retenue." % [
				_with_preposition("de", target), effect.amount,
			]
		SpellModSkillTreeEffect.EffectType.TERRAIN_DURATION:
			return "Ajoute %d tour(s) à la durée %s." % [effect.amount, _with_preposition("de", target)]
		SpellModSkillTreeEffect.EffectType.TERRAIN_DAMAGE:
			return "Ajoute %d dégâts %s." % [effect.amount, _with_preposition("à", target)]
		SpellModSkillTreeEffect.EffectType.CLEANSE:
			return "Retire jusqu’à %d effet(s) négatif(s) simple(s) %s." % [effect.amount, _with_preposition("de", target)]
		SpellModSkillTreeEffect.EffectType.ATTACK_BUFF:
			return "La prochaine attaque de %s fait %+d dégâts, jusqu’à %d charge(s)." % [
				target, effect.amount, effect.charges,
			]
		SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET:
			return "Déplace %s, sur une case libre alignée." % target
		SpellModSkillTreeEffect.EffectType.ALLOW_FREE_CELL_TARGET:
			return "Autorise le sort à cibler une case libre, sans unité dessus."
		_:
			return "%s : valeur principale %d." % [
				effect_type_label(effect.effect_type), effect.amount,
			]


## Cible réellement affectée par le runtime. Pour les 11 types listés dans
## SCOPE_AWARE_EFFECTS, le champ target_scope choisi par l'auteur compte
## vraiment ; pour les 22 autres, la cible est fixe et vient du registre.
static func _target_phrase(effect: SpellModSkillTreeEffect) -> String:
	if effect.effect_type in SkillEffectEditorRegistry.SCOPE_AWARE_EFFECTS:
		return _target_label(effect.target_scope)
	return str(SkillEffectEditorRegistry.FIXED_TARGETS.get(
		effect.effect_type, "la cible du sort"
	))


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


## Contracte "à/de/par + les" en "aux/des/par les" pour un français naturel.
## "Ajoute 7 dégâts à les ennemis affectés" devient "aux ennemis affectés".
static func _with_preposition(preposition: String, target: String) -> String:
	if target.begins_with("les "):
		var rest := target.substr(4)
		match preposition:
			"à":
				return "aux %s" % rest
			"de":
				return "des %s" % rest
	elif target.begins_with("le "):
		var rest := target.substr(3)
		match preposition:
			"à":
				return "au %s" % rest
			"de":
				return "du %s" % rest
	return "%s %s" % [preposition, target]
