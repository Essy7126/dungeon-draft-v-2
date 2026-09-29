extends RefCounted
## Player vocabulary. Numeric effects come from the effective card definition.
const Math := preload("res://core/expedition/consumable_card_math.gd")
const CLASSES := {
	"assassin": [
		"Lames de l'ombre",
		"Marquez une cible, puis frappez son point faible.",
		"Ouvrir la garde → Frapper la faille : préparez votre attaque pour frapper plus fort.",
	],
	"gardien": [
		"Rempart de bronze",
		"Protégez-vous, puis ripostez au contact.",
		"Garde ferme → Heurt du rempart : votre protection renforce l'attaque.",
	],
	"arpenteur": [
		"Chasseur des rives",
		"Bougez pour trouver un angle de tir et garder vos distances.",
		"Déplacez-vous de 2 cases → Tir de relais : attaquez et piochez une carte.",
	],
	"thaumaturge": [
		"Secrets du Léthé",
		"Ralentissez, marquez et transformez le terrain.",
		"Onde du Léthé → Trait de givre : gelez l'eau créée par votre sort.",
	],
}
const DECK_HELP := "Un sort a un nom, comme Estoc. Chaque carte de ce sort permet de le jouer une fois dans la run.\n3 cartes Estoc = 3 utilisations, avec au maximum une utilisation par tour. Améliorer Estoc renforce tous ses exemplaires."
const USE_RULE := "Cette carte disparaît de la run après utilisation. Un même sort ne peut être joué qu'une fois par tour."
const PASSIVES := {
	"assassin": "Une fois par tour, votre première attaque de carte contre un ennemi isolé gagne un bonus égal à 25 % de votre Puissance. Isolé : aucun de ses alliés sur une case voisine, hors diagonales.",
	"gardien": "Une fois par tour, quand votre garde absorbe une attaque ennemie, renvoyez à l'attaquant des dégâts physiques égaux à 25 % de votre Puissance.",
	"arpenteur": "Après une attaque de carte à 3 cases ou plus, revenez sur votre case de début de tour pour 1 PM. Une fois par tour ; la case doit être libre et à 3 cases maximum.",
	"thaumaturge": "Une fois par tour, gagnez une garde égale à 20 % de votre Puissance en appliquant une Marque, une Brûlure ou une Entrave, ou en transformant un terrain élémentaire.",
}
const SPECIALIZATIONS := {
	"execution": "Une fois par tour, votre première attaque contre une cible à 35 % de PV ou moins gagne un bonus égal à 30 % de votre Puissance.",
	"bastion": "Une fois par tour, votre première carte de garde donne 25 % de protection supplémentaire.",
	"crusher": "Une fois par tour, le premier ennemi que vous réussissez à repousser subit des dégâts physiques supplémentaires égaux à 25 % de votre Puissance.",
	"sniper": "Une fois par tour, votre première attaque à 4 cases ou plus gagne un bonus égal à 25 % de votre Puissance.",
	"skirmish": "Une fois par tour, après 2 cases de déplacement volontaire, votre première carte offensive fait piocher 1 carte si votre main n'est pas pleine.",
	"pyre": "La première Brûlure appliquée à chaque tour gagne un bonus de dégâts égal à 10 % de votre Puissance à chaque déclenchement.",
	"frost": "La première Entrave appliquée à chaque tour donne une garde égale à 30 % de votre Puissance.",
	"relay": "Une fois par tour, tuer directement un ennemi marqué permet de transférer sa Marque à un ennemi à 2 cases maximum. Le bonus transféré est limité à 20 % de votre Puissance. Il expire à la fin de votre prochain tour et ne peut plus être transféré.",
}


static func plain(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("([0-9]+(?:[,.][0-9]+)?) P\\b")
	var found := regex.search_all(text)
	found.reverse()
	for hit in found:
		var percent := float(hit.get_string(1).replace(",", ".")) * 100
		text = text.substr(0, hit.get_start()) + ("%.0f %% de Puissance" % percent) + text.substr(
			hit.get_end()
		)
	return text \
			.replace("la prochaine activation", "le prochain tour") \
			.replace("La prochaine activation", "Le prochain tour") \
			.replace("sa prochaine activation", "son prochain tour") \
			.replace("Une activation", "Un tour") \
			.replace("chaque activation", "chaque tour") \
			.replace("activation", "tour") \
			.replace("copies", "cartes") \
			.replace("copie", "carte") \
			.replace("famille", "sort") \
			.replace("impact", "coup")


static func role(row: Dictionary) -> String:
	match str(row.op):
		"guard", "counter", "edict":
			return "Protection"
		"move", "blink", "swap":
			return "Déplacement"
		"draw":
			return "Pioche"
		"heal", "renew", "drain":
			return "Soin"
		"firefield", "icefield":
			return "Terrain"
		"mark", "slow", "stasis", "disrupt", "pull", "push", "converge":
			return "Contrôle"
	return "Attaque"


static func identity(row: Dictionary) -> String:
	var element := "Physique" if row.type == "physical" else "Magie"
	if row.op in ["burn", "firefield"]:
		element = "Feu · magique"
	elif row.op == "icefield" or row.id == "t01":
		element = "Givre · magique"
	elif row.get("waterField", false):
		element = "Eau · magique"
	if row.op in ["move", "blink", "draw", "swap", "guard", "counter", "edict", "heal", "renew"]:
		return role(row)
	return role(row) + " · " + element


static func effect(row: Dictionary, power: float) -> String:
	var lines: PackedStringArray = []
	var damage := Math.rounded(float(row.get("damage", 0)) * power)
	var amount := float(row.get("amount", 0))
	var strength := Math.rounded(amount * power)
	var duration := int(row.get("duration", 2))
	if float(row.get("damage", 0)) > 0:
		lines.append(
			"Inflige %d dégâts %s."
			% [damage, "physiques" if row.type == "physical" else "magiques"]
		)
	var shape := str(row.get("shape", "single"))
	if shape != "single":
		lines.append(
			{
				"cross": "Zone : croix de 5 cases.",
				"radius2": "Zone : rayon de 2 cases.",
				"line3_perpendicular": "Zone : ligne de 3 cases, perpendiculaire au tir.",
			}.get(shape, "")
		)
	match str(row.op):
		"guard", "counter":
			lines.append(
				"Garde : absorbe %d dégâts avant vos PV. Expire à votre prochain tour." % strength
			)
			if row.op == "counter":
				lines.append(
					"Avant votre prochain tour, riposte de %d dégâts au premier ennemi qui vous frappe au contact."
					% Math.rounded(float(row.counter) * power)
				)
		"move":
			lines.append("Avancez jusqu'à %d cases par un chemin libre." % int(row.max))
		"blink":
			lines.append("Téléportez-vous jusqu'à %d cases." % int(row.max))
		"push":
			lines.append("Repousse la cible de %d case(s)." % int(amount))
		"pull":
			lines.append(
				"Attire la cible de %d case(s)." % int(amount) if not row.get("choosePull", false) else "Attire la cible de 1 ou 2 cases, au choix."
			)
		"mark":
			lines.append(
				"Marque : le prochain coup de carte inflige %d dégâts supplémentaires. Expire après %d tours ennemis."
				% [strength, duration]
			)
		"slow":
			lines.append("Entrave : −%d PM au prochain tour de la cible." % int(amount))
		"burn", "bleed":
			lines.append(
				"%s : %d dégâts à chacun des %d prochains tours de la cible."
				% ["Brûlure" if row.op == "burn" else "Saignement", strength, duration]
			)
		"draw":
			lines.append(
				"Piochez jusqu'à %d cartes, sans dépasser la taille de votre main." % int(amount)
			)
		"drain":
			lines.append("Récupérez %d %% des PV retirés à la cible." % roundi(amount * 100))
		"disrupt":
			lines.append(
				"La prochaine attaque de la cible inflige 50 % de dégâts en moins (25 % contre un boss)."
			)
		"stasis":
			lines.append(
				"Retire la Marque pour faire sauter le prochain tour de la cible. Elle devient immunisée pendant 3 tours.\nBoss : réduit plutôt sa prochaine attaque de 25 %."
			)
		"guardburst":
			lines.append(
				"Sacrifiez jusqu'à %d points de votre garde. Ajoute 150 %% de la garde sacrifiée aux dégâts."
				% floori(float(row.get("sacrificeCap", .8)) * power)
			)
		"swap":
			lines.append("Échangez votre position avec celle de la cible. Sans effet sur les boss.")
		"firefield":
			lines.append(
				"Feu : %d dégâts magiques à toute unité qui commence son tour dessus, même vous. Dure %d tours."
				% [strength, duration]
			)
		"icefield":
			lines.append(
				"Glace : les ennemis qui commencent leur tour dessus perdent %d PM. Dure %d tours."
				% [int(amount), duration]
			)
		"converge":
			lines.append("Attire d'une case les ennemis à 2 cases du centre, puis frappe en croix.")
		"heal":
			lines.append("Récupérez %d PV." % strength)
		"edict":
			lines.append(
				"Jusqu'à votre prochain tour, le premier coup mortel vous laisse à 1 PV. Ne protège pas de la pression des combats trop longs."
			)
		"renew":
			lines.append(
				"Récupérez %d %% de vos PV maximum. Termine votre tour." % roundi(amount * 100)
			)
	var conditional_damage := (float(row.get("damage", 0)) + float(row.get("bonus", 0))) * power
	var bonus := Math.rounded(conditional_damage) - damage
	match str(row.get("condition", "")):
		"marked":
			lines.append("+%d dégâts si la cible porte une Marque." % bonus)
		"moved":
			lines.append(
				"+%d dégâts après avoir parcouru %d case(s) avec vos PM ou un déplacement, ce tour."
				% [bonus, int(row.get("movementThreshold", 2))]
			)
		"execute":
			lines.append("+%d dégâts si la cible a 35 %% de PV ou moins." % bonus)
		"guarded":
			lines.append("+%d dégâts si vous avez encore de la garde." % bonus)
		"absorbed":
			lines.append("+%d dégâts si votre garde a absorbé un coup au tour précédent." % bonus)
	if row.get("pierce", false):
		lines.append("Ignore la résistance physique.")
	if row.get("shield", 0) > 0:
		lines.append("Gagnez %d points de garde." % Math.rounded(float(row.shield) * power))
	if row.get("retain", 0) > 0:
		lines.append("Vous pouvez garder une autre carte en main pour le tour suivant.")
	if row.get("drawOnMoved", 0) > 0:
		lines.append(
			"Après %d cases de déplacement ce tour, piochez 1 carte si votre main n'est pas pleine."
			% int(row.get("movementThreshold", 2))
		)
	if row.get("collisionGuard", 0) > 0:
		lines.append(
			"Si un mur arrête la poussée, gagnez %d points de garde (une fois)."
			% Math.rounded(float(row.collisionGuard) * power)
		)
	if row.get("waterField", false):
		lines.append("Recouvre les cases de la croix d'eau pendant %d tours." % duration)
	if row.get("waterReaction", "") == "freeze":
		lines.append(
			"Gèle l'eau créée par un sort pendant %d tours : −1 PM aux ennemis qui commencent leur tour dessus."
			% int(row.get("waterReactionDuration", 2))
		)
	if row.get("waterReaction", "") == "steam":
		lines.append(
			"Sur une case d'eau créée par un sort : crée de la vapeur qui bloque la vue pendant %d tour(s)."
			% int(row.get("waterReactionDuration", 1))
		)
	return "\n".join(lines)


static func power_reference(power: float) -> String:
	var value := String.num(power, 1).replace(".", ",")
	return "Valeurs de base pour %s de Puissance. Protections et bonus peuvent modifier le résultat." % value


static func scaling(row: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in ["damage", "bonus", "counter", "shield", "collisionGuard"]:
		if float(row.get(key, 0)) <= 0:
			continue
		var title: String = {
			"damage": "Dégâts",
			"bonus": "Bonus conditionnel",
			"counter": "Riposte",
			"shield": "Garde",
			"collisionGuard": "Garde de collision",
		}[key]
		parts.append("%s : %.0f %% de votre Puissance." % [title, float(row[key]) * 100])
	if row.op in ["guard", "counter", "mark", "burn", "bleed", "firefield", "heal"]:
		parts.append(
			"%s : %.0f %% de votre Puissance."
			% [
				{
					"guard": "Garde",
					"counter": "Garde",
					"mark": "Bonus de Marque",
					"burn": "Brûlure par tour",
					"bleed": "Saignement par tour",
					"firefield": "Feu par tour",
					"heal": "Soin",
				}[row.op],
				float(row.amount) * 100,
			]
		)
	if row.op == "guardburst":
		parts.append(
			"Garde sacrifiable : jusqu'à 80 % de votre Puissance, dans la limite de votre garde actuelle."
		)
	return "\n".join(parts) if not parts.is_empty() else "Cet effet ne dépend pas de votre Puissance."
