extends RefCounted
## Explicit body gestures for the current deck; icons are not animation identifiers.
## Empty reference means native neutral while a dedicated gesture is still missing.
const CURRENT := {
	"n01": ["a_ambush", "Estoc : frappe de lame partagée"],
	"n02": ["guard", "Garde brève : sceau de parade"],
	"n03": ["dash", "Pas latéral : déplacement natif"],
	"n04": ["kick", "Heurt : coup de talon haut"],
	"n05": ["r_shot", "Trait court : tir à l’arc, malgré son ancienne icône de dague"],
	"n06": ["r_shot", "Repérage : trait de marquage"],
	"n07": ["r_shot", "Entrave légère : trait de contrôle"],
	"n08": ["", "Recentrage : geste utilitaire à créer"],
	"a01": ["a_dagger", "Ouvrir la garde : lancer de lame à courte portée"],
	"a02": ["a_ambush", "Frapper la faille : frappe de lame"],
	"a03": ["a_sweep", "Entaille tenace : entailles de dagues"],
	"a04": ["a_ambush", "Attaque oblique : riposte oblique dédiée"],
	"a05": ["blink", "Bond spectral : départ neutre, téléportation réelle"],
	"a06": ["a_sweep", "Dernier verdict : coupe appuyée partagée"],
	"a07": ["a_dagger", "Pointe franche : projection de lame jusqu’à trois cases"],
	"a08": ["a_dagger", "Couper le souffle : lancer perturbateur"],
	"a09": ["incantation", "Sommeil marqué : incantation de malédiction"],
	"g01": ["incantation", "Garde ferme : incantation de protection"],
	"g02": ["a_ambush", "Heurt du rempart : frappe partagée, arme dédiée manquante"],
	"g03": ["kick", "Repousser : coup de talon haut"],
	"g04": ["pull", "Ramener au front : crochet spectral et traction du buste"],
	"g05": ["guard", "Contre préparé : sceau de parade, riposte au coup reçu"],
	"g06": ["kick", "Choc de masse : poussée par coup de talon partagé"],
	"g07": ["a_ambush", "Dette du bronze : riposte partagée"],
	"g08": ["incantation", "Bastion vivant : incantation de protection"],
	"g09": ["t_mark", "Répercussion : geste de projection partagé"],
	"r01": ["r_shot", "Tir de relais : tir tendu"],
	"r02": ["r_shot", "Trait de recul : flèche, pas un coup de pied"],
	"r03": ["r_shot", "Flèche entravante : tir tendu"],
	"r04": ["r_fan", "Volée croisée : volée"],
	"r05": ["blink", "Au-delà du front : téléportation"],
	"r06": ["r_fan", "Pluie de pointes : volée"],
	"r07": ["r_shot", "Trait harpon : tir tendu"],
	"r08": ["blink", "Permutation : échange réel des positions, pas une marche"],
	"r09": ["r_shot", "La longue vue : tir tendu"],
	"t01": ["t_mark", "Trait de givre : incantation sans braise"],
	"t02": ["t_fire", "Braise tenace : projection de braise"],
	"t03": ["incantation", "Sceau ombreux : incantation de malédiction"],
	"t04": ["t_mark", "Onde du Léthé : incantation partagée"],
	"t05": ["t_fire", "Bûcher des ombres : projection de feu"],
	"t06": ["incantation", "Jardin de givre : incantation de glyphe"],
	"t07": ["t_mark", "Prélèvement : geste de siphon partagé"],
	"t08": ["t_mark", "Convergence : appel magique"],
	"t09": ["incantation", "Résonance du sceau : incantation de résonance"],
	"l01": ["t_mark", "Orage du passage : incantation de zone"],
	"l02": ["incantation", "Grâce du bronze : incantation de soin"],
	"d01": ["", "Décret du dernier souffle : protection dédiée à créer"],
	"i01": ["", "Seconde aurore : soin dédié à créer"],
	"fallback_strike": ["a_ambush", "Attaque de secours : frappe de lame"],
	"fallback_guard": ["guard", "Garde de secours : sceau de parade"],
}
const Legacy := preload("res://core/expedition/class_card_catalog.gd")
## Visual recipes only. Spell IDs, ranges, damage and state rules stay authoritative.
const EFFECTS := {
	"n01": "a_pierce",
	"n02": "a_parry",
	"n03": "r_step",
	"n04": "a_push",
	"n05": "r_shot",
	"n06": "r_mark",
	"n07": "r_slow",
	"n08": "t_guard",
	"a01": "a_dagger",
	"a02": "a_finish",
	"a03": "a_cut",
	"a04": "a_ambush",
	"a05": "a_phantom",
	"a06": "a_execute",
	"a07": "a_dagger",
	"a08": "a_dagger",
	"a09": "a_stasis",
	"g01": "g_guard",
	"g02": "g_hit",
	"g03": "g_push",
	"g04": "g_pull",
	"g05": "g_guard",
	"g06": "g_crush",
	"g07": "g_riposte",
	"g08": "g_bastion",
	"g09": "g_push",
	"r01": "r_shot",
	"r02": "r_push",
	"r03": "r_slow",
	"r04": "r_fan",
	"r05": "r_horizon",
	"r06": "r_fan",
	"r07": "r_pull",
	"r08": "r_horizon",
	"r09": "r_long",
	"t01": "t_frost",
	"t02": "t_burn",
	"t03": "t_mark",
	"t04": "t_ice",
	"t05": "t_flamewall",
	"t06": "t_glacier",
	"t07": "t_touch",
	"t08": "t_pull",
	"t09": "t_hex",
	"l01": "t_storm",
	"l02": "t_guard",
	"d01": "g_guard",
	"i01": "t_guard",
	"fallback_strike": "a_pierce",
	"fallback_guard": "a_parry",
}


static func resolve(spell_id: String) -> Dictionary:
	var id := spell_id.trim_prefix("cast:")
	if id.begins_with("cc2_"):
		var key := id.trim_prefix("cc2_")
		if not CURRENT.has(key):
			return { "reference": "", "status": "unmapped", "reason": "Carte inconnue : " + id }
		var entry: Array = CURRENT[key]
		return {
			"reference": entry[0],
			"status": "pending" if entry[0] == "" else "assigned",
			"reason": entry[1],
		}
	id = id.trim_prefix("class_")
	if id in ["basic_guard", "basic_strike"]:
		return {
			"reference": "" if id == "basic_guard" else "a_ambush",
			"status": "assigned",
			"reason": "Secours historique",
		}
	var row := Legacy.row(id)
	if row.is_empty():
		return { "reference": "", "status": "unmapped", "reason": "Sort sans liaison : " + id }
	var effect: String = row[7]
	var reference := ""
	var logical := id.trim_prefix("i_").trim_prefix("s_")
	if effect == "move":
		reference = "dash"
	elif effect == "blink":
		reference = "blink"
	elif effect == "guard":
		reference = ""
	elif row[1] == "thaumaturge":
		reference = "t_fire" if effect in ["fire", "burn", "fire_field"] else "t_mark"
	elif logical in ["a_push", "g_push", "g_crush"]:
		reference = "kick"
	elif logical in ["r_fan", "r_scatter"]:
		reference = "r_fan"
	elif row[1] == "arpenteur" and int(row[5]) > 1 and effect not in ["ice_field", "root"]:
		reference = "r_shot"
	elif logical in ["a_dagger", "g_shot", "a_pull"]:
		reference = "a_dagger"
	elif effect in ["stasis", "lure", "mark", "root", "ice_field", "fire_field"]:
		reference = "t_mark"
	elif effect in ["bleed", "cross", "execute"]:
		reference = "a_sweep"
	else:
		reference = "a_ambush"
	return {
		"reference": reference,
		"status": "pending" if reference == "" else "assigned",
		"reason": "Famille historique : " + str(row[2]),
	}
