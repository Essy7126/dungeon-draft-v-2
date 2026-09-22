extends Node2D
const Catalog := preload("res://vfx/class_cards/class_card_vfx_catalog.gd")
const Player := preload("res://vfx/class_cards/class_card_vfx_player.gd")
const Profiles := preload("res://vfx/class_cards/class_card_vfx_profiles.gd")
const Ground := preload("res://vfx/class_cards/class_card_vfx_ground.gd")
const SELECTION := [
	"a_reap",
	"g_bastion",
	"g_crash",
	"r_scatter",
	"r_bounty",
	"t_cataclysm",
	"t_hourglass",
	"a_stasis",
]
const PAGE_SIZE := 8
const OUT := "res://artifacts/dev/class_card_vfx/ethereal/gallery/"
const EnemyInventory := preload("res://tools/class_card_vfx/enemy_inventory.gd")
const LOOP := 2.2
var enemy_spells: Dictionary = { }
const STATUS_TITLES := {
	"slash": "Entaille",
	"pierce": "Percée",
	"cleave": "Frappe ample",
	"push": "Poussée",
	"pull": "Attraction",
	"lightning": "Foudre",
	"summon": "Invocation",
	"mark": "Marque",
	"root": "Entrave",
	"bleed": "Saignement",
	"fire": "Brûlure",
	"weaken": "Affaiblissement",
	"shadow": "Envoûtement",
	"stasis": "Stase",
	"guard": "Protection",
	"ice": "Engourdissement",
	"disrupt": "Désorientation",
	"heal": "Soin du laurier",
	"move": "Esquive",
	"water": "Mouillé",
	"poison": "Poison",
}
var entries: Array = []
var effects: Array[Node] = []
var tiles: Array[Node] = []
var page := 0
var elapsed := 0.0
var speed := 1.0
var playing := true
var capturing := false
var clock_label: Label
var page_label: Label
var timeline: HSlider
var selector: OptionButton
var body_font := preload(
	"res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf"
)
var title_font := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
var scenery := preload("res://asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png")
var actor := preload("res://assets/characters/Achilles/passe_rive_iso_v1/atlases/strike_E.png")


func _ready() -> void:
	enemy_spells = EnemyInventory.spells()
	get_window().size = Vector2i(1440, 950)
	get_tree().root.content_scale_size = Vector2i(1440, 950)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	capturing = "--capture" in OS.get_cmdline_user_args()
	_label("CATABASE  /  ATELIER DES SORTS", Vector2(38, 25), 13, Color("92b9a8"))
	_label("Les arts éthérés", Vector2(36, 46), 33, Color("e8ddbd"), true)
	_label(
		"%d cartes · %d sorts adversaires · %d familles"
		% [Catalog.Cards.pool().size(), enemy_spells.size(), Catalog.FAMILIES.size()],
		Vector2(39, 96),
		16,
	)
	selector = OptionButton.new()
	selector.position = Vector2(825, 49)
	selector.size = Vector2(245, 42)
	for title in [
		"Sélection d'atelier",
		"Toutes les cartes",
		"Assassin",
		"Gardien",
		"Arpenteur",
		"Thaumaturge",
		"États et effets",
		"Sorts adversaires",
		"Toutes les familles",
		"États durables",
		"Puissance : courant / épique",
	]:
		selector.add_item(title)
	selector.item_selected.connect(_select)
	add_child(selector)
	_button(
		"←",
		Vector2(1090, 49),
		48,
		func():
			_turn_page(-1),
	)
	_button(
		"→",
		Vector2(1148, 49),
		48,
		func():
			_turn_page(1),
	)
	page_label = _label("", Vector2(1220, 57), 18)
	_button(
		"Rejouer",
		Vector2(38, 867),
		112,
		func():
			elapsed = 0.0
			playing = true,
	)
	_button(
		"Pause / lecture",
		Vector2(162, 867),
		155,
		func():
			playing = not playing,
	)
	for i in 3:
		var rate: float = [.5, 1.0, 1.5][i]
		_button(
			"× %.1f" % rate,
			Vector2(340 + i * 82, 867),
			72,
			func():
				speed = rate,
		)
	timeline = HSlider.new()
	timeline.position = Vector2(621, 874)
	timeline.size = Vector2(490, 28)
	timeline.min_value = 0
	timeline.max_value = LOOP
	timeline.step = .01
	timeline.value_changed.connect(
		func(value):
			elapsed = value
			playing = false
			_sample(),
	)
	add_child(timeline)
	clock_label = _label("", Vector2(1140, 874), 17)
	_label(
		"Run Cartes uniquement · Transparence, lumière et volutes · Même rendu que le combat · Personnage fixe dans l'atelier",
		Vector2(38, 924),
		13,
		Color("8ca79a"),
	)
	_select(0)
	if capturing:
		playing = false
		_capture.call_deferred()


func _label(
	text_value: String,
	at: Vector2,
	size_value: int,
	color := Color("c5ccbc"),
	title := false,
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_override("font", title_font if title else body_font)
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _button(text_value: String, at: Vector2, width: float, action: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = Vector2(width, 38)
	button.add_theme_font_override("font", body_font)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(action)
	add_child(button)


func _select(index: int) -> void:
	selector.select(index)
	entries.clear()
	var ids: Array = SELECTION.duplicate()
	if index == 1:
		ids = Catalog.Cards.pool()
	elif index >= 2 and index <= 5:
		ids = Catalog.Cards.pool(["assassin", "gardien", "arpenteur", "thaumaturge"][index - 2])
	elif index == 6:
		ids = [
			"mark",
			"root",
			"bleed",
			"fire",
			"weaken",
			"shadow",
			"stasis",
			"guard",
			"ice",
			"disrupt",
			"heal",
			"move",
		]
	elif index == 7:
		ids = enemy_spells.keys()
		ids.sort()
	elif index == 8:
		ids = Catalog.FAMILIES
	elif index == 9:
		ids = Catalog.STATUSES.keys()
		ids.sort()
	elif index == 10:
		ids = [
			"a_dagger",
			"a_reap",
			"g_guard",
			"g_bastion",
			"r_shot",
			"r_bounty",
			"t_burn",
			"t_cataclysm",
		]
	for id in ids:
		var entry := Catalog.for_spell(enemy_spells[id]) if index == 7 else Catalog.recipe(id)
		if index == 9:
			entry = Profiles.state(Catalog.feedback(Catalog.STATUSES[id]), id)
			entry["name"] = STATUS_TITLES.get(entry.family, entry.family)
			entry["class_id"] = "État durable"
			entry["effect"] = id
			entry["hold_preview"] = true
		if entry.is_empty():
			entry = Catalog.feedback(id)
			entry["name"] = STATUS_TITLES.get(id, id)
			entry["class_id"] = "effet"
		entries.append(entry)
	page = 0
	_show_page()


func _turn_page(direction: int) -> void:
	page = posmod(page + direction, ceili(entries.size() / float(PAGE_SIZE)))
	_show_page()


func _show_page() -> void:
	for fx in effects:
		if is_instance_valid(fx):
			fx.cancel()
	effects.clear()
	for tile in tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	tiles.clear()
	for index in mini(PAGE_SIZE, entries.size() - page * PAGE_SIZE):
		var entry: Dictionary = entries[page * PAGE_SIZE + index]
		var at := Vector2(38 + (index % 4) * 345, 147 + (index / 4) * 352)
		var root := Control.new()
		root.position = at
		root.size = Vector2(330, 336)
		root.clip_contents = true
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.z_index = 10
		add_child(root)
		tiles.append(root)
		var label := _label(str(entry.name), at + Vector2(16, 13), 17, Color("ebdfbf"))
		tiles.append(label)
		var caption := _label(
			str(entry.class_id).capitalize() + "  /  " + str(entry.effect),
			at + Vector2(16, 38),
			12,
			Color("91b3a3"),
		)
		tiles.append(caption)
		var anchor := Node2D.new()
		root.add_child(anchor)
		anchor.position = Vector2(170, 312)
		var sprite := Sprite2D.new()
		sprite.texture = actor
		sprite.region_enabled = true
		sprite.region_rect = Rect2(4, 4, 452, 442)
		sprite.centered = false
		sprite.offset = Vector2(-194, -434)
		sprite.scale = Vector2.ONE * .245
		anchor.add_child(sprite)
		if entry.has("ground_motif"):
			var floor_fx := Ground.new()
			root.add_child(floor_fx)
			var center := anchor.global_position - Vector2(0, 16)
			floor_fx.configure(
				entry.family,
				PackedVector2Array(
					[
						center + Vector2(0, -35),
						center + Vector2(82, 0),
						center + Vector2(0, 35),
						center + Vector2(-82, 0),
					]
				),
				2,
				float(entry.seed % 97),
				entry.ground_motif,
			)
			floor_fx.manual = true
			effects.append(floor_fx)
			continue
		var fx := Player.new()
		root.add_child(fx)
		fx.configure(
			entry,
			anchor.global_position,
			92 * float(entry.get("width", 1.5)),
			anchor,
			entry.get("hold_preview", false),
		)
		fx.manual = true
		effects.append(fx)
	page_label.text = "%02d / %02d" % [page + 1, ceili(entries.size() / float(PAGE_SIZE))]
	elapsed = 0
	_sample()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 950), Color("111e1b"))
	draw_line(Vector2(38, 128), Vector2(1400, 128), Color("687356"), 1)
	for index in mini(PAGE_SIZE, entries.size() - page * PAGE_SIZE):
		var at := Vector2(38 + (index % 4) * 345, 147 + (index / 4) * 352)
		draw_rect(Rect2(at, Vector2(330, 336)), Color("20372f"))
		draw_texture_rect_region(
			scenery,
			Rect2(at + Vector2(1, 66), Vector2(328, 268)),
			Rect2(340, 320, 1150, 530),
			Color(.5, .58, .47, 1),
		)
		draw_rect(Rect2(at, Vector2(330, 336)), Color("4c6554"), false, 1)


func _sample() -> void:
	for fx in effects:
		fx.sample(elapsed)
	timeline.set_value_no_signal(elapsed)
	clock_label.text = "%.2f s  ·  × %.1f" % [elapsed, speed]


func _process(delta: float) -> void:
	if playing and not capturing:
		elapsed = fmod(elapsed + delta * speed, LOOP)
		_sample()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
	preload("res://tools/class_card_vfx/export_contracts.gd").write(OUT)
	# Warm the shared noise texture and shader pipelines before recording.
	await get_tree().process_frame
	if Player.NOISE.get_image() == null:
		await Player.NOISE.changed
	for frame in 66:
		elapsed = frame / 30.0
		_sample()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(OUT + "frames/%03d.png" % frame)
		if frame == 8:
			image.save_png(OUT + "poster.png")
	_select(10)
	elapsed = .24
	_sample()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "power_comparison.png")
	var reviewed: Array[String] = []
	_select(1)
	for p in ceili(entries.size() / float(PAGE_SIZE)):
		page = p
		_show_page()
		elapsed = .24
		_sample()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "cards_%02d.png" % p)
		for index in mini(PAGE_SIZE, entries.size() - page * PAGE_SIZE):
			reviewed.append(entries[page * PAGE_SIZE + index].id)
	var enemies_reviewed: Array[String] = []
	_select(7)
	for p in ceili(entries.size() / float(PAGE_SIZE)):
		page = p
		_show_page()
		elapsed = .28
		_sample()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "enemies_%02d.png" % p)
		for index in mini(PAGE_SIZE, entries.size() - page * PAGE_SIZE):
			enemies_reviewed.append(entries[page * PAGE_SIZE + index].id)
	_select(8)
	for p in ceili(entries.size() / float(PAGE_SIZE)):
		page = p
		_show_page()
		elapsed = .28
		_sample()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "families_%02d.png" % p)
	_select(6)
	elapsed = .24
	_sample()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "effects.png")
	_select(9)
	for p in ceili(entries.size() / float(PAGE_SIZE)):
		page = p
		_show_page()
		elapsed = 2.0
		_sample()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "durable_%02d.png" % p)
	var file := FileAccess.open(OUT + "report.json", FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"cards_captured": reviewed,
				"count": reviewed.size(),
				"frames": 66,
				"showcase": SELECTION,
				"enemies_captured": enemies_reviewed,
				"enemy_count": enemy_spells.size(),
				"families": Catalog.FAMILIES,
				"durable_statuses": Catalog.STATUSES.keys(),
				"coverage": Catalog.coverage(),
				"renderer": RenderingServer.get_current_rendering_method(),
			},
			"\t",
		)
	)
	for fx in effects:
		fx.cancel()
	await get_tree().process_frame
	get_tree().quit()
