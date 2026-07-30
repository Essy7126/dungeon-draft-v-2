extends GutTest

const HUD_SCENE := preload(
	"res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn"
)
const THEME := preload("res://data/ui/elf_hud_theme.tres")
const ELF_DATA := preload("res://data/units/alliés/elfe.tres")
const MAGE_DATA := preload("res://data/units/alliés/mage.tres")
const GENERATED_DIR := "res://asset/ui/character_hud/generated"
const GENERATED_V2_DIR := GENERATED_DIR + "/v2"


class FakeCombatContext:
	extends Node

	var active_unit = null
	var end_turn_count := 0

	func get_active_unit():
		return active_unit

	func _on_move_pressed() -> void:
		pass

	func _on_attack_pressed() -> void:
		pass

	func _on_spell_pressed(_spell, _imprinted: bool = false) -> void:
		pass

	func _on_awakening_pressed() -> void:
		pass

	func _on_reaction_pressed() -> void:
		pass

	func _on_end_turn_pressed() -> void:
		end_turn_count += 1


func test_generated_assets_atlas_and_manifest_are_complete() -> void:
	for filename in [
		"elf_character_bar.png",
		"elf_hunter_emblem.png",
		"turn_intro_banner.png",
		"spell_icons_atlas.png",
		"spell_icons_manifest.json",
	]:
		var path := "%s/%s" % [GENERATED_DIR, filename]
		assert_true(FileAccess.file_exists(path), path)
	for filename in [
		"elf_character_bar.png",
		"elf_hunter_emblem.png",
		"turn_intro_banner.png",
		"spell_icons_atlas.png",
	]:
		assert_not_null(load("%s/%s" % [GENERATED_DIR, filename]), filename)
	for filename in [
		"spell_frame_archer.png",
		"spell_frame_assassin.png",
		"spell_frame_mage.png",
		"spell_frame_healer.png",
		"gold_health_bar_frame.png",
		"gold_end_turn_button.png",
		"hud_v2_manifest.json",
	]:
		var path := "%s/%s" % [GENERATED_V2_DIR, filename]
		assert_true(FileAccess.file_exists(path), path)
		if filename.ends_with(".png"):
			assert_not_null(load(path), filename)

	var manifest = JSON.parse_string(
		FileAccess.get_file_as_string(
			"%s/spell_icons_manifest.json" % GENERATED_DIR
		)
	)
	assert_not_null(manifest)
	assert_eq(manifest["rows"], 10.0)
	assert_eq(manifest["columns"], 6.0)
	assert_eq(manifest["icons"].size(), 60)
	for entry in manifest["icons"]:
		assert_true(entry.has("row"))
		assert_true(entry.has("column"))
		assert_true(FileAccess.file_exists(
			"%s/%s" % [GENERATED_DIR, entry["filename"]]
		))


func test_elf_theme_maps_four_real_spells_and_basic_attack() -> void:
	assert_eq(THEME.character_id, &"elf")
	assert_eq(THEME.spell_icon_mapping.size(), 5)
	assert_eq(THEME.spell_frame_mapping.size(), 5)
	assert_eq(ELF_DATA.spells.size(), 4)
	for spell in ELF_DATA.spells:
		var spell_id: StringName = spell.get_effective_spell_id()
		assert_true(THEME.spell_icon_mapping.has(spell_id), spell_id)
		assert_not_null(THEME.get_spell_icon_for(spell), spell_id)
		assert_not_null(THEME.get_spell_frame_for(spell), spell_id)
	assert_not_null(THEME.get_spell_icon(&"basic_attack"))
	assert_not_null(THEME.get_spell_frame(&"basic_attack"))
	assert_same(
		THEME.get_spell_frame(&"basic_attack"),
		THEME.get_spell_frame(&"elf_precise_shot")
	)
	assert_ne(
		THEME.get_spell_frame(&"elf_precise_shot"),
		THEME.get_spell_frame(&"elf_sneak_strike")
	)
	assert_ne(
		THEME.get_spell_frame(&"elf_sneak_strike"),
		THEME.get_spell_frame(&"elf_fireball")
	)
	assert_ne(
		THEME.get_spell_frame(&"elf_fireball"),
		THEME.get_spell_frame(&"elf_sylvan_heal")
	)
	assert_not_null(THEME.character_bar_texture)
	assert_not_null(THEME.discipline_emblem_texture)
	assert_not_null(THEME.turn_banner_texture)
	assert_same(
		THEME.portrait_frame_texture,
		THEME.get_spell_frame(&"basic_attack")
	)
	assert_not_null(THEME.health_bar_frame_texture)
	assert_not_null(THEME.end_turn_button_texture)


func test_elf_hud_uses_real_values_and_data_driven_icons() -> void:
	var elf := Unit.from_data(ELF_DATA)
	var hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	hud.set_ui_mode(hud.RunUIMode.COMBAT)
	hud.set_player_controls_enabled(true)
	hud.update_info(elf)
	hud.build_spell_buttons(elf)

	assert_same(hud.get_active_character_theme(), THEME)
	assert_true(hud.get_node("%CharacterThemeBar").visible)
	assert_same(
		hud.get_node("%CharacterThemeBar").texture,
		THEME.character_bar_texture
	)
	assert_true(hud.get_node("%PortraitView/DisciplineEmblem").visible)
	assert_same(
		hud.get_node("%PortraitView/Frame").texture,
		THEME.portrait_frame_texture
	)
	assert_eq(
		hud.get_node("%HealthBar/ValueLabel").text,
		"%d / %d" % [elf.current_hp, elf.max_hp.get_int()]
	)
	assert_eq(hud.get_node("%ActionPointsBadge/ValueLabel").text, str(elf.current_ap))
	assert_eq(hud.get_node("%MovementPointsBadge/ValueLabel").text, str(elf.current_mp))
	assert_false(hud.get_node("%EnergyBar").visible)
	assert_true(hud.get_node("%HealthBar/ThemeFrame").visible)
	assert_same(
		hud.get_node("%HealthBar/ThemeFrame").texture,
		THEME.health_bar_frame_texture
	)

	var buttons: Array = hud.get("_spell_buttons")
	assert_eq(buttons.size(), ELF_DATA.spells.size())
	var displayed_order: Array[StringName] = []
	for button in buttons:
		var spell: Spell = button.get_meta("spell")
		displayed_order.append(spell.get_effective_spell_id())
		assert_same(
			(button as RecraftSpellSlotView).get_displayed_icon(),
			THEME.get_spell_icon_for(spell),
			spell.get_effective_spell_id()
		)
		assert_same(
			(button as RecraftSpellSlotView).frame.texture,
			THEME.get_spell_frame_for(spell),
			spell.get_effective_spell_id()
		)
	assert_eq(
		displayed_order,
		[
			&"elf_precise_shot",
			&"elf_sneak_strike",
			&"elf_fireball",
			&"elf_sylvan_heal",
		]
	)
	assert_same(
		hud.get_node("%AttackButton/ActionIcon").texture,
		THEME.get_spell_icon(&"basic_attack")
	)
	assert_same(
		hud.get_node("%AttackButton/Background").texture,
		THEME.get_spell_frame(&"basic_attack")
	)
	assert_same(
		hud.get_node("%EndTurnButton/Background").texture,
		THEME.end_turn_button_texture
	)
	elf.clear_traits()


func test_spell_selection_unavailable_state_and_signal_are_preserved() -> void:
	var elf := Unit.from_data(ELF_DATA)
	var hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	hud.set_ui_mode(hud.RunUIMode.COMBAT)
	hud.set_player_controls_enabled(true)
	hud.update_info(elf)
	hud.build_spell_buttons(elf)
	var received: Array = []
	hud.spell_pressed.connect(
		func(received_spell, imprinted: bool) -> void:
			received.assign([received_spell, imprinted])
	)
	for candidate in hud.get("_spell_buttons"):
		var candidate_spell: Spell = candidate.get_meta("spell")
		received.clear()
		candidate.pressed.emit()
		assert_same(received[0], candidate_spell)
		assert_false(received[1])
	var attack_count := [0]
	hud.attack_pressed.connect(func() -> void: attack_count[0] += 1)
	hud.get_node("%AttackButton").pressed.emit()
	assert_eq(attack_count[0], 1)
	var first: RecraftSpellSlotView = hud.get("_spell_buttons")[0]
	var spell: Spell = first.get_meta("spell")
	hud.set_active_mode("spell", spell, false)
	assert_eq(first.visual_state, RecraftSpellSlotView.VisualState.SELECTED)
	elf.current_ap = 0
	elf.stats_changed.emit(elf)
	assert_eq(first.visual_state, RecraftSpellSlotView.VisualState.UNAFFORDABLE)
	elf.clear_traits()


func test_character_switch_applies_elf_theme_and_neutral_fallback_without_residue() -> void:
	var elf := Unit.from_data(ELF_DATA)
	var mage := Unit.from_data(MAGE_DATA)
	var hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)

	hud.update_info(elf)
	hud.build_spell_buttons(elf)
	var old_buttons: Array = hud.get("_spell_buttons").duplicate()
	assert_same(hud.get_active_character_theme(), THEME)

	hud.update_info(mage)
	hud.build_spell_buttons(mage)
	assert_null(hud.get_active_character_theme())
	assert_false(hud.get_node("%CharacterThemeBar").visible)
	assert_false(hud.get_node("%PortraitView/DisciplineEmblem").visible)
	assert_false(hud.get_node("%AttackButton/ActionIcon").visible)
	for button in old_buttons:
		assert_false(is_instance_valid(button))

	hud.update_info(elf)
	hud.build_spell_buttons(elf)
	assert_same(hud.get_active_character_theme(), THEME)
	assert_true(hud.get_node("%CharacterThemeBar").visible)
	assert_eq(hud.get("_spell_buttons").size(), 4)
	elf.clear_traits()
	mage.clear_traits()


func test_real_turn_signal_shows_banner_once_and_end_turn_remains_connected() -> void:
	var elf := Unit.from_data(ELF_DATA)
	var context := FakeCombatContext.new()
	context.active_unit = elf
	var hud = HUD_SCENE.instantiate()
	add_child_autofree(context)
	add_child_autofree(hud)
	hud.bind_combat_context(context)
	hud.set_player_controls_enabled(true)
	var banner: CharacterTurnIntroBanner = hud.get_turn_intro_banner()
	var before := banner.presentation_count

	EventBus.turn_started.emit(elf)
	EventBus.turn_started.emit(elf)
	assert_eq(banner.presentation_count, before + 1)
	assert_true(banner.visible)
	assert_eq(banner.get_node("%TurnLabel").text, "TOUR DE L'ELFE")
	assert_gte(banner.total_animation_duration(), 1.8)
	assert_lte(banner.total_animation_duration(), 2.1)
	hud.get_node("%EndTurnButton").pressed.emit()
	assert_eq(context.end_turn_count, 1)
	await get_tree().create_timer(2.1).timeout
	assert_false(banner.visible)
	elf.clear_traits()


func test_hud_remains_inside_three_target_viewports() -> void:
	for resolution in [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]:
		var elf := Unit.from_data(ELF_DATA)
		var viewport := SubViewport.new()
		viewport.size = resolution
		add_child_autofree(viewport)
		var hud = HUD_SCENE.instantiate()
		viewport.add_child(hud)
		hud.set_ui_mode(hud.RunUIMode.COMBAT)
		hud.update_info(elf)
		hud.build_spell_buttons(elf)
		await get_tree().process_frame
		var metrics: Dictionary = hud.get_calibrated_spell_metrics()
		var band: Control = hud.get_node("%HudBand")
		var band_rect := band.get_global_rect()
		assert_gte(band_rect.position.y, 0.0, str(resolution))
		assert_lte(band_rect.end.y, float(resolution.y), str(resolution))
		assert_almost_eq(
			hud.get_node("%CharacterThemeBar").get_global_rect().size.x,
			band_rect.size.x,
			0.1,
			str(resolution)
		)
		for button in hud.get("_spell_buttons"):
			var rect := (button as Control).get_global_rect()
			assert_gte(rect.position.x, 0.0, str(resolution))
			assert_lte(rect.end.x, float(resolution.x), str(resolution))
			assert_gte(rect.size.x, 48.0, str(resolution))
		if resolution == Vector2i(1920, 1080):
			assert_eq(metrics["visual_size"], 100.0)
			assert_eq(metrics["icon_size"], 78.0)
			assert_eq(metrics["shortcut_height"], 14.0)
			assert_eq(metrics["gap"], 8.0)
			assert_eq(metrics["portrait_size"], 112.0)
			assert_eq(metrics["health_bar_size"], Vector2(230.0, 26.0))
			assert_eq(metrics["badge_size"], 50.0)
			assert_eq(metrics["end_turn_size"], Vector2(170.0, 54.0))
			var banner: CharacterTurnIntroBanner = hud.get_turn_intro_banner()
			var banner_size := banner.get_presentation_size()
			assert_lte(banner_size.y, resolution.y * 0.72 + 0.1)
			assert_almost_eq(
				banner_size.x / banner_size.y,
				468.0 / 1245.0,
				0.001
			)
		elf.clear_traits()
