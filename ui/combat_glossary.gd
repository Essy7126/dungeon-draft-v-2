class_name CombatGlossary
extends RefCounted

static func entries() -> Dictionary:
	return {
		"elan": _entry("Elan", Color(0.42, 0.84, 1.0), "Energie d'action des heros. Elle sert aux attaques et aux sorts, puis revient au debut du tour."),
		"pm": _entry("PM", Color(0.74, 0.88, 1.0), "Points de mouvement. Ils servent uniquement a se deplacer sur la grille."),
		"ferveur": _entry("Ferveur", Color(0.86, 0.74, 1.0), "Energie d'identite. Elle se gagne en jouant selon le style du heros, puis se depense en Empreinte, Eveil ou Reaction."),
		"rage": _entry("Rage", Color(1.0, 0.28, 0.22), "Ferveur offensive. Favorise les coups, la prise de risque et les pics de degats."),
		"foi": _entry("Foi", Color(1.0, 0.82, 0.28), "Ferveur defensive. Favorise la protection, les boucliers et la tenue de ligne."),
		"nature": _entry("Nature", Color(0.35, 0.9, 0.45), "Ferveur vitale. Favorise le soin, les terrains et les effets de symbiose."),
		"ombre": _entry("Ombre", Color(0.62, 0.42, 1.0), "Ferveur opportuniste. Favorise les marques, les debuffs et les attaques de precision."),
		"resonance": _entry("Resonance", Color(1.0, 0.92, 0.68), "Jauge d'equipe. Elle recompense les combos entre heros."),
		"empreinte": _entry("Empreinte", Color(0.92, 0.74, 1.0), "Version amplifiee d'un sort. Elle depense de la Ferveur en plus du cout normal."),
		"eveil": _entry("Eveil", Color(1.0, 0.9, 0.45), "Etat temporaire puissant. Il coute 50 Ferveur et change les regles du heros pendant 2 tours."),
		"reaction": _entry("Reaction", Color(0.85, 0.78, 1.0), "Defense automatique possible pendant le tour ennemi quand assez de Ferveur est disponible."),
		"berserker": _entry("Berserker", Color(1.0, 0.22, 0.15), "Eveil de la Rage : degats augmentes, mais soins refuses pendant la fenetre."),
		"sanctifie": _entry("Sanctifie", Color(1.0, 0.86, 0.28), "Eveil de la Foi : boucliers amplifies, mais degats directs bloques pendant la fenetre."),
		"symbiose": _entry("Symbiose", Color(0.42, 1.0, 0.48), "Eveil de la Nature : surplus de soin converti en bouclier, avec un revenu d'Elan reduit."),
		"voile": _entry("Voile", Color(0.58, 0.42, 1.0), "Eveil de l'Ombre : difficile a cibler, mais soins refuses pendant la fenetre."),
		"eau": _entry("Eau", Color(0.34, 0.7, 1.0), "Terrain humide. Il applique Mouille et reagit avec certains elements."),
		"feu": _entry("Feu", Color(1.0, 0.38, 0.12), "Terrain brulant. Il blesse les unites qui y restent."),
		"lave": _entry("Lave", Color(1.0, 0.28, 0.08), "Terrain tres dangereux. Il inflige de lourds degats."),
		"ronces": _entry("Ronces", Color(0.18, 0.72, 0.28), "Terrain vegetal. Il blesse legerement et ralentit les passages."),
		"glace": _entry("Glace", Color(0.68, 0.92, 1.0), "Terrain glissant. Il gene le placement et peut fondre au Feu."),
		"rune": _entry("Rune", Color(0.88, 0.62, 1.0), "Terrain d'amplification. Il augmente la generation de Ferveur."),
		"sanctuaire": _entry("Sanctuaire", Color(1.0, 0.86, 0.34), "Terrain protecteur. Il reduit les degats subis par les allies."),
		"vapeur": _entry("Vapeur", Color(0.72, 0.82, 0.86), "Nuage de reaction. Il reduit la precision dans la zone."),
		"protege": _entry("Protege", Color(0.78, 0.86, 1.0), "Statut defensif. Les prochains degats sont absorbes avant les PV."),
		"vulnerable": _entry("Vulnerable", Color(1.0, 0.42, 0.32), "Statut offensif. La cible subit davantage de degats."),
		"saignement": _entry("Saignement", Color(0.86, 0.08, 0.08), "Statut de blessure. La cible perd des PV au debut de ses tours."),
		"mouille": _entry("Mouille", Color(0.42, 0.76, 1.0), "Statut elementaire. La cible devient plus sensible a la Foudre."),
		"marque": _entry("Marque", Color(0.95, 0.55, 1.0), "Statut de focus. Plusieurs effets d'Ombre deviennent plus forts contre cette cible."),
		"choc": _entry("Choc", Color(1.0, 0.96, 0.34), "Statut de controle. Il perturbe fortement les cibles Mouillees."),
		"petrifie": _entry("Petrifie", Color(0.62, 0.62, 0.58), "Statut de controle. La cible perd son prochain tour."),
		"enracine": _entry("Enracine", Color(0.35, 0.72, 0.25), "Statut de controle. La cible ne peut pas se deplacer."),
		"etourdi": _entry("Etourdi", Color(1.0, 0.9, 0.3), "Statut de controle. La cible saute une action ou son tour selon l'effet."),
	}

static func _entry(display_name: String, color: Color, definition: String) -> Dictionary:
	return { "name": display_name, "color": color, "definition": definition }

static func has(id: String) -> bool:
	return entries().has(id.strip_edges().to_lower())

static func get_entry(id: String) -> Dictionary:
	var key := id.strip_edges().to_lower()
	return entries().get(key, _entry(id, Color.WHITE, "Terme non defini dans le glossaire."))

static func token(id: String) -> String:
	return "[kw:%s]" % id.strip_edges().to_lower()

static func keyword_id_for_name(value: String) -> String:
	var n := value.strip_edges().to_lower()
	if n == "":
		return ""
	if "elan" in n:
		return "elan"
	if "pm" == n:
		return "pm"
	if "ferveur" in n:
		return "ferveur"
	if "rage" in n:
		return "rage"
	if "foi" in n:
		return "foi"
	if "nature" in n:
		return "nature"
	if "ombre" in n:
		return "ombre"
	if "empreinte" in n:
		return "empreinte"
	if "eveil" in n:
		return "eveil"
	if "reaction" in n:
		return "reaction"
	if "berserker" in n:
		return "berserker"
	if "sanct" in n:
		return "sanctifie"
	if "symbiose" in n:
		return "symbiose"
	if "voile" in n:
		return "voile"
	if "vuln" in n:
		return "vulnerable"
	if "saign" in n:
		return "saignement"
	if "mouill" in n:
		return "mouille"
	if "marqu" in n:
		return "marque"
	if "choc" in n:
		return "choc"
	if "petr" in n:
		return "petrifie"
	if "enracin" in n:
		return "enracine"
	if "etourd" in n or "stun" in n:
		return "etourdi"
	if "prote" in n:
		return "protege"
	if "sanctuaire" in n:
		return "sanctuaire"
	if "vapeur" in n:
		return "vapeur"
	if "ronce" in n:
		return "ronces"
	if "glace" in n or "gel" in n:
		return "glace"
	if "lave" in n:
		return "lave"
	if "feu" in n or "braise" in n:
		return "feu"
	if "rune" in n:
		return "rune"
	if "eau" == n:
		return "eau"
	return n if has(n) else ""

static func token_for_name(value: String) -> String:
	var id := keyword_id_for_name(value)
	return token(id) if id != "" else value

static func annotate_text(text: String) -> String:
	if "[kw:" in text:
		return text
	var out := text
	var pairs := [
		["Ferveur", "ferveur"], ["Elan", "elan"], ["PM", "pm"], ["Empreinte", "empreinte"], ["Eveil", "eveil"], ["Reaction", "reaction"],
		["Berserker", "berserker"], ["Sanctifie", "sanctifie"], ["Symbiose", "symbiose"], ["Voile", "voile"],
		["Vulnerable", "vulnerable"], ["Saignement", "saignement"], ["Mouille", "mouille"], ["Marque", "marque"],
		["Petrifie", "petrifie"], ["Enracine", "enracine"], ["Etourdi", "etourdi"], ["Protege", "protege"],
		["Ronces", "ronces"], ["Sanctuaire", "sanctuaire"], ["Vapeur", "vapeur"], ["Glace", "glace"], ["Lave", "lave"], ["Rune", "rune"],
		["Rage", "rage"], ["Foi", "foi"], ["Nature", "nature"], ["Ombre", "ombre"],
	]
	for pair in pairs:
		out = out.replace(pair[0], token(pair[1]))
	return out

static func render_keywords(text: String) -> String:
	var source := annotate_text(text)
	var out := ""
	var index := 0
	while index < source.length():
		var start := source.find("[kw:", index)
		if start == -1:
			out += _escape_bbcode(source.substr(index))
			break
		out += _escape_bbcode(source.substr(index, start - index))
		var end := source.find("]", start)
		if end == -1:
			out += _escape_bbcode(source.substr(start))
			break
		var id := source.substr(start + 4, end - start - 4).strip_edges().to_lower()
		out += keyword_bbcode(id)
		index = end + 1
	return out

static func keyword_bbcode(id: String) -> String:
	var entry := get_entry(id)
	var color: Color = entry["color"]
	return "[color=#%s][b][url=kw:%s]%s[/url][/b][/color]" % [color.to_html(false), id, entry["name"]]

static func definition_bbcode(id: String) -> String:
	var entry := get_entry(id)
	var color: Color = entry["color"]
	return "[b][color=#%s]%s[/color][/b]\n%s" % [color.to_html(false), entry["name"], render_keywords(entry["definition"])]

static func spell_tier(spell: Spell) -> String:
	if spell == null:
		return "Sort"
	var cost := maxf(spell.energy_cost, float(spell.ap_cost * 10))
	if cost <= 10.0:
		return "Geste"
	if cost <= 25.0:
		return "Leger"
	if cost <= 45.0:
		return "Standard"
	return "Signature"

static func spell_card_bbcode(caster, spell: Spell, imprinted: bool, unusable_reason: String = "") -> String:
	if spell == null:
		return ""
	var title := spell.spell_name
	if imprinted:
		title = "Empreinte - " + title
	var lines: Array = []
	lines.append("[b][font_size=18]%s[/font_size][/b] [color=#b9b2a8]%s[/color]" % [_escape_bbcode(title), spell_tier(spell)])
	lines.append("Cout : " + render_keywords(_cost_text(caster, spell, imprinted)))
	lines.append("Portee : %d | Zone : %s" % [spell.spell_range, _aoe_text(spell)])
	if unusable_reason != "":
		lines.append("[color=#ff5a4f]Injouable : %s[/color]" % _escape_bbcode(unusable_reason))
	lines.append("\n[b]Effet normal[/b]")
	lines.append(render_keywords(_effect_text(spell, false)))
	if spell.can_imprint():
		var imprint_cost := _imprint_cost_text(caster, spell)
		lines.append("\n[color=#d8b8ff][b]Empreinte%s[/b][/color]" % imprint_cost)
		lines.append(render_keywords(_effect_text(spell, true)))
	if spell.charge_verb.strip_edges() != "":
		lines.append("\n[font_size=11][color=#8b8b8b]Verbe : %s[/color][/font_size]" % _escape_bbcode(spell.charge_verb.strip_edges().to_upper()))
	return "\n".join(lines)

static func _cost_text(caster, spell: Spell, imprinted: bool) -> String:
	var parts: Array = []
	if caster != null and caster.has_method("has_energy") and caster.has_energy():
		var elan_cost: float = caster.get_spell_elan_cost(spell)
		var fervor_cost: float = caster.get_spell_fervor_cost(spell, imprinted)
		parts.append("%d Elan" % int(elan_cost))
		if fervor_cost > 0.0:
			parts.append("%d %s" % [int(fervor_cost), caster.energy_type.energy_name])
	else:
		parts.append("%d PA" % spell.ap_cost)
	return " / ".join(parts)

static func _imprint_cost_text(caster, spell: Spell) -> String:
	if caster != null and caster.has_method("get_spell_imprint_fervor_cost"):
		return " (+%d Ferveur)" % int(caster.get_spell_imprint_fervor_cost(spell))
	return ""

static func _aoe_text(spell: Spell) -> String:
	match spell.aoe_shape:
		Spell.AoeShape.CROSS:
			return "Croix %d" % spell.aoe_size
		Spell.AoeShape.SQUARE:
			return "Carre %d" % spell.aoe_size
		Spell.AoeShape.LINE:
			return "Ligne"
	return "1"

static func _effect_text(spell: Spell, imprinted: bool) -> String:
	var effects: Array = []
	var damage := spell.damage + (spell.imprint_damage_bonus if imprinted else 0)
	var heal := spell.heal + (spell.imprint_heal_bonus if imprinted else 0)
	var shield := spell.shield_grant + (spell.imprint_shield_bonus if imprinted else 0)
	if damage > 0:
		effects.append("Inflige %d degats." % damage)
	if heal > 0:
		effects.append("Rend %d PV." % heal)
	if shield > 0:
		effects.append("Donne %d bouclier." % shield)
	if spell.applied_status != null:
		effects.append("Applique %s." % token_for_name(spell.applied_status.status_name))
	if imprinted and spell.imprint_status != null:
		effects.append("Applique %s." % token_for_name(spell.imprint_status.status_name))
	if spell.terrain_effect != null:
		effects.append("Pose %s." % token_for_name(spell.terrain_effect.effect_name))
	if imprinted and spell.imprint_terrain_effect != null:
		effects.append("Pose %s." % token_for_name(spell.imprint_terrain_effect.effect_name))
	if spell.push_distance > 0:
		effects.append("Pousse de %d case(s)." % spell.push_distance)
	if spell.forces_taunt:
		effects.append("Force la cible a viser le lanceur.")
	if spell.elan_drain > 0.0:
		effects.append("Draine %d [kw:elan]." % int(spell.elan_drain))
	if spell.fervor_drain > 0.0:
		effects.append("Draine %d [kw:ferveur]." % int(spell.fervor_drain))
	if spell.teleport_behind_target:
		effects.append("Replace le lanceur derriere la cible.")
	if spell.bonus_damage_if_marked > 0:
		effects.append("+%d degats contre une cible [kw:marque]." % spell.bonus_damage_if_marked)
	if effects.is_empty():
		effects.append("Effet tactique.")
	return "\n".join(effects)

static func _escape_bbcode(text: String) -> String:
	var escaped := text.replace("[", "__CODEX_LB__").replace("]", "__CODEX_RB__")
	return escaped.replace("__CODEX_LB__", "[lb]").replace("__CODEX_RB__", "[rb]")
