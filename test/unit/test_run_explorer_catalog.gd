extends GutTest
const Catalog = preload("res://tools/run_explorer/route_explorer_catalog.gd")


func test_every_destination_has_a_valid_path_and_source() -> void:
	for seed_value in [2401, 1, 2, 9]:
		var nodes := ExpeditionRouteCatalog.create_nodes(seed_value)
		for node in nodes:
			var path := Catalog.path_to(nodes, str(node.id))
			assert_eq(path.size(), int(node.depth), str(node.id))
			assert_eq(path.back(), str(node.id))
			var description := Catalog.describe(node)
			assert_false(description.is_empty(), str(node.id))
			if ExpeditionRouteCatalog.is_combat(str(node.kind)):
				assert_true(FileAccess.file_exists(description.room))
				assert_false(description.geometry.get("floor_cells", []).is_empty())
			if not str(description.image).is_empty():
				assert_true(FileAccess.file_exists(description.image), str(description.image))


func test_audit_does_not_change_runtime_visibility_or_rng() -> void:
	var runtime := ExpeditionRouteState.new()
	runtime.initialize(2401)
	var before := runtime.to_snapshot()
	var visible := runtime.get_visible_nodes()
	var audit := Catalog.AuditRoute.new()
	audit.initialize(2401)
	assert_gt(audit.get_visible_nodes().size(), visible.size())
	for node in audit.nodes:
		Catalog.describe(node)
	assert_eq(runtime.to_snapshot(), before)
	assert_eq(runtime.get_visible_nodes(), visible)
	assert_eq(audit.nodes, ExpeditionRouteCatalog.create_nodes(2401))


func test_late_branch_uses_depth_map_not_catalog_number() -> void:
	for node in ExpeditionRouteCatalog.create_nodes(2401):
		if int(node.depth) == 7:
			assert_true(str(Catalog.describe(node).plan).contains("cavern_crypt_v1"))
		if int(node.depth) == 18:
			assert_true(str(Catalog.describe(node).room).contains("catabase_routes"))
			assert_eq(Catalog.describe(node).decor, node.title)


func test_secret_does_not_inherit_public_halt_painting() -> void:
	for node in ExpeditionRouteCatalog.create_nodes(2401):
		if str(node.id) == "d08_secret":
			assert_eq(Catalog.describe(node).image, "")
			assert_eq(Catalog.describe(node).decor, "Écran de halte générique")
		elif int(node.depth) == 8 and str(node.kind) == "sanctuary":
			assert_true(str(Catalog.describe(node).image).contains("emerald_sanctuary"))


func test_invalid_destination_cannot_create_a_path() -> void:
	assert_true(Catalog.path_to(ExpeditionRouteCatalog.create_nodes(2401), "missing").is_empty())


func test_entry_is_outside_twenty_steps() -> void:
	assert_eq(Catalog.entry().depth, 0)
	assert_true(str(Catalog.describe(Catalog.entry()).image).contains("threshold_ash"))
