class_name CatabaseMonsterEncounterCatalog
extends RefCounted
## Authored packs budget numbers, access and spell economy independently.
const Evolution = preload("res://core/expedition/catabase_monster_evolution_catalog.gd")
const EarlyEncounters = preload("res://core/expedition/catabase_early_encounters.gd")
const UNIT_PATHS := {
	&"sentinelle": "res://data/units/enemies/catabase_sentinelle_airain.tres",
	&"rejeton": "res://data/units/enemies/catabase_rejeton_braise.tres",
	&"molosse": "res://data/units/enemies/catabase_molosse_styx.tres",
	&"lamie": "res://data/units/enemies/catabase_lamie_lethe.tres",
}
const RECOVERY_DEPTHS := [5, 9, 13, 17]


static func uses_monsters(node: Dictionary) -> bool:
	var depth := int(node.get("depth", 1))
	return depth > 1 and depth not in [7, 20] \
		and str(node.get("kind", "normal")) in ["normal", "elite"]


static func configure_encounter(encounter: EncounterDefinition, node: Dictionary) -> void:
	if not uses_monsters(node):
		return
	var pack := encounter_preview(node)
	var roles := composition_for(node)
	encounter.roster_units = []
	encounter.roster_counts = PackedInt32Array()
	encounter.minimum_path_distance_by_role = {}
	encounter.maximum_path_distance_by_role = {}
	encounter.shared_normal_summon_budget = 0
	encounter.shared_chief_summon_budget = 0
	encounter.disabled_ability_ids = []
	encounter.formation_profiles = formations_for(node)
	var counts := {}
	for role in roles:
		counts[role] = int(counts.get(role, 0)) + 1
	for role: StringName in counts:
		var unit := Evolution.build_unit(role, node)
		EarlyEncounters.tune(unit, role, node)
		# Five colosses deliberately trade access for numbers.
		if int(pack.get("mp_cap", 0)) > 0:
			unit.max_mp = mini(unit.max_mp, int(pack.mp_cap))
		encounter.roster_units.append(unit)
		encounter.roster_counts.append(int(counts[role]))
		var minimum_distance := maxi(5, unit.max_mp + 3)
		if unit.combat_style == 1:
			minimum_distance = maxi(minimum_distance, unit.maximum_range + 1)
		encounter.minimum_path_distance_by_role[unit.tactical_role_id] = minimum_distance
		encounter.maximum_path_distance_by_role[unit.tactical_role_id] = minimum_distance + 8
	encounter.living_enemy_cap = roles.size()


static func composition_for(node: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(encounter_preview(node).get("roles", []))
	return result


static func formations_for(node: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(encounter_preview(node).get("formations", [&"split", &"double_line"]))
	return result


static func hp_factor(node: Dictionary) -> float:
	return float(encounter_preview(node).get("hp_factor", 1.0))


static func attack_factor(node: Dictionary) -> float:
	return float(encounter_preview(node).get("attack_factor", 1.0))


static func encounter_preview(node: Dictionary) -> Dictionary:
	if not uses_monsters(node):
		return {}
	var early := EarlyEncounters.preview(node)
	if not early.is_empty():
		return early
	var reward := str(node.get("reward", "melee"))
	match int(node.get("depth", 2)):
		2:
			if reward == "ranged":
				return _pack("Les trois angles", [&"archer", &"archer", &"archer"],
					"Trois tireurs fragiles occupent des lignes différentes.", "Fermez une ligne avec le couvert, puis engagez un tireur.", 0.90, 0.85, "split")
			return _pack("Les porteurs de bronze", [&"brute", &"brute"],
				"Deux brutes à 2 PM, une seule attaque de contact.", "Contournez leur approche lente et concentrez vos frappes.", 1.0, 1.0, "line")
		3:
			if reward == "mobility":
				return _pack("La première chasse", [&"archer", &"molosse", &"molosse"],
					"Deux prédateurs approchent sous la couverture d'un tireur.", "Utilisez un goulet pour éviter les deux morsures ensemble.", 0.90, 0.85, "left_flank")
			return _pack("Le tribut de bronze", [&"brute", &"brute"],
				"Deux gardiens plus résistants tiennent le passage.", "Leur lenteur permet de les séparer avant le contact.", 1.05, 1.0, "double_line")
		5:
			if reward == "ranged":
				return _pack("Les roseaux sifflants", [&"archer", &"archer", &"archer"],
					"Trois tireurs gardent les traversées.", "Changez de ligne derrière les obstacles ; menacez le flanc.", 0.80, 0.80, "split")
			return _pack("La gardienne du gué", [&"lamie", &"brute"],
				"La magie du Léthé accompagne un défenseur lent.", "Approchez la mage en gardant une issue hors du contact.", 1.0, 0.90, "double_line")
		6:
			if reward == "elemental":
				return _pack("La meute des braises", [&"conducteur", &"molosse", &"molosse", &"molosse"],
					"Un conducteur marque sa proie pour trois molosses.", "Brisez la ligne du conducteur ou éliminez-le avant l'encerclement.", 0.85, 0.70, "left_flank")
			return _pack("La procession des cinq", [&"brute", &"brute", &"brute", &"brute", &"brute"],
				"Cinq lourds vétérans avancent à 2 PM.", "Faites-les converger dans vos zones ; conservez une sortie.", 0.65, 0.65, "double_line", 2)
		9:
			if reward == "mobility":
				return _pack("La nuée du Styx", [&"serviteur", &"serviteur", &"serviteur", &"serviteur", &"serviteur", &"serviteur"],
					"Six petites bêtes rapides et fragiles chassent ensemble.", "Les zones et les passages étroits réduisent vite leur nombre.", 0.90, 0.65, "split")
			return _pack("Le premier officiant", [&"officiant", &"brute", &"porteur", &"porteur"],
				"Un soigneur à réserve limitée soutient un garde et deux porteurs.", "Forcez ses soins sur les petites cibles ou atteignez le soutien.", 0.85, 0.80, "double_line")
		10:
			if reward == "control":
				return _pack("L'aimant et l'enclume", [&"rabatteur", &"executeur"],
					"Une chaîne attire vers le grand coup préparé de l'exécuteur.", "Séparez le duo, quittez le contact de l’exécuteur et bloquez la chaîne par le couvert.", 1.15, 0.85, "line")
			return _pack("Les lignes de chasse", [&"archer", &"archer", &"archer", &"molosse", &"molosse", &"lamie"],
				"Trois tireurs, deux poursuivants et une mage menacent plusieurs fronts.", "Cassez les lignes de tir et supprimez un flanc avant de traverser.", 0.65, 0.55, "split")
		11:
			if reward == "discovery":
				return _pack("La garde des mémoires", [&"officiant", &"brute", &"brute", &"archer", &"archer"],
					"Un soutien soigne les défenseurs sous couverture des tireurs.", "Contournez la garde ou épuisez les soins sur une cible isolée.", 0.70, 0.65, "double_line")
			return _pack("Les deux piliers", [&"brute", &"brute", &"serviteur", &"serviteur", &"serviteur", &"serviteur", &"serviteur"],
				"Deux lourds tiennent le centre ; cinq serviteurs remplissent les intervalles.", "Ouvrez de l'espace avec une zone avant d'affronter les piliers.", 0.85, 0.60, "double_line")
		13:
			if reward == "armor":
				return _pack("La batterie d'airain", [&"porte_egide", &"porte_egide", &"archer", &"archer"],
					"Deux porteurs d'égide protègent les tireurs proches.", "Déplacez un protecteur ou attaquez hors de sa couverture.", 0.65, 0.65, "double_line")
			return _pack("La fournaise vivante", [&"fondeur", &"deplaceur", &"deplaceur"],
				"Un fondeur crée des braises ; deux molosses cherchent à vous y pousser.", "Éliminez un pousseur et conservez une sortie hors du feu.", 0.90, 0.75, "left_flank")
		14:
			if reward == "melee":
				return _pack("Les cinq colosses", [&"brute", &"brute", &"brute", &"porte_egide", &"porte_egide"],
					"Cinq colosses à 2 PM, dont deux boucliers de groupe.", "Rassemblez-les pour les zones, puis séparez les protecteurs de leurs alliés.", 0.62, 0.60, "double_line", 2)
			return _pack("La chasse blanche", [&"guetteur", &"guetteur", &"traqueur", &"chasseur", &"chasseur", &"tisseuse"],
				"Les ralentissements préparent les tirs et la poursuite sur les ponts.", "Quittez le givre et les lignes de visée ; attaquez une aile à la fois.", 0.65, 0.55, "split")
		15:
			return _pack("Le serment de l'enclume", [&"rabatteur", &"executeur"],
				"Le rabatteur mobile attire vers l'exécuteur et ses coups préparés.", "Rompez leur alignement et exploitez le tour de préparation.", 1.10, 0.85, "line")
		16:
			return _pack("Le champion sans repos", [&"champion"],
				"Un seul champion alterne chaîne, frappes et garde avec ses 6 PA.", "Exploitez le délai de sa chaîne et évitez son contact lorsque le revers est disponible.", 1.40, 0.90, "line")
		17:
			if reward == "armor":
				return _pack("Le dernier rempart", [&"porte_egide", &"guetteur", &"protecteur"],
					"Un bouclier et un officiant soutiennent le tir du guetteur.", "La garde est courte : isolez le tireur ou atteignez le soutien.", 0.75, 0.70, "double_line")
			return _pack("Le hurlement du jardin", [&"alpha", &"serviteur", &"serviteur", &"serviteur", &"serviteur"],
				"Un alpha renforce quatre petits chasseurs.", "Frappez la meute groupée ou éliminez l'alpha qui la renforce.", 0.85, 0.65, "left_flank")
		18:
			if reward == "melee":
				return _pack("La phalange des damnés", [&"rabatteur", &"executeur", &"artilleur", &"deplaceur", &"deplaceur", &"oracle"],
					"Attraction, poussées, bombardement et soutien composent le dernier assaut.", "Brisez d'abord une combinaison : oracle, artilleur ou rabatteur selon votre angle.", 0.62, 0.55, "split")
			return _pack("Le convoi des âmes", [&"collecteur", &"brute", &"brute", &"brute", &"porteur", &"porteur", &"porteur", &"porteur"],
				"Trois gardes protègent un collecteur dont les soins exigent un porteur proche.", "Interceptez les quatre porteurs fragiles ou éloignez-les du collecteur.", 0.68, 0.55, "double_line")
	return _pack("La garde errante", [&"brute", &"archer"],
		"Un défenseur et un tireur tiennent la salle.", "Séparez leur ligne de défense.", 1.0, 0.85, "split")


static func _pack(title: String, roles: Array, summary: String, counterplay: String,
		hp: float, attack: float, formation: String, mp_cap: int = 0) -> Dictionary:
	return {"name": title, "count": roles.size(), "roles": roles, "summary": summary,
		"counterplay": counterplay, "hp_factor": hp, "attack_factor": attack,
		"formations": [StringName(formation)], "mp_cap": mp_cap}
