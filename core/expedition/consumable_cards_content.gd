extends RefCounted
## Versioned resources use the same Studio projection, item identities and
## validation services as the other profiles. The manifest remains the source.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Item := preload("res://data/cards/consumable_v2/consumable_item_definition.gd")
static var _arenas := {}
static var _items: ItemCatalog

static func arena(id: String, regenerate := false) -> ArenaDefinition:
	if _arenas.has(id) and not regenerate: return _arenas[id]
	if not Catalog.data().maps.has(id): return null
	var path := "res://data/cards/consumable_v2/maps/cc2_" + id + ".tres"
	if not regenerate and ResourceLoader.exists(path):
		var published := load(path) as ArenaDefinition
		if published == null or not ArenaRuntimeBridge.sync_runtime_resources(published): return null
		_arenas[id] = published
		return published
	var value := ArenaDefinition.new()
	value.set_identity("Cartes V2 · " + id.capitalize(), "cc2_" + id)
	value.grid_size = Vector2i(7, 7)
	value.visual_mode = ArenaDefinition.VisualMode.MODULAR
	value.modular_visual_profile = load("res://data/arenas/produced/room_01_forest/modular_visual_profile.tres")
	value.border_thickness = 0
	value.grid_origin = Vector2(350, 100)
	value.axis_x = Vector2(32, 16)
	value.axis_y = Vector2(-32, 16)
	value.production_notes = "Profil catabase_cards_consumable_v2. Géométrie de référence 7×7. Le décor ne modifie pas la logique."
	for x in 7:
		for y in 7:
			var cell := ArenaCellDefinition.new()
			cell.coordinate = Vector2i(x, y)
			var wall: bool = Catalog.data().maps[id].walls.any(func(p): return int(p[0]) == x and int(p[1]) == y)
			cell.terrain_id = &"stone"
			value.cells.append(cell)
			if wall:
				var obstacle := ArenaObstacleDefinition.new()
				obstacle.cell = cell.coordinate
				obstacle.obstacle_id = StringName("cc2_wall_%d_%d" % [x, y])
				obstacle.wall_id = &"normal"
				value.obstacles.append(obstacle)
	var spawn := ArenaSpawnDefinition.new()
	spawn.spawn_id = &"cc2_hero"
	spawn.unit_id = &"achilles"
	spawn.kind = ArenaSpawnDefinition.Kind.HERO_1
	spawn.cell = Vector2i(3, 5)
	value.spawns.append(spawn)
	for position in [Vector2i(3,1), Vector2i(1,1), Vector2i(5,1), Vector2i(3,2)]:
		var enemy_spawn := ArenaSpawnDefinition.new()
		enemy_spawn.spawn_id = StringName("cc2_enemy_%d" % value.spawns.size())
		enemy_spawn.cell = position
		value.spawns.append(enemy_spawn)
	ArenaRuntimeBridge.sync_runtime_resources(value)
	_arenas[id] = value
	return value

static func grid(id: String) -> GridData:
	return ArenaRuntimeBridge.build_grid_from_synced_resources(arena(id))

static func items(regenerate := false) -> ItemCatalog:
	if _items != null and not regenerate: return _items
	if not regenerate and ResourceLoader.exists("res://data/cards/consumable_v2/item_catalog.tres"):
		var published := load("res://data/cards/consumable_v2/item_catalog.tres") as ItemCatalog
		if published != null and published.rebuild_index():
			_items = published
			return published
	var catalog := ItemCatalog.new()
	var slots := {"weapon": ItemDefinition.EquipmentSlot.WEAPON, "body": ItemDefinition.EquipmentSlot.ARMOR, "head": ItemDefinition.EquipmentSlot.HEAD, "feet": ItemDefinition.EquipmentSlot.FEET, "belt": ItemDefinition.EquipmentSlot.BELT, "amulet": ItemDefinition.EquipmentSlot.ACCESSORY}
	var identities := ItemIdPathService.new()
	for key in ["equipment", "relics"]:
		for row in Catalog.data()[key]:
			var item := Item.new()
			item.item_id = StringName(identities.normalize_item_id("cc2_" + str(row.id)))
			item.display_name = row.name
			item.tags.assign([&"catabase_cards_consumable_v2"])
			if key == "equipment":
				item.equipment_slot = slots[row.slot]
				item.category = ItemDefinition.Category.WEAPON if row.slot == "weapon" else ItemDefinition.Category.ARMOR if row.slot in ["body", "head", "feet"] else ItemDefinition.Category.ACCESSORY
				item.profile_modifiers = row.mods.duplicate(true)
				item.description = preload("res://ui/expedition/consumable_cards_presenter.gd").item_text(row)
			else:
				item.category = ItemDefinition.Category.RELIC
				item.profile_relic_rule = row.id
				item.description = row.rule
			catalog.definitions.append(item)
	if not catalog.rebuild_index(): return null
	_items = catalog
	return _items
