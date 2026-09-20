extends SpellModifier
var effect := ""
var value := 0.0

func get_target_cell_failure_reason(_caster, _spell, cell: Vector2i, grid) -> StringName:
	if effect != "stasis":
		return &""
	var target: Unit = grid.get_unit(cell)
	if target == null or not target.has_status(&"class_marked"):
		return &"requires_marked_target"
	if target.has_status(&"ecosystem_stasis_ward"):
		return &"stasis_immunity"
	return &""

func on_targets_resolved(ctx) -> void:
	if effect != "stasis":
		return
	var target: Unit = ctx.grid.get_unit(ctx.cell)
	if target == null:
		return
	var disable := StatusData.new()
	disable.status_id = &"ecosystem_stasis"
	disable.status_name = "Stase"
	disable.duration = 1
	disable.unique_per_source = true
	if "paris" in str(target.unit_id):
		disable.ap_reduction = 1
	else:
		disable.skips_turn = true
	var ward := StatusData.new()
	ward.status_id = &"ecosystem_stasis_ward"
	ward.status_name = "Éveil · immunité à la stase"
	ward.duration = 3
	ctx.additional_statuses_by_unit[target] = [disable, ward]
	ctx.additional_status_sources_by_unit[target] = ctx.caster

func on_terrain_resolved(ctx) -> void:
	if effect != "fire_field" or ctx.terrain == null:
		return
	var tile := surface(effect, value)
	tile.damage = maxi(1, roundi(ctx.caster.attack_power.get_value() * value))
	for cell in ctx.affected_cells:
		var result: Dictionary = ctx.terrain.place_effect(cell, tile, ctx.caster, ctx.spell)
		if result.get("changed", false) and cell not in ctx.report.terrain_changed:
			ctx.report.terrain_changed.append(cell)

static func surface(kind: String, coefficient: float) -> TerrainEffectData:
	var tile := TerrainEffectData.new()
	var fire := kind == "fire_field"
	tile.effect_name = "Braises persistantes" if fire else "Piège de givre"
	if fire:
		tile.description = "Croix de braises pendant 2 tours : %d %% de Prouesse en dégâts au début du tour d'une unité sur une dalle." % roundi(coefficient * 100)
	else:
		tile.description = "Croix gelée pendant 2 tours : retire %d PM à la prochaine activation des unités qui entrent." % int(coefficient)
	tile.surface_id = &"fire" if fire else &"ice"
	tile.visual_terrain_id = tile.surface_id
	tile.cell_type = 3 if fire else 4
	tile.color = Color("ec7749") if fire else Color("77d0df")
	tile.trigger = TerrainEffectData.Trigger.TURN_START if fire else TerrainEffectData.Trigger.ON_ENTER
	tile.duration = 2
	tile.element = Spell.Element.FIRE if fire else Spell.Element.ICE
	tile.dangerous_for_ai = true
	tile.ai_danger_weight = 4.0
	tile.same_surface_policy = TerrainEffectData.SameSurfacePolicy.REPLACE
	if not fire:
		var slow := StatusData.new()
		slow.status_id = &"ecosystem_ice"
		slow.status_name = "Engourdi"
		slow.mp_reduction = int(coefficient)
		slow.duration = 1
		tile.applied_status = slow
	return tile
