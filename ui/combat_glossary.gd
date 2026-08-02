class_name CombatGlossary
extends RefCounted

static func entries() -> Dictionary:
	return {
		"pa": _entry("PA", Color(1.0, 0.85, 0.3), "Points d'Action. Ils paient les attaques et les sorts, et reviennent en entier au debut de chaque tour."),
		"pm": _entry("PM", Color(0.74, 0.88, 1.0), "Points de mouvement. Ils servent uniquement a se deplacer sur la grille."),
		"eau": _entry("Eau", Color(0.34, 0.7, 1.0), "Terrain humide. Il applique Mouille et reagit avec certains elements."),
		"feu": _entry("Feu", Color(1.0, 0.38, 0.12), "Terrain brulant. Il blesse les unites qui y restent."),
		"lave": _entry("Lave", Color(1.0, 0.28, 0.08), "Terrain tres dangereux. Il inflige de lourds degats."),
		"ronces": _entry("Ronces", Color(0.18, 0.72, 0.28), "Terrain vegetal. Il blesse legerement et ralentit les passages."),
		"glace": _entry("Glace", Color(0.68, 0.92, 1.0), "Terrain glissant. Il gene le placement et peut fondre au Feu."),
		"rune": _entry("Rune", Color(0.88, 0.62, 1.0), "Terrain magique aux effets propres a la salle."),
		"sanctuaire": _entry("Sanctuaire", Color(1.0, 0.86, 0.34), "Terrain protecteur. Il reduit les degats subis par les allies."),
		"vapeur": _entry("Vapeur", Color(0.72, 0.82, 0.86), "Nuage de reaction. Il reduit la precision dans la zone."),
		"protege": _entry("Protege", Color(0.78, 0.86, 1.0), "Statut defensif. Les prochains degats sont absorbes avant les PV."),
		"vulnerable": _entry("Vulnerable", Color(1.0, 0.42, 0.32), "Statut offensif. La cible subit davantage de degats."),
		"saignement": _entry("Saignement", Color(0.86, 0.08, 0.08), "Statut de blessure. La cible perd des PV au debut de ses tours."),
		"mouille": _entry("Mouille", Color(0.42, 0.76, 1.0), "Statut elementaire. La cible devient plus sensible a la Foudre."),
		"marque": _entry("Marque", Color(0.95, 0.55, 1.0), "Statut de focus exploite par certains sorts contre cette cible."),
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
	if "pa" == n:
		return "pa"
	if "pm" == n:
		return "pm"
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
		["PA", "pa"], ["PM", "pm"],
		["Vulnerable", "vulnerable"], ["Saignement", "saignement"], ["Mouille", "mouille"], ["Marque", "marque"],
		["Petrifie", "petrifie"], ["Enracine", "enracine"], ["Etourdi", "etourdi"], ["Protege", "protege"],
		["Ronces", "ronces"], ["Sanctuaire", "sanctuaire"], ["Vapeur", "vapeur"], ["Glace", "glace"], ["Lave", "lave"], ["Rune", "rune"],
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
	var cost := spell.ap_cost
	if cost <= 1:
		return "Geste"
	if cost <= 2:
		return "Leger"
	if cost <= 4:
		return "Standard"
	return "Majeur"

static func spell_card_bbcode(caster, spell: Spell, unusable_reason: String = "") -> String:
	if spell == null:
		return ""
	var title := spell.spell_name
	var lines: Array = []
	lines.append("[b][font_size=18]%s[/font_size][/b] [color=#b9b2a8]%s[/color]" % [_escape_bbcode(title), spell_tier(spell)])
	lines.append("Cout : " + render_keywords(_cost_text(caster, spell)))
	lines.append("Portee : %d | Zone : %s" % [spell.spell_range, _aoe_text(spell)])
	if unusable_reason != "":
		lines.append("[color=#ff5a4f]Injouable : %s[/color]" % _escape_bbcode(unusable_reason))
	lines.append("\n[b]Effet normal[/b]")
	lines.append(render_keywords(_effect_text(spell)))
	return "\n".join(lines)

static func _cost_text(caster, spell: Spell) -> String:
	var parts: Array = []
	var ap_cost: int = spell.ap_cost
	if caster != null and caster.has_method("get_spell_ap_cost"):
		ap_cost = caster.get_spell_ap_cost(spell)
	parts.append("%d PA" % ap_cost)
	return " / ".join(parts)

static func _aoe_text(spell: Spell) -> String:
	match spell.aoe_shape:
		Spell.AoeShape.CROSS:
			return "Croix %d" % spell.aoe_size
		Spell.AoeShape.SQUARE:
			return "Carre %d" % spell.aoe_size
		Spell.AoeShape.LINE:
			return "Ligne"
	return "1"

static func _effect_text(spell: Spell) -> String:
	var effects: Array = []
	var damage := spell.damage
	var heal := spell.heal
	var shield := spell.shield_grant
	if damage > 0:
		effects.append("Inflige %d degats." % damage)
	if heal > 0:
		effects.append("Rend %d PV." % heal)
	if shield > 0:
		effects.append("Donne %d bouclier." % shield)
	if spell.applied_status != null:
		effects.append("Applique %s." % token_for_name(spell.applied_status.status_name))
	if spell.terrain_effect != null:
		effects.append("Pose %s." % token_for_name(spell.terrain_effect.effect_name))
	if spell.push_distance > 0:
		effects.append("Pousse de %d case(s)." % spell.push_distance)
	if spell.forces_taunt:
		effects.append("Force la cible a viser le lanceur.")
	if spell.ap_drain > 0:
		effects.append("Draine %d [kw:pa] au prochain tour." % spell.ap_drain)
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
