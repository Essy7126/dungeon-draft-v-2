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

const COMBAT_HIGHLIGHT_MARKER := preload(
	"res://battle/combat_highlight_marker.gd"
)

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
	var known_cells := {}
	for cell in zone:
		if known_cells.has(cell):
			continue
		known_cells[cell] = true
		if _battle.grid.is_valid(cell) \
				and _battle.grid.is_walkable(cell) \
				and not _battle.grid.has_unit(cell):
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
# La zone de héros reste prioritaire, puis le secours s'étend à toute case libre
# de la grille. Le combat ne peut démarrer que si chaque héros a réellement été
# enregistré dans GridData.
func _deploy_fallback_auto() -> void:
	var pool := _build_fallback_pool()
	if pool.size() < _heroes_to_place.size():
		push_error(
			"Déploiement : capacité totale insuffisante (%d case(s) pour %d héros)." \
					% [pool.size(), _heroes_to_place.size()]
		)
		# Aucun placement n'a encore été effectué. Rendre la main à Battle lui
		# permet d'appliquer son contrat terminal « zéro héros = défaite » au lieu
		# de laisser la partie suspendue dans une phase de déploiement impossible.
		deployment_completed.emit()
		return

	while not _heroes_to_place.is_empty():
		var hero = _heroes_to_place[0]
		hero.current_ap = hero.max_ap.get_int()
		hero.current_mp = hero.max_mp.get_int()
		var cell = _battle._resolve_spawn_cell(pool, hero.unit_name)
		if cell == Vector2i(-1, -1):
			push_error(
				"Déploiement : aucune case de secours pour %s." % hero.unit_name
			)
			return
		if not _battle._place(hero, cell) \
				or _battle.grid.get_unit(cell) != hero:
			push_error(
				"Déploiement : placement de secours refusé pour %s." % hero.unit_name
			)
			_abort_fallback_to_terminal_outcome()
			return
		if not _battle.units.has(hero):
			_battle.units.append(hero)
		_deployed.append({ "unit": hero, "cell": cell })
		_heroes_to_place.pop_front()
	deployment_completed.emit()


func _abort_fallback_to_terminal_outcome() -> void:
	# Un échec inattendu après un placement partiel ne doit ni démarrer avec une
	# équipe tronquée, ni laisser la phase active sans issue. On remet la grille
	# dans son état pré-déploiement ; Battle constatera alors zéro héros.
	for deployment in _deployed:
		var hero := deployment.get("unit") as Unit
		var cell := deployment.get("cell", Vector2i(-1, -1)) as Vector2i
		if _battle.grid.get_unit(cell) == hero:
			_battle.grid.clear_unit(cell)
		if hero != null and hero.died.is_connected(_battle._on_unit_died):
			hero.died.disconnect(_battle._on_unit_died)
		var view = _battle._unit_views.get(hero)
		if is_instance_valid(view):
			view.queue_free()
		_battle._unit_views.erase(hero)
		_battle.units.erase(hero)
	_deployed.clear()
	deployment_completed.emit()


func _build_fallback_pool() -> Array:
	var result: Array = []
	var known_cells := {}
	for cell in _deploy_zone:
		if known_cells.has(cell) or not _battle.grid.is_walkable(cell):
			continue
		known_cells[cell] = true
		result.append(cell)
	for y in _battle.grid.rows:
		for x in _battle.grid.cols:
			var cell := Vector2i(x, y)
			if known_cells.has(cell) or not _battle.grid.is_walkable(cell):
				continue
			known_cells[cell] = true
			result.append(cell)
	return result

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
	_battle.grid_view.highlight(
		free_cells,
		_battle.SPELL_COLOR,
		COMBAT_HIGHLIGHT_MARKER.DEPLOYMENT,
	)

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
	var hero = _heroes_to_place[0]
	hero.current_ap = hero.max_ap.get_int()
	hero.current_mp = hero.max_mp.get_int()
	if not _battle._place(hero, cell):
		push_error(
			"Déploiement : placement manuel refusé pour %s." % hero.unit_name
		)
		_refresh_deploy()
		return
	_heroes_to_place.pop_front()
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
