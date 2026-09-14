extends GutTest

const CATALOG := preload("res://core/expedition/painted_halt_catalog.gd")
const CAMP := "res://data/halts/companions_quarry_v1.json"


func test_camp_follows_saved_route_identity_without_changing_the_graph() -> void:
	var lanes: Array[int] = []
	for revision in [2, 3, 4]:
		for seed_value in [1, 2, 17, 2401]:
			var nodes := ExpeditionRouteCatalog.create_nodes(seed_value, revision)
			var before := nodes.duplicate(true)
			var found := 0
			for node: Dictionary in nodes:
				var path := CATALOG.manifest_for(node)
				if str(node.title) == "Le camp des compagnons":
					found += 1
					assert_eq(path, CAMP)
					if not int(node.lane) in lanes:
						lanes.append(int(node.lane))
				else:
					assert_ne(path, CAMP)
			assert_eq(found, 1)
			assert_eq(nodes, before)
	assert_eq(lanes.size(), 2)


func test_camp_does_not_replace_other_halts() -> void:
	var node := { "depth": 4, "lane": 0, "kind": "hub", "title": "Le camp des compagnons" }
	assert_eq(CATALOG.manifest_for(node), CAMP)
	for override in [
		{ "title": "Un autre camp" },
		{ "kind": "lore" },
		{ "depth": 8 },
		{ "hidden": true },
		{ "lane": -1 },
		{ "lane": 3 },
	]:
		var other := node.duplicate(true)
		other.merge(override, true)
		assert_ne(CATALOG.manifest_for(other), CAMP)
