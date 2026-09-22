extends Node
## Catalogue facts and loot-only sampling. This does not simulate combat victories.
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const Drops := preload("res://core/expedition/card_drop_catalog.gd")


func _ready() -> void:
	var output := "res://artifacts/dev/cards-catalog-20260921"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("output="):
			output = arg.trim_prefix("output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var entries: Array = []
	var counts := { }
	var effects := { }
	var csv := FileAccess.open(output.path_join("cards.csv"), FileAccess.WRITE)
	csv.store_csv_line(
		PackedStringArray(
			[
				"id",
				"class",
				"title",
				"rarity",
				"ap",
				"min_range",
				"max_range",
				"effect",
				"role",
				"damage_P20_rank0",
				"damage_P20_rank2",
				"damage_P20_rank4",
				"effect_value",
				"shield_P20_rank2",
				"cooldown",
				"once_per_activation",
				"description",
			]
		)
	)
	for family in Cards.pool():
		var row := Cards.row(family)
		var spell := Cards.make_spell(family, 2)
		var tier: int = Cards.Ecology.tier(family)
		var entry := {
			"id": family,
			"class": row[1],
			"title": row[2],
			"rarity": Cards.Ecology.TIER_NAMES[tier],
			"ap": spell.ap_cost,
			"range": [spell.minimum_range, spell.spell_range],
			"effect": row[7],
			"role": row[9],
			"damage_P20": [],
			"effect_value": row[8],
			"shield_P20_rank2": roundi(spell.shield_scaling.prowess_coefficient * 20) if spell.shield_scaling
			!= null else 0,
			"cooldown": spell.cooldown_activations,
			"once_per_activation": spell.once_per_activation,
			"description": spell.description,
		}
		for rank in [0, 2, 4]:
			entry.damage_P20.append(
				roundi(Cards.make_spell(family, rank).damage_scaling.prowess_coefficient * 20)
			)
		entries.append(entry)
		if not counts.has(row[1]):
			counts[row[1]] = [0, 0, 0, 0]
		counts[row[1]][tier] += 1
		effects[row[7]] = int(effects.get(row[7], 0)) + 1
		csv.store_csv_line(
			PackedStringArray(
				[
					family,
					row[1],
					row[2],
					entry.rarity,
					str(entry.ap),
					str(spell.minimum_range),
					str(spell.spell_range),
					row[7],
					row[9],
					str(entry.damage_P20[0]),
					str(entry.damage_P20[1]),
					str(entry.damage_P20[2]),
					str(row[8]),
					str(entry.shield_P20_rank2),
					str(entry.cooldown),
					str(entry.once_per_activation),
					spell.description,
				]
			)
		)
	csv.close()
	var samples: Array = []
	for depth in [1, 4, 10, 20]:
		for kind in ["normal", "elite", "boss"]:
			for drought in [0, 3]:
				var count := 0
				var zero := 0
				var native := 0
				var rarities := [0, 0, 0, 0]
				var factors := Drops.factors(depth, kind, drought)
				var expected := 0.0
				var zero_probability := 1.0
				for chance in factors.chances:
					expected += chance / 100.0
					zero_probability *= 1.0 - chance / 100.0
				for seed_value in range(7000, 7300):
					var result := Drops.roll(
						seed_value,
						{ "id": "audit_%d_%s" % [depth, kind], "depth": depth, "kind": kind },
						"assassin",
						drought,
					)
					if result.families.is_empty():
						zero += 1
					for family in result.families:
						count += 1
						rarities[Cards.Ecology.tier(family)] += 1
						if Cards.row(family)[1] == "assassin":
							native += 1
				samples.append(
					{
						"depth": depth,
						"kind": kind,
						"drought": drought,
						"rolls": 300,
						"factors": factors,
						"expected_cards": expected,
						"zero_probability": zero_probability,
						"observed_cards": count,
						"observed_zero": zero,
						"observed_native": native,
						"observed_rarities": rarities,
					}
				)
	var report := {
		"public_families": entries.size(),
		"legacy_initiation_compatibility_only": Cards.Ecology.legacy_initiation_rows().size(),
		"by_class_and_tier": counts,
		"effects": effects,
		"cards": entries,
		"loot_samples": samples,
		"limits": "Damage at Prowess 20 before armor, class passives and conditional bonuses. Loot-only independent trials, not run outcomes. Synthetic depth/kind combinations expose formulas even where that node kind is absent from the route.",
	}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(
		"CARD_CATALOG_AUDIT ",
		JSON.stringify(
			{
				"cards": entries.size(),
				"counts": counts,
				"effects": effects.size(),
				"loot_rolls": samples.size() * 300,
				"report": output.path_join("report.json"),
			}
		),
	)
	get_tree().quit()
