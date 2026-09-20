extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var rows: Array = []
	var spells := preload("res://tools/class_card_vfx/enemy_inventory.gd").spells()
	var ids := spells.keys()
	ids.sort()
	for id in ids:
		var spell: Spell = spells[id]
		rows.append(
			{
				"id": id,
				"name": spell.spell_name,
				"element": spell.element,
				"heal": spell.heal,
				"shield": spell.shield_grant,
				"delayed": spell.delayed_resolution,
				"flight": spell.impact_delay_seconds,
				"push": spell.push_distance,
				"status": (
					str(spell.applied_status.get_effective_status_id())
					if spell.applied_status != null
					else ""
				),
				"terrain": spell.terrain_effect != null,
			}
		)
	DirAccess.make_dir_recursive_absolute("res://artifacts/dev/class_card_vfx/ethereal")
	var file := FileAccess.open(
		"res://artifacts/dev/class_card_vfx/ethereal/inventory.json",
		FileAccess.WRITE,
	)
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	print("Enemy spell inventory: ", rows.size())
	get_tree().quit()
