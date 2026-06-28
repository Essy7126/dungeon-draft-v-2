# battle/energy_draft_controller.gd
# ============================================================
# ENERGY DRAFT CONTROLLER — overlay de choix d'énergie (Rage / Foi)
# affiché avant le combat.
#
# Extrait de battle.gd par COMPOSITION (pas un autoload) : battle.gd instancie
# ce contrôleur, l'ajoute à l'arbre, appelle start(heroes), puis enchaîne sur
# le combat quand le signal draft_completed est émis.
#
# ÉTAT PAR-COMBAT : ce contrôleur est créé à chaque combat et son overlay est
# libéré dès la fin du draft. Aucun état ne survit entre deux combats — d'où
# l'absence volontaire d'autoload (qui aurait imposé un reset manuel).
# ============================================================

class_name EnergyDraftController
extends Node

# Chemins des ressources d'énergie proposées au draft.
const PATH_RAGE := "res://data/energy/rage.tres"
const PATH_FOI  := "res://data/energy/foi.tres"

# Émis quand le draft est terminé : soit tous les héros ont choisi, soit aucun
# draft n'était nécessaire (pas de héros à énergie, ressources introuvables).
# battle.gd écoute ce signal pour lancer le combat.
signal draft_completed

var _draft_ui: CanvasLayer = null
var _draft_choices: Dictionary = {}   # Unit → EnergyTypeData
var _draft_pending: int = 0           # nombre de héros n'ayant pas encore choisi

# Lance la phase de draft pour la liste de héros fournie.
# Si rien n'est à drafter (liste vide, aucun héros à énergie, ressources
# introuvables), émet draft_completed immédiatement sans afficher d'overlay.
func start(heroes: Array) -> void:
	var any_has_energy := false
	for h in heroes:
		if h.has_energy():
			any_has_energy = true
			break

	if heroes.is_empty() or not any_has_energy:
		draft_completed.emit()
		return

	var rage_res: EnergyTypeData = load(PATH_RAGE) as EnergyTypeData
	var foi_res: EnergyTypeData  = load(PATH_FOI)  as EnergyTypeData
	if rage_res == null or foi_res == null:
		push_warning("Draft : rage.tres ou foi.tres introuvable. Combat sans draft.")
		draft_completed.emit()
		return

	_build_overlay(heroes, rage_res, foi_res)

func _build_overlay(heroes: Array, rage_res: EnergyTypeData, foi_res: EnergyTypeData) -> void:
	_draft_ui = CanvasLayer.new()
	add_child(_draft_ui)
	_draft_pending = heroes.size()

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	_draft_ui.add_child(bg)

	var title := Label.new()
	title.text = "Choisissez l'énergie de vos champions"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.15
	title.anchor_bottom = 0.25
	_draft_ui.add_child(title)

	var slot_width  := 200
	var total_width := heroes.size() * slot_width + (heroes.size() - 1) * 24
	var start_x     := -total_width / 2

	for i in heroes.size():
		var hero: Unit = heroes[i]
		var slot := VBoxContainer.new()
		slot.anchor_left   = 0.5
		slot.anchor_right  = 0.5
		slot.anchor_top    = 0.3
		slot.anchor_bottom = 0.75
		slot.offset_left   = start_x + i * (slot_width + 24)
		slot.offset_right  = start_x + i * (slot_width + 24) + slot_width
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_theme_constant_override("separation", 12)
		_draft_ui.add_child(slot)

		var name_lbl := Label.new()
		name_lbl.text = hero.unit_name
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(name_lbl)

		var rage_btn := Button.new()
		rage_btn.text = "⚔ Rage"
		rage_btn.add_theme_font_size_override("font_size", 16)
		rage_btn.custom_minimum_size = Vector2(slot_width, 48)
		rage_btn.modulate = Color(1.0, 0.45, 0.1)
		rage_btn.pressed.connect(_on_draft_choice.bind(hero, rage_res))
		slot.add_child(rage_btn)

		var foi_btn := Button.new()
		foi_btn.text = "✦ Foi"
		foi_btn.add_theme_font_size_override("font_size", 16)
		foi_btn.custom_minimum_size = Vector2(slot_width, 48)
		foi_btn.modulate = Color(0.4, 0.7, 1.0)
		foi_btn.pressed.connect(_on_draft_choice.bind(hero, foi_res))
		slot.add_child(foi_btn)

func _on_draft_choice(hero: Unit, energy: EnergyTypeData) -> void:
	hero.energy_type    = energy
	hero.current_energy = energy.start_energy
	hero.ensure_energy_traits()
	hero.reset_combat_resources()
	_draft_choices[hero] = energy
	DebugLogger.info(DebugLogger.LogCategory.COMBAT,
		"Draft : %s → %s" % [hero.unit_name, energy.energy_name])
	_draft_pending -= 1
	if _draft_pending <= 0:
		_finish()

func _finish() -> void:
	if is_instance_valid(_draft_ui):
		_draft_ui.queue_free()
	_draft_ui = null
	draft_completed.emit()
