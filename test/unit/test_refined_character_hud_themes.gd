extends GutTest

const HUD_SCENE := preload(
	"res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn"
)

const CASES := [
	{
		"unit": "res://data/units/alliés/elfe.tres",
		"theme": "res://data/ui/elf_hud_theme_refined.tres",
		"badge": "res://asset/ui/character_hud/refined/hunter_badge.png",
		"energy": "",
		"discipline": &"archer",
		"spells": [&"elf_precise_shot", &"elf_sneak_strike", &"elf_fireball", &"elf_sylvan_heal"],
		"names": ["Tir précis", "Frappe sournoise", "Boule de feu", "Soin sylvestre"],
		"ap": [2, 2, 1, 2],
		"fervor": [0.0, 0.0, 0.0, 0.0],
		"icons": [
			"res://asset/ui/character_hud/refined/spells/precise_shot.png",
			"res://asset/ui/character_hud/refined/spells/sneak_strike.png",
			"res://asset/ui/character_hud/refined/spells/fireball.png",
			"res://asset/ui/character_hud/refined/spells/sylvan_heal.png",
		],
	},
	{
		"unit": "res://data/units/alliés/mage.tres",
		"theme": "res://data/ui/mage_hud_theme_refined.tres",
		"badge": "res://asset/ui/character_hud/generated/spell_icon_r06_c04.png",
		"energy": "",
		"discipline": &"mage_fire",
		"spells": [&"mage_fireball", &"mage_ice_wall", &"mage_thunderstorm", &"mage_seismic_wave"],
		"names": ["Boule de feu du Mage", "Mur de glace", "Tempête orageuse", "Onde sismique"],
		"ap": [1, 1, 3, 2],
		"fervor": [0.0, 0.0, 0.0, 0.0],
		"icons": [
			"res://asset/icone/boule de feu.png",
			"res://asset/ui/character_hud/generated/spell_icon_r08_c01.png",
			"res://asset/sorts/tempete_orageuse/tex_storm_lightning_cluster.png.png",
			"res://asset/ui/character_hud/generated/spell_icon_r06_c01.png",
		],
	},
	{
		"unit": "res://data/units/alliés/Gardien.tres",
		"theme": "res://data/ui/guardian_hud_theme_refined.tres",
		"badge": "res://asset/ui/character_hud/generated/spell_icon_r07_c00.png",
		"energy": "Foi",
		"discipline": &"",
		"spells": [
			&"res://data/spells/Gardien/rempart.tres",
			&"res://data/spells/Gardien/garde.tres",
			&"res://data/spells/Gardien/frappe_de_bouclier.tres",
			&"res://data/spells/Gardien/provocation.tres",
			&"res://data/spells/Gardien/bastion.tres",
		],
		"names": ["Rempart", "Garde", "Frappe de bouclier", "Provocation", "Bastion"],
		"ap": [5, 3, 2, 3, 4],
		"fervor": [40.0, 0.0, 0.0, 0.0, 40.0],
		"icons": [
			"res://asset/ui/character_hud/generated/spell_icon_r07_c00.png",
			"res://asset/icone/icone spell.png_11.png",
			"res://asset/ui/character_hud/generated/spell_icon_r04_c04.png",
			"res://asset/ui/character_hud/generated/spell_icon_r03_c03.png",
			"res://asset/ui/character_hud/generated/spell_icon_r00_c05.png",
		],
	},
	{
		"unit": "res://data/units/alliés/Guerrier.tres",
		"theme": "res://data/ui/warrior_hud_theme_refined.tres",
		"badge": "res://asset/ui/character_hud/generated/spell_icon_r04_c02.png",
		"energy": "Rage",
		"discipline": &"",
		"spells": [
			&"res://data/spells/Guerrier/bourrade.tres",
			&"res://data/spells/Guerrier/crochet.tres",
			&"res://data/spells/Guerrier/coup_épaule.tres",
			&"res://data/spells/Guerrier/onde_de_choc.tres",
			&"res://data/spells/Guerrier/marque_de_guerre.tres",
			&"res://data/spells/Guerrier/execution_de_guerre.tres",
			&"res://data/spells/Guerrier/pietinement.tres",
			&"res://data/spells/Guerrier/sol_corrompu.tres",
		],
		"names": ["Bourrade", "Crochet", "Coup d'epaule", "Onde de choc", "Marque de guerre", "Execution de guerre", "Pietinement", "Sol Corrompu"],
		"ap": [1, 2, 3, 4, 2, 1, 2, 1],
		"fervor": [0.0, 0.0, 0.0, 40.0, 0.0, 40.0, 0.0, 40.0],
		"icons": [
			"res://asset/ui/character_hud/generated/spell_icon_r03_c02.png",
			"res://asset/ui/character_hud/generated/spell_icon_r09_c04.png",
			"res://asset/ui/character_hud/generated/spell_icon_r02_c05.png",
			"res://asset/ui/character_hud/generated/spell_icon_r03_c01.png",
			"res://asset/ui/character_hud/generated/spell_icon_r05_c04.png",
			"res://asset/ui/character_hud/generated/spell_icon_r02_c02.png",
			"res://asset/ui/character_hud/generated/spell_icon_r01_c05.png",
			"res://asset/ui/character_hud/generated/spell_icon_r06_c01.png",
		],
	},
	{
		"unit": "res://data/units/alliés/healer.tres",
		"theme": "res://data/ui/druid_hud_theme_refined.tres",
		"badge": "res://asset/ui/character_hud/generated/spell_icon_r01_c03.png",
		"energy": "Nature",
		"discipline": &"",
		"spells": [
			&"res://data/spells/Healer/seve_legere.tres",
			&"res://data/spells/Healer/ronces.tres",
			&"res://data/spells/Healer/graine_vive.tres",
			&"res://data/spells/Healer/floraison.tres",
		],
		"names": ["Seve legere", "Ronces", "Graine vive", "Floraison"],
		"ap": [2, 3, 3, 5],
		"fervor": [0.0, 0.0, 0.0, 40.0],
		"icons": [
			"res://asset/ui/character_hud/generated/spell_icon_r01_c03.png",
			"res://asset/ui/character_hud/generated/spell_icon_r05_c04.png",
			"res://asset/ui/character_hud/generated/spell_icon_r02_c00.png",
			"res://asset/ui/character_hud/generated/spell_icon_r02_c04.png",
		],
	},
	{
		"unit": "res://data/units/alliés/Assassin.tres",
		"theme": "res://data/ui/assassin_hud_theme_refined.tres",
		"badge": "res://asset/ui/character_hud/generated/spell_icon_r06_c00.png",
		"energy": "Ombre",
		"discipline": &"",
		"spells": [
			&"res://data/spells/assasin/lame.tres",
			&"res://data/spells/assasin/marque.tres",
			&"res://data/spells/assasin/pas_de_l_ombre.tres",
			&"res://data/spells/assasin/execution.tres",
		],
		"names": ["Lame", "Marque", "Pas de l'ombre", "Execution"],
		"ap": [2, 3, 3, 5],
		"fervor": [0.0, 0.0, 0.0, 40.0],
		"icons": [
			"res://asset/ui/character_hud/generated/spell_icon_r07_c03.png",
			"res://asset/ui/character_hud/generated/spell_icon_r06_c04.png",
			"res://asset/ui/character_hud/generated/spell_icon_r06_c00.png",
			"res://asset/ui/character_hud/generated/spell_icon_r05_c05.png",
		],
	},
	{
		"unit": "res://data/units/alliés/Necromant.tres",
		"theme": "res://data/ui/necromancer_hud_theme_refined.tres",
		"badge": "res://asset/ui/character_hud/generated/spell_icon_r05_c02.png",
		"energy": "Ombre",
		"discipline": &"",
		"spells": [
			&"res://data/spells/Necromant/eclat_ombre.tres",
			&"res://data/spells/Necromant/lever.tres",
			&"res://data/spells/Necromant/faille.tres",
			&"res://data/spells/Necromant/moisson.tres",
		],
		"names": ["Eclat d Ombre", "Lever", "Faille", "Moisson"],
		"ap": [2, 3, 3, 5],
		"fervor": [0.0, 0.0, 0.0, 40.0],
		"icons": [
			"res://asset/ui/character_hud/generated/spell_icon_r05_c00.png",
			"res://asset/ui/character_hud/generated/spell_icon_r05_c02.png",
			"res://asset/ui/character_hud/generated/spell_icon_r05_c04.png",
			"res://asset/ui/character_hud/generated/spell_icon_r09_c04.png",
		],
	},
	{
		"unit": "res://data/units/alliés/Hoplite.tres",
		"theme": "res://data/ui/hoplite_hud_theme_refined.tres",
		"badge": "res://asset/ui/character_hud/generated/spell_icon_r04_c04.png",
		"energy": "Foi",
		"discipline": &"",
		"spells": [
			&"res://data/spells/Hoplite/estoc.tres",
			&"res://data/spells/Hoplite/repousse.tres",
			&"res://data/spells/Hoplite/mur_de_lances.tres",
			&"res://data/spells/Hoplite/phalange.tres",
		],
		"names": ["Estoc", "Repousse", "Mur de lances", "Phalange"],
		"ap": [2, 3, 4, 5],
		"fervor": [0.0, 0.0, 0.0, 40.0],
		"icons": [
			"res://asset/ui/character_hud/generated/spell_icon_r08_c02.png",
			"res://asset/ui/character_hud/generated/spell_icon_r03_c02.png",
			"res://asset/ui/character_hud/generated/spell_icon_r08_c01.png",
			"res://asset/ui/character_hud/generated/spell_icon_r04_c04.png",
		],
	},
]


func _unit(case_data: Dictionary) -> Unit:
	return Unit.from_data(load(case_data["unit"]) as UnitData)


func _theme(case_data: Dictionary) -> CharacterHUDThemeData:
	return load(case_data["theme"]) as CharacterHUDThemeData


func _refined_hud():
	var hud = HUD_SCENE.instantiate()
	hud.skin_variant = hud.HudSkinVariant.REFINED
	return hud


func _base_buttons(hud) -> Array:
	return hud.get("_spell_buttons").filter(
		func(button): return not button.get_meta("imprinted", false)
	)


func test_theme_contract_covers_every_real_capability_in_unit_order() -> void:
	for case_data in CASES:
		var unit := _unit(case_data)
		var theme := _theme(case_data)
		assert_not_null(theme, case_data["theme"])
		assert_true(theme.matches_unit(unit), case_data["unit"])
		assert_eq(theme.energy_name, case_data["energy"], unit.unit_name)
		assert_eq(theme.default_discipline_id, case_data["discipline"], unit.unit_name)
		assert_eq(theme.discipline_emblem_texture.resource_path, case_data["badge"], unit.unit_name)
		assert_eq(theme.spell_icon_mapping.size(), unit.spells.size() + 1, unit.unit_name)
		assert_not_null(theme.get_spell_icon(&"basic_attack"), unit.unit_name)
		assert_eq(unit.spells.size(), case_data["spells"].size(), unit.unit_name)
		for index in range(unit.spells.size()):
			var spell: Spell = unit.spells[index]
			var spell_id := spell.get_effective_spell_id()
			assert_eq(spell_id, case_data["spells"][index], "%s #%d" % [unit.unit_name, index + 1])
			assert_eq(spell.spell_name, case_data["names"][index], str(spell_id))
			assert_eq(unit.get_spell_ap_cost(spell), case_data["ap"][index], str(spell_id))
			assert_eq(unit.get_spell_fervor_cost(spell), case_data["fervor"][index], str(spell_id))
			assert_true(theme.spell_icon_mapping.has(spell_id), str(spell_id))
			assert_eq(theme.get_spell_icon_for(spell).resource_path, case_data["icons"][index], str(spell_id))
			assert_false(spell.description.is_empty(), str(spell_id))
		unit.clear_traits()


func test_refined_hud_applies_identity_resources_costs_shortcuts_and_icons() -> void:
	for case_data in CASES:
		var unit := _unit(case_data)
		var hud = _refined_hud()
		add_child_autofree(hud)
		hud.set_ui_mode(hud.RunUIMode.COMBAT)
		hud.set_player_controls_enabled(true)
		hud.update_info(unit)
		hud.build_spell_buttons(unit)
		var theme := _theme(case_data)
		assert_same(hud.get_active_character_theme(), theme, unit.unit_name)
		assert_eq(hud.get_node("%CharacterName").text, unit.unit_name)
		assert_same(hud.get_node("%PortraitView/DisciplineEmblem").texture, theme.discipline_emblem_texture)
		assert_true(hud.get_node("%PortraitView/DisciplineEmblem").visible)
		if theme.portrait_texture != null:
			assert_same(hud.get_node("%PortraitView/PortraitTexture").texture, theme.portrait_texture)
			assert_true(hud.get_node("%PortraitView/PortraitTexture").visible)
		else:
			assert_not_null(hud.get_node("%PortraitView/CharacterPreview").get_visual_instance())
		assert_eq(hud.get_node("%HealthBar/ValueLabel").text, "%d / %d" % [unit.current_hp, unit.max_hp.get_int()])
		assert_eq(hud.get_node("%ActionPointsBadge/ValueLabel").text, str(unit.current_ap))
		assert_eq(hud.get_node("%MovementPointsBadge/ValueLabel").text, str(unit.current_mp))
		assert_eq(hud.get_node("%EnergyBar").visible, unit.has_energy(), unit.unit_name)
		if unit.has_energy():
			assert_eq(hud.get_node("%EnergyBar/ValueLabel").text, "%d / %d" % [int(unit.current_energy), int(unit.energy_type.max_energy)])
		assert_true(hud.get_node("%UtilityDock").visible)
		assert_true(hud.get_node("%InventoryButton").disabled)
		assert_true(hud.get_node("%MapButton").disabled)
		assert_false(hud.get_node("%SkillsButton").disabled)

		var all_buttons: Array = hud.get("_spell_buttons")
		for index in range(all_buttons.size()):
			assert_eq(all_buttons[index].get_node("%ShortcutLabel").text, str(index + 1), "%s shortcut %d" % [unit.unit_name, index + 1])
		var base_buttons := _base_buttons(hud)
		assert_eq(base_buttons.size(), unit.spells.size(), unit.unit_name)
		for index in range(base_buttons.size()):
			var button: RecraftSpellSlotView = base_buttons[index]
			var spell: Spell = unit.spells[index]
			assert_same(button.get_meta("spell"), spell)
			assert_same(button.get_displayed_icon(), theme.get_spell_icon_for(spell), spell.spell_name)
			assert_eq(button.get_node("%CostLabel").text, "%d PA" % unit.get_spell_ap_cost(spell), spell.spell_name)
			assert_string_contains(button.accessibility_name, spell.spell_name)
			assert_string_contains(button.accessibility_name, "%d PA" % unit.get_spell_ap_cost(spell))
			var fervor_cost := unit.get_spell_fervor_cost(spell)
			assert_eq(button.get_node("%EnergyCostBadge").visible, fervor_cost > 0.0, spell.spell_name)
		unit.clear_traits()
		hud.queue_free()
		await get_tree().process_frame


func test_every_character_keeps_shared_refined_chassis_inside_target_viewports() -> void:
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		for case_data in CASES:
			var unit := _unit(case_data)
			var viewport := SubViewport.new()
			viewport.size = resolution
			add_child_autofree(viewport)
			var hud = _refined_hud()
			viewport.add_child(hud)
			hud.set_ui_mode(hud.RunUIMode.COMBAT)
			hud.update_info(unit)
			hud.build_spell_buttons(unit)
			await get_tree().process_frame
			var band_rect: Rect2 = hud.get_node("%HudBand").get_global_rect()
			assert_gte(band_rect.position.x, 0.0, "%s %s" % [unit.unit_name, resolution])
			assert_gte(band_rect.position.y, 0.0, "%s %s" % [unit.unit_name, resolution])
			assert_lte(band_rect.end.x, float(resolution.x), "%s %s" % [unit.unit_name, resolution])
			assert_lte(band_rect.end.y, float(resolution.y), "%s %s" % [unit.unit_name, resolution])
			for control_path in ["%CharacterAnchor", "%ActionResourcesAnchor", "%MoveActionHost", "%SpellAnchor", "%TurnAnchor"]:
				var rect: Rect2 = hud.get_node(control_path).get_global_rect()
				assert_gte(rect.position.x, 0.0, "%s %s %s" % [unit.unit_name, resolution, control_path])
				assert_lte(rect.end.x, float(resolution.x), "%s %s %s" % [unit.unit_name, resolution, control_path])
			var spell_anchor_rect: Rect2 = hud.get_node("%SpellAnchor").get_global_rect()
			var turn_anchor_rect: Rect2 = hud.get_node("%TurnAnchor").get_global_rect()
			assert_lte(spell_anchor_rect.end.x, turn_anchor_rect.position.x, "%s %s blocks" % [unit.unit_name, resolution])
			for button in hud.get("_spell_buttons"):
				var button_rect: Rect2 = button.get_global_rect()
				assert_gte(button_rect.position.x, spell_anchor_rect.position.x - 0.1, "%s %s slot" % [unit.unit_name, resolution])
				assert_lte(button_rect.end.x, spell_anchor_rect.end.x + 0.1, "%s %s slot" % [unit.unit_name, resolution])
				assert_lte(button_rect.end.x, turn_anchor_rect.position.x + 0.1, "%s %s slot/turn" % [unit.unit_name, resolution])
			assert_true(hud._refined_skin_active())
			unit.clear_traits()
			viewport.queue_free()
			await get_tree().process_frame


func test_banner_uses_each_active_character_identity_without_duplicates() -> void:
	for case_data in CASES:
		var unit := _unit(case_data)
		var hud = _refined_hud()
		add_child_autofree(hud)
		var banner: CharacterTurnIntroBanner = hud.get_turn_intro_banner()
		var theme := _theme(case_data)
		assert_true(banner.present(unit, theme), unit.unit_name)
		assert_false(banner.present(unit, theme), unit.unit_name)
		assert_eq(banner.get_node("%CharacterName").text, theme.display_name)
		assert_eq(banner.get_node("%TurnLabel").text, banner._turn_title(unit.unit_name))
		assert_same(banner.get_node("%PortraitView/DisciplineEmblem").texture, theme.discipline_emblem_texture)
		banner.hide_immediately()
		unit.clear_traits()
		hud.queue_free()
		await get_tree().process_frame


func test_switching_all_characters_replaces_slots_without_residue() -> void:
	var hud = _refined_hud()
	add_child_autofree(hud)
	var previous_buttons: Array = []
	for case_data in CASES:
		var unit := _unit(case_data)
		hud.update_info(unit)
		hud.build_spell_buttons(unit)
		for old_button in previous_buttons:
			assert_false(is_instance_valid(old_button), unit.unit_name)
		assert_eq(
			hud.get_node("%SpellSlotsContainer").get_child_count(),
			hud.get("_spell_buttons").size()
		)
		previous_buttons = hud.get("_spell_buttons").duplicate()
		unit.clear_traits()
