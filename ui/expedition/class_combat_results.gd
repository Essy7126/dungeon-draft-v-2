extends VBoxContainer
## Immutable reward receipt: independent from current inventory, sales and equips.
signal deck_requested
signal inventory_requested
const P := preload("res://ui/expedition/class_card_presentation.gd")
const Catalog := preload("res://core/expedition/class_card_catalog.gd")
const LootIcon := preload("res://ui/expedition/class_loot_icon.gd")
const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")
var session: ExpeditionSession
var _detail: VBoxContainer


func _ready() -> void:
	name = "ClassCombatResults"
	session = GameManager.expedition
	add_theme_constant_override("separation", 18)
	var node := session.route.get_current_node()
	var receipt: Dictionary = session.cards.battle_results.get(str(node.id), { })
	var title := HBoxContainer.new()
	add_child(title)
	P.label(title, "VICTOIRE", 28).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var duration := ""
	if receipt.has("duration_seconds"):
		duration = "%02d:%02d · " % [
			int(receipt.duration_seconds) / 60,
			int(receipt.duration_seconds) % 60,
		]
	P.label(
		title,
		duration
		+ (
			"%d tours" % int(receipt.turns) if int(receipt.get("turns", 0)) > 0 else "Combat terminé"
		),
		18,
	)
	P.label(self, str(node.title) + " · Gains conservés pour cette run", 18)
	var discovery: Dictionary = receipt.get("card_discovery", {})
	if not discovery.is_empty():
		var found: int = receipt.get("card_families", []).size()
		var echo := P.label(self, "Résonance des échos : %d · %d carte%s trouvée%s · ajout en réserve" % [int(discovery.resonance), found, "s" if found != 1 else "", "s" if found != 1 else ""], 16)
		echo.name = "CardDiscoverySummary"
		echo.mouse_filter = Control.MOUSE_FILTER_STOP
		var chances: Array[String] = []
		for chance in discovery.chances: chances.append("%d %%" % int(chance))
		echo.tooltip_text = "Résonance = 10 + profondeur (%d) + danger (%d) + mémoire des combats sans carte (%d).\nJets indépendants : %s. Chaque jet réussi donne une carte. Aucun gain garanti.\nUne victoire sans carte ajoute 15 de mémoire (maximum 45) ; trouver une carte remet cette mémoire à zéro.\nLa Résonance favorise aussi les raretés débloquées : rare dès le palier 4, épique dès le palier 10.\nLes objets gardent leurs propres règles de butin." % [int(discovery.exploration), int(discovery.danger), int(discovery.memory), " / ".join(chances)]
	var headings := HBoxContainer.new()
	add_child(headings)
	for entry in [
		["PERSONNAGE", 210],
		["NIVEAU", 115],
		["XP GAGNÉE", 130],
		["OBOLES", 100],
		["BUTIN REÇU", 100],
	]:
		var heading := P.label(headings, entry[0], 14)
		heading.custom_minimum_size.x = entry[1]
		heading.modulate = Color("cfbf9d")
	var row_panel := PanelContainer.new()
	add_child(row_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("203c3c")
	style.set_content_margin_all(12)
	style.set_corner_radius_all(5)
	row_panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row_panel.add_child(row)
	row.add_theme_constant_override("separation", 8)
	var hero := HBoxContainer.new()
	hero.custom_minimum_size.x = 198
	row.add_child(hero)
	var appearance := CharacterHUDThemeCatalog.resolve_refined(session.character.unit)
	var portrait: Texture2D = appearance.portrait_texture if appearance != null else null
	P.icon(hero, portrait if portrait != null else Catalog.icon(session.cards.primary_class), 48)
	P.label(
		hero,
		"%s\n%s"
		% [session.character.unit.unit_name, Catalog.CLASSES[session.cards.primary_class][0]],
		17,
	)
	var level := VBoxContainer.new()
	level.custom_minimum_size.x = 115
	row.add_child(level)
	var after := int(
		receipt.get("level_after", session.character.champion_progression.current_level)
	)
	var before := int(receipt.get("level_before", after))
	P.label(level, str(after) if before == after else "%d → %d" % [before, after], 20)
	var progress := ProgressBar.new()
	level.add_child(progress)
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(100, 9)
	var profile := session.character.champion_progression.profile
	var lower := profile.xp_for_level(after)
	var upper := profile.xp_for_level(mini(after + 1, profile.level_cap))
	progress.max_value = maxi(1, upper - lower)
	progress.value = int(receipt.get("xp_after", session.character.champion_progression.current_xp)) - lower
	var xp := P.label(row, "+%d XP" % int(receipt.xp) if receipt.has("xp") else "—", 20)
	xp.custom_minimum_size.x = 130
	var gold := P.label(row, "+%d" % int(receipt.gold) if receipt.has("gold") else "—", 20)
	gold.custom_minimum_size.x = 100
	gold.modulate = Color("ffe0a0")
	var loot := HFlowContainer.new()
	loot.name = "ReceivedLootIcons"
	loot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(loot)
	var records := records_for(session)
	for record in records:
		var tile := LootIcon.new()
		tile.name = "LootReceipt_" + str(record.id)
		tile.configure(
			record.title,
			record.icon,
			record.body,
			record.count,
			record.get("rarity", "common"),
			record.get("kind", ""),
		)
		loot.add_child(tile)
		tile.pressed.connect(
			func():
				_inspect(record),
		)
		tile.focus_entered.connect(
			func():
				_inspect(record),
		)
	P.label(
		self,
		"Survolez pour lire les effets ; cliquez pour garder la fiche ouverte. C : carte · R : rune · I–III : palier d'équipement. Le butin n'est jamais équipé automatiquement.",
		16,
	)
	var defeated := HFlowContainer.new()
	add_child(defeated)
	P.label(defeated, "VAINCUS   ", 14).modulate = Color("cfbf9d")
	var enemies: Dictionary = receipt.get("enemies", { })
	if enemies.is_empty():
		P.label(defeated, "Rencontre terminée", 16)
	for enemy in enemies:
		P.label(defeated, "%s ×%d    " % [enemy, int(enemies[enemy])], 16)
	if receipt.has("damage_dealt"):
		P.label(
			self,
			"%d dégâts infligés    ·    %d dégâts subis    ·    %d garde créée"
			% [
				int(receipt.damage_dealt),
				int(receipt.get("damage_taken", 0)),
				int(receipt.get("shield", 0)),
			],
			16,
		)
	var detail_panel := PanelContainer.new()
	add_child(detail_panel)
	detail_panel.add_theme_stylebox_override("panel", CardSkin.frame())
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size.y = 110
	detail_panel.add_child(_detail)
	detail_panel.hide()
	var actions := HBoxContainer.new()
	add_child(actions)
	_action(
		actions,
		"Mon deck · cartes et effets",
		func():
			deck_requested.emit(),
	)
	_action(
		actions,
		"Inventaire · équiper ou vendre",
		func():
			inventory_requested.emit(),
	)
	if not session.cards.pending_items.is_empty():
		P.label(
			self,
			"%d objet(s) en attente : faites de la place dans l'inventaire, puis récupérez-les depuis le sac."
			% session.cards.pending_items.size(),
			17,
		)


func _action(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	CardSkin.action(button)
	button.add_theme_font_size_override("font_size", 17)
	parent.add_child(button)
	button.pressed.connect(callback)


func _inspect(record: Dictionary) -> void:
	for tile in find_children("LootReceipt_*", "Button", true, false):
		tile.set_marked(tile.name == "LootReceipt_" + str(record.id))
	_detail.get_parent().show()
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var header := HBoxContainer.new()
	_detail.add_child(header)
	P.icon(header, record.icon, 58)
	P.label(header, record.title + " · ×%d" % record.count, 22)
	P.label(_detail, record.body, 17).name = "SelectedLootDescription"
	var ancestor := get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer:
		_reveal_detail(ancestor)


func _reveal_detail(scroll: ScrollContainer) -> void:
	# Wait for wrapped text and the scroll range to settle after opening the pane.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(scroll) or not is_instance_valid(_detail):
		return
	scroll.scroll_vertical += roundi(_detail.global_position.y - scroll.global_position.y) - 8


static func records_for(s: ExpeditionSession) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var node_id := s.route.current_node_id
	var receipt: Dictionary = s.cards.battle_results.get(node_id, { })
	var families: Array = receipt.get("card_families", []).duplicate()
	if families.is_empty():
		for id in s.cards.receipts.get(node_id, []):
			var copy: Dictionary = s.cards.copy_for(id)
			if not copy.is_empty():
				families.append(copy.family)
	var counts := { }
	for id in families:
		counts[id] = int(counts.get(id, 0)) + 1
	for id in s.cards.loot_items.get(node_id, []):
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		var spell: Spell = s.cards.family_spell(id)
		if spell != null:
			records.append(
				{
					"id": id,
					"title": spell.spell_name,
					"icon": spell.icon,
					"count": counts[id],
					"kind": "C",
					"rarity": ["common", "common", "rare", "epic"][Catalog.Ecology.tier(id)],
					"body": (
						"CARTE DE VOTRE CLASSE" if Catalog.row(id)[1] == s.cards.primary_class else "CARTE ÉTRANGÈRE · Utilisable dès maintenant"
					)
					+ " · Réserve\n"
					+ preload("res://ui/expedition/catabase_card_text.gd").details(
						spell,
						s.character.unit,
					),
				}
			)
		else:
			var item := s.card_inventory.get_catalog().get_definition(StringName(id))
			if item != null:
				records.append(
					{
						"id": id,
						"title": item.display_name,
						"icon": item.icon,
						"count": counts[id],
						"rarity": str(item.rarity),
						"kind": P.item_badge(item),
						"body": "OBJET · Butin acquis\n" + P.item_description(item),
					}
				)
	return records
