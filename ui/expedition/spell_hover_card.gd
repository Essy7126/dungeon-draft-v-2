extends Node
## Passive, delayed spell explanation: never receives pointer input or steals focus.
const Text := preload("res://ui/expedition/catabase_card_text.gd")
const P := preload("res://ui/expedition/class_card_presentation.gd")
const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")
var anchor: Button
var spell: Spell
var actor: Unit
var exclusion: Control
var context := ""
var _timer: Timer
var _layer: CanvasLayer
var _panel: PanelContainer
var _pointer := false


static func attach(
	button: Button,
	action: Spell,
	caster: Unit,
	avoid: Control = null,
	note := "",
) -> Node:
	var view = load("res://ui/expedition/spell_hover_card.gd").new()
	view.anchor = button
	view.spell = action
	view.actor = caster
	view.exclusion = avoid
	view.context = note
	button.tooltip_text = ""
	button.add_child(view)
	return view


func _ready() -> void:
	name = "SpellHoverController"
	# Tiles are configured before entering the deck grid. Resolve its scroll area
	# only once the anchor belongs to the scene tree.
	if not is_instance_valid(exclusion):
		var ancestor := anchor.get_parent()
		while ancestor != null and not ancestor is ScrollContainer:
			ancestor = ancestor.get_parent()
		exclusion = ancestor as Control
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.22
	add_child(_timer)
	_timer.timeout.connect(_show)
	anchor.mouse_entered.connect(
		func():
			_pointer = true
			_timer.start(),
	)
	anchor.mouse_exited.connect(
		func():
			_pointer = false
			_hide(),
	)
	anchor.focus_entered.connect(
		func():
			_timer.start(),
	)
	anchor.focus_exited.connect(
		func():
			if not _pointer:
				_hide(),
	)
	anchor.pressed.connect(_hide)
	_layer = CanvasLayer.new()
	_layer.layer = 119
	add_child(_layer)
	set_process(false)


func _hide() -> void:
	_timer.stop()
	if is_instance_valid(_panel):
		_panel.hide()
	set_process(false)


func _show() -> void:
	if not anchor.is_visible_in_tree() or (not _pointer and not anchor.has_focus()):
		return
	# Only one spell explanation, including when switching from keyboard to mouse.
	for other in get_tree().get_nodes_in_group("passive_spell_hover"):
		if other != self:
			other._hide()
	add_to_group("passive_spell_hover")
	if is_instance_valid(_panel):
		_layer.remove_child(_panel)
		_panel.queue_free()
	_panel = PanelContainer.new()
	_panel.name = "SpellHoverCard"
	_panel.custom_minimum_size.x = 360
	_panel.add_theme_stylebox_override("panel", CardSkin.frame(true))
	_layer.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	P.icon(header, spell.icon, 54)
	var title := P.label(header, spell.spell_name, 22)
	title.custom_minimum_size.x = 275
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	P.label(
		box,
		"%d PA   ·   Portée %s" % [actor.get_spell_ap_cost(spell), Text.range_text(spell, actor)],
		19,
	)
	P.label(box, "Ligne de vue requise" if spell.needs_line_of_sight else "Sans ligne de vue", 15)
	var impact: Array[String] = []
	if spell.deals_damage():
		impact.append("%d dégâts avant défenses" % spell.get_scaled_damage(actor))
	if spell.get_scaled_shield(actor) > 0:
		impact.append("%d garde" % spell.get_scaled_shield(actor))
	if spell.get_scaled_heal(actor) > 0:
		impact.append("%d soin de base" % spell.get_scaled_heal(actor))
	if not impact.is_empty():
		P.label(box, " · ".join(impact), 18)
	var effect := RichTextLabel.new()
	effect.name = "SpellHoverEffects"
	effect.bbcode_enabled = true
	effect.fit_content = true
	effect.scroll_active = false
	effect.custom_minimum_size.x = 344
	effect.add_theme_font_override("normal_font", CardSkin.FONT)
	effect.add_theme_font_size_override("normal_font_size", 17)
	var description := spell.description
	if str(spell.spell_id).begins_with("class_") and "\n" in description:
		description = description.substr(description.find("\n") + 1)
	var class_spell := str(spell.spell_id).begins_with("class_")
	effect.text = "[color=#a8ebd5][b]%s[/b][/color]\n%s" % [
		_escape(P.rule(spell) if class_spell else "Effets"),
		_escape(description) if class_spell else CombatGlossary.render_keywords(description),
	]
	box.add_child(effect)
	if str(spell.spell_id).begins_with("class_"):
		var explanation := _effect_explanation()
		if not explanation.is_empty():
			P.label(box, explanation, 15).modulate = Color("a8ebd5")
	if not context.is_empty():
		P.label(box, context, 15).modulate = Color("ffe0a0")
	_ignore_pointer(_panel)
	_panel.reset_size()
	_place()
	set_process(true)


func _effect_explanation() -> String:
	var row := preload("res://core/expedition/class_card_catalog.gd").row(
		str(spell.spell_id).trim_prefix("class_")
	)
	if row.is_empty():
		return ""
	match str(row[7]):
		"mark", "marked":
			return "Marque : permet aux techniques qui l'exploitent de déclencher leur bonus. Elle ne donne aucun bonus de dégâts à elle seule."
		"slow", "frost", "ice_area":
			return "Ralenti : la cible dispose de 1 PM de moins à son prochain tour."
		"guard", "guarded":
			return "Garde : absorbe les dégâts avant les PV, puis expire selon sa durée."
		"bleed", "burn":
			return "Dégâts périodiques : appliqués au début des tours de la cible. Leur puissance est fixée au lancement."
		"weaken":
			return "Prouesse : la statistique qui renforce les techniques. La réduire affaiblit les effets qui en dépendent."
		"move":
			return "Déplacement du lanceur : choisissez une case libre dans la portée affichée."
	return ""


func _process(_delta: float) -> void:
	if not anchor.is_visible_in_tree():
		_hide()
		return
	_ignore_pointer(_panel)
	_place()


func _place() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var rect := anchor.get_global_rect()
	var bounds := exclusion.get_global_rect() if is_instance_valid(exclusion) else rect
	var extent := _panel.get_combined_minimum_size()
	# Autowrapped text settles after the first layout. Shrink the actual panel too,
	# otherwise its initial height can remain much larger than its current minimum.
	_panel.size = extent
	var desired := Vector2(rect.get_center().x - extent.x / 2, bounds.position.y - extent.y - 12)
	if desired.y < 8 or exclusion is ScrollContainer:
		desired = Vector2(bounds.end.x + 12, bounds.position.y)
		if desired.x + extent.x > viewport.x - 8:
			desired.x = bounds.position.x - extent.x - 12
	desired.x = clampf(desired.x, 8, maxf(8, viewport.x - extent.x - 8))
	desired.y = clampf(desired.y, 8, maxf(8, viewport.y - extent.y - 8))
	_panel.position = desired


static func _ignore_pointer(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_pointer(child)


static func _escape(value: String) -> String:
	return value.replace("[", "[lb]")
