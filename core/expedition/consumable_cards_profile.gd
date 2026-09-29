extends RefCounted
## Explicit dispatch boundary; a revision number never opts a legacy run into V2.
const ID := "catabase_cards_consumable_v2"
const CONTENT_VERSION := "2.0.0-design.1"
const SCHEMA_VERSION := 1
const SAVE_PATH := "user://catabase_cards_consumable_v2.json"
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")


static func matches(value: Dictionary) -> bool:
	return value.get("ruleset_id") == ID


static func capabilities() -> Dictionary:
	return {
		"consumes_copies": true,
		"can_prepare_opening": true,
		"can_retain": true,
		"uses_family_upgrades": true,
		"uses_masteries": true,
		"prototype_name": "Prototype v1",
		"action_checkpoints": true,
		"minimum_prepared": 0,
		"maximum_prepared": 30,
		"reserve_paginated": true,
	}


static func create_cards(selection: Dictionary):
	if not Catalog.valid_departure(selection):
		return null
	var state = load("res://core/expedition/consumable_cards_state.gd").new()
	state.initialize_deck(selection)
	return state
