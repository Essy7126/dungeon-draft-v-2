extends PasseRiveAutoSpriteBackend
## Exploration owns neutral locomotion and dash; approved paintings own card attacks.
const Catalog := preload("passe_rive_s19_catalog.gd")
const Body := preload("passe_rive_s19_body.gd")
const Directions := preload("passe_rive_s20_directions.gd")
var cards_mode := false
var body: Node2D
const HEIGHT := 94.16 # 214 reference pixels Ã— exploration profile scale 0.44.
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const Registration := preload("res://characters/achilles/2d/passe_rive_registration.gd")
const Bindings := preload("res://characters/achilles/2d/passe_rive_card_bindings.gd")
const KICK := "PR_KICK_B_S24"
const KICK_ATLAS := preload("res://assets/characters/PasseRive/sprites_s24/kick_high.png")
const SUPPORT := Vector2(-18.3333584, 17.19648)
const PullBody := preload("passe_rive_pull_body.gd")
const IncantationBody := preload("passe_rive_incantation_body.gd")
const GuardBody := preload("passe_rive_guard_body.gd")
const DrainBody := preload("passe_rive_drain_body.gd")
var drain: Sprite2D
var guard: Sprite2D
var incantation: Sprite2D
var pull: Sprite2D
var kick: Sprite2D
var kick_data: Dictionary = { }
var kick_frame := 0
var gesture_binding: Dictionary = { }


func configure(profile: AchillesSpriteVisualProfile) -> bool:
	if not super.configure(profile):
		return false
	body = Body.new()
	body.name = "PaintedS18Body"
	body.scale = Vector2.ONE * HEIGHT / 330.0
	add_child(body)
	body.hide()
	_configure_kick(profile)
	pull = PullBody.new()
	pull.name = "RamenerAuFront"
	add_child(pull)
	pull.configure(profile)
	incantation = IncantationBody.new()
	incantation.name = "IncantationDuSceau"
	add_child(incantation)
	incantation.configure(profile)
	guard = GuardBody.new()
	guard.name = "SceauDeParade"
	add_child(guard)
	guard.configure(profile)
	drain = DrainBody.new()
	drain.name = "Prelevement"
	add_child(drain)
	drain.configure(profile)
	return true


func set_cards_mode(enabled: bool) -> void:
	if cards_mode == enabled or not is_instance_valid(body):
		return
	cancel_action()
	cards_mode = enabled
	_hold_idle_pose()


func _action_spec(action_id: StringName, presentation: Dictionary) -> Dictionary:
	if not cards_mode or action_for(action_id, presentation) == "dash":
		return super._action_spec(action_id, presentation)
	var id := str(presentation.get("spell_id", str(action_id).trim_prefix("cast:")))
	gesture_binding = Bindings.resolve(id)
	var reference := str(gesture_binding.reference)
	if reference == "drain":
		if _facing == "SE":
			return {
				"stem": DrainBody.CLIP,
				"duration": DrainBody.DURATION,
				"release_seconds": DrainBody.RELEASE,
				"release_frame": DrainBody.RELEASE_FRAME,
				"legacy_loop": false,
				"speed": 1.0,
			}
		gesture_binding["status"] = "pending_direction"
		gesture_binding["fallback_reference"] = "t_mark"
		gesture_binding["reason"] += " · geste directionnel existant : " + _facing
		reference = "t_mark"
	if reference == "guard":
		if _facing == "SE":
			return {
				"stem": GuardBody.CLIP,
				"duration": GuardBody.DURATION,
				"release_seconds": GuardBody.RELEASE,
				"release_frame": GuardBody.RELEASE_FRAME,
				"legacy_loop": false,
				"speed": 1.0,
			}
		gesture_binding["status"] = "pending_direction"
		gesture_binding["fallback_reference"] = "idle"
		gesture_binding["reason"] += " · garde neutre : orientation non dessinée " + _facing
		return {
			"stem": "idle",
			"duration": GuardBody.DURATION,
			"release_seconds": GuardBody.RELEASE,
			"release_frame": 0,
			"legacy_loop": false,
			"speed": 1.0,
		}
	if reference == "incantation":
		if _facing == "SE":
			return {
				"stem": IncantationBody.CLIP,
				"duration": IncantationBody.DURATION,
				"release_seconds": IncantationBody.RELEASE,
				"release_frame": IncantationBody.RELEASE_FRAME,
				"legacy_loop": false,
				"speed": 1.0,
			}
		# Retain an authored directional cast until this new angle is drawn.
		gesture_binding["status"] = "pending_direction"
		gesture_binding["fallback_reference"] = "t_mark"
		gesture_binding["reason"] += " · incantation directionnelle existante : " + _facing
		reference = "t_mark"
	if reference == "pull" and _facing == "SE":
		return {
			"stem": PullBody.CLIP,
			"duration": PullBody.DURATION,
			"release_seconds": PullBody.RELEASE,
			"release_frame": PullBody.RELEASE_FRAME,
			"legacy_loop": false,
			"speed": 1.0,
		}
	if reference == "dash":
		var dash := presentation.duplicate(true)
		dash["animation_stem"] = "dash"
		return super._action_spec(action_id, dash)
	if reference == "kick" and _facing == "SE":
		return {
			"stem": KICK,
			"duration": .65,
			"release_seconds": .31,
			"release_frame": 4,
			"legacy_loop": false,
			"speed": 1.0,
		}
	if reference in ["kick", "pull"]:
		gesture_binding["status"] = "pending_direction"
		gesture_binding["reason"] += " · orientation non dessinée : " + _facing
	var card := Catalog.card(id)
	if card.is_empty():
		card = Catalog.Data.CARDS.get(reference, { })
	if card.is_empty():
		# No unrelated attack for a guard, utility, unknown card or unauthored kick angle.
		return {
			"stem": "idle",
			"duration": .65,
			"release_seconds": .31,
			"release_frame": 0,
			"legacy_loop": false,
			"speed": 1.0,
		}
	return {
		"stem": card.clip,
		"duration": card.body_duration_ms / 1000.0,
		"release_seconds": card.confirm_ms / 1000.0,
		"release_frame": int(card.confirm_frame),
		"legacy_loop": false,
		"speed": 1.0,
	}


func _show_native() -> void:
	if is_instance_valid(drain):
		drain.hide()
	if is_instance_valid(guard):
		guard.hide()
	if is_instance_valid(incantation):
		incantation.hide()
	if is_instance_valid(pull):
		pull.hide()
	if is_instance_valid(kick):
		kick.hide()
	if is_instance_valid(animated_sprite):
		animated_sprite.self_modulate = Color.WHITE
		animated_sprite.show()
	if is_instance_valid(body):
		body.hide()
		body.card = { }


func _show(clip: String, frame: int) -> void:
	if is_instance_valid(drain):
		drain.hide()
	if is_instance_valid(guard):
		guard.hide()
	if is_instance_valid(incantation):
		incantation.hide()
	if is_instance_valid(pull):
		pull.hide()
	if is_instance_valid(kick):
		kick.hide()
	if not is_instance_valid(body):
		return
	animated_sprite.hide()
	body.show()
	# Assign the complete transform: negative X scale decomposes to a rotation.
	var factor := _profile.display_scale * 214.0 / 330.0
	var flip := -1.0 if _facing in ["W", "NW", "SW"] else 1.0
	body.transform = Transform2D(Vector2(flip * factor, 0), Vector2(0, factor), Vector2.ZERO)
	body.modulate = Color.WHITE
	body.facing = _facing
	body.show_frame(clip, frame)


func _select_clip(stem: String) -> void:
	if stem == DrainBody.CLIP:
		drain.reset_siphon()
		_show_drain(0.0)
	elif stem == GuardBody.CLIP:
		guard.reset_ward()
		_show_guard(0.0)
	elif stem == IncantationBody.CLIP:
		_show_incantation(0.0)
	elif stem == PullBody.CLIP:
		_show_pull(0.0)
	elif stem == KICK:
		_show_kick(0)
	elif cards_mode and Catalog.Data.CLIPS.has(stem) and stem not in ["PR_IDLE", "PR_WALK"]:
		_show(stem, 0)
	else:
		super._select_clip(stem)
		_show_native()


func _sample_weighted_clip(clip: StringName, phase: float) -> void:
	super._sample_weighted_clip(clip, phase)
	_show_native()


func _sample_action_at(seconds: float) -> void:
	if cards_mode and _stem == DrainBody.CLIP:
		_show_drain(seconds)
		return
	if cards_mode and _stem == GuardBody.CLIP:
		_show_guard(seconds)
		return
	if cards_mode and _stem == IncantationBody.CLIP:
		_show_incantation(seconds)
		return
	if cards_mode and _stem == PullBody.CLIP:
		_show_pull(seconds)
		return
	if not cards_mode or _stem in ["dash", "idle"]:
		super._sample_action_at(seconds)
		_show_native()
		return
	if _stem == KICK:
		var end_ms := 0.0
		for i in kick_data.duration_ms.size():
			end_ms += float(kick_data.duration_ms[i])
			if seconds * 1000.0 < end_ms - .001:
				_show_kick(i)
				return
		_show_kick(7)
		return
	_show(_stem, Catalog.frame_at(_stem, seconds))
	body.card = Catalog.card(str(_presentation.get("spell_id", "")))
	body.action_time = seconds * 1000.0
	body.queue_redraw()


func cancel_action() -> void:
	super.cancel_action()
	if is_instance_valid(drain):
		drain.reset_siphon()
		drain.hide()
	if is_instance_valid(guard):
		guard.reset_ward()
		guard.hide()
	if is_instance_valid(incantation):
		incantation.hide()
	if is_instance_valid(pull):
		pull.hide()
	if is_instance_valid(kick):
		kick.hide()
	if is_instance_valid(body):
		body.card = { }
		body.queue_redraw()


func get_vfx_origin() -> Vector2:
	if is_instance_valid(drain) and drain.visible:
		return drain.hand_position()
	if is_instance_valid(guard) and guard.visible:
		return guard.hand_position()
	if is_instance_valid(incantation) and incantation.visible:
		return incantation.hand_position()
	if is_instance_valid(pull) and pull.visible:
		return pull.hand_position()
	if is_instance_valid(kick) and kick.visible:
		var pivot: Array = kick_data.frames[4].pivot
		return SUPPORT * _profile.display_scale + (Vector2(429, 196) - Vector2(pivot[0], pivot[1])) * kick.scale
	if not cards_mode:
		return super.get_vfx_origin()
	var drawing_scale := (
		Registration.factor(_stem, _facing)
		if (is_instance_valid(body) and body.visible)
		else 1.0
	)
	return (Vector2(0, -65) + Directions.axis(_facing) * 23.0) * (
		_profile.display_scale * 214.0 / 108.0 * drawing_scale
	)


func get_runtime_state() -> Dictionary:
	var state := super.get_runtime_state()
	state["s19_enabled"] = cards_mode
	state["ground_phase"] = _ground_phase
	state["landing_duration_seconds"] = LANDING_SECONDS
	state["painted_visible"] = is_instance_valid(body) and body.visible
	state["painted_weight"] = body.modulate.a if is_instance_valid(body) and body.visible else 0.0
	state["directional_source"] = "autosprite_v1/" + str(state.get("animation", ""))
	state["gesture_binding"] = gesture_binding.duplicate()
	state["drain_visible"] = is_instance_valid(drain) and drain.visible
	if state.drain_visible:
		state["animation"] = DrainBody.CLIP
		state["frame"] = drain.source_frame
		state["painted_visible"] = true
		state["painted_weight"] = 1.0
		state["directional_source"] = drain.texture.resource_path
		state["drawing_scale"] = drain.scale.x
		state["drawing_scale_y"] = drain.scale.y
		state["siphon_confirmed"] = drain.siphon_confirmed
		state["siphon_visible"] = drain.siphon.visible
		state["healing_glint"] = drain.siphon.glint and drain.siphon.visible
		state["drained_hp"] = drain.hp_damage
		state["healed_hp"] = drain.hp_healing
	state["guard_visible"] = is_instance_valid(guard) and guard.visible
	if state.guard_visible:
		state["animation"] = GuardBody.CLIP
		state["frame"] = guard.source_frame
		state["painted_visible"] = true
		state["painted_weight"] = 1.0
		state["directional_source"] = guard.texture.resource_path
		state["drawing_scale"] = guard.scale.x
		state["drawing_scale_y"] = guard.scale.y
		state["ward_confirmed"] = guard.ward_confirmed
		state["ward_visible"] = guard.ward.visible
	state["incantation_visible"] = is_instance_valid(incantation) and incantation.visible
	if state.incantation_visible:
		state["animation"] = IncantationBody.CLIP
		state["frame"] = incantation.source_frame
		state["painted_visible"] = true
		state["painted_weight"] = 1.0
		state["directional_source"] = incantation.texture.resource_path
		state["drawing_scale"] = incantation.scale.x
		state["drawing_scale_y"] = incantation.scale.y
	state["pull_visible"] = is_instance_valid(pull) and pull.visible
	if state.pull_visible:
		state["animation"] = PullBody.CLIP
		state["frame"] = pull.source_frame
		state["painted_visible"] = true
		state["painted_weight"] = 1.0
		state["directional_source"] = pull.texture.resource_path
		state["drawing_scale"] = pull.scale.x
	state["s24_prototype"] = is_instance_valid(kick) and kick.visible
	if state.s24_prototype:
		state["animation"] = KICK
		state["frame"] = kick_frame
		state["painted_visible"] = true
		state["painted_weight"] = 1.0
		state["directional_source"] = KICK_ATLAS.resource_path
		state["drawing_scale"] = kick.scale.x
	if cards_mode and is_instance_valid(body) and body.visible:
		state["animation"] = body.current_clip
		state["frame"] = body.current_frame
		state["mirrored"] = body.transform.x.x < 0
		state["directional_source"] = Directions.source(body.current_clip, _facing)
	return state


func _configure_kick(profile: AchillesSpriteVisualProfile) -> void:
	kick_data = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://assets/characters/PasseRive/sprites_s24/kick_high.json"
		)
	)
	kick = Sprite2D.new()
	kick.name = "CoupDeTalonHigh"
	kick.texture = KICK_ATLAS
	kick.centered = false
	kick.region_enabled = true
	kick.region_filter_clip_enabled = true
	kick.material = Appearance.material_for("")
	for group in kick_data.palette:
		for field in ["gain", "center"]:
			var rgb: Array = kick_data.palette[group][field]
			kick.material.set_shader_parameter(group + "_" + field, Vector3(rgb[0], rgb[1], rgb[2]))
	kick.material.set_shader_parameter("display_scale", profile.display_scale)
	add_child(kick)
	kick.hide()


func _show_kick(frame: int) -> void:
	if is_instance_valid(drain):
		drain.hide()
	if is_instance_valid(guard):
		guard.hide()
	if is_instance_valid(incantation):
		incantation.hide()
	if is_instance_valid(pull):
		pull.hide()
	if not is_instance_valid(kick):
		return
	kick_frame = frame
	animated_sprite.hide()
	body.hide()
	kick.show()
	var data: Dictionary = kick_data.frames[frame]
	var region: Array = data.region
	kick.region_rect = Rect2(region[0], region[1], region[2], region[3])
	var factor := _profile.display_scale * Appearance.SOURCE_HEIGHT / float(kick_data.source_height)
	kick.scale = Vector2.ONE * factor
	kick.position = SUPPORT * _profile.display_scale - Vector2(data.pivot[0], data.pivot[1]) * factor


func _show_pull(seconds: float) -> void:
	if is_instance_valid(drain):
		drain.hide()
	if is_instance_valid(guard):
		guard.hide()
	if is_instance_valid(incantation):
		incantation.hide()
	animated_sprite.hide()
	body.hide()
	kick.hide()
	pull.sample(seconds)


func _show_incantation(seconds: float) -> void:
	if is_instance_valid(drain):
		drain.hide()
	if is_instance_valid(guard):
		guard.hide()
	animated_sprite.hide()
	body.hide()
	kick.hide()
	pull.hide()
	incantation.sample(seconds)


func _show_guard(seconds: float) -> void:
	if is_instance_valid(drain):
		drain.hide()
	animated_sprite.hide()
	body.hide()
	kick.hide()
	pull.hide()
	incantation.hide()
	guard.sample(seconds)


func confirm_guard_ward() -> void:
	if cards_mode and is_instance_valid(guard) and guard.visible:
		guard.confirm_ward()


func _show_drain(seconds: float) -> void:
	animated_sprite.hide()
	body.hide()
	kick.hide()
	pull.hide()
	incantation.hide()
	guard.hide()
	drain.sample(seconds)


func confirm_drain(point: Vector2, damage: int, healing: int) -> bool:
	if not cards_mode or not is_instance_valid(drain) or not drain.visible:
		return false
	drain.confirm_siphon(point, damage, healing)
	return drain.siphon_confirmed


func owns_drain_heal_feedback() -> bool:
	# Battle can resume its cast coroutine on the frame after release. Own only
	# the self-heal before this cast's report confirms its presentation.
	return (
		cards_mode and is_instance_valid(drain) and drain.visible \
				and drain.seconds >= DrainBody.RELEASE
		and not drain.siphon_confirmed
	)
