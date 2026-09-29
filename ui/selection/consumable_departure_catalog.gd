extends RefCounted
const Language := preload("res://ui/expedition/card_player_language.gd")
const Rules := preload("res://core/expedition/consumable_card_catalog.gd")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const Ecology := preload("res://core/expedition/card_ecosystem_catalog.gd")
const CLASSES := {
	"assassin": [
		"Assassin",
		"Isoler · marquer · exécuter",
		Language.PASSIVES.assassin,
		"Marquez une cible ou isolez-la avant de jouer vos attaques les plus fortes.",
	],
	"gardien": [
		"Gardien",
		"Protéger · déplacer · riposter",
		Language.PASSIVES.gardien,
		"La garde absorbe les dégâts avant vos PV et expire au début de votre prochain tour.",
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
		Language.PASSIVES.thaumaturge,
		"Alternez les éléments et les effets. Le bonus de garde ne se déclenche qu’une fois par tour.",
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
				Language.SPECIALIZATIONS[spec],
			]
		)
	return result
