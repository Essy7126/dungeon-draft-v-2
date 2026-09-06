extends GutTest

const PANEL := preload("res://ui/inspect_panel.gd")
const DESCRIPTION := preload("res://ui/paris_enemy_inspection.gd")
const PARIS: UnitData = preload("res://data/units/enemies/catabase_shadow_paris.tres")


func _text(panel) -> String:
	var parts: PackedStringArray = []
	for child: Node in panel.get("_content").get_children():
		if child is Label:
			parts.append(child.text)
		elif child is RichTextLabel:
			parts.append(child.get_parsed_text())
	return "\n".join(parts)


func test_paris_inspection_announces_the_threshold_and_future_kit() -> void:
	var paris := Unit.from_data(PARIS)
	var panel := PANEL.new()
	add_child_autofree(panel)
	panel.show_unit(paris, true)
	var text := _text(panel)
	assert_string_contains(text, "sous 20 %")
	assert_string_contains(text, "30 bouclier")
	assert_string_contains(text, "sans soin")
	for spell: Spell in paris.combat_form_change.spells:
		assert_string_contains(text, spell.spell_name)
	assert_eq(panel.get("_subtitle").text, "Ennemi · Archer spectral")
	assert_true(panel.is_locked())


func test_locked_inspection_refreshes_after_real_nonlethal_threshold_damage() -> void:
	var paris := Unit.from_data(PARIS)
	var panel := PANEL.new()
	add_child_autofree(panel)
	panel.show_unit(paris, true)
	paris.take_damage(97)
	await get_tree().process_frame
	assert_eq(paris.combat_form_id, &"infernal")
	assert_eq(panel.get("_subtitle").text, "Ennemi · Démon de feu")
	var text := _text(panel)
	assert_string_contains(text, "Métamorphose accomplie")
	assert_false(text.contains("Flèche du Cocyte"))
	assert_false(text.contains("Flèche incendiaire"))
	for spell: Spell in paris.spells:
		assert_string_contains(text, spell.spell_name)
	assert_true(panel.is_locked())
	panel.release_lock()
	assert_null(panel.get("_paris_form_subject"))


func test_other_units_keep_their_existing_inspection_and_pull_is_visible() -> void:
	var other := Unit.new("Spectre", 1, 100, 9, 4, 3, 20)
	assert_true(DESCRIPTION.describe(other).is_empty())
	var panel := PANEL.new()
	add_child_autofree(panel)
	panel.show_unit(other)
	assert_eq(panel.get("_subtitle").text, "Ennemi")
	assert_false(_text(panel).contains("Métamorphose"))
	var pull := load("res://data/spells/enemies/paris/vortex_arrow.tres") as Spell
	assert_string_contains(panel._spell_summary(pull), "Attire 1")
