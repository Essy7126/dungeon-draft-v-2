extends "res://tools/catabase_monster_validation/challenge_capture.gd"
## Real UI buttons and saved session; victory is injected to isolate the reward flow.
var screen: ExpeditionScreen
var failures: Array[String] = []


func _ready() -> void:
	output = "res://artifacts/dev/guided_progression_capture"
	super._ready()


func _run() -> void:
	var run := ExpeditionRunFactory.create(2401)
	var resolution := GameManager.resolve_run_hero_data(run, false)
	if not GameManager._prepare_preconfigured_run(run, resolution.heroes):
		await _finish(false)
		return
	GameManager.expedition = ExpeditionSession.new()
	GameManager.expedition.initialize(GameManager.get_character_state(&"achilles"), 2401)
	GameManager.expedition.needs_preparation = true
	screen = preload("res://ui/expedition/ExpeditionScreen.tscn").instantiate()
	add_child(screen)
	await _capture("01_weapon")
	await _press("Preset_hampe")
	await _press("DepartureNext")
	await _capture("02_armor")
	await _press("DepartureNext")
	await _capture("03_technique")
	await _press("DepartureNext")
	await _press("DepartureNext")
	await _capture("04_relic")
	await _press("DepartureChoice_urne")
	await _capture("05_relic_selection")
	await _press("DepartureNext")
	await _capture("06_supply")
	await _press("DepartureNext")
	await _capture("07_review")
	# Use the departure's real transactional service without launching a battle scene.
	var view = screen.find_child("ConfirmCatabaseDeparture", true, false).get_parent().get_parent()
	view.commit = func(selection: Dictionary):
		return GameManager.expedition.prepare_start(
			selection,
			GameManager.run_inventory,
			GameManager.item_catalog,
		)
	await _press("ConfirmCatabaseDeparture")
	var session := GameManager.expedition
	if not session.enter("d01_0") or not session.combat_won():
		failures.append("Opening encounter resolution failed")
	screen._continue_flow()
	await _capture("08_level_up")
	await _press("CatabaseTab_attributes")
	await _capture("08b_character_details")
	await _press("ResumeCharacterProgression")
	await _press("BeginLevelUp")
	await _capture("09_attributes")
	for point in session.character.champion_progression.unspent_attribute_points:
		await _press("Attribute_vitality")
	await _press("ContinueExpeditionFlow")
	await _capture("10_spells")
	var choices := screen.find_children("LevelSpell_*", "Button", true, false)
	if choices.is_empty():
		failures.append("No available spell choices")
	else:
		await _press(str(choices[0].name))
		await _capture("11_spell_detail")
		await _press("PurchaseTechnique")
		await _press("BackToLevelSpells")
	await _press("FinishLevelSpells")
	await _capture("12_loot")
	await _press("RewardOption_0")
	await _press("ConfirmExpeditionReward")
	await _capture("13_receipt")
	await _press("EquipReceivedLoot")
	await _capture("13b_inventory")
	GameManager.get_persistent_run_ui().inventory_screen.close_screen()
	await _press("OpenRouteMap")
	await _capture("14_map")
	if screen._page != "map" or not session.advancement_step.is_empty():
		failures.append("Flow did not finish on map")
	FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(
		JSON.stringify(
			{
				"success": failures.is_empty(),
				"failures": failures,
				"scope": "Rendered preparation and level-up windows; real UI actions and transactions, simulated opening victory",
				"resolution": get_viewport().get_visible_rect().size,
			},
			"\t",
		)
	)
	screen.queue_free()
	await _finish(failures.is_empty())


func _press(control_name: String) -> void:
	var button := screen.find_child(control_name, true, false) as Button
	if button == null or button.disabled:
		failures.append("Unavailable control: " + control_name)
		return
	button.pressed.emit()
	for frame in 3:
		await get_tree().process_frame
