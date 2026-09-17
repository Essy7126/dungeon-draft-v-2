extends Node

const VIEW := preload("res://characters/achilles/PasseRiveIsoUnitView.tscn")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
var output := "res://artifacts/dev/passe_rive_animation_audit/before"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var parent := Node2D.new()
	add_child(parent)
	var visual := VIEW.instantiate() as PasseRiveAutoSpriteView
	parent.add_child(visual)
	await get_tree().process_frame
	await get_tree().process_frame
	visual.set_process(false)
	var backend := visual.sprite_backend as PasseRiveAutoSpriteBackend
	backend.set_process(false)
	var frames := backend.animated_sprite.sprite_frames
	var directions: Array[Dictionary] = []
	for direction: String in PasseRiveAutoSpriteProfile.DIRECTIONS:
		visual._facing = direction
		backend.play_idle(direction)
		var initial := _snapshot(backend)
		var seen: Dictionary = { }
		for tick in 50:
			backend.advance_simulation(0.05)
			seen[backend.animated_sprite.frame] = true
		var item := {
			"direction": direction,
			"initial": initial,
			"after_2_5_seconds": _snapshot(backend),
			"idle_distinct_frames": seen.size(),
			"returns": [],
		}
		for running in [false, true]:
			backend.play_move(direction, running)
			backend.advance_ground_distance(100.0)
			backend.play_idle(direction)
			item.returns.append(
				{ "after": "run" if running else "walk", "state": _snapshot(backend) }
			)
		for stem: String in ["bow_quick", "bow_charged", "bow_air", "jump", "dodge", "dash"]:
			backend.play_action(direction, StringName("preview:" + stem))
			backend.advance_simulation(2.0)
			item.returns.append({ "after": stem, "state": _snapshot(backend) })
		backend.play_action(direction, &"preview:bow_charged")
		backend.advance_simulation(0.2)
		visual.cancel_pending_visual_actions()
		item.returns.append({ "after": "cancel", "state": _snapshot(backend) })
		backend.play_hit(direction)
		backend.advance_simulation(0.6)
		item.returns.append({ "after": "hit", "state": _snapshot(backend) })
		backend.play_dodge(direction)
		backend.advance_simulation(0.6)
		item.returns.append({ "after": "reaction_dodge", "state": _snapshot(backend) })
		directions.append(item)
	var catalog := ExpeditionBuildCatalog.new()
	var spells: Array[Dictionary] = []
	for spell: Spell in catalog.all_spells():
		var presentation := AchillesSpellVisualResolver.resolve(spell)
		spells.append(
			{
				"id": spell.get_effective_spell_id(),
				"name": spell.spell_name,
				"family": presentation.action_family,
				"requested_stem": presentation.animation_stem,
				"played_stem": PasseRiveAutoSpriteBackend.action_for(&"cast", presentation),
				"gesture": presentation.gesture_variant,
				"heal": spell.is_healing(),
			}
		)
	var clips: Array[Dictionary] = []
	for name: StringName in frames.get_animation_names():
		var hashes: Dictionary = { }
		for i in frames.get_frame_count(name):
			var texture := frames.get_frame_texture(name, i) as AtlasTexture
			hashes[str(texture.atlas.resource_path) + str(texture.region)] = true
		clips.append(
			{
				"name": name,
				"frames": frames.get_frame_count(name),
				"regions": hashes.size(),
				"loop": frames.get_animation_loop(name),
				"fps": frames.get_animation_speed(name),
			}
		)
	var report := {
		"scope": "Production PasseRiveIsoUnitView with deterministic backend clock; no battle simulation",
		"directions": directions,
		"spells": spells,
		"clips": clips,
		"profile": PROFILE.resource_path,
	}
	var file := FileAccess.open(output.path_join("runtime.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	parent.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print(
		"PASSE_RIVE_AUDIT: ",
		directions.size(),
		" directions; ",
		spells.size(),
		" spells; ",
		clips.size(),
		" clips",
	)
	get_tree().quit()


func _snapshot(backend: PasseRiveAutoSpriteBackend) -> Dictionary:
	var sprite := backend.animated_sprite
	return {
		"clip": sprite.animation,
		"frame": sprite.frame,
		"clip_frames": sprite.sprite_frames.get_frame_count(sprite.animation),
		"action_pending": backend.get_runtime_state().action_pending,
		"anchor": backend.position,
		"scale": sprite.scale,
		"offset": sprite.offset,
	}
