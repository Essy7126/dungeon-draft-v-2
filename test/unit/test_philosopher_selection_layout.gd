extends GutTest

const SCREEN_SCENE := preload("res://ui/selection/CharacterSelectionScreen.tscn")
const TRIAL: RunData = preload("res://data/runs/philosopher_trial.tres")


class AdventureManager:
	extends Node
	var configured_run: RunData
	var configured_room := -1

	func configure_next_run(run_data: RunData, room: int) -> bool:
		configured_run = run_data
		configured_room = room
		return true


func test_all_five_cards_fit_without_covering_note_or_each_other_at_common_sizes() -> void:
	var screen := SCREEN_SCENE.instantiate() as CharacterSelectionScreen
	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_eq(screen._roster_buttons.size(), 5)
	var note := screen.find_child("RosterNote", true, false) as Control
	assert_not_null(note)
	for viewport_size in [Vector2(1280, 720), Vector2(1440, 900), Vector2(1920, 1080)]:
		screen.size = viewport_size
		await wait_process_frames(2)
		var rectangles: Array[Rect2] = []
		for button in screen._roster_buttons:
			assert_true(button.is_visible_in_tree())
			var rect := button.get_global_rect()
			assert_true(screen.get_global_rect().encloses(rect), str(viewport_size))
			assert_false(rect.intersects(note.get_global_rect()), "%s overlaps note at %s" % [button.name, viewport_size])
			for previous in rectangles:
				assert_false(rect.intersects(previous), str(viewport_size))
			rectangles.append(rect)


func test_visible_trial_card_activates_its_own_run_and_displays_its_chapter() -> void:
	var screen := SCREEN_SCENE.instantiate() as CharacterSelectionScreen
	add_child_autofree(screen)
	await wait_process_frames(3)
	var entries := screen.get_entries()
	var last := entries.size() - 1
	var button := screen._roster_buttons[last]
	var journey := button.get_node("Journey") as Label
	assert_eq(entries[last].run, TRIAL)
	assert_eq(journey.text, TRIAL.run_name.to_upper())
	assert_false(journey.text.contains("TRIO"))
	assert_true(button.tooltip_text.contains(TRIAL.run_name))
	# Exercise the connected button activation; the graphical harness also
	# covers viewport hit testing and the actual GameManager scene transition.
	button.pressed.emit()
	assert_eq(screen.selected_index, last)
	assert_same(screen.get_selected_entry().run, TRIAL)
	assert_eq(screen._chapter.text, TRIAL.run_name)
	assert_true(screen.start_button.tooltip_text.contains(TRIAL.run_name))
	var manager := AdventureManager.new()
	add_child_autofree(manager)
	assert_true(screen.prepare_adventure(manager))
	assert_same(manager.configured_run, TRIAL)
	assert_eq(manager.configured_room, 0)
