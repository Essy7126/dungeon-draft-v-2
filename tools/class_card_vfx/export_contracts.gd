extends RefCounted
## Reproducible brief exported from the exact catalogue loaded by the visual gallery.
const Catalog := preload("res://vfx/class_cards/class_card_vfx_catalog.gd")
const LIFETIMES := {
	"mark": "Marque : 1 activation de la cible.",
	"slow": "Signe de ralentissement : retrait de 1 PM à la prochaine activation.",
	"frost": "Signe de givre : retrait de 1 PM à la prochaine activation.",
	"ice_area": "Cibles réelles de la croix ; retrait de 1 PM à la prochaine activation.",
	"root": "Signe de liens : réduction de PM pendant 1 activation, sans promettre un blocage total.",
	"disrupt": "Badge de sceau brisé : réduction de PA pendant 1 activation.",
	"lure": "Attraction confirmée puis signe de perte de PA pendant 1 activation ; équipe inchangée.",
	"guard": "Badge d’écu intact tant que le bouclier existe : 1 activation du porteur, 2 si améliorée ; disparition sur consommation ou expiration.",
	"bleed": "Badge de saignement maintenu pendant 2 activations ; pulsation seulement sur dégâts périodiques réels.",
	"burn": "Badge de brûlure maintenu pendant 2 activations ; ignition puis pulsations sur dégâts réels.",
	"weaken": "Badge d’affaiblissement pendant 1 activation de Prouesse réduite.",
	"stasis": "Cible marquée requise ; suspension 1 activation, protection anti-stase 3. Paris : signe PA, aucun sommeil affiché.",
	"fire_field": "Dalles réelles pendant 2 tours de terrain ; pulsation sur dégâts au début du tour seulement.",
	"ice_field": "Dalles réelles pendant 2 tours de terrain ; signe de PM réduit 1 activation à l'entrée ou lors de la pose sous une unité.",
	"move": "Départ puis arrivée sur fin du mouvement visuel confirmé ; aucun signe de trajet bloqué.",
	"blink": "Dissolution puis retour à la destination réelle ; pas de trajet fictif entre les obstacles.",
}


static func write(out: String) -> void:
	var rows: Array = []
	var lines := PackedStringArray(
		[
			"# Contrats visuels des cartes — 22 septembre 2026",
			"",
			"Instantané reproductible du catalogue chargé par la galerie native. DA : animation cel. Poses dessinées, aplats et ruptures de silhouette ; arrière / avant séparés autour du personnage.",
			"",
			"112 compositions explicites construites avec 17 séquences de six poses dessinées, soit 102 poses. Ce ne sont pas 112 animations entièrement indépendantes. Les 28 anciennes cartes `s_` restent sur leur rendu de compatibilité ; les 28 initiations `i_` actuelles sont incluses.",
			"Huit épiques reçoivent une silhouette monumentale dédiée ; dix autres grosses dépenses de PA ont un impact renforcé et quatre terrains à 3 PA une naissance plus intense. Contact immédiat, déploiement en 0,15–0,26 s, rémanence jusqu'à 1,75 s. Les silhouettes de puissance ne sont jamais rejouées par le maintien, un tick ou une expiration.",
			"",
			"Les secondes ci-dessous mesurent la rémanence visuelle après confirmation. Elles ne retardent aucun dégât. Un bonus conditionnel n'a pas de flash de réussite inventé : le rapport actuel ne fournit pas de confirmation distincte par cible. Aucun agrandissement de zone au-delà des cellules réellement affectées.",
			"",
			"| Carte | Concept avant rendu | Séquence / composition | Impact | Maintien / fin |",
			"|---|---|---|---:|---|",
		]
	)
	for id in Catalog.Cards.pool():
		var entry := Catalog.recipe(id)
		var spell := Catalog.Cards.make_spell(id)
		var lifetime: String = LIFETIMES.get(
			entry.effect,
			"Impact confirmé puis dissipation ; aucun état durable inventé.",
		)
		rows.append(
			{
				"id": id,
				"name": entry.name,
				"concept": entry.get("concept", "MISSING"),
				"motif": entry.get("motif", ""),
				"cel_clip": entry.cel_clip,
				"cel_motion": entry.cel_motion,
				"cel_copies": entry.cel_copies,
				"variant": entry.get("variant", 0),
				"power": entry.get("power", 0),
				"power_shape": entry.get("power_shape", ""),
				"visual_seconds": entry.duration,
				"width_cells": entry.width,
				"lifetime": lifetime,
				"actual_rule_description": spell.description,
				"impact_delay_seconds": spell.impact_delay_seconds,
			}
		)
		lines.append(
			"| %s (`%s`) | %s | %s / %s × %d | %.2f s | %s |"
			% [
				entry.name,
				id,
				entry.get("concept", "MISSING"),
				entry.cel_clip,
				entry.cel_motion,
				entry.cel_copies,
				entry.duration,
				lifetime,
			]
		)
	lines.append_array(
		PackedStringArray(
			[
				"",
				"## Production et validation",
				"",
				"Brief → six poses cel → animation cadencée → événements confirmés → galerie → arène → validation des durées.",
				"Références : [dossier de production](cards_vfx_cel_2026-09-22.md).",
				"",
				"L'atelier utilise un personnage fixe. Les captures cel utilisent la vraie arène avec IA suspendue et une horloge VFX échantillonnée. Ce ne sont pas des mesures GPU en combat chargé.",
				"Les règles effectivement chargées sont conservées dans contracts.json et les rapports des lancers.",
			]
		)
	)
	var json_file := FileAccess.open(out + "contracts.json", FileAccess.WRITE)
	json_file.store_string(JSON.stringify(rows, "\t"))
	var doc_path := "res://docs/design/achilles/cards_vfx_cel_contracts_2026-09-22.md"
	var doc_file := FileAccess.open(doc_path, FileAccess.WRITE)
	doc_file.store_string("\n".join(lines) + "\n")
