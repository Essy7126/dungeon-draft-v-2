extends Node

const Layout = preload("res://tools/philosopher_sprite_pipeline/trial_terrain_layout.gd")


func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	var source := ResourceLoader.load(Layout.SOURCE, "", ResourceLoader.CACHE_MODE_IGNORE) as ArenaDefinition
	var room := Layout.build(source)
	if room == null:
		push_error("The independent philosopher terrain trial could not be built.")
		get_tree().quit(1)
		return
	var result := ResourceSaver.save(room, Layout.OUTPUT)
	if result != OK:
		push_error("The independent philosopher terrain trial could not be saved: %s" % result)
		get_tree().quit(1)
		return
	print(JSON.stringify({"ok": true, "room": Layout.OUTPUT, "source": Layout.SOURCE,
		"arena_id": room.arena_id, "cells": room.cells.size(), "terrain_cells": 8,
		"portal_network": Layout.NETWORK_ID, "hero_spawns": room.hero_spawn_zone.size(),
		"enemy_spawns": room.enemy_spawn_zone.size()}))
	get_tree().quit(0)
