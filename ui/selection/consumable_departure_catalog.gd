extends RefCounted
const Rules := preload("res://core/expedition/consumable_card_catalog.gd")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const Ecology := preload("res://core/expedition/card_ecosystem_catalog.gd")
const CLASSES := {
	"assassin": [
		"Assassin",
		"Isoler · marquer · exécuter",
		"Premier impact sur une cible isolée : +0,25 P, une fois par tour.",
		"Préparez une cible avant de dépenser vos copies offensives.",
	],
	"gardien": [
		"Gardien",
		"Protéger · déplacer · riposter",
		"Première attaque ennemie absorbée par la garde : renvoie 0,25 P.",
		"La garde expire au début de votre prochaine activation.",
	],
	"arpenteur": [
		"Arpenteur",
		"Se déplacer · viser · se replier",
		"Après un impact à 3 cases ou plus, retour à l'ancre pour 1 PM, une fois par tour.",
		"La case de départ doit être libre et à 3 cases au plus.",
	],
	"thaumaturge": [
		"Thaumaturge",
		"Affaiblir · transformer · déchaîner",
		"Première marque, brûlure, entrave ou transformation du tour : +0,20 P de garde.",
		"Ces déclenchements partagent un seul compteur par tour.",
	],
}


static func preset(id := "assassin") -> Dictionary:
	return Rules.preset(id)


static func valid_departure(value: Dictionary) -> bool:
	return Rules.valid_departure(value)


static func icon(id: String) -> Texture2D:
	return Spells.LegacyIcons.icon(id)


static func make_spell(id: String, _rank := 0) -> Spell:
	return Spells.make_spell(id)


static func starter_pool(id: String) -> Array[String]:
	return Rules.pool(id, "normal", true)


static func row(id: String) -> Array:
	var card := Rules.card(id)
	return [
		id,
		card.affinity,
		card.name,
		0,
		0,
		0,
		0,
		0,
		0,
		"Physique" if card.type == "physical" else "Magique",
	]


static func specs(id: String) -> Array:
	var result := []
	for spec in Rules.class_row(id).specs:
		result.append(
			[
				spec,
				preload("res://ui/expedition/consumable_cards_presenter.gd").SPECS.get(
					spec,
					str(spec).capitalize(),
				),
				Rules.data().specs[spec],
			]
		)
	return result
