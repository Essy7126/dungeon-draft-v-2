# bat# battle/turn_state.gd
# ============================================================
# TURN STATE — Machine à états du contrôle du tour.
# ============================================================

class_name TurnState
extends RefCounted

enum State {
	IDLE,
	MOVE,
	TARGET_MELEE,
	TARGET_SPELL,   # ciblage d'un sort
	ENEMY_TURN,
	ANIMATING,
}

var current: State = State.IDLE

# Le sort en cours de ciblage (null si aucun).
var selected_spell: Spell = null
var selected_spell_imprinted: bool = false

# Signaux d'intention vers Battle.
signal request_show_move_range
signal request_show_attack_range
signal request_show_spell_range(spell, imprinted)
signal request_clear_highlights
signal request_move_to(cell)
signal request_attack(cell)
signal request_cast_spell(spell, cell, imprinted)

func set_state(new_state: State) -> void:
	current = new_state
	_on_enter_state(new_state)

func _on_enter_state(state: State) -> void:
	match state:
		State.IDLE:
			selected_spell = null
			selected_spell_imprinted = false
			request_clear_highlights.emit()
		State.MOVE:
			request_show_move_range.emit()
		State.TARGET_MELEE:
			request_show_attack_range.emit()
		State.TARGET_SPELL:
			request_show_spell_range.emit(selected_spell, selected_spell_imprinted)
		State.ENEMY_TURN:
			request_clear_highlights.emit()
		State.ANIMATING:
			request_clear_highlights.emit()

# ============================================================
# ENTRÉES DU JOUEUR
# ============================================================

func on_move_button() -> void:
	if current == State.MOVE:
		set_state(State.IDLE)
	else:
		set_state(State.MOVE)

func on_attack_button() -> void:
	if current == State.TARGET_MELEE:
		set_state(State.IDLE)
	else:
		set_state(State.TARGET_MELEE)

# Le joueur a sélectionné un sort dans la barre.
func on_spell_selected(spell: Spell, imprinted: bool = false) -> void:
	# Si on reclique le même sort déjà sélectionné, on annule.
	if current == State.TARGET_SPELL and selected_spell == spell and selected_spell_imprinted == imprinted:
		set_state(State.IDLE)
	else:
		selected_spell = spell
		selected_spell_imprinted = imprinted
		set_state(State.TARGET_SPELL)

func on_cell_clicked(cell: Vector2i) -> void:
	match current:
		State.MOVE:
			request_move_to.emit(cell)
		State.TARGET_MELEE:
			request_attack.emit(cell)
		State.TARGET_SPELL:
			request_cast_spell.emit(selected_spell, cell, selected_spell_imprinted)
		_:
			pass

func on_cancel() -> void:
	if current in [State.MOVE, State.TARGET_MELEE, State.TARGET_SPELL]:
		set_state(State.IDLE)

# ============================================================
# CONTRÔLE PAR BATTLE
# ============================================================

func begin_animating() -> void:
	set_state(State.ANIMATING)

func end_animating() -> void:
	set_state(State.IDLE)

func begin_enemy_turn() -> void:
	set_state(State.ENEMY_TURN)

func begin_player_turn() -> void:
	set_state(State.IDLE)
