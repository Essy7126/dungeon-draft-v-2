# battle/floating_text_spawner.gd
# ============================================================
# FLOATING TEXT SPAWNER — LE système de texte flottant du combat.
# Composant autonome : instancié par battle.tscn, il s'abonne à l'EventBus
# et ne connaît ni battle.gd ni unit.gd. (Les anciens petits popups de
# unit_view.gd ont été migrés ici — un seul système, pas deux.)
#
# Signal → texte :
#   fervor_gained            → « +12 » couleur d'école + verbe source dessous
#   damage_dealt             → « -15 » blanc (crit : rouge-orangé, plus gros)
#   unit_healed              → « +10 » vert clair
#   shield_gained            → « +20 » bleu-gris
#   attack_dodged            → « Esquive »
#   fervor_threshold_changed → nom du seuil (« Berserker ») couleur d'école
#
# Anti-chevauchement : les textes nés sur la même unité dans la même
# seconde s'empilent verticalement (STACK_STEP px) au lieu de se superposer.
# Performance : pool de scènes FloatingText réutilisées.
# ============================================================

extends Node2D

const FloatingTextScene := preload("res://battle/floating_text.tscn")

const BASE_OFFSET_Y := -52.0   # naissance au-dessus de la tête de l'unité
const STACK_STEP := 14.0       # décalage vertical entre textes simultanés
const STACK_WINDOW := 1.0      # fenêtre (s) pendant laquelle on empile
const FONT_SIZE := 14
const FONT_SIZE_CRIT := 20

const COLOR_DAMAGE := Color(0.96, 0.96, 0.96)
const COLOR_CRIT := Color(1.0, 0.42, 0.18)
const COLOR_HEAL := Color(0.55, 1.0, 0.62)
const COLOR_SHIELD := Color(0.62, 0.72, 0.86)
const COLOR_FALLBACK_ENERGY := Color(0.86, 0.74, 1.0)

# Verbe de gain_table → étiquette lisible par le joueur.
const VERB_LABELS := {
	"HIT": "frappe",
	"PROTECT": "protection",
	"HEAL": "soin",
	"EXPLOIT": "opportunité",
	"TAKE_DAMAGE": "endurance",
}

var _pool: Array = []
# unit → { "until": float (ticks ms), "count": int } pour l'empilement.
var _stacks: Dictionary = {}
var _battle_view: Node2D = null

func _ready() -> void:
	# Les vues d'unités vivent dans GridView, ajouté au root APRÈS nous :
	# on force le dessus de la pile de dessin.
	z_index = 100
	EventBus.fervor_gained.connect(_on_fervor_gained)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.unit_healed.connect(_on_unit_healed)
	EventBus.shield_gained.connect(_on_shield_gained)
	EventBus.attack_dodged.connect(_on_attack_dodged)
	EventBus.fervor_threshold_changed.connect(_on_threshold_changed)
	EventBus.battle_view_ready.connect(_register_battle_view)

func _register_battle_view(view: Node) -> void:
	_battle_view = view as Node2D

# --- Handlers EventBus ---

func _on_fervor_gained(unit, _energy_id: String, amount: float, source: String) -> void:
	if unit == null or amount <= 0.0:
		return
	var color: Color = unit.energy_type.get_school_color() if unit.has_energy() else COLOR_FALLBACK_ENERGY
	_spawn(unit, "+%d" % int(round(amount)), color, VERB_LABELS.get(source, ""))

func _on_damage_dealt(target, _attacker, amount: int, _category: int, _element: int, is_crit: bool) -> void:
	if target == null or amount <= 0:
		return
	if is_crit:
		_spawn(target, "-%d" % amount, COLOR_CRIT, "critique", FONT_SIZE_CRIT)
	else:
		_spawn(target, "-%d" % amount, COLOR_DAMAGE)

func _on_unit_healed(unit, amount: int) -> void:
	if unit == null or amount <= 0:
		return
	_spawn(unit, "+%d" % amount, COLOR_HEAL)

func _on_shield_gained(unit, amount: int) -> void:
	if unit == null or amount <= 0:
		return
	_spawn(unit, "+%d" % amount, COLOR_SHIELD, "bouclier")

func _on_attack_dodged(target, _attacker) -> void:
	if target == null:
		return
	_spawn(target, "Esquive", Color(0.85, 0.85, 0.7), "", 12)

func _on_threshold_changed(unit, active: bool) -> void:
	if unit == null or not active or not unit.has_energy():
		return
	_spawn(unit, unit.energy_type.threshold_name, unit.energy_type.get_school_color(), "", 16)

# --- Mécanique ---

func _spawn(unit, text: String, color: Color, source_text: String = "", font_size: int = FONT_SIZE) -> void:
	if not is_inside_tree():
		return
	var ft := _acquire()
	ft.position = _anchor_for(unit) + Vector2(0, -STACK_STEP * float(_stack_slot(unit)))
	ft.play(text, color, source_text, font_size)

# Position locale de la tete de l'unite. La vue d'unite est l'ancre de
# reference lorsqu'elle existe ; le facade de grille sert de repli. Aucune
# hypothese sur la taille ou la projection des cellules n'est faite ici.
func _anchor_for(unit) -> Vector2:
	if get_tree() != null:
		for candidate in get_tree().get_nodes_in_group("unit_views"):
			if candidate is Node2D and candidate.get("unit") == unit:
				if candidate.has_method("get_optional_visual"):
					var optional_visual = candidate.get_optional_visual()
					if is_instance_valid(optional_visual) \
							and optional_visual.has_method("get_popup_anchor"):
						return to_local(optional_visual.to_global(
							optional_visual.get_popup_anchor()
						))
				return to_local(candidate.to_global(Vector2(0.0, BASE_OFFSET_Y)))
	if is_instance_valid(_battle_view):
		var cell_local: Vector2
		if _battle_view.has_method("grid_to_local"):
			cell_local = _battle_view.grid_to_local(unit.grid_pos)
		else:
			cell_local = _battle_view.grid_to_world(unit.grid_pos)
		return to_local(_battle_view.to_global(cell_local) + Vector2(0.0, BASE_OFFSET_Y))
	return Vector2(0.0, BASE_OFFSET_Y)

# Rang d'empilement : 0 pour le premier texte, +1 par texte né sur la même
# unité dans la fenêtre STACK_WINDOW, remis à zéro ensuite.
func _stack_slot(unit) -> int:
	var now := Time.get_ticks_msec()
	var entry: Dictionary = _stacks.get(unit, {})
	if entry.is_empty() or now > int(entry.get("until", 0)):
		_stacks[unit] = { "until": now + int(STACK_WINDOW * 1000.0), "count": 1 }
		return 0
	var slot: int = int(entry["count"])
	entry["count"] = slot + 1
	entry["until"] = now + int(STACK_WINDOW * 1000.0)
	return slot

func _acquire() -> Node2D:
	var ft: Node2D
	if _pool.is_empty():
		ft = FloatingTextScene.instantiate()
		ft.finished.connect(_release)
		add_child(ft)
	else:
		ft = _pool.pop_back()
	return ft

func _release(ft) -> void:
	_pool.append(ft)
