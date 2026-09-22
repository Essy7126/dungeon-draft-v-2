extends RefCounted
## Reproducible brief exported from the exact catalogue loaded by the visual gallery.
const Catalog := preload("res://vfx/class_cards/class_card_vfx_catalog.gd")
const LIFETIMES := {
	"mark": "Marque : 1 activation de la cible.",
	"slow": "Liens aux chevilles : retrait de 1 PM à la prochaine activation.",
	"frost": "Givre aux chevilles : retrait de 1 PM à la prochaine activation.",
	"ice_area": "Cibles réelles de la croix ; retrait de 1 PM à la prochaine activation.",
	"root": "Liens bas : réduction de PM pendant 1 activation, sans promettre un blocage total.",
	"disrupt": "Fragments près du buste : réduction de PA pendant 1 activation.",
	"lure": "Attraction confirmée puis signe de perte de PA pendant 1 activation ; équipe inchangée.",
	"guard": "Pans maintenus tant que le bouclier existe : 1 activation du porteur, 2 si améliorée ; disparition sur consommation ou expiration.",
	"bleed": "Filaments maintenus pendant 2 activations ; pulsation seulement sur dégâts périodiques réels.",
	"burn": "Braises maintenues pendant 2 activations ; ignition puis pulsations sur dégâts réels.",
	"weaken": "Éclats descendants pendant 1 activation de Prouesse réduite.",
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
			"# Contrats visuels des cartes — 21 septembre 2026",
			"",
			"Instantané reproductible du catalogue chargé par la galerie native. DA : lumière éthérée, matière transparente, volutes ; noyau contrasté, silhouette lisible, personnage préservé.",
			"",
			"112 fiches explicites ; 20 motifs de matière partagés, avec construction, largeur et rythme propres aux cartes. Ce ne sont pas 112 simulations Blender indépendantes. Les 28 anciennes cartes `s_` restent sur leur rendu de compatibilité ; les 28 initiations `i_` actuelles sont incluses.",
			"Huit épiques reçoivent une silhouette monumentale dédiée ; dix autres grosses dépenses de PA ont un impact renforcé et quatre terrains à 3 PA une naissance plus intense. Contact immédiat, déploiement en 0,15–0,26 s, rémanence jusqu'à 1,75 s. Les silhouettes de puissance ne sont jamais rejouées par le maintien, un tick ou une expiration.",
			"",
			"Les secondes ci-dessous mesurent la rémanence visuelle après confirmation. Elles ne retardent aucun dégât. Un bonus conditionnel n'a pas de flash de réussite inventé : le rapport actuel ne fournit pas de confirmation distincte par cible. Aucun agrandissement de zone au-delà des cellules réellement affectées.",
			"",
			"| Carte | Concept avant rendu | Impact | Maintien / fin |",
			"|---|---|---:|---|",
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
			"| %s (`%s`) | %s | %.2f s | %s |"
			% [entry.name, id, entry.get("concept", "MISSING"), entry.duration, lifetime]
		)
	lines.append_array(
		PackedStringArray(
			[
				"",
				"## Production et validation",
				"",
				"Brief → silhouette → matière → événements confirmés → galerie → arène → validation des durées.",
				"Références : [dossier de production](cards_vfx_production_2026-09-21.md).",
				"",
				"L'atelier utilise un personnage fixe. Les captures extension utilisent la vraie arène avec IA suspendue et une horloge VFX échantillonnée. Ce ne sont pas des mesures GPU en combat chargé.",
				"Les règles effectivement chargées sont conservées dans contracts.json et les rapports des lancers.",
			]
		)
	)
	var json_file := FileAccess.open(out + "contracts.json", FileAccess.WRITE)
	json_file.store_string(JSON.stringify(rows, "\t"))
	var doc_path := "res://docs/design/achilles/cards_vfx_contracts_2026-09-21.md"
	var doc_file := FileAccess.open(doc_path, FileAccess.WRITE)
	doc_file.store_string("\n".join(lines) + "\n")
