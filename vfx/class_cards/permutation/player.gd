extends Node2D
## Two fixed sites; only a confirmed exchange advances to the opening poses.
signal cancelled
const CONTACT := 8.0 / 30.0
const END := 20.0 / 30.0
const ART := "res://vfx/class_cards/permutation/"
static var assets: Dictionary = { }
static var textures: Dictionary = { }
var recipe: Dictionary = { }
var point := Vector2.ZERO
var origin := Vector2.ZERO
var width := 128.0
var elapsed := 0.0
var duration := END
var closed := false
var persistent := false
var badge_mode := false
var manual := false
var preparing := false
var confirmed := false
var full_sequence := false
var sites: Array[Dictionary] = []
var sheets: Array[Dictionary] = []
var _clock := 0.0


func configure(
	entry: Dictionary,
	at: Vector2,
	display_width: float,
	_anchor: Node2D = null,
	_hold := false,
) -> void:
	recipe = entry.duplicate(true)
	point = at
	origin = at
	width = display_width
	preparing = bool(entry.get("permutation_preparing", false))
	full_sequence = preparing
	confirmed = not preparing
	duration = END if preparing else END - CONTACT
	global_position = point
	z_index = 4
	if assets.is_empty():
		assets = JSON.parse_string(FileAccess.get_file_as_string(ART + "provenance.json")).assets
	for site: Dictionary in entry.get("permutation_sites", []):
		sites.append(site.duplicate())
		for id in ["clasp_back", "clasp_front", "slit"]:
			_sheet(id, sites.size() - 1)
	sample(0)


func _sheet(id: String, site_index: int) -> void:
	if not textures.has(id):
		textures[id] = load(ART + id + ".png")
	var asset: Dictionary = assets[id]
	var sprite := Sprite2D.new()
	sprite.texture = textures[id]
	sprite.hframes = int(asset.columns)
	sprite.vframes = int(asset.rows)
	sprite.offset = Vector2.ONE * float(asset.size) * .5 - Vector2(asset.pivot[0], asset.pivot[1])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	var sheet := { "id": id, "site": site_index, "sprite": sprite, "frames": int(asset.frames) }
	sheets.append(sheet)
	_attach(sheet)
	sprite.global_scale = Vector2.ONE * width * (1.35 if id == "slit" else 1.55) / float(asset.size)
	sprite.global_position = sites[site_index].point


func _attach(sheet: Dictionary) -> void:
	var sprite: Sprite2D = sheet.sprite
	var owner_view: Node2D = sites[sheet.site].get("view")
	var destination: Node = owner_view if is_instance_valid(owner_view) else self
	if sprite.get_parent() != destination:
		sprite.reparent(destination, true)
	sprite.show_behind_parent = sheet.id == "clasp_back" and destination != self
	sprite.z_index = 0 if sheet.id == "clasp_back" else 3
	if sprite.show_behind_parent:
		destination.move_child(sprite, 0)


func confirm(occupants: Array[Node2D] = []) -> void:
	if closed or confirmed:
		return
	# The actors have exchanged sites; keep each back/front pair around the
	# actor now occupying that site, while preserving the exact ground anchor.
	for i in mini(sites.size(), occupants.size()):
		sites[i].view = occupants[i]
	for sheet in sheets:
		if is_instance_valid(sheet.sprite):
			_attach(sheet)
	confirmed = true
	preparing = false
	elapsed = CONTACT
	sample(elapsed)


func _process(delta: float) -> void:
	if closed or manual:
		return
	sample(elapsed + delta)
	if (preparing and elapsed > CONTACT + .8) or (confirmed and elapsed >= duration):
		cancel()


func sample(time: float) -> void:
	elapsed = maxf(time, 0)
	_clock = elapsed if full_sequence else elapsed + CONTACT
	if preparing:
		_clock = minf(_clock, CONTACT - .00001)
	for sheet in sheets:
		var sprite: Sprite2D = sheet.sprite
		if not is_instance_valid(sprite):
			continue
		var age := _clock - (.2 if sheet.id == "slit" else 0.0)
		sprite.global_position = sites[sheet.site].point
		sprite.visible = not closed and age >= 0 and age < float(sheet.frames) / 30.0
		sprite.frame = clampi(int(age * 30.0 + .00001), 0, sheet.frames - 1)
		sprite.modulate.a = 1.0 - smoothstep(.47, END, _clock)


func cancel() -> void:
	if closed:
		return
	closed = true
	for sheet in sheets:
		if is_instance_valid(sheet.sprite):
			sheet.sprite.hide()
			sheet.sprite.queue_free()
	sheets.clear()
	hide()
	cancelled.emit()
	queue_free()


func _exit_tree() -> void:
	for sheet in sheets:
		if is_instance_valid(sheet.sprite):
			sheet.sprite.queue_free()
	sheets.clear()
