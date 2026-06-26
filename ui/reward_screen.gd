# ui/reward_screen.gd
# Screen de choix de recompense entre deux salles.
extends Control

var _offered: Array = []
var _content: VBoxContainer
var _dynamic: VBoxContainer

func _ready() -> void:
	_offered = GameManager.get_offered_rewards()
	_build_base()
	_show_reward_cards()

func _build_base() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.018, 0.025, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_CENTER)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 26)
	add_child(_content)

	var title := Label.new()
	title.text = "Choisis une recompense"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	_dynamic = VBoxContainer.new()
	_dynamic.alignment = BoxContainer.ALIGNMENT_CENTER
	_dynamic.add_theme_constant_override("separation", 18)
	_content.add_child(_dynamic)

func _show_reward_cards() -> void:
	_clear_dynamic()

	if _offered.is_empty():
		var none := Label.new()
		none.text = "Aucune recompense disponible."
		_dynamic.add_child(none)
		_add_skip_button("Continuer")
		return

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_dynamic.add_child(row)

	for reward in _offered:
		row.add_child(_make_card(reward))

	_add_skip_button("Refuser et continuer")

func _make_card(reward: RewardData) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(285, 225)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.tooltip_text = _reward_tooltip(reward)

	var lines: Array = [reward.reward_name]
	var summary := _effect_summary(reward)
	if summary != "":
		lines.append(summary)
	if reward.description.strip_edges() != "":
		lines.append(reward.description.strip_edges())
	lines.append(_target_hint(reward))
	btn.text = "\n\n".join(lines)

	if reward.icon != null:
		btn.icon = reward.icon
		btn.expand_icon = true
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

	match reward.rarity:
		1:
			btn.modulate = Color(0.70, 0.86, 1.0)
		2:
			btn.modulate = Color(0.92, 0.72, 1.0)

	btn.pressed.connect(func(): _on_reward_chosen(reward))
	return btn

func _add_skip_button(label: String) -> void:
	var skip := Button.new()
	skip.text = label
	skip.custom_minimum_size = Vector2(220, 42)
	skip.tooltip_text = "Passe cette recompense et va a la salle suivante."
	skip.pressed.connect(func(): GameManager.choose_reward(null))
	_dynamic.add_child(skip)

func _effect_summary(reward: RewardData) -> String:
	var parts: Array = []
	if reward.spell != null:
		parts.append("Nouveau sort: %s" % reward.spell.spell_name)
	if reward.trait_data != null:
		parts.append("Trait: %s" % reward.trait_data.display_name)
	if reward.heal_amount > 0:
		parts.append("Soin immediat: +%d PV" % reward.heal_amount)
	if reward.stat != RewardData.StatKind.NONE:
		parts.append("Bonus: %s %s" % [_stat_label(reward.stat), _amount_label(reward.stat_amount, reward.stat_is_percent)])
	if reward.malus_stat != RewardData.StatKind.NONE:
		parts.append("Contrecoup: %s %s" % [_stat_label(reward.malus_stat), _amount_label(reward.malus_amount, reward.malus_is_percent)])
	if reward.status_effect != null:
		parts.append("Statut permanent: %s" % reward.status_effect.status_name)
	return "Effet: " + " | ".join(parts) if not parts.is_empty() else ""

func _amount_label(amount: float, percent: bool) -> String:
	if percent:
		return "%+.0f%%" % (amount * 100.0)
	return "%+.0f" % amount

func _stat_label(kind: int) -> String:
	match kind:
		RewardData.StatKind.MAX_HP:
			return "PV max"
		RewardData.StatKind.ATTACK:
			return "attaque"
		RewardData.StatKind.MAX_MP:
			return "PM max"
		RewardData.StatKind.MAX_AP:
			return "PA max"
		RewardData.StatKind.INITIATIVE:
			return "initiative"
	return "stat"

func _reward_tooltip(reward: RewardData) -> String:
	var text := reward.reward_name
	var summary := _effect_summary(reward)
	if summary != "":
		text += "\n" + summary
	if reward.description.strip_edges() != "":
		text += "\n" + reward.description.strip_edges()
	text += "\n" + _target_hint(reward)
	return text

func _target_hint(reward: RewardData) -> String:
	if reward.forced_unit_name.strip_edges() != "":
		return "Cible: %s" % reward.forced_unit_name
	match reward.target:
		RewardData.Target.ALL:
			return "Cible: toute l'equipe"
		RewardData.Target.LOWEST_HP:
			return "Cible: le plus blesse"
		RewardData.Target.HIGHEST_HP:
			return "Cible: le plus en forme"
		RewardData.Target.CHOICE:
			return "Cible: au choix"
	return ""

func _on_reward_chosen(reward: RewardData) -> void:
	if reward.needs_hero_choice():
		_show_hero_choice(reward)
	else:
		GameManager.choose_reward(reward)

func _show_hero_choice(reward: RewardData) -> void:
	_clear_dynamic()

	var prompt := Label.new()
	prompt.text = "Appliquer \"%s\" a quel heros ?" % reward.reward_name
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dynamic.add_child(prompt)

	var detail := Label.new()
	detail.text = _effect_summary(reward)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(620, 0)
	_dynamic.add_child(detail)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_dynamic.add_child(row)

	for hero in GameManager.get_living_heroes():
		var b := Button.new()
		b.custom_minimum_size = Vector2(185, 96)
		b.text = "%s\n%d PV" % [hero.unit_name, hero.current_hp]
		b.tooltip_text = "Appliquer cette recompense a %s." % hero.unit_name
		b.pressed.connect(func(): GameManager.choose_reward(reward, hero))
		row.add_child(b)

	var back := Button.new()
	back.text = "Retour"
	back.pressed.connect(_show_reward_cards)
	_dynamic.add_child(back)

func _clear_dynamic() -> void:
	for child in _dynamic.get_children():
		_dynamic.remove_child(child)
		child.queue_free()