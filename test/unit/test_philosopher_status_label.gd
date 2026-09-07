extends GutTest

const Factory := preload("res://test/support/factory.gd")
const APORIA: StatusData = preload("res://data/status/enemies/philosopher_aporia.tres")
const SETTINGS: CombatFeedbackSettings = preload("res://battle/combat_feedback/combat_feedback_settings.tres")


func test_real_aporia_addition_and_expiry_display_the_canonical_french_name() -> void:
	var target := Factory.make_unit()
	var facts: Array[CombatEventFact] = []
	var collect := func(fact: CombatEventFact) -> void: facts.append(fact)
	EventBus.status_added.connect(collect)
	EventBus.combat_status_expired.connect(collect)
	target.apply_status(APORIA)
	target.remove_status(APORIA.get_effective_status_id(), null, false)
	EventBus.status_added.disconnect(collect)
	EventBus.combat_status_expired.disconnect(collect)
	assert_eq(facts.size(), 2)
	assert_false(target.has_status(APORIA.get_effective_status_id()))
	for fact in facts:
		var payload := FloatingCombatText.describe_fact(fact, SETTINGS.style_for_fact(fact))
		assert_eq(payload.detail_text, APORIA.status_name)
		assert_eq(payload.detail_text, "Aporie")
		assert_false(str(payload.detail_text).contains("Philosopher"))
