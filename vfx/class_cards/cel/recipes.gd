extends RefCounted
## Drawn poses plus explicit compositions. No damage, duration-of-status or RNG changes.
const CLIPS := [
	"cut",
	"pierce",
	"fire",
	"ice",
	"lightning",
	"guard",
	"wind",
	"chain",
	"seal",
	"shadow",
	"hourglass",
	"heal",
	"water",
	"reaper",
	"bastion",
	"hammer",
	"corona",
]
const FAMILIES := {
	"slash": "cut",
	"pierce": "pierce",
	"cleave": "cut",
	"mark": "seal",
	"bleed": "cut",
	"guard": "guard",
	"move": "wind",
	"shadow": "shadow",
	"root": "chain",
	"push": "wind",
	"pull": "chain",
	"weaken": "seal",
	"ice": "ice",
	"fire": "fire",
	"lightning": "lightning",
	"disrupt": "seal",
	"stasis": "hourglass",
	"heal": "heal",
	"summon": "shadow",
	"water": "water",
	"poison": "water",
}
## Clip, staging, angle in degrees, copies, intent. Angles are artwork angles, not targeting rules.
const CARDS := {
	"a_open": [
		"seal",
		"stamp",
		-15,
		1,
		"Deux crochets désignent l'ouverture ; le petit signe de marque prend le relais.",
	],
	"a_finish": [
		"pierce",
		"thrust",
		-8,
		2,
		"Une pointe et son éclat latéral frappent l'ouverture confirmée.",
	],
	"a_cut": [
		"cut",
		"slash",
		25,
		1,
		"Entaille oblique carmin, puis trois lambeaux courts ; le saignement reste un état séparé.",
	],
	"a_step": [
		"wind",
		"step",
		0,
		1,
		"Un coup de poussière latéral au départ, une retombée courte à l'arrivée réelle.",
	],
	"a_parry": [
		"guard",
		"brace",
		-18,
		1,
		"Petit pan de métal incliné devant la parade, puis badge de garde.",
	],
	"a_dagger": [
		"pierce",
		"thrust",
		0,
		1,
		"Pointe de dague dirigée depuis le lanceur ; éclat bref au contact réel.",
	],
	"a_ambush": [
		"cut",
		"slash",
		-35,
		1,
		"Coupe remontante du flanc, large au contact puis déchirée en deux morceaux.",
	],
	"a_sweep": [
		"cut",
		"cross",
		15,
		2,
		"Deux lames opposées se croisent sur les seules cibles touchées.",
	],
	"a_hamstring": [
		"cut",
		"low",
		5,
		1,
		"Incision basse aux appuis ; le ralentissement devient un signe distinct.",
	],
	"a_push": ["wind", "thrust", 0, 1, "Souffle court du talon, dirigé dans le sens de la poussée."],
	"a_execute": [
		"reaper",
		"slash",
		-10,
		1,
		"Grand tranchant descendant au coup de grâce ; pas de bonus de dégâts inventé.",
	],
	"a_pull": [
		"chain",
		"inward",
		0,
		1,
		"Crochet de lame et lien tendu, rétraction vers le lanceur.",
	],
	"a_blind": [
		"shadow",
		"break",
		0,
		1,
		"Poussière noire brisée en petits pans autour des épaules.",
	],
	"a_pierce": [
		"pierce",
		"thrust",
		0,
		1,
		"Une pointe nette traverse au niveau du buste et se fragmente vite.",
	],
	"a_escape": [
		"wind",
		"step",
		-12,
		2,
		"Deux traînées fuyantes, puis poussière basse lorsque le déplacement finit.",
	],
	"g_guard": [
		"guard",
		"brace",
		0,
		1,
		"Un écu d'airain s'assemble en trois poses ; maintien en badge compact.",
	],
	"g_push": [
		"wind",
		"thrust",
		0,
		2,
		"Deux fronts de souffle courts projettent le contact vers l'extérieur.",
	],
	"g_hit": [
		"hammer",
		"stamp",
		-14,
		1,
		"Un coin d'airain frappe lourdement avec quelques éclats de métal.",
	],
	"g_step": ["wind", "step", 0, 1, "Poussière lourde et basse pour le pas prudent."],
	"g_slow": [
		"chain",
		"bind",
		0,
		1,
		"Deux maillons se referment au niveau des jambes et freinent l'élan.",
	],
	"g_pull": ["chain", "inward", 0, 2, "Deux liens d'airain se tendent puis reviennent au front."],
	"g_wall": [
		"bastion",
		"brace",
		0,
		1,
		"Deux pans latéraux ferment le passage ; centre ouvert pour le gardien.",
	],
	"g_sweep": [
		"cut",
		"slash",
		52,
		1,
		"Large balayage horizontal de hampe, éclats bas sur chaque cible réelle.",
	],
	"g_crush": [
		"hammer",
		"stamp",
		0,
		1,
		"Tête de masse, contact anguleux et pierres projetées, puis extinction.",
	],
	"g_mark": [
		"seal",
		"stamp",
		0,
		1,
		"Sceau d'airain carré désignant la menace, relayé par la marque.",
	],
	"g_riposte": [
		"cut",
		"slash",
		155,
		1,
		"Revers remontant depuis la garde, épais au talon et effilé en sortie.",
	],
	"g_shot": ["pierce", "thrust", 0, 1, "Fer de javelot large, impact sec et fragments de hampe."],
	"g_weaken": [
		"guard",
		"break",
		0,
		1,
		"Plaque d'arme fendue en fragments : affaiblissement, aucune garde créée.",
	],
	"g_charge": [
		"wind",
		"step",
		0,
		2,
		"Deux sillages bas encadrent la percée et s'arrêtent à son arrivée.",
	],
	"g_punish": [
		"pierce",
		"thrust",
		12,
		2,
		"Pointe oblique et éclat de déséquilibre sur le contact confirmé.",
	],
	"r_shot": [
		"pierce",
		"thrust",
		0,
		1,
		"Trait rectiligne fin, pointe blanche et empennage déchiré.",
	],
	"r_step": ["wind", "step", 8, 1, "Une plume de poussière rase le sol dans le sens du pas."],
	"r_slow": ["chain", "bind", -12, 1, "Le trait se termine en liens courts autour des chevilles."],
	"r_push": [
		"pierce",
		"thrust",
		0,
		2,
		"Trait de recul avec deux éclats divergents ; même direction que le tir.",
	],
	"r_guard": [
		"guard",
		"brace",
		22,
		1,
		"Écu oblique léger qui couvre un flanc puis rejoint le badge de garde.",
	],
	"r_mark": [
		"seal",
		"stamp",
		45,
		1,
		"Quatre pointes de visée se resserrent autour du point faible.",
	],
	"r_hunt": [
		"pierce",
		"thrust",
		-5,
		2,
		"Fer de chasse barbelé accompagné de deux éclats d'empennage.",
	],
	"r_fan": [
		"pierce",
		"volley",
		0,
		3,
		"Trois traits en éventail convergent sur chaque cible touchée.",
	],
	"r_close": [
		"wind",
		"low",
		0,
		1,
		"Coup de crosse compact, poussière et éclat bas sans grand projectile.",
	],
	"r_bleed": [
		"pierce",
		"thrust",
		0,
		1,
		"Fer barbelé carmin ; fragments rouges au contact, puis état de saignement.",
	],
	"r_long": [
		"pierce",
		"thrust",
		0,
		3,
		"Long trait central renforcé par deux fins sillages parallèles.",
	],
	"r_move": ["pierce", "thrust", 14, 1, "Trait oblique, vif et court, pour le tir en mouvement."],
	"r_escape": [
		"wind",
		"step",
		0,
		3,
		"Trois rubans d'air traversent la ligne ; retombée au point d'arrivée.",
	],
	"r_pull": [
		"chain",
		"inward",
		0,
		1,
		"Crochet de harpon, lien tendu puis rétraction vers l'archer.",
	],
	"r_weak": [
		"seal",
		"break",
		30,
		1,
		"Deux petits éclats se brisent à hauteur des mains touchées.",
	],
	"t_frost": [
		"ice",
		"rise",
		0,
		1,
		"Une pointe de givre pousse, s'ouvre en éventail puis casse en éclats.",
	],
	"t_fire": [
		"fire",
		"rise",
		0,
		1,
		"Ignition franche, trois langues de braise, déchirure en flammes puis cendres.",
	],
	"t_mark": [
		"seal",
		"stamp",
		30,
		1,
		"Sceau violet fermé sur la cible, puis marque compacte au-dessus d'elle.",
	],
	"t_guard": [
		"guard",
		"brace",
		0,
		1,
		"Deux pans gris de cendre s'assemblent en écran, puis badge de garde.",
	],
	"t_step": [
		"shadow",
		"step",
		0,
		1,
		"Un pli sombre court se défait au départ et se reforme à l'arrivée.",
	],
	"t_bolt": [
		"lightning",
		"rise",
		0,
		1,
		"Foudre déjà au contact, fourche blanche, branches cassées puis étincelles.",
	],
	"t_hex": [
		"shadow",
		"stamp",
		0,
		1,
		"Deux mâchoires d'ombre se rejoignent sur le sceau puis se déchirent.",
	],
	"t_weak": [
		"seal",
		"break",
		0,
		1,
		"Le sceau perd ses quatre appuis et tombe en fragments violets.",
	],
	"t_pull": [
		"shadow",
		"inward",
		0,
		2,
		"Deux griffes d'ombre convergent vers le lanceur, sans conversion de la cible.",
	],
	"t_push": [
		"hammer",
		"thrust",
		0,
		1,
		"Souffle de pierre : gerbe minérale horizontale au contact puis débris.",
	],
	"t_burn": [
		"fire",
		"low",
		0,
		1,
		"Petite ignition aux flancs ; brûlure suivie en badge et pulse au vrai tick.",
	],
	"t_ice": [
		"ice",
		"rise",
		-8,
		2,
		"Deux bouquets de glace se chevauchent sur les cibles réelles de la croix.",
	],
	"t_storm": [
		"lightning",
		"rise",
		0,
		3,
		"Colonne principale et deux branches d'orage, extinction nette après les éclats.",
	],
	"t_touch": ["shadow", "slash", 45, 1, "Griffe courte du Tartare remontant depuis le contact."],
	"t_escape": [
		"shadow",
		"step",
		0,
		2,
		"Deux nappes découpées se séparent au départ, se rejoignent à l'arrivée.",
	],
	"a_venom": [
		"cut",
		"cross",
		-15,
		2,
		"Deux entailles carmin pour le Venin du Styx, qui inflige réellement un saignement.",
	],
	"a_disarm": [
		"seal",
		"break",
		45,
		1,
		"Section nette du signe d'action : retrait de PA, pas immobilisation.",
	],
	"a_lure": [
		"shadow",
		"inward",
		20,
		1,
		"Une griffe sombre se replie vers le lanceur pour l'attirance.",
	],
	"a_stasis": [
		"shadow",
		"brace",
		0,
		2,
		"Deux ailes nocturnes referment le sommeil ; la petite horloge d'état demeure.",
	],
	"a_reap": [
		"reaper",
		"cross",
		0,
		1,
		"Deux immenses faux pourpres se croisent, puis leurs tranchants se déchirent.",
	],
	"a_phantom": [
		"shadow",
		"step",
		-20,
		3,
		"Trois plis sombres étirés marquent départ et arrivée de la traversée.",
	],
	"g_bastion": [
		"bastion",
		"brace",
		0,
		1,
		"Trois remparts à créneaux se dressent autour d'un centre ouvert ; badge de garde ensuite.",
	],
	"g_prison": [
		"chain",
		"bind",
		0,
		3,
		"Trois bandes de maillons de bronze se referment au niveau des jambes.",
	],
	"g_fault": [
		"fire",
		"ground",
		0,
		1,
		"Fissures d'airain brûlantes dans les seules dalles modifiées.",
	],
	"g_crash": [
		"hammer",
		"stamp",
		0,
		1,
		"Masse monumentale d'airain, choc blanc puis fragments lourds au sol.",
	],
	"g_hook": ["chain", "inward", 0, 3, "Trois chaînes crochues tirent ensemble vers le gardien."],
	"g_silence": [
		"seal",
		"break",
		0,
		2,
		"Deux sceaux d'incantation se fendent ; malus de PA signalé séparément.",
	],
	"r_caltrop": ["ice", "ground", 0, 1, "Dents de givre courtes sur chaque case réelle du piège."],
	"r_embers": [
		"fire",
		"ground",
		0,
		1,
		"La flèche répand des îlots de braises sur les dalles effectivement embrasées.",
	],
	"r_net": ["chain", "bind", 45, 3, "Trois liens croisés se rabattent en filet sur les jambes."],
	"r_scatter": [
		"pierce",
		"volley",
		0,
		5,
		"Cinq grands traits du crépuscule convergent en éventail puis se fragmentent.",
	],
	"r_horizon": [
		"wind",
		"step",
		0,
		4,
		"Quatre traînées allongées relient visuellement départ et arrivée réels.",
	],
	"r_bounty": [
		"pierce",
		"thrust",
		0,
		3,
		"Grand fer de chasse central et deux barbes latérales pour la Prime.",
	],
	"t_flamewall": [
		"fire",
		"ground",
		0,
		1,
		"Foyers dessinés distincts sur la croix réelle ; animation basse pendant les deux tours.",
	],
	"t_glacier": [
		"ice",
		"ground",
		0,
		1,
		"Cristaux courts et veines bleues poussent dans les cases du jardin.",
	],
	"t_charm": [
		"shadow",
		"inward",
		0,
		3,
		"Trois appels d'ombre se rétractent vers le lanceur, aucune conversion d'équipe.",
	],
	"t_hourglass": [
		"hourglass",
		"stamp",
		0,
		1,
		"Grand sablier, sable arrêté puis verre brisé ; l'état réel prend le relais.",
	],
	"t_disrupt": [
		"seal",
		"break",
		15,
		3,
		"Trois sceaux déphasés éclatent en fragments d'incantation.",
	],
	"t_cataclysm": [
		"corona",
		"rise",
		0,
		1,
		"Couronne à cinq langues de feu, contact blanc, nappes détachées puis cendres.",
	],
	"i_a_open": ["seal", "stamp", -10, 1, "Deux petits crochets révèlent la première faille."],
	"i_a_strike": [
		"pierce",
		"thrust",
		-8,
		1,
		"Une pointe courte atteint la faille, avec une seule écharde.",
	],
	"i_a_step": ["wind", "step", -10, 1, "Courte plume au sol pour l'approche furtive."],
	"i_a_cut": ["cut", "slash", 20, 1, "Une petite entaille rouge descend, puis disparaît."],
	"i_a_ambush": ["cut", "slash", -45, 1, "Un revers court arrive par le flanc."],
	"i_a_dagger": [
		"pierce",
		"thrust",
		10,
		1,
		"Petite pointe de diversion, contact et deux fragments.",
	],
	"i_a_escape": ["shadow", "step", 0, 1, "Un pli sombre bref accompagne la sortie."],
	"i_g_guard": ["guard", "brace", 0, 1, "Premier écu assemblé, sans monumentalité de Bastion."],
	"i_g_hit": ["hammer", "stamp", -20, 1, "Petit coin d'airain heurtant depuis la garde."],
	"i_g_push": ["wind", "thrust", 0, 1, "Court souffle d'airain vers l'extérieur."],
	"i_g_pull": ["chain", "inward", 0, 1, "Un seul crochet ramène au front."],
	"i_g_weaken": ["guard", "break", 20, 1, "Éclats d'une plaque d'arme affaiblie."],
	"i_g_step": ["wind", "step", 0, 1, "Petite retombée de poussière lourde au pas."],
	"i_g_punish": ["pierce", "thrust", 15, 1, "Une pointe oblique punit le déséquilibre."],
	"i_r_shot": ["pierce", "thrust", 0, 1, "Une flèche simple et son court empennage."],
	"i_r_slow": ["chain", "bind", -20, 1, "Deux fils courts se nouent aux appuis."],
	"i_r_push": ["pierce", "thrust", 8, 1, "Trait court avec éclat de recul."],
	"i_r_step": ["wind", "step", 12, 1, "Poussière discrète du pas d'éclaireur."],
	"i_r_move": ["pierce", "thrust", -16, 1, "Flèche oblique de tir mobile."],
	"i_r_mark": ["seal", "stamp", 45, 1, "Petit viseur losange au-dessus de la proie."],
	"i_r_hunt": ["pierce", "thrust", -5, 1, "Pointe de chasse courte à deux barbes."],
	"i_t_frost": ["ice", "rise", 0, 1, "Trois petites dents de givre surgissent puis cassent."],
	"i_t_hex": ["shadow", "stamp", -12, 1, "Une morsure d'ombre courte ferme le sceau latent."],
	"i_t_mark": ["seal", "stamp", 25, 1, "Deux crochets violets composent le sceau naissant."],
	"i_t_fire": ["fire", "rise", 0, 1, "Petite gerbe de cendres qui se déchire en trois flammes."],
	"i_t_burn": [
		"fire",
		"low",
		10,
		1,
		"Deux braises courtes accrochent les flancs, puis badge de brûlure.",
	],
	"i_t_pull": ["shadow", "inward", 10, 1, "Un appel sombre bref revient vers le lanceur."],
	"i_t_guard": ["guard", "brace", 15, 1, "Petit écran de suie assemblé en deux pans."],
}
static var textures: Dictionary = { }


static func texture(id: String) -> Texture2D:
	if not textures.has(id):
		textures[id] = load("res://vfx/class_cards/cel/art/%s.png" % id)
	return textures[id]


static func apply(entry: Dictionary, id: String) -> Dictionary:
	var brief: Array = CARDS.get(id, [])
	if brief.is_empty():
		brief = [
			FAMILIES.get(entry.family, "seal"),
			"stamp",
			0,
			1,
			"Réponse cel au fait de combat confirmé.",
		]
	entry.merge(
		{
			"art_direction": "cel",
			"cel_clip": brief[0],
			"cel_motion": brief[1],
			"cel_angle": brief[2],
			"cel_copies": brief[3],
			"concept": brief[4],
		},
		true,
	)
	if entry.get("effect", "") in ["mark", "weaken", "lure", "stasis", "disrupt"]:
		entry["ranged"] = false
	return entry


static func playback(entry: Dictionary, hold: bool) -> Dictionary:
	var family: String = entry.family
	var phase: String = entry.get("feedback_phase", "")
	var minor := (
		hold
		or phase
		in ["tick", "expire", "break", "absorb", "immune", "critical", "passive", "warning"]
	)
	var clip: String = (
		FAMILIES.get(family, "seal")
		if minor
		else entry.get("cel_clip", FAMILIES.get(family, "seal"))
	)
	var motion: String = "stamp" if minor else entry.get("cel_motion", "stamp")
	# The real Paris exception removes AP, not a turn: never draw a sleeping hourglass.
	if entry.get("motif", "") == "discord":
		clip = "seal"
		motion = "break"
	if family == "guard":
		motion = "brace"
	if phase in ["expire", "break"]:
		motion = "break"
	return {
		"clip": clip,
		"motion": motion,
		"copies": 1 if minor else int(entry.get("cel_copies", 1)),
		"angle": 0.0 if minor else float(entry.get("cel_angle", 0)),
		"minor": minor,
	}


static func frame_at(u: float, motion: String) -> int:
	var beat := 0
	for end in [.055, .14, .34, .54, .76]:
		if u >= end:
			beat += 1
	if motion == "brace":
		return [0, 1, 2, 2, 2, 2][beat]
	if motion == "break":
		return [2, 3, 3, 4, 4, 5][beat]
	return beat
