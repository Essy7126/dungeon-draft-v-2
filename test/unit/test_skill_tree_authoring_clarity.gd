extends GutTest

## Clarté du contenu produit : deux améliorations ne doivent pas porter le même
## nom à l'écran, et une comparaison de parties doit nommer le rang et le nœud
## qui diffèrent, pas seulement leur discipline.

const ELF_PATH := "res://data/units/alliés/elfe.tres"


func _discipline_with_two_ranks() -> DisciplineData:
	var discipline := DisciplineData.new()
	discipline.discipline_id = &"test_discipline"
	discipline.display_name = "Discipline de test"
	var first := DisciplineRankData.new()
	first.rank = 1
	first.required_total_xp = 0
	var second := DisciplineRankData.new()
	second.rank = 2
	second.required_total_xp = 5
	discipline.ranks = [first, second]
	return discipline


func _node(node_id: StringName, display_name: String, rank: int) -> SkillTreeNodeData:
	var node := SkillTreeNodeData.new()
	node.upgrade_id = node_id
	node.display_name = display_name
	node.description = "Description de test."
	node.discipline_id = &"test_discipline"
	node.rank = rank
	return node


func _codes(messages: Array[SkillTreeValidationMessage]) -> PackedStringArray:
	var result := PackedStringArray()
	for message in messages:
		result.append(str(message.code))
	return result


## Point 9 : un doublon de nom affiché doit produire un avertissement
## actionnable, pas passer inaperçu comme avant.
func test_duplicate_display_names_raise_a_warning() -> void:
	var unit := UnitData.new()
	unit.unit_id = &"test_unit"
	unit.unit_name = "Testeur"
	var discipline := _discipline_with_two_ranks()
	discipline.ranks[1].choices = [
		_node(&"node_a", "Nouvelle amélioration", 2),
		_node(&"node_b", "Nouvelle amélioration", 2),
	]
	unit.disciplines = [discipline]
	var messages := SkillTreeEditorValidator.validate_unit(unit)
	assert_has(_codes(messages), "node_name_duplicate")


## L'avertissement est un avertissement, pas une erreur : un contenu existant
## portant des doublons reste ouvrable et sauvegardable.
func test_duplicate_display_names_do_not_block_saving() -> void:
	var unit := UnitData.new()
	unit.unit_id = &"test_unit"
	unit.unit_name = "Testeur"
	var discipline := _discipline_with_two_ranks()
	discipline.ranks[1].choices = [
		_node(&"node_a", "Doublon", 2),
		_node(&"node_b", "Doublon", 2),
	]
	unit.disciplines = [discipline]
	var messages := SkillTreeEditorValidator.validate_unit(unit)
	var duplicates: Array[SkillTreeValidationMessage] = []
	for message in messages:
		if str(message.code) == "node_name_duplicate":
			duplicates.append(message)
	assert_gt(duplicates.size(), 0)
	for message in duplicates:
		assert_false(message.is_error(), "Un doublon de nom reste un avertissement")


## Des noms distincts ne déclenchent aucun avertissement.
func test_distinct_display_names_produce_no_duplicate_warning() -> void:
	var unit := UnitData.new()
	unit.unit_id = &"test_unit"
	unit.unit_name = "Testeur"
	var discipline := _discipline_with_two_ranks()
	discipline.ranks[1].choices = [
		_node(&"node_a", "Flèches brûlantes", 2),
		_node(&"node_b", "Tir perforant", 2),
	]
	unit.disciplines = [discipline]
	var messages := SkillTreeEditorValidator.validate_unit(unit)
	assert_does_not_have(_codes(messages), "node_name_duplicate")


## Deux créations sans saisie ne doivent plus produire deux noms identiques.
func test_two_unnamed_creations_receive_distinct_default_names() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	if source == null:
		pass_test("Fixture Elfe absente de ce checkout")
		return
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	var discipline := session.working_unit.disciplines[0] as DisciplineData
	assert_true(session.select_discipline(discipline.discipline_id))
	var first := session.add_node(2, "")
	var second := session.add_node(2, "")
	assert_not_null(first)
	assert_not_null(second)
	assert_ne(
		first.display_name, second.display_name,
		"Deux créations sans nom doivent rester distinguables à l'écran"
	)
	assert_ne(first.upgrade_id, second.upgrade_id)
	session.release_document(false)


## Point 14 amont : la comparaison doit descendre au rang et au nœud.
func test_run_comparison_names_the_rank_and_node_that_differ() -> void:
	var left := {
		"pyromancie": {
			"fingerprint": "gauche",
			"ranks": [
				{"rank": 2, "xp": 5, "nodes": [
					{"id": "brasier", "effects": 1, "fingerprint": "a"},
				]},
			],
		},
	}
	var right := {
		"pyromancie": {
			"fingerprint": "droite",
			"ranks": [
				{"rank": 2, "xp": 5, "nodes": [
					{"id": "brasier", "effects": 2, "fingerprint": "b"},
				]},
			],
		},
	}
	var differences: Array[Dictionary] = []
	SkillTreeRunComparisonService._compare_discipline_details(left, right, differences)
	assert_gt(differences.size(), 0, "Une divergence de nœud doit être rapportée")
	var mentions_node := false
	for difference in differences:
		if str(difference.get("id", "")).contains("brasier"):
			mentions_node = true
	assert_true(mentions_node, "La différence doit nommer le nœud, pas seulement la discipline")


## Un écart de seuil d'XP est nommé avec son rang.
func test_run_comparison_names_the_rank_for_an_xp_threshold_change() -> void:
	var left := {
		"pyromancie": {"fingerprint": "g", "ranks": [{"rank": 3, "xp": 12, "nodes": []}]},
	}
	var right := {
		"pyromancie": {"fingerprint": "d", "ranks": [{"rank": 3, "xp": 20, "nodes": []}]},
	}
	var differences: Array[Dictionary] = []
	SkillTreeRunComparisonService._compare_discipline_details(left, right, differences)
	var mentions_rank := false
	for difference in differences:
		if str(difference.get("id", "")).contains("R3"):
			mentions_rank = true
	assert_true(mentions_rank, "Le rang concerné doit être nommé")


## Deux profils identiques ne produisent aucune fausse divergence.
func test_identical_profiles_report_no_difference() -> void:
	var snapshot := {
		"pyromancie": {"fingerprint": "x", "ranks": [
			{"rank": 2, "xp": 5, "nodes": [{"id": "brasier", "effects": 1, "fingerprint": "a"}]},
		]},
	}
	var differences: Array[Dictionary] = []
	SkillTreeRunComparisonService._compare_discipline_details(
		snapshot, snapshot.duplicate(true), differences
	)
	assert_eq(differences.size(), 0)
