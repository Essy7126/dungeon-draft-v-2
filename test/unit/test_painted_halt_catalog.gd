extends GutTest
## Painted presentation follows stable room content across saved route revisions.
const CATALOG := preload("res://core/expedition/painted_halt_catalog.gd")
const STELE := "res://data/halts/stele_names_v1.json"


func test_stele_binding_follows_title_across_saved_revisions_and_lane_inversions() -> void:
	var lanes: Array[int] = []
	for revision in [2, 3, 4]:
		for seed_value in [1, 2, 17, 2401]:
			var nodes := ExpeditionRouteCatalog.create_nodes(seed_value, revision)
			var before := nodes.duplicate(true)
			var found := 0
			for node: Dictionary in nodes:
				var manifest := CATALOG.manifest_for(node)
				if str(node.title) == "La stèle des noms":
					found += 1
					assert_eq(manifest, STELE)
					if not int(node.lane) in lanes:
						lanes.append(int(node.lane))
				else:
					assert_ne(manifest, STELE)
			assert_eq(found, 1)
			assert_eq(nodes, before, "Reading presentation must leave the saved graph untouched")
	assert_eq(lanes.size(), 2, "The legacy route exercises both outer lane positions")


func test_stele_selector_rejects_other_titles_kinds_depths_and_missing_identity() -> void:
	var node := { "depth": 4, "lane": 2, "kind": "lore", "title": "La stèle des noms" }
	assert_eq(CATALOG.manifest_for(node), STELE)
	for override in [{ "title": "Une autre mémoire" }, { "kind": "merchant" }, { "depth": 12 }]:
		var other := node.duplicate(true)
		other.merge(override, true)
		assert_eq(CATALOG.manifest_for(other), "")
	node.erase("title")
	assert_eq(CATALOG.manifest_for(node), "")


func test_hidden_and_nonstandard_lanes_never_acquire_a_painted_halt_binding() -> void:
	for kind in ["lore", "merchant", "sanctuary"]:
		var node := {
			"depth": 4 if kind == "lore" else 8,
			"lane": 0,
			"kind": kind,
			"title": "La stèle des noms",
			"hidden": true,
		}
		assert_eq(CATALOG.manifest_for(node), "")
		node.hidden = false
		for lane in [-1, 3, 4]:
			node.lane = lane
			assert_eq(CATALOG.manifest_for(node), "")
		node.erase("lane")
		assert_eq(CATALOG.manifest_for(node), "")


func test_legacy_depth_eight_bindings_keep_their_kind_based_contract() -> void:
	for lane in 3:
		assert_eq(
			CATALOG.manifest_for({ "depth": 8, "lane": lane, "kind": "sanctuary" }),
			"res://data/halts/emerald_sanctuary_v1.json",
		)
		assert_eq(
			CATALOG.manifest_for({ "depth": 8, "lane": lane, "kind": "merchant" }),
			"res://data/halts/bronze_forge_v1.json",
		)
