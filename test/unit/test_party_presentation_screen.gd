extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const SCREEN_SCENE := preload("res://ui/party/PartyPresentationScreen.tscn")

var screen: PartyPresentationScreen


func before_each() -> void:
	screen = SCREEN_SCENE.instantiate() as PartyPresentationScreen
	add_child_autofree(screen)
	await wait_process_frames(3)


func test_screen_builds_three_data_driven_cards_in_fixed_order() -> void:
	assert_eq(screen.get_node("Background/Margin/Layout/Title").text, "Votre groupe")
	var cards := screen.get_cards()
	assert_eq(cards.size(), 3)
	assert_eq(cards.map(func(card): return card.character_data.unit_name), [
		"Elfe",
		"Mage",
		"Guerrier",
	])
	assert_eq(cards.map(func(card): return card.spell_count_label.text), [
		"4 sorts",
		"4 sorts",
		"8 sorts",
	])


func test_fixed_trio_uses_real_3d_previews_including_warrior() -> void:
	var cards := screen.get_cards()
	assert_true(cards[0].preview.get_visual_instance() is ElfVisual3D)
	assert_false(cards[0].preview.is_using_fallback())
	assert_eq(cards[0].character_data.disciplines.size(), 4)
	assert_false(cards[0].badge_label.visible)

	assert_true(cards[1].preview.get_visual_instance() is MageVisual3D)
	assert_false(cards[1].preview.is_using_fallback())
	assert_eq(
		(cards[1].preview.get_visual_instance() as MageVisual3D).scale,
		Vector3(1.2, 1.2, 1.2),
	)
	assert_eq(
		(cards[0].preview.get_visual_instance() as ElfVisual3D).scale,
		Vector3.ONE,
	)
	assert_eq(
		cards[1].disciplines_label.text,
		"Disciplines : Pyromancie, Cryomancie, Foudromancie, Géomancie",
	)
	assert_eq(cards[1].role_label.text, "Mage de combat élémentaire")
	assert_false(cards[1].badge_label.visible)

	assert_true(cards[2].preview.get_visual_instance() is WarriorVisual3D)
	assert_false(cards[2].preview.is_using_fallback())
	assert_eq(cards[2].badge_label.text, "Troisième héros de la première run")
	assert_true(cards[2].badge_label.visible)


func test_preview_replacement_frees_the_previous_true_visual() -> void:
	var preview := screen.get_cards()[0].preview as CharacterPreview3D
	var old_visual := preview.get_visual_instance()
	preview.configure(screen.party_members[1])
	assert_false(is_instance_valid(old_visual))
	assert_true(preview.get_visual_instance() is MageVisual3D)
	preview.configure(screen.party_members[2])
	assert_false(preview.get_visual_instance() is MageVisual3D)
	assert_true(preview.get_visual_instance() is WarriorVisual3D)
	assert_false(preview.is_using_fallback())


func test_start_uses_existing_preconfigured_run_api_with_exact_party() -> void:
	var manager = GameManagerScript.new()
	var requested := {"count": 0}
	screen.run_requested.connect(
		func(_run, _party): requested["count"] += 1
	)
	assert_true(screen.start_with_manager(manager))
	assert_eq(requested["count"], 1)
	assert_eq(manager.get_ordered_heroes().map(func(hero): return hero.unit_name), [
		"Elfe",
		"Mage",
		"Guerrier",
	])
	assert_eq(manager.current_room_index, 0)
	assert_true(screen.start_button.disabled)
	manager.cleanup_run_state()
	manager.free()


func test_back_emits_and_frees_cards_previews_without_navigation() -> void:
	var cards := screen.get_cards()
	var previews := cards.map(func(card): return card.preview.get_visual_instance())
	var observed := {"count": 0}
	screen.back_requested.connect(func(): observed["count"] += 1)
	assert_true(screen.request_back(false))
	assert_eq(observed["count"], 1)
	assert_true(screen.get_cards().is_empty())
	assert_true(cards.all(func(card): return not is_instance_valid(card)))
	assert_true(previews.all(
		func(preview): return preview == null or not is_instance_valid(preview)
	))


func test_title_primary_entry_opens_presentation_and_keeps_dev_entries() -> void:
	var title = load("res://ui/TitreEcran.tscn").instantiate()
	assert_eq(
		title.get_node("UI/Boutons/BoutonTrioFixe").text,
		"Trio fixe — prototype",
	)
	assert_eq(title.get_node("UI/Boutons/BoutonPrototypeElfe").text, "Prototype Elfe")
	assert_eq(
		title.get_node("UI/Boutons/BoutonValidationEquipe").text,
		"Validation technique — équipe de 3",
	)
	assert_eq(
		title.get_node("UI/Boutons/BoutonNouvellePartie").text,
		"Ancien prototype / Draft historique",
	)
	assert_eq(
		title.get_script().get_script_constant_map()["PARTY_PRESENTATION_SCREEN_PATH"],
		"res://ui/party/PartyPresentationScreen.tscn",
	)
	title.free()
