extends VBoxContainer
## Victory is a receipt, not an inventory editor. Closing owns the next step.
signal deck_requested
signal inventory_requested
const Receipt := preload("res://ui/expedition/consumable_loot_receipt.gd")
const Tile := preload("res://ui/expedition/consumable_loot_tile.gd")
const P := preload("res://ui/expedition/class_card_presentation.gd")
const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")
const D := preload("res://ui/expedition/player_dossier_skin.gd")
var session: ExpeditionSession
var _preview: PanelContainer
var _source: Control
var _layer: CanvasLayer
const WIDTHS := [190, 90, 105, 85]


func _ready() -> void:
	name = "ConsumableCombatResults"
	if session == null:
		session = GameManager.expedition
	add_theme_constant_override("separation", 8)
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	var node := session.route.get_current_node()
	var receipt: Dictionary = session.cards.battle_results.get(str(node.id), { })
	var banner := HBoxContainer.new()
	add_child(banner)
	var victory := P.label(banner, "VICTOIRE", 30)
	victory.add_theme_color_override("font_color", Color("f0d99c"))
	victory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	P.label(
		banner,
		"%d tours" % int(receipt.turns) if int(receipt.get("turns", 0)) > 0 else "Combat terminé",
		18,
	)
	P.label(self, str(node.title) + " · Tous les gains ci-dessous sont acquis.", 16)
	add_child(HSeparator.new())
	P.label(self, "GAGNANT", 13).add_theme_color_override("font_color", Color("b4cbbf"))
	var headings := HBoxContainer.new()
	headings.add_theme_constant_override("separation", 0)
	add_child(headings)
	for i in 5:
		var cell := _cell(headings, i)
		P.label(cell, ["PERSONNAGE", "NIVEAU", "XP GAGNÉE", "OBOLES", "OBJETS GAGNÉS"][i], 13).add_theme_color_override(
			"font_color",
			Color("c5bda5"),
		)
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", D.framed_surface(0))
	add_child(row_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row_panel.add_child(row)
	var hero := HBoxContainer.new()
	_cell(row, 0).add_child(hero)
	var appearance := CharacterHUDThemeCatalog.resolve_refined(session.character.unit)
	P.icon(hero, (appearance.portrait_texture
			if appearance != null
			else Receipt.Icons.icon(session.cards.primary_class)), 42)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(identity)
	P.label(identity, session.character.unit.unit_name, 18)
	P.label(identity, str(session.cards.primary_class).capitalize(), 14).add_theme_color_override(
		"font_color",
		Color("b4cbbf"),
	)
	var level := _cell(row, 1)
	var after := int(receipt.get("level_after", session.cards.level))
	P.label(level, str(after), 22).add_theme_color_override("font_color", Color("f0d99c"))
	var progress := ProgressBar.new()
	progress.name = "ReceiptExperience"
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 7)
	var thresholds: Array = Receipt.Catalog.data().rules.xpThresholds
	var lower := int(thresholds[clampi(after - 1, 0, thresholds.size() - 1)])
	var upper := int(thresholds[mini(after, thresholds.size() - 1)])
	progress.max_value = maxi(1, upper - lower)
	progress.value = int(receipt.get("xp_after", 0)) - lower if upper > lower else 1
	level.add_child(progress)
	P.label(_cell(row, 2), "+%d" % int(receipt.get("xp", 0)), 21)
	P.label(_cell(row, 3), "+%d" % int(receipt.get("gold", 0)), 21).add_theme_color_override(
		"font_color",
		Color("f0d99c"),
	)
	var loot := HFlowContainer.new()
	loot.name = "ReceivedLootIcons"
	loot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loot.add_theme_constant_override("h_separation", 8)
	loot.add_theme_constant_override("v_separation", 12)
	_cell(row, 4).add_child(loot)
	var records := Receipt.records_for(session)
	for record in records:
		var tile := Tile.new()
		tile.configure(record)
		loot.add_child(tile)
		tile.mouse_entered.connect(_show_preview.bind(tile))
		tile.mouse_exited.connect(_hide_preview.bind(tile))
		tile.focus_entered.connect(_show_preview.bind(tile))
		tile.focus_exited.connect(_hide_preview.bind(tile))
		tile.pressed.connect(_show_preview.bind(tile))
	if records.is_empty():
		P.label(loot, "Aucun objet obtenu", 16)
	var hint := P.label(
		self,
		"Survolez un butin pour lire ses effets. Cartes dans la réserve · objets dans l’inventaire. Filtre : « Dernier butin ».",
		14,
	)
	hint.add_theme_color_override("font_color", Color("abc0b5"))
	add_child(HSeparator.new())
	var foes := Receipt.commitment(session)
	var forfeited := 0
	for drop in foes.values():
		if drop.get("forfeited", false):
			forfeited += 1
	P.label(
		self,
		("ADVERSAIRES VAINCUS · %d" % foes.size() if not foes.is_empty() else "RENCONTRE TERMINÉE")
		+ (" · %d butin(s) sacrifié(s)" % forfeited if forfeited > 0 else ""),
		13,
	)
	var actions := HBoxContainer.new()
	add_child(actions)
	for index in 2:
		var button := Button.new()
		button.text = ["Mon deck", "Mon inventaire"][index]
		button.custom_minimum_size = Vector2(150, 34)
		D.button(button)
		button.pressed.connect(deck_requested.emit if index == 0 else inventory_requested.emit)
		actions.add_child(button)


func _cell(parent: HBoxContainer, index: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	if index < 4:
		margin.custom_minimum_size.x = WIDTHS[index]
	else:
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(margin)
	var box := VBoxContainer.new()
	# A large drop row must not push the hero and XP below the visible area.
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(box)
	return box


func _show_preview(tile: Control) -> void:
	if is_instance_valid(_preview):
		_preview.free()
	_source = tile
	_preview = Tile.detail(tile.record, session.character.unit)
	_preview.minimum_size_changed.connect(_position_preview, CONNECT_DEFERRED)
	_layer.add_child(_preview)
	_preview.hide()
	_position_preview.call_deferred()


func _position_preview() -> void:
	if not is_instance_valid(_preview) or not is_instance_valid(_source):
		return
	_preview.reset_size()
	var bounds := get_viewport_rect().size
	var anchor := _source.get_global_rect()
	# Keep the entire loot strip unobscured, even when hovering its last card.
	var strip: Control = _source.get_parent() as Control
	var left := strip.get_global_rect().position.x if strip is HFlowContainer else anchor.position.x
	var x := left - _preview.size.x - 14
	if x < 12:
		x = anchor.end.x + 14
	_preview.position = Vector2(
		clampf(x, 12, maxf(12, bounds.x - _preview.size.x - 12)),
		clampf(anchor.position.y - 60, 12, maxf(12, bounds.y - _preview.size.y - 12)),
	)
	_preview.show()


func _hide_preview(tile: Control) -> void:
	if tile != _source:
		return
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	_source = null
