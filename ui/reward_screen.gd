# ui/reward_screen.gd
# ============================================================
# REWARD SCREEN — Écran de choix de récompense (après un combat gagné).
# Affiche 3 récompenses proposées par le GameManager. Le joueur en
# choisit une ; si elle cible un héros précis (CHOICE), une 2e étape
# demande lequel. Puis on rend la main au GameManager, qui applique
# et enchaîne sur la salle suivante.
#
# Construit entièrement en code (comme action_bar). Plus tard, ça
# pourra devenir une vraie scène visuelle avec assets/thème.
# ============================================================

extends Control

var _offered: Array = []
var _content: VBoxContainer
var _dynamic: VBoxContainer   # zone re-remplie selon l'étape (cartes / héros)

func _ready() -> void:
	_offered = GameManager.get_offered_rewards()
	_build_base()
	_show_reward_cards()

# ============================================================
# STRUCTURE DE BASE (fond + titre + zone dynamique)
# ============================================================

func _build_base() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Fond sombre plein écran.
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Conteneur central.
	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_CENTER)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 28)
	add_child(_content)

	var title = Label.new()
	title.text = "Choisis une récompense"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	# Zone dynamique (cartes de récompense, puis choix du héros).
	_dynamic = VBoxContainer.new()
	_dynamic.alignment = BoxContainer.ALIGNMENT_CENTER
	_dynamic.add_theme_constant_override("separation", 20)
	_content.add_child(_dynamic)

# ============================================================
# ÉTAPE 1 — LES CARTES DE RÉCOMPENSE
# ============================================================

func _show_reward_cards() -> void:
	_clear_dynamic()

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_dynamic.add_child(row)

	if _offered.is_empty():
		var none = Label.new()
		none.text = "(Aucune récompense disponible)"
		_dynamic.add_child(none)
		var skip = Button.new()
		skip.text = "Continuer →"
		skip.pressed.connect(func(): GameManager.choose_reward(null))
		_dynamic.add_child(skip)
		return

	for reward in _offered:
		row.add_child(_make_card(reward))

func _make_card(reward: RewardData) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(230, 170)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var label = reward.reward_name
	if reward.description != "":
		label += "\n\n" + reward.description
	# Petit indice de cible.
	label += "\n\n" + _target_hint(reward)
	btn.text = label

	if reward.icon != null:
		btn.icon = reward.icon
		btn.expand_icon = true
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

	# Teinte selon la rareté (commune / rare / épique).
	match reward.rarity:
		1: btn.modulate = Color(0.6, 0.8, 1.0)
		2: btn.modulate = Color(0.85, 0.6, 1.0)

	btn.pressed.connect(func(): _on_reward_chosen(reward))
	return btn

func _target_hint(reward: RewardData) -> String:
	match reward.target:
		RewardData.Target.ALL:        return "[Toute l'équipe]"
		RewardData.Target.LOWEST_HP:  return "[Le plus blessé]"
		RewardData.Target.HIGHEST_HP: return "[Le plus en forme]"
		RewardData.Target.CHOICE:     return "[Au choix]"
	return ""

func _on_reward_chosen(reward: RewardData) -> void:
	if reward.needs_hero_choice():
		_show_hero_choice(reward)
	else:
		GameManager.choose_reward(reward)

# ============================================================
# ÉTAPE 2 — CHOIX DU HÉROS (récompenses à cible CHOICE)
# ============================================================

func _show_hero_choice(reward: RewardData) -> void:
	_clear_dynamic()

	var prompt = Label.new()
	prompt.text = "Appliquer « %s » à quel héros ?" % reward.reward_name
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dynamic.add_child(prompt)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_dynamic.add_child(row)

	for hero in GameManager.get_living_heroes():
		var b = Button.new()
		b.custom_minimum_size = Vector2(170, 90)
		b.text = "%s\n%d PV" % [hero.unit_name, hero.current_hp]
		b.pressed.connect(func(): GameManager.choose_reward(reward, hero))
		row.add_child(b)

	var back = Button.new()
	back.text = "← Retour"
	back.pressed.connect(_show_reward_cards)
	_dynamic.add_child(back)

# ============================================================
# OUTILS
# ============================================================

# Vide la zone dynamique immédiatement (retire du layout + libère).
func _clear_dynamic() -> void:
	for child in _dynamic.get_children():
		_dynamic.remove_child(child)
		child.queue_free()
