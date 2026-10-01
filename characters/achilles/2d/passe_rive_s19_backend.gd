extends PasseRiveAutoSpriteBackend
## Exploration owns neutral locomotion and dash; approved paintings own card attacks.
const Catalog := preload("passe_rive_s19_catalog.gd")
const Body := preload("passe_rive_s19_body.gd")
const Directions := preload("passe_rive_s20_directions.gd")
var cards_mode := false
var body: Node2D
const HEIGHT := 94.16 # 214 reference pixels × exploration profile scale 0.44.
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const Registration := preload("res://characters/achilles/2d/passe_rive_registration.gd")
const Bindings := preload("res://characters/achilles/2d/passe_rive_card_bindings.gd")
const KickBody := preload("passe_rive_kick_body.gd")
const KICK := "PR_KICK_B_S24"
const KICK_ATLAS := preload("res://assets/characters/PasseRive/sprites_s24/kick_high.png")
const SUPPORT := Vector2(-18.3333584, 17.19648)
const PullBody := preload("passe_rive_pull_body.gd")
const IncantationBody := preload("passe_rive_incantation_body.gd")
const GuardBody := preload("passe_rive_guard_body.gd")
const DrainBody := preload("passe_rive_drain_body.gd")
const RenewBody := preload("passe_rive_renew_body.gd")
var renew: Node2D
const RecenterBody := preload("passe_rive_recenter_body.gd")
var recenter: Node2D
const SpectralBody := preload("passe_rive_spectral_body.gd")
var spectral: Node2D
var spectral_origin := Vector2.ZERO
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
	spectral = SpectralBody.new()
	spectral.name = "PassageSpectral"
	add_child(spectral)
	spectral.configure(profile)
	renew = RenewBody.new()
	renew.name = "SecondeAurore"
	add_child(renew)
	renew.configure(profile)
	recenter = RecenterBody.new()
	recenter.name = "Recentrage"
	add_child(recenter)
	recenter.configure(profile)
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
	if reference == "recenter":
		return {
			"stem": RecenterBody.CLIP,
			"duration": RecenterBody.DURATION,
			"release_seconds": RecenterBody.RELEASE,
			"release_frame": RecenterBody.RELEASE_FRAME,
			"legacy_loop": false,
			"speed": 1.0,
		}
	if reference == "renew":
		var compact := id == "cc2_l02"
		return {
			"stem": RenewBody.CLIP,
			"duration": RenewBody.SHORT_DURATION if compact else RenewBody.DURATION,
			"release_seconds": RenewBody.SHORT_RELEASE if compact else RenewBody.RELEASE,
			"release_frame": 4 if compact else 6,
			"legacy_loop": false,
			"speed": 1.0,
		}
	if reference == "blink":
		return {
			"stem": SpectralBody.CLIP,
			"duration": SpectralBody.DURATION,
			"release_seconds": SpectralBody.RELEASE,
			"release_frame": SpectralBody.RELEASE_FRAME,
			"legacy_loop": false,
			"speed": 1.0,
		}
	if reference == "drain":
		return {
			"stem": DrainBody.CLIP,
			"duration": DrainBody.DURATION,
			"release_seconds": DrainBody.RELEASE,
			"release_frame": DrainBody.RELEASE_FRAME,
			"legacy_loop": false,
			"speed": 1.0,
		}
	if reference == "guard":
		return {
			"stem": GuardBody.CLIP,
			"duration": GuardBody.DURATION,
			"release_seconds": GuardBody.RELEASE,
			"release_frame": GuardBody.RELEASE_FRAME,
			"legacy_loop": false,
			"speed": 1.0,
		}
	if reference == "incantation":
		return {
			"stem": IncantationBody.CLIP,
			"duration": IncantationBody.DURATION,
			"release_seconds": IncantationBody.RELEASE,
			"release_frame": IncantationBody.RELEASE_FRAME,
			"legacy_loop": false,
			"speed": 1.0,
		}
	if reference == "pull":
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
	if reference == "kick":
		return {
			"stem": KICK,
			"duration": .65,
			"release_seconds": .31,
			"release_frame": 4,
			"legacy_loop": false,
			"speed": 1.0,
		}
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
	if is_instance_valid(recenter):
		recenter.hide()
	if is_instance_valid(renew):
		renew.hide()
	if is_instance_valid(spectral):
		spectral.hide()
	if is_instance_valid(animated_sprite):
		animated_sprite.self_modulate = Color.WHITE
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
	if is_instance_valid(recenter):
		recenter.hide()
	if is_instance_valid(renew):
		renew.hide()
	if is_instance_valid(spectral):
		spectral.hide()
	if is_instance_valid(animated_sprite):
		animated_sprite.self_modulate = Color.WHITE
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
	if stem == RecenterBody.CLIP:
		recenter.reset()
		super._select_clip("idle")
		_show_recenter(0.0)
	elif stem == RenewBody.CLIP:
		renew.reset(str(_presentation.get("spell_id", "")) == "cc2_l02")
		super._select_clip("idle")
		_show_renew(0.0)
	elif stem == SpectralBody.CLIP:
		spectral.reset()
		spectral_origin = global_position
		super._select_clip("idle")
		_show_spectral(0.0)
	elif stem == DrainBody.CLIP:
		super._select_clip("idle")
		drain.reset_siphon()
		_show_drain(0.0)
	elif stem == GuardBody.CLIP:
		super._select_clip("idle")
		guard.reset_ward()
		_show_guard(0.0)
	elif stem == IncantationBody.CLIP:
		super._select_clip("idle")
		_show_incantation(0.0)
	elif stem == PullBody.CLIP:
		super._select_clip("idle")
		_show_pull(0.0)
	elif stem == KICK:
		super._select_clip("idle")
		_show_kick(0, 0.0)
	elif cards_mode and Catalog.Data.CLIPS.has(stem) and stem not in ["PR_IDLE", "PR_WALK"]:
		_show(stem, 0)
	else:
		super._select_clip(stem)
		_show_native()


func _sample_weighted_clip(clip: StringName, phase: float) -> void:
	super._sample_weighted_clip(clip, phase)
	_show_native()


func _sample_action_at(seconds: float) -> void:
	if cards_mode and _stem == RecenterBody.CLIP:
		_show_recenter(seconds)
		return
	if cards_mode and _stem == RenewBody.CLIP:
		_show_renew(seconds)
		return
	if cards_mode and _stem == SpectralBody.CLIP:
		_show_spectral(seconds)
		return
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
				_show_kick(i, seconds)
				return
		_show_kick(7, seconds)
		return
	_show(_stem, Catalog.frame_at(_stem, seconds))
	body.card = Catalog.card(str(_presentation.get("spell_id", "")))
	body.action_time = seconds * 1000.0
	body.queue_redraw()


func cancel_action() -> void:
	var was_spectral := _stem in [SpectralBody.CLIP, RenewBody.CLIP, RecenterBody.CLIP]
	super.cancel_action()
	if is_instance_valid(recenter):
		recenter.reset()
	if is_instance_valid(renew):
		renew.reset()
	if is_instance_valid(spectral):
		spectral.reset()
	if was_spectral and is_instance_valid(animated_sprite):
		_hold_idle_pose()
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
	if is_instance_valid(recenter) and recenter.visible:
		return recenter.hand_position()
	if is_instance_valid(renew) and renew.visible:
		return renew.hand_position()
	if is_instance_valid(drain) and drain.visible:
		return drain.hand_position()
	if is_instance_valid(guard) and guard.visible:
		return guard.hand_position()
	if is_instance_valid(incantation) and incantation.visible:
		return incantation.hand_position()
	if is_instance_valid(pull) and pull.visible:
		return pull.hand_position()
	if is_instance_valid(kick) and kick.visible:
		return kick.heel_position()
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
	state["spectral_visible"] = is_instance_valid(spectral) and spectral.visible
	if state.spectral_visible:
		state["animation"] = SpectralBody.CLIP
		state["frame"] = spectral.source_frame
		state["painted_visible"] = spectral.drawing.visible
		state["painted_weight"] = spectral.drawing.self_modulate.a
		state["authored_direction"] = spectral.facing
		state["mirrored"] = false
		state["spectral_alpha"] = spectral.body_alpha
		state["spectral_native_weight"] = spectral.native_weight
		state["arrival_confirmed"] = spectral.arrival_confirmed
		state["veil_frame"] = spectral.veil_frame
		state["drawing_scale"] = spectral.drawing.scale.x
		state["drawing_scale_y"] = spectral.drawing.scale.y
		state["directional_source"] = spectral.drawing.texture.resource_path if spectral.painted else "autosprite_v1/idle_" + _facing
	state["drain_visible"] = is_instance_valid(drain) and drain.visible
	if state.drain_visible:
		state["animation"] = DrainBody.CLIP
		state["frame"] = drain.source_frame
		state["painted_visible"] = true
		state["painted_weight"] = drain.blend
		state["directional_source"] = drain.texture.resource_path
		state["drawing_scale"] = drain.scale.x
		state["drawing_scale_y"] = drain.scale.y
		state["siphon_confirmed"] = drain.siphon_confirmed
		state["siphon_visible"] = drain.siphon.visible
		state["healing_glint"] = drain.siphon.glint and drain.siphon.visible
		state["drained_hp"] = drain.hp_damage
		state["healed_hp"] = drain.hp_healing
		state["authored_direction"] = drain.facing
		state["mirrored"] = false
	state["guard_visible"] = is_instance_valid(guard) and guard.visible
	if state.guard_visible:
		state["animation"] = GuardBody.CLIP
		state["frame"] = guard.source_frame
		state["painted_visible"] = true
		state["painted_weight"] = guard.blend
		state["directional_source"] = guard.texture.resource_path
		state["drawing_scale"] = guard.scale.x
		state["drawing_scale_y"] = guard.scale.y
		state["ward_confirmed"] = guard.ward_confirmed
		state["ward_visible"] = guard.ward.visible
		state["authored_direction"] = guard.facing
		state["mirrored"] = false
	state["incantation_visible"] = is_instance_valid(incantation) and incantation.visible
	if state.incantation_visible:
		state["animation"] = IncantationBody.CLIP
		state["frame"] = incantation.source_frame
		state["painted_visible"] = true
		state["painted_weight"] = incantation.blend
		state["directional_source"] = incantation.texture.resource_path
		state["drawing_scale"] = incantation.scale.x
		state["drawing_scale_y"] = incantation.scale.y
		state["authored_direction"] = incantation.facing
		state["mirrored"] = false
	state["pull_visible"] = is_instance_valid(pull) and pull.visible
	if state.pull_visible:
		state["animation"] = PullBody.CLIP
		state["frame"] = pull.source_frame
		state["painted_visible"] = true
		state["painted_weight"] = pull.blend
		state["directional_source"] = pull.texture.resource_path
		state["drawing_scale"] = pull.scale.x
		state["drawing_scale_y"] = pull.scale.y
		state["authored_direction"] = pull.facing
		state["mirrored"] = false
	state["s24_prototype"] = is_instance_valid(kick) and kick.visible
	if state.s24_prototype:
		state["animation"] = KICK
		state["frame"] = kick_frame
		state["painted_visible"] = true
		state["painted_weight"] = 1.0
		state["directional_source"] = kick.texture.resource_path
		state["authored_direction"] = kick.facing
		state["source_frame"] = kick.source_frame
		state["painted_weight"] = kick.blend
		state["mirrored"] = false
		state["drawing_scale"] = kick.scale.x
	if cards_mode and is_instance_valid(body) and body.visible:
		state["animation"] = body.current_clip
		state["frame"] = body.current_frame
		state["mirrored"] = body.transform.x.x < 0
		state["directional_source"] = Directions.source(body.current_clip, _facing)
	state["renew_visible"] = is_instance_valid(renew) and renew.visible
	if state.renew_visible:
		state["animation"] = RenewBody.CLIP
		state["authored_direction"] = renew.facing
		state["mirrored"] = false
		state["frame"] = renew.source_frame
		state["renew_compact"] = renew.compact
		state["renew_confirmed"] = renew.confirmed
		state["renew_healing"] = renew.healing
		state["renew_guard"] = renew.guard_gain
		state["renew_heal_visible"] = renew.healing_visible
		state["renew_guard_visible"] = renew.guard_visible
		state["painted_weight"] = renew.blend
		if renew.painted:
			state["painted_visible"] = renew.drawing.visible
			state["drawing_scale"] = renew.drawing.scale.x
			state["drawing_scale_y"] = renew.drawing.scale.y
			state["directional_source"] = renew.drawing.texture.resource_path
	state["recenter_visible"] = is_instance_valid(recenter) and recenter.visible
	if state.recenter_visible:
		state["animation"] = RecenterBody.CLIP
		state["frame"] = recenter.source_frame
		state["authored_direction"] = recenter.facing
		state["mirrored"] = false
		state["recenter_confirmed"] = recenter.confirmed
		state["cards_drawn"] = recenter.drawn
		state["glyph_count"] = recenter.glyph_count
		state["painted_visible"] = recenter.drawing.visible
		state["painted_weight"] = recenter.blend
		state["drawing_scale"] = recenter.drawing.scale.x
		state["drawing_scale_y"] = recenter.drawing.scale.y
		state["directional_source"] = recenter.drawing.texture.resource_path
	return state


func _configure_kick(profile: AchillesSpriteVisualProfile) -> void:
	kick_data = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://assets/characters/PasseRive/sprites_s24/kick_high.json"
		)
	)
	kick = KickBody.new()
	kick.name = "CoupDeTalonHigh"
	add_child(kick)
	kick.configure(profile)


func _show_kick(frame: int, seconds: float = -1.0) -> void:
	if is_instance_valid(recenter):
		recenter.hide()
	if is_instance_valid(renew):
		renew.hide()
	if is_instance_valid(spectral):
		spectral.hide()
	if is_instance_valid(animated_sprite):
		animated_sprite.self_modulate = Color.WHITE
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
	var native_weight: float = kick.sample_frame(frame, _facing, seconds)
	animated_sprite.self_modulate.a = native_weight
	animated_sprite.visible = native_weight > 0.0


func _show_pull(seconds: float) -> void:
	if is_instance_valid(recenter):
		recenter.hide()
	if is_instance_valid(renew):
		renew.hide()
	if is_instance_valid(spectral):
		spectral.hide()
	if is_instance_valid(animated_sprite):
		animated_sprite.self_modulate = Color.WHITE
	if is_instance_valid(drain):
		drain.hide()
	if is_instance_valid(guard):
		guard.hide()
	if is_instance_valid(incantation):
		incantation.hide()
	animated_sprite.hide()
	body.hide()
	kick.hide()
	var native_weight: float = pull.sample(seconds, _facing)
	animated_sprite.self_modulate.a = native_weight
	animated_sprite.visible = native_weight > 0.0


func _show_incantation(seconds: float) -> void:
	if is_instance_valid(recenter):
		recenter.hide()
	if is_instance_valid(renew):
		renew.hide()
	if is_instance_valid(spectral):
		spectral.hide()
	if is_instance_valid(animated_sprite):
		animated_sprite.self_modulate = Color.WHITE
	if is_instance_valid(drain):
		drain.hide()
	if is_instance_valid(guard):
		guard.hide()
	animated_sprite.hide()
	body.hide()
	kick.hide()
	pull.hide()
	var native_weight: float = incantation.sample(seconds, _facing)
	animated_sprite.self_modulate.a = native_weight
	animated_sprite.visible = native_weight > 0.0


func _show_guard(seconds: float) -> void:
	if is_instance_valid(recenter):
		recenter.hide()
	if is_instance_valid(renew):
		renew.hide()
	if is_instance_valid(spectral):
		spectral.hide()
	if is_instance_valid(animated_sprite):
		animated_sprite.self_modulate = Color.WHITE
	if is_instance_valid(drain):
		drain.hide()
	animated_sprite.hide()
	body.hide()
	kick.hide()
	pull.hide()
	incantation.hide()
	var native_weight: float = guard.sample(seconds, _facing)
	animated_sprite.self_modulate.a = native_weight
	animated_sprite.visible = native_weight > 0.0


func confirm_guard_ward() -> void:
	if cards_mode and is_instance_valid(guard) and guard.visible:
		guard.confirm_ward()


func _show_drain(seconds: float) -> void:
	if is_instance_valid(recenter):
		recenter.hide()
	if is_instance_valid(renew):
		renew.hide()
	if is_instance_valid(spectral):
		spectral.hide()
	if is_instance_valid(animated_sprite):
		animated_sprite.self_modulate = Color.WHITE
	animated_sprite.hide()
	body.hide()
	kick.hide()
	pull.hide()
	incantation.hide()
	guard.hide()
	var native_weight: float = drain.sample(seconds, _facing)
	animated_sprite.self_modulate.a = native_weight
	animated_sprite.visible = native_weight > 0.0


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


func _show_spectral(seconds: float) -> void:
	_show_native()
	# Battle has already snapped the public UnitView to the resolved cell.
	# Camera movement cannot change this world-space anchor.
	if _release_emitted and global_position.distance_squared_to(spectral_origin) > .0001:
		spectral.arrival_confirmed = true
	animated_sprite.self_modulate.a = spectral.sample(seconds, _facing)


func owns_spectral_feedback() -> bool:
	return (
		cards_mode and _action_pending and _stem == SpectralBody.CLIP
		and is_instance_valid(spectral) and spectral.visible
	)


func _show_renew(seconds: float) -> void:
	_show_native()
	var native_weight: float = renew.sample(seconds, _facing)
	animated_sprite.self_modulate.a = native_weight


func owns_renew_feedback() -> bool:
	return (
		cards_mode and _action_pending and _stem == RenewBody.CLIP
		and is_instance_valid(renew) and renew.visible and not renew.confirmed
		and renew.seconds + .000001 >= renew.release_time()
	)


func confirm_renew(spell_id: String, healing: int, guard_gain: int) -> bool:
	if not owns_renew_feedback() or str(_presentation.get("spell_id", "")) != spell_id:
		return false
	return renew.confirm_result(healing, guard_gain)


func _show_recenter(seconds: float) -> void:
	_show_native()
	animated_sprite.self_modulate.a = recenter.sample(seconds, _facing)


func confirm_recenter(spell_id: String, drawn: int) -> bool:
	if not (
		cards_mode and _action_pending and _stem == RecenterBody.CLIP
		and spell_id == "cc2_n08" and str(_presentation.get("spell_id", "")) == spell_id
	):
		return false
	return recenter.confirm_result(drawn)
