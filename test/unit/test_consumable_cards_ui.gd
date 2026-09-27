extends GutTest
const Run := preload("res://core/expedition/consumable_cards_run.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Screen := preload("res://ui/expedition/consumable_cards_screen.gd")
var screen
var runtime
var path := ""


func after_each() -> void:
	if is_instance_valid(screen):
		remove_child(screen)
		screen.free()
	GameManager.cleanup_run_state()
	if runtime != null:
		runtime.dispose()
	if not path.is_empty():
		ExpeditionSaveService.remove_snapshot(path)
	GameManager.select_run_variant("classic")


func create_screen(with_run: bool) -> void:
	GameManager.cleanup_run_state()
	if with_run:
		path = "user://cc2_ui_%d.json" % Time.get_ticks_usec()
		runtime = Run.new()
		assert_true(runtime.create(Catalog.preset(), 436, path))
	screen = Screen.new()
	screen.run = runtime if with_run else null
	screen.size = Vector2(1200, 896)
	add_child(screen)


func test_new_departure_and_every_management_tab_render() -> void:
	create_screen(false)
	assert_true(Catalog.valid_departure(screen.selection))
	assert_gt(screen._body.get_child_count(), 3)
	screen.free()
	screen = null
	create_screen(true)
	for tab in ["Préparation", "Progression", "Équipement", "Parcours"]:
		screen._tab = tab
		screen._render()
		assert_gt(screen._body.get_child_count(), 3, tab)
	await get_tree().process_frame


func test_reference_combat_and_preview_preserve_checkpoint() -> void:
	create_screen(true)
	assert_true(runtime.act({ "kind": "depart" }).success)
	screen._render()
	await get_tree().process_frame
	assert_not_null(screen._grid_view)
	var before: Dictionary = runtime.checkpoint.state.duplicate(true)
	var dossier: AcceptDialog = screen._combat_dossier()
	assert_true(dossier.visible)
	dossier.queue_free()
	screen._cell_hovered(Vector2i(3, 4))
	assert_eq(runtime.checkpoint.state, before)
	assert_string_contains(screen._detail.text, "Après l'action")
	screen._cell_clicked(Vector2i(3, 4))
	assert_eq(runtime.battle.hero.grid_pos, Vector2i(3, 4))
	assert_eq(int(runtime.checkpoint.state.action_seq), int(before.action_seq) + 1)
	await get_tree().process_frame


func test_public_profile_uses_existing_cards_save() -> void:
	assert_false(GameManager.select_run_variant("cards_v2"))
	assert_true(GameManager.select_run_variant("cards"))
	assert_eq(GameManager.expedition_save_path, ExpeditionSaveService.CARDS_SAVE_PATH)


func test_card_display_uses_equipped_range_and_current_archive_cost() -> void:
	create_screen(true)
	assert_true(runtime.act({"kind": "depart"}).success)
	var cards = runtime.cards
	for row in Catalog.data().equipment:
		if row.mods.has("range"):
			cards.equipped[row.slot] = row.id
	cards.active_relics.assign(["archive"])
	var spell: Spell = null
	for row in Catalog.data().cards:
		if int(row.ap) >= 3 and int(row.max) > 0:
			spell = cards.family_spell(row.id)
			break
	assert_not_null(spell)
	var values: Dictionary = screen._spell_values(spell)
	assert_gt(int(values.maximum), spell.spell_range)
	assert_eq(int(values.cost), spell.ap_cost - 1)
	var details := VBoxContainer.new()
	screen.add_child(details)
	screen._card_detail(details, str(spell.spell_id).trim_prefix("cc2_"))
	var labels := ""
	for child in details.get_children():
		if child is Label:
			labels += child.text + "\n"
	assert_string_contains(labels, "%d PA · Portée %d–%d" % [values.cost, values.minimum, values.maximum])
	cards.take_trigger("archive", true)
	assert_eq(int(screen._spell_values(spell).cost), spell.ap_cost)
