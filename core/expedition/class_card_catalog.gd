extends RefCounted
## Immutable definitions. Every request creates fresh combat resources.
const CLASSES := {
	"assassin": [
		"Assassin",
		"Isoler • préparer • exécuter",
		"Premier coup au contact contre un ennemi sans allié adjacent : +20 % dégâts, une fois par tour.",
		"Privilégiez une cible isolée. Les groupes demandent du placement.",
	],
	"gardien": [
		"Gardien",
		"Protéger • déplacer • riposter",
		"Première garde créée chaque tour : +20 %.",
		"Tenez un passage et poussez les ennemis. Les attaques magiques contournent l'armure.",
	],
	"arpenteur": [
		"Arpenteur",
		"Se déplacer • viser • contrôler",
		"Premier coup à au moins 3 cases chaque tour : +20 % dégâts.",
		"Gardez vos distances. Les adversaires mobiles peuvent fermer votre ligne de tir.",
	],
	"thaumaturge": [
		"Thaumaturge",
		"Affaiblir • regrouper • déchaîner",
		"Premier coup magique sur un ennemi ralenti ou marqué chaque tour : +20 % dégâts.",
		"Préparez vos cibles. Une main de sorts coûteux peut vous laisser exposé.",
	],
}
const SPECS := {
	"assassin": [
		[
			"execution",
			"Exécuteur",
			"Premier coup contre une cible à 35 % PV ou moins : +35 % dégâts.",
		],
		["ambush", "Embusqué", "Premier coup au contact après 2 cases parcourues : +30 % dégâts."],
		["stalker", "Traqueur", "Premier coup sur une cible marquée : +30 % dégâts."],
	],
	"gardien": [
		["bastion", "Rempart", "Première garde créée : +40 %."],
		[
			"retaliation",
			"Vengeur",
			"Premier coup après avoir perdu des PV depuis votre activation précédente : +30 % dégâts.",
		],
		["breaker", "Percuteur", "Premier coup sur une cible déjà déplacée ce tour : +35 % dégâts."],
	],
	"arpenteur": [
		["sniper", "Tireur", "Premier coup à au moins 4 cases : +35 % dégâts."],
		["skirmish", "Escarmoucheur", "Premier coup après 2 cases parcourues : +30 % dégâts."],
		["hunter", "Chasseur", "Premier coup sur une cible ralentie : +30 % dégâts."],
	],
	"thaumaturge": [
		["fire", "Pyromancien", "Premier sort de feu chaque tour : +25 % dégâts directs."],
		["ice", "Cryomancien", "Premier coup magique sur une cible ralentie : +35 % dégâts."],
		[
			"area",
			"Dévastateur",
			"Premier sort touchant au moins deux ennemis : +25 % dégâts directs.",
		],
	],
}
# id, class, title, AP, min/max range, Prowess coefficient, effect, value, role.
const ROWS := [
	["a_open", "assassin", "Ouvrir la garde", 1, 1, 3, .35, "mark", 1, "Préparation"],
	["a_finish", "assassin", "Frapper l'ouverture", 2, 1, 1, .8, "marked", .55, "Exécution"],
	["a_cut", "assassin", "Entaille profonde", 2, 1, 1, .7, "bleed", .2, "Usure"],
	["a_step", "assassin", "Pas de côté", 1, 1, 2, 0., "move", 2, "Mobilité"],
	["a_parry", "assassin", "Parade courte", 1, 0, 0, 0., "guard", .35, "Défense"],
	["a_dagger", "assassin", "Dague lancée", 1, 2, 3, .55, "hit", 0, "Distance"],
	["a_ambush", "assassin", "Attaque oblique", 2, 1, 1, 1., "moved", .4, "Placement"],
	["a_sweep", "assassin", "Lames croisées", 3, 1, 1, .95, "cross", 1, "Zone"],
	["a_hamstring", "assassin", "Couper les appuis", 2, 1, 1, .65, "slow", 1, "Contrôle"],
	["a_push", "assassin", "Coup de talon", 1, 1, 1, .25, "push", 1, "Placement"],
	["a_execute", "assassin", "Coup de grâce", 3, 1, 1, 1.2, "execute", .7, "Exécution"],
	["a_pull", "assassin", "Crochet de lame", 2, 2, 3, .55, "pull", 1, "Placement"],
	["a_blind", "assassin", "Poussière noire", 2, 1, 2, .4, "weaken", .2, "Défense"],
	["a_pierce", "assassin", "Pointe précise", 2, 1, 1, 1.1, "hit", 0, "Dégâts"],
	["a_escape", "assassin", "Fuite préparée", 2, 1, 3, 0., "move", 3, "Mobilité"],
	["g_guard", "gardien", "Garde brève", 2, 0, 0, 0., "guard", .8, "Défense"],
	["g_push", "gardien", "Repousser", 2, 1, 1, .75, "push", 1, "Placement"],
	["g_hit", "gardien", "Heurt d'airain", 2, 1, 1, 1., "guarded", .3, "Riposte"],
	["g_step", "gardien", "Avancée prudente", 1, 1, 1, 0., "move", 1, "Mobilité"],
	["g_slow", "gardien", "Briser l'élan", 2, 1, 2, .65, "slow", 1, "Contrôle"],
	["g_pull", "gardien", "Ramener au front", 2, 2, 3, .5, "pull", 2, "Placement"],
	["g_wall", "gardien", "Tenir le passage", 3, 0, 0, 0., "guard", 1.25, "Défense"],
	["g_sweep", "gardien", "Balayage de hampe", 3, 1, 1, .9, "cross", 1, "Zone"],
	["g_crush", "gardien", "Choc de masse", 3, 1, 1, 1.1, "push", 2, "Placement"],
	["g_mark", "gardien", "Désigner la menace", 1, 1, 3, .3, "mark", 1, "Préparation"],
	["g_riposte", "gardien", "Rendre le coup", 2, 1, 1, .8, "wounded", .5, "Riposte"],
	["g_shot", "gardien", "Javelot lourd", 2, 2, 3, .95, "hit", 0, "Distance"],
	["g_weaken", "gardien", "Casser les armes", 2, 1, 1, .6, "weaken", .25, "Contrôle"],
	["g_charge", "gardien", "Percée", 2, 1, 2, 0., "move", 2, "Mobilité"],
	["g_punish", "gardien", "Punir le recul", 2, 1, 2, .9, "displaced", .5, "Riposte"],
	["r_shot", "arpenteur", "Trait tendu", 2, 2, 4, 1., "hit", 0, "Distance"],
	["r_step", "arpenteur", "Pas latéral", 1, 1, 2, 0., "move", 2, "Mobilité"],
	["r_slow", "arpenteur", "Flèche entravante", 2, 2, 4, .65, "slow", 1, "Contrôle"],
	["r_push", "arpenteur", "Trait de recul", 2, 1, 3, .6, "push", 1, "Placement"],
	["r_guard", "arpenteur", "Se couvrir", 1, 0, 0, 0., "guard", .35, "Défense"],
	["r_mark", "arpenteur", "Visée révélatrice", 1, 2, 5, .25, "mark", 1, "Préparation"],
	["r_hunt", "arpenteur", "Flèche de chasse", 2, 2, 4, .75, "marked", .55, "Exécution"],
	["r_fan", "arpenteur", "Volée croisée", 3, 2, 4, .75, "cross", 1, "Zone"],
	["r_close", "arpenteur", "Coup de crosse", 1, 1, 1, .45, "push", 1, "Secours"],
	["r_bleed", "arpenteur", "Flèche barbelée", 2, 2, 4, .65, "bleed", .2, "Usure"],
	["r_long", "arpenteur", "Tir de longue vue", 3, 3, 6, 1.45, "hit", 0, "Distance"],
	["r_move", "arpenteur", "Tir en mouvement", 2, 1, 3, .8, "moved", .4, "Mobilité"],
	["r_escape", "arpenteur", "Traverser la ligne", 2, 1, 3, 0., "move", 3, "Mobilité"],
	["r_pull", "arpenteur", "Trait harpon", 2, 2, 4, .55, "pull", 1, "Placement"],
	["r_weak", "arpenteur", "Tir aux mains", 2, 2, 4, .6, "weaken", .2, "Défense"],
	["t_frost", "thaumaturge", "Trait de givre", 2, 1, 3, .7, "frost", 1, "Contrôle"],
	["t_fire", "thaumaturge", "Éclat de braise", 3, 1, 3, .8, "fire", 1, "Zone"],
	["t_mark", "thaumaturge", "Sceau d'ombre", 1, 1, 3, .3, "mark", 1, "Préparation"],
	["t_guard", "thaumaturge", "Écran de cendre", 2, 0, 0, 0., "guard", .75, "Défense"],
	["t_step", "thaumaturge", "Pas de brume", 1, 1, 2, 0., "move", 2, "Mobilité"],
	["t_bolt", "thaumaturge", "Arc fulgurant", 2, 1, 4, 1., "lightning", 0, "Dégâts"],
	["t_hex", "thaumaturge", "Morsure du sceau", 2, 1, 3, .75, "marked", .55, "Exécution"],
	["t_weak", "thaumaturge", "Éteindre la force", 2, 1, 3, .5, "weaken", .25, "Défense"],
	["t_pull", "thaumaturge", "Appel des profondeurs", 2, 2, 4, .4, "pull", 2, "Placement"],
	["t_push", "thaumaturge", "Souffle de pierre", 2, 1, 3, .6, "push", 1, "Placement"],
	["t_burn", "thaumaturge", "Braise tenace", 2, 1, 3, .6, "burn", .22, "Usure"],
	["t_ice", "thaumaturge", "Éclats gelés", 3, 1, 3, .7, "ice_area", 1, "Contrôle de zone"],
	["t_storm", "thaumaturge", "Orage concentré", 3, 2, 4, 1.5, "lightning", 0, "Dégâts"],
	["t_touch", "thaumaturge", "Toucher du Tartare", 1, 1, 1, .6, "shadow", 0, "Secours"],
	["t_escape", "thaumaturge", "Traversée de brume", 2, 1, 3, 0., "move", 3, "Mobilité"],
]


static func row(id: String) -> Array:
	for entry in ROWS:
		if entry[0] == id:
			return entry
	return []


static func pool(class_id := "") -> Array[String]:
	var result: Array[String] = []
	for entry in ROWS:
		if class_id.is_empty() or entry[1] == class_id:
			result.append(entry[0])
	return result


static func preset(class_id := "assassin") -> Dictionary:
	return {
		"class_id": class_id,
		"card_families": pool(class_id).slice(0, 5),
		"difficulty_id": "normal",
	}


static func valid(selection: Dictionary) -> bool:
	if not CLASSES.has(selection.get("class_id", "")):
		return false
	var families: Variant = selection.get("card_families")
	if not families is Array or families.size() != 5:
		return false
	var seen := { }
	for id in families:
		if not id is String or id not in pool(str(selection.class_id)) or seen.has(id):
			return false
		seen[id] = true
	return selection.get("difficulty_id", "normal") in ["normal", "easy"]


static func icon(id: String) -> Texture2D:
	var path := "res://asset/ui/class_cards/" + id + ".svg"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func make_spell(id: String, rank := 0, upgraded := false) -> Spell:
	var r := row(id)
	if r.is_empty() or rank < 0 or rank > 4 or (upgraded and rank < 3):
		return null
	var s := Spell.new()
	s.spell_id = StringName("class_" + id)
	s.spell_name = str(r[2]) + (" •" if upgraded else "")
	s.icon = icon(id)
	s.ap_cost = r[3]
	s.minimum_range = r[4]
	s.spell_range = r[5]
	s.damage_type = Spell.DamageType.MAGICAL if r[1] == "thaumaturge" else Spell.DamageType.PHYSICAL
	var mult := 1.0 + .1 * rank
	s.damage_scaling = scaling(float(r[6]) * mult)
	var effect: String = r[7]
	s.once_per_activation = effect in [
		"move",
		"guard",
		"push",
		"pull",
		"slow",
		"frost",
		"ice_area",
		"weaken",
	]
	var detail := ""
	match effect:
		"mark":
			s.applied_status = status("marked", "Marqué", 1)
			detail = "Marque pendant 1 activation de la cible."
		"slow", "frost", "ice_area":
			s.applied_status = status("slow", "Ralenti", 1)
			s.applied_status.mp_reduction = 1
			detail = "Retire 1 PM à la prochaine activation. Ne se cumule pas."
			if effect != "slow":
				s.element = Spell.Element.ICE
		"guard":
			s.can_target_enemy = false
			s.can_target_self = true
			s.shield_scaling = scaling(float(r[8]) * mult)
			s.shield_tags = [&"guard"]
			s.shield_duration_activations = 1
			detail = "Garde jusqu'à votre prochaine activation."
		"move":
			s.can_target_enemy = false
			s.can_target_free_cell = true
			s.caster_movement = Spell.CasterMovement.TARGET_CELL
			s.movement_requires_clear_path = true
			detail = "Déplacement vers une case libre, chemin dégagé. Ne consomme pas de PM."
		"push":
			s.push_distance = int(r[8])
			detail = "Repousse de %d case(s)." % r[8]
		"pull":
			s.pull_distance = int(r[8])
			detail = "Attire de %d case(s)." % r[8]
		"bleed", "burn":
			s.applied_status = status(effect, "Saignement" if effect == "bleed" else "Brûlure", 2)
			if effect == "burn":
				s.element = Spell.Element.FIRE
			detail = "Inflige encore %d %% de Prouesse pendant 2 activations ; valeur fixée au lancement. Ne se cumule pas." % roundi(
				float(r[8]) * mult * 100
			)
		"weaken":
			s.applied_status = status("weak", "Affaibli", 1)
			detail = "Réduit la Prouesse de %d %% pendant 1 activation." % roundi(float(r[8]) * 100)
		"fire":
			s.element = Spell.Element.FIRE
		"lightning":
			s.element = Spell.Element.LIGHTNING
		"shadow":
			s.element = Spell.Element.SHADOW
		"marked":
			detail = "+%d %% de Prouesse si la cible est marquée." % roundi(
				float(r[8]) * mult * 100
			)
		"moved":
			detail = "+%d %% de Prouesse après 2 cases parcourues ce tour." % roundi(
				float(r[8]) * mult * 100
			)
		"execute":
			detail = "+%d %% de Prouesse sur une cible à 35 %% PV ou moins." % roundi(
				float(r[8]) * mult * 100
			)
		"guarded":
			detail = "+%d %% de Prouesse tant que vous avez de la garde." % roundi(
				float(r[8]) * mult * 100
			)
		"wounded":
			detail = "+%d %% de Prouesse si vous avez perdu des PV depuis votre activation précédente." % roundi(
				float(r[8]) * mult * 100
			)
		"displaced":
			detail = "+%d %% de Prouesse sur une cible déjà déplacée ce tour." % roundi(
				float(r[8]) * mult * 100
			)
	if effect in ["cross", "fire", "ice_area"]:
		s.aoe_shape = Spell.AoeShape.CROSS
		s.aoe_size = 1
		s.can_target_free_cell = true
		s.exclude_allies_from_area_effects = true
		detail = "Croix de rayon 1, ennemis seulement. " + detail
	if upgraded:
		if effect == "guard":
			s.shield_duration_activations = 2
			detail += " Amélioration : garde pendant 2 activations."
		elif effect == "move":
			s.movement_requires_clear_path = false
			s.needs_line_of_sight = false
			detail += " Amélioration : franchit les obstacles."
		elif s.spell_range > 1:
			s.needs_line_of_sight = false
			detail += " Amélioration : ignore la ligne de vue."
		else:
			s.spell_range += 1
			detail += " Amélioration : +1 portée."
	var mod := preload("res://core/expedition/class_card_modifier.gd").new()
	mod.effect = effect
	mod.value = float(r[8]) * (1.0 if effect == "weaken" else mult)
	mod.class_id = r[1]
	if effect in ["bleed", "burn", "weaken"]:
		s.applied_status = null
	s.modifiers.append(mod)
	s.modifiers.append(CatabaseCombatModifier.new())
	s.description = "%s · %s · maîtrise %d (+%d %% dégâts et garde).\n%s%s" % [
		CLASSES[r[1]][0],
		r[9],
		rank,
		rank * 10,
		detail,
		" Une fois par tour, copies confondues." if s.once_per_activation else "",
	]
	return s


static func scaling(p: float) -> SpellScalingData:
	var s := SpellScalingData.new()
	s.prowess_coefficient = p
	return s


static func status(id: String, title: String, duration: int) -> StatusData:
	var s := StatusData.new()
	s.status_id = StringName("class_" + id)
	s.status_name = title
	s.duration = duration
	return s
