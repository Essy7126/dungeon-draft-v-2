# battle/deployment_controller.gd
# ============================================================
# DEPLOYMENT CONTROLLER — phase de placement manuel des héros (façon Dofus),
# AVANT le démarrage du combat.
#
# Flux : les cases de hero_spawn_zone s'illuminent → le joueur clique pour poser
# chaque héros (ordre imposé) → quand tous sont placés, deployment_completed est
# émis et battle.gd lance le combat. Un label indique qui placer ; un bouton
# "Annuler" reprend le dernier héros posé.
#
# Extrait de battle.gd par COMPOSITION. battle.gd reste le chef d'orchestre : il
# appelle start() après le spawn des ennemis, route les clics via on_cell_clicked()
# tant que is_active() est vrai, et enchaîne sur le combat au signal
# deployment_completed.
#
# Couplage assumé via la référence-retour `_battle` : le déploiement est tissé
# dans le cycle de vie des unités (placement, vues, signaux died, liste units).
# Les primitives partagées avec le spawn ennemi (_place, _resolve_spawn_cell,
# _on_unit_died) RESTENT dans battle.gd ; ce contrôleur n'orchestre que la phase
# de placement et son UI.
#
# ÉTAT PAR-COMBAT : recréé avec la scène de combat, libère son UI à la fin.
# ============================================================

class_name DeploymentController
extends Node

# Émis quand la phase de déploiement est terminée : placement manuel fini,
# secours auto, ou aucun héros à placer. battle.gd écoute pour lancer le combat.
signal deployment_completed

var _battle = null

var _deploying: bool = false
var _heroes_to_place: Array = []        # héros restant à placer (ordre imposé)
var _deploy_zone: Array = []            # toutes les cases de placement valides
var _deployed: Array = []               # historique : [{ "unit":Unit, "cell":Vector2i }]
var _deploy_ui: CanvasLayer = null      # label + bouton "Annuler" pendant la phase
var _deploy_label: Label = null

func setup(battle) -> void:
	_battle = battle

# Le déploiement est-il en cours ? (battle.gd route les clics ici si oui)
func is_active() -> bool:
	return _deploying

# Démarre la phase de déploiement. On ne place RIEN tant que le joueur n'a pas
# cliqué : le combat ne démarre qu'à l'émission de deployment_completed.
func start() -> void:
	# Héros à placer (vivants, empruntés au GameManager), dans l'ordre.
	_heroes_to_place = GameManager.get_living_heroes().duplicate()
	_deployed = []

	# Zone de placement : on ne garde que les cases réellement utilisables.
	var zone: Array = []
	if _battle.room_data != null and _battle.room_data.hero_spawn_zone.size() > 0:
		zone = _battle.room_data.hero_spawn_zone.duplicate()
	else:
		zone = [Vector2i(2, 6), Vector2i(2, 8)]

	_deploy_zone = []
	for cell in zone:
		if _battle.grid.is_valid(cell) and _battle.grid.is_walkable(cell):
			_deploy_zone.append(cell)

	# Cas dégénéré : aucun héros, ou pas assez de cases pour les placer.
	# On ne reste pas coincé : on prévient et on enchaîne sur le combat.
	if _heroes_to_place.is_empty():
		push_warning("Déploiement : aucun héros à placer.")
		deployment_completed.emit()
		return
	if _deploy_zone.size() < _heroes_to_place.size():
		push_warning("Déploiement : pas assez de cases (%d) pour %d héros. Placement auto de secours." \
				% [_deploy_zone.size(), _heroes_to_place.size()])
		_deploy_fallback_auto()
		return

	_deploying = true
	_build_deploy_ui()
	_refresh_deploy()

# --- Secours : si la zone est trop petite, on place automatiquement. ---
# Garantit qu'on n'a JAMAIS un combat sans héros (sinon boucle infinie).
func _deploy_fallback_auto() -> void:
	var pool = _deploy_zone.duplicate()
	for hero in _heroes_to_place:
		hero.current_ap = hero.max_ap.get_int()
		hero.current_mp = hero.max_mp.get_int()
		var cell = _battle._resolve_spawn_cell(pool, hero.unit_name)
		if cell == Vector2i(-1, -1):
			continue
		_battle._place(hero, cell)
		_battle.units.append(hero)
	_heroes_to_place = []
	deployment_completed.emit()

# --- Rafraîchit l'affichage : cases libres illuminées + label. ---
func _refresh_deploy() -> void:
	_highlight_deploy_zone()
	_update_deploy_label()

# Illumine en bleu les cases de déploiement encore libres.
func _highlight_deploy_zone() -> void:
	_battle.grid_view.clear_highlights()
	var free_cells: Array = []
	for cell in _deploy_zone:
		if not _battle.grid.has_unit(cell):
			free_cells.append(cell)
	_battle.grid_view.highlight(free_cells, _battle.SPELL_COLOR)

# Appelé par battle.gd quand le joueur clique une case pendant le déploiement.
func on_cell_clicked(cell: Vector2i) -> void:
	if _heroes_to_place.is_empty():
		return
	# La case doit appartenir à la zone et être libre.
	if not _deploy_zone.has(cell):
		return
	if _battle.grid.has_unit(cell):
		return

	# Place le héros courant (ordre imposé : le premier de la liste).
	var hero = _heroes_to_place.pop_front()
	hero.current_ap = hero.max_ap.get_int()
	hero.current_mp = hero.max_mp.get_int()
	_battle._place(hero, cell)
	_battle.units.append(hero)
	_deployed.append({ "unit": hero, "cell": cell })

	# Tous placés ? On termine. Sinon on passe au suivant.
	if _heroes_to_place.is_empty():
		_end_deployment()
	else:
		_refresh_deploy()

# --- Annule le dernier placement (bouton "Annuler"). ---
func _undo_last_deploy() -> void:
	if _deployed.is_empty():
		return
	var last = _deployed.pop_back()
	var hero: Unit = last["unit"]
	var cell: Vector2i = last["cell"]

	# On retire le héros de la grille, de la vue et de la liste des unités.
	_battle.grid.clear_unit(cell)
	if hero.died.is_connected(_battle._on_unit_died):
		hero.died.disconnect(_battle._on_unit_died)
	var view = _battle._unit_views.get(hero)
	if is_instance_valid(view):
		view.queue_free()
	_battle._unit_views.erase(hero)
	_battle.units.erase(hero)

	# Le héros repasse en tête de file (il sera le prochain à placer).
	_heroes_to_place.push_front(hero)
	_refresh_deploy()

func _end_deployment() -> void:
	_deploying = false
	_battle.grid_view.clear_highlights()
	_destroy_deploy_ui()
	deployment_completed.emit()

# ============================================================
# UI DE DÉPLOIEMENT (label + bouton Annuler, construits en code)
# Volontairement simple. Plus tard, ça pourra devenir une vraie scène.
# ============================================================

func _build_deploy_ui() -> void:
	_deploy_ui = CanvasLayer.new()
	add_child(_deploy_ui)

	var panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = 16
	_deploy_ui.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_deploy_label = Label.new()
	_deploy_label.add_theme_font_size_override("font_size", 20)
	_deploy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_deploy_label)

	var hint = Label.new()
	hint.text = "Cliquez une case bleue pour placer ce héros."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hint)

	var undo_btn = Button.new()
	undo_btn.text = "Annuler le dernier placement"
	undo_btn.pressed.connect(_undo_last_deploy)
	vbox.add_child(undo_btn)

func _update_deploy_label() -> void:
	if _deploy_label == null:
		return
	if _heroes_to_place.is_empty():
		_deploy_label.text = ""
		return
	var hero = _heroes_to_place[0]
	var total = GameManager.get_living_heroes().size()
	var current = total - _heroes_to_place.size() + 1
	_deploy_label.text = "Placez : %s  (%d/%d)" % [hero.unit_name, current, total]

func _destroy_deploy_ui() -> void:
	if is_instance_valid(_deploy_ui):
		_deploy_ui.queue_free()
	_deploy_ui = null
	_deploy_label = null
