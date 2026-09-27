extends GutTest
const Checkpoint := preload("res://core/expedition/consumable_cards_checkpoint.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Profile := preload("res://core/expedition/consumable_cards_profile.gd")
var paths: Array[String] = []


func after_each() -> void:
	for path in paths:
		ExpeditionSaveService.remove_snapshot(path)
		ExpeditionSaveService.remove_snapshot(path + ".tmp")
	paths.clear()


func create_checkpoint():
	var checkpoint := Checkpoint.new()
	checkpoint.path = "user://cc2_test_%d.json" % Time.get_ticks_usec()
	paths.append(checkpoint.path)
	assert_true(checkpoint.initialize("test", Profile.create_cards(Catalog.preset()), 42))
	return checkpoint


func test_commit_once_and_reload_receipt() -> void:
	var checkpoint = create_checkpoint()
	var purchase := func(s: Dictionary):
		s.cards.gold -= 8
		return { "success": true, "paid": 8 }
	assert_true(checkpoint.transact("test/1", 0, purchase).success)
	assert_eq(checkpoint.state.cards.gold, 32)
	var reloaded := Checkpoint.new()
	reloaded.path = checkpoint.path
	assert_true(reloaded.restore())
	assert_true(reloaded.transact("test/1", 0, purchase).replayed)
	assert_eq(int(reloaded.state.cards.gold), 32)
	assert_false(reloaded.transact("test/3", 1, purchase).success)
	assert_eq(int(reloaded.state.action_seq), 1)


func test_rejection_and_failed_write_never_expose_candidate() -> void:
	var checkpoint = create_checkpoint()
	var before: Dictionary = checkpoint.state.duplicate(true)
	var illegal := func(s: Dictionary):
		s.cards.gold = 0
		return { "success": false, "reason": "invalid_target" }
	assert_false(checkpoint.transact("test/1", 0, illegal).success)
	assert_eq(checkpoint.state, before)
	checkpoint.writer = func(_snapshot, _path):
		return false
	var legal := func(s: Dictionary):
		s.cards.gold -= 8
		return { "success": true }
	assert_false(checkpoint.transact("test/1", 0, legal).success)
	assert_eq(checkpoint.state, before)
	assert_true(checkpoint.blocked)
	assert_false(checkpoint.transact("test/1", 0, legal).success)
	checkpoint.writer = ExpeditionSaveService.write_snapshot
	assert_true(checkpoint.retry())
	assert_true(checkpoint.transact("test/1", 0, legal).success)
	assert_eq(checkpoint.state.cards.gold, 32)


func test_foreign_profile_and_corrupt_checksum_preserve_live_state() -> void:
	var checkpoint = create_checkpoint()
	var before: Dictionary = checkpoint.state.duplicate(true)
	var foreign := before.duplicate(true)
	foreign.ruleset_id = "catabase_cards_v1"
	assert_false(Checkpoint.validation_errors(foreign).is_empty())
	var file := FileAccess.open(checkpoint.path, FileAccess.WRITE)
	file.store_string('{"payload":"{}","sha256":"wrong"}')
	file.close()
	assert_false(checkpoint.restore())
	assert_eq(checkpoint.state, before)
