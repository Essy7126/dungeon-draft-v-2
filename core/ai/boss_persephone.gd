# core/ai/boss_persephone.gd
# ============================================================
# BOSS — PERSÉPHONE, reine des Enfers.
# Archétype : lanceuse à distance qui CONTRÔLE.
#
# Personnalité de combat (ordre de priorité à chaque tour) :
#   1. Si ses héros sont groupés → AoE (tombeau fleuri).
#   2. Si un héros est au contact → flétrissement dessus (lui couper
#      PM/PA), puis elle RECULE (kiting) pour reprendre ses distances.
#   3. Sinon → frappe à distance (étreinte des enfers) sur le plus proche.
#   4. Hors de portée → elle se rapproche, mais sans jamais coller.
#
# Les trois sorts sont assignés par RÔLE dans le .tres (pas devinés),
# pour que tu voies clairement qui fait quoi et puisses les changer.
# ============================================================

class_name BossPersephone
extends BossBehavior

@export_group("Sorts par rôle")
@export var aoe_spell: Spell = null      # tombeau fleuri (dégâts de zone)
@export var debuff_spell: Spell = null   # flétrissement (malus PM/PA)
@export var single_spell: Spell = null   # étreinte des enfers (mono-cible)

@export_group("Réglages")
# Elle lâche l'AoE seulement si elle touche au moins ce nombre de héros.
@export var aoe_min_targets: int = 2
# Distance qu'elle cherche à garder avec les héros (en cases).
@export var keep_distance: int = 2

# ============================================================
# DÉCISION
# ============================================================

func decide(boss, all_units, ai) -> Array:
	var grid = ai.get_grid()
	var caster = ai.get_spell_caster()
	var heroes = _living_heroes(boss, all_units)
	if heroes.is_empty():
		return []

	# --- Priorité 1 : AoE si elle touche assez de héros groupés. ---
	if _can_cast(boss, aoe_spell):
		var best = _best_aoe_cell(boss, caster, heroes)
		if best["count"] >= aoe_min_targets:
			return [_cast(aoe_spell, best["cell"])]

	# --- Priorité 2 : un héros au contact → flétrissement + repli (kiting). ---
	var intruder = _adjacent_hero(boss, heroes, grid)
	if intruder != null:
		var plan: Array = []
		if _can_cast(boss, debuff_spell) \
				and caster.is_valid_target(boss, debuff_spell, intruder.grid_pos):
			plan.append(_cast(debuff_spell, intruder.grid_pos))
		var retreat = _retreat_action(boss, heroes, ai)
		if not retreat.is_empty():
			plan.append(retreat)
		if not plan.is_empty():
			return plan

	# --- Priorité 3 : frappe mono-cible à distance sur le plus proche. ---
	var target = _nearest(boss, heroes, grid)
	if target != null and _can_cast(boss, single_spell):
		if caster.is_valid_target(boss, single_spell, target.grid_pos):
			return [_cast(single_spell, target.grid_pos)]

	# --- Priorité 4 : pas à portée → se rapprocher sans coller. ---
	var approach = _approach_action(boss, target, ai)
	if not approach.is_empty():
		return [approach]

	# --- Repli par défaut (sécurité). ---
	return ai.default_attack_plan(boss, all_units)

# ============================================================
# OUTILS
# ============================================================

# Les héros vivants (équipe différente du boss).
func _living_heroes(boss, all_units) -> Array:
	var result: Array = []
	for u in all_units:
		if u.is_alive and u.team != boss.team:
			result.append(u)
	return result

# A-t-on les PA pour ce sort ?
func _can_cast(boss, spell) -> bool:
	return spell != null and boss.current_ap >= spell.ap_cost

# Raccourci pour fabriquer une action de sort.
func _cast(spell, cell) -> Dictionary:
	return { "type": "cast", "spell": spell, "cell": cell }

# Le héros le plus proche du boss (ou null).
func _nearest(boss, heroes, grid) -> Unit:
	var best: Unit = null
	var best_dist := 999999
	for h in heroes:
		var d = grid.manhattan(boss.grid_pos, h.grid_pos)
		if d < best_dist:
			best_dist = d
			best = h
	return best

# Un héros est-il adjacent au boss ? (= il a réussi à la coller en mêlée)
func _adjacent_hero(boss, heroes, grid) -> Unit:
	for h in heroes:
		if grid.are_adjacent(boss.grid_pos, h.grid_pos):
			return h
	return null

# Cherche la case d'AoE qui touche le PLUS de héros.
# Renvoie { "cell": Vector2i, "count": int }.
func _best_aoe_cell(boss, caster, heroes) -> Dictionary:
	var best_cell := Vector2i(-1, -1)
	var best_count := 0
	for cell in caster.get_targetable_cells(boss, aoe_spell):
		var zone = caster.get_aoe_cells(aoe_spell, cell)
		var count := 0
		for h in heroes:
			if zone.has(h.grid_pos):
				count += 1
		if count > best_count:
			best_count = count
			best_cell = cell
	return { "cell": best_cell, "count": best_count }

# Action de repli : la case atteignable la plus ÉLOIGNÉE du héros le plus proche.
func _retreat_action(boss, heroes, ai) -> Dictionary:
	var grid = ai.get_grid()
	var pf = ai.get_pathfinder()
	var nearest = _nearest(boss, heroes, grid)
	if nearest == null:
		return {}
	var best_cell = boss.grid_pos
	var best_dist = grid.manhattan(boss.grid_pos, nearest.grid_pos)
	for cell in pf.get_reachable(boss.grid_pos, boss.current_mp, boss):
		var d = grid.manhattan(cell, nearest.grid_pos)
		if d > best_dist:
			best_dist = d
			best_cell = cell
	if best_cell == boss.grid_pos:
		return {}
	var path = pf.find_path(boss.grid_pos, best_cell, boss)
	if path.size() < 2:
		return {}
	return { "type": "move", "path": path }

# Action d'approche : se rapprocher de la cible SANS descendre sous keep_distance.
func _approach_action(boss, target, ai) -> Dictionary:
	if target == null:
		return {}
	var grid = ai.get_grid()
	var pf = ai.get_pathfinder()
	var best_cell = boss.grid_pos
	var best_dist = grid.manhattan(boss.grid_pos, target.grid_pos)
	for cell in pf.get_reachable(boss.grid_pos, boss.current_mp, boss):
		var d = grid.manhattan(cell, target.grid_pos)
		# On veut se rapprocher (d plus petit) mais pas coller (>= keep_distance).
		if d < keep_distance:
			continue
		if d < best_dist:
			best_dist = d
			best_cell = cell
	if best_cell == boss.grid_pos:
		return {}
	var path = pf.find_path(boss.grid_pos, best_cell, boss)
	if path.size() < 2:
		return {}
	return { "type": "move", "path": path }
