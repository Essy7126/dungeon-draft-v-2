extends RefCounted
## Native map statuses remain part of the authored Battle when resuming cards.


static func definition(kind: String) -> StatusData:
	match kind:
		"status":
			return StatusData.new()
		"vulnerability":
			return ChargedDamageVulnerabilityData.new()
		"outgoing":
			return ChargedOutgoingDamageData.new()
	return null


static func fields(data: StatusData) -> Array[String]:
	var result: Array[String] = []
	for property in data.get_property_list():
		if (
			property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE
			and property.usage & PROPERTY_USAGE_STORAGE
		):
			result.append(property.name)
	return result


static func snapshot(unit: Unit) -> Array:
	var result := []
	for entry in unit.active_statuses:
		var data: StatusData = entry.data
		var values := { }
		for key in fields(data):
			var value: Variant = data.get(key)
			if value is Color:
				value = [value.r, value.g, value.b, value.a]
			elif value is PackedScene:
				value = value.resource_path
			values[key] = value
		var source: Unit = entry.get("source")
		result.append(
			{
				"kind": (
					"vulnerability"
					if data is ChargedDamageVulnerabilityData
					else ("outgoing" if data is ChargedOutgoingDamageData else "status")
				),
				"values": values,
				"source": str(source.unit_id) if source != null else "",
				"remaining": entry.remaining,
				"charges": entry.get("charges", 0),
				"metadata": entry.get("metadata", { }).duplicate(true),
			}
		)
	return result


static func valid(value: Variant, identities: Dictionary) -> bool:
	if not value is Array or value.size() > 100:
		return false
	for entry in value:
		if not entry is Dictionary or not entry.get("kind") is String:
			return false
		var data := definition(entry.kind)
		if (
			data == null or not entry.get("values") is Dictionary
			or not entry.get("metadata") is Dictionary
		):
			return false
		if entry.get("source") != "" and not identities.has(entry.get("source")):
			return false
		if not whole(entry.get("remaining"), 1, 1000) or not whole(entry.get("charges"), 0, 99):
			return false
		var names := fields(data)
		if entry.values.size() != names.size():
			return false
		for key in names:
			if not entry.values.has(key):
				return false
			var saved: Variant = entry.values[key]
			var initial: Variant = data.get(key)
			match typeof(initial):
				TYPE_BOOL:
					if not saved is bool:
						return false
				TYPE_INT:
					if not whole(saved, -100000, 100000):
						return false
				TYPE_FLOAT:
					if not number(saved) or absf(saved) > 100000:
						return false
				TYPE_STRING, TYPE_STRING_NAME:
					if not saved is String:
						return false
				TYPE_DICTIONARY:
					if not saved is Dictionary:
						return false
					for stat in saved:
						if (
							not stat is String or Unit.new()._stat_for_status_name(StringName(stat)) == null
							or not number(saved[stat])
						):
							return false
				TYPE_COLOR:
					if not saved is Array or saved.size() != 4:
						return false
					for component in saved:
						if not number(component):
							return false
				TYPE_NIL, TYPE_OBJECT:
					if (
						saved != null
						and (
							not saved is String or not saved.begins_with("res://")
							or not ResourceLoader.exists(saved, "PackedScene")
						)
					):
						return false
				_:
					return false
	return true


static func restore(unit: Unit, value: Array, units: Dictionary) -> void:
	for entry in unit.active_statuses:
		unit._remove_status_stat_modifiers(entry)
	unit.active_statuses.clear()
	for saved in value:
		var data := definition(saved.kind)
		for key in fields(data):
			var item: Variant = saved.values[key]
			if data.get(key) is Color:
				item = Color(item[0], item[1], item[2], item[3])
			elif key == "vfx_scene" and item is String:
				item = load(item)
			data.set(key, item)
		var source: Unit = units.get(saved.source)
		unit.active_statuses.append(
			{
				"data": data,
				"remaining": int(saved.remaining),
				"source": source,
				"charges": int(saved.charges),
				"metadata": saved.metadata.duplicate(true),
			}
		)
		# Reconstruct modifiers without emitting a second application event.
		unit._apply_status_stat_modifiers(data, source)


static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func whole(value: Variant, low: int, high: int) -> bool:
	return number(value) and value == floorf(value) and value >= low and value <= high
