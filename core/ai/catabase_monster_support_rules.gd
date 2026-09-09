extends RefCounted


## The collector's supply line is a real cast condition, shared by combat and
## AI previews. Metadata opt-in leaves every existing spell unchanged.
static func can_cast(grid: GridData, caster: Unit, spell: Spell, origin: Vector2i) -> bool:
	var role := StringName(spell.get_meta("catabase_requires_role_nearby", &""))
	if role == &"":
		return true
	var radius := maxi(0, int(spell.get_meta("catabase_support_radius", 2)))
	for value in grid.get_units():
		var ally := value as Unit
		if ally != null and ally != caster and ally.is_alive and ally.team == caster.team \
				and ally.tactical_role_id == role and grid.manhattan(origin, ally.grid_pos) <= radius:
			return true
	return false
