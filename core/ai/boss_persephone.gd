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
# Cette version est BAVARDE : chaque décision (et chaque option écartée)
# est tracée dans la console de debug, catégorie AI. Filtre sur "AI"
# pour suivre son raisonnement tour par tour.
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

# Raccourci de catégorie pour alléger les appels.
const CAT := DebugLogger.LogCategory.AI

# ============================================================
# DÉCISION
# ============================================================

func decide(boss, all_units, ai) -> Array:
	var grid = ai.get_grid()
	var caster = ai.get_spell_caster()
	var heroes = _living_heroes(boss, all_units)

	DebugLogger.info(CAT, "%s réfléchit" % boss.unit_name, {
		"PA": boss.current_ap, "PM": boss.current_mp,
		"PV": "%d/%d" % [boss.current_hp, boss.max_hp.get_int()],
		"héros_vivants": heroes.size(),
	})

	if heroes.is_empty():
		DebugLogger.warn(CAT, "%s : aucun héros vivant, rien à faire" % boss.unit_name)
		return []

	# --- Priorité 1 : AoE si elle touche assez de héros groupés. ---
	if _can_cast(boss, aoe_spell):
		var best = _best_aoe_cell(boss, caster, heroes)
		DebugLogger.trace(CAT, "Option AoE (%s)" % _spell_name(aoe_spell), {
			"meilleure_case": str(best["cell"]),
			"héros_touchés": best["count"],
			"seuil": aoe_min_targets,
		})
		if best["count"] >= aoe_min_targets:
			DebugLogger.info(CAT, "%s → AoE %s sur %s (%d héros)" % [
				boss.unit_name, _spell_name(aoe_spell), str(best["cell"]), best["count"]])
			return [_cast(aoe_spell, best["cell"])]
		else:
			DebugLogger.trace(CAT, "AoE écartée : pas assez de héros groupés")
	else:
		DebugLogger.trace(CAT, "AoE indisponible (sort manquant ou PA insuffisants)")

	# --- Priorité 2 : un héros au contact → flétrissement + repli (kiting). ---
	var intruder = _adjacent_hero(boss, heroes, grid)
	if intruder != null:
		DebugLogger.debug(CAT, "%s : %s est au contact → contrôle + repli" % [
			boss.unit_name, intruder.unit_name])
		var plan: Array = []
		if _can_cast(boss, debuff_spell) \
				and caster.is_valid_target(boss, debuff_spell, intruder.grid_pos):
			plan.append(_cast(debuff_spell, intruder.grid_pos))
			DebugLogger.info(CAT, "%s → flétrissement (%s) sur %s" % [
				boss.unit_name, _spell_name(debuff_spell), intruder.unit_name])
		else:
			DebugLogger.trace(CAT, "Flétrissement indisponible sur %s" % intruder.unit_name)
		var retreat = _retreat_action(boss, heroes, ai)
		if not retreat.is_empty():
			var dest = retreat["path"][retreat["path"].size() - 1]
			plan.append(retreat)
			DebugLogger.info(CAT, "%s → repli vers %s" % [boss.unit_name, str(dest)])
		else:
			DebugLogger.trace(CAT, "Aucun repli possible (coincée)")
		if not plan.is_empty():
			return plan
		DebugLogger.trace(CAT, "Contact géré sans action : on passe à la suite")

	# --- Priorité 3 : frappe mono-cible à distance sur le plus proche. ---
	var target = _nearest(boss, heroes, grid)
	if target != null and _can_cast(boss, single_spell):
		var dist = grid.manhattan(boss.grid_pos, target.grid_pos)
		if caster.is_valid_target(boss, single_spell, target.grid_pos):
			DebugLogger.info(CAT, "%s → %s sur %s (dist %d)" % [
				boss.unit_name, _spell_name(single_spell), target.unit_name, dist])
			return [_cast(single_spell, target.grid_pos)]
		else:
			DebugLogger.trace(CAT, "%s hors de portée du mono-cible (dist %d)" % [
				target.unit_name, dist])
	elif target != null:
		DebugLogger.trace(CAT, "Mono-cible indisponible (PA insuffisants)")

	# --- Priorité 4 : pas à portée → se rapprocher sans coller. ---
	var approach = _approach_action(boss, target, ai)
	if not approach.is_empty():
		var dest = approach["path"][approach["path"].size() - 1]
		DebugLogger.info(CAT, "%s → se rapproche vers %s" % [boss.unit_name, str(dest)])
		return [approach]

	# --- Repli par défaut (sécurité). ---
	DebugLogger.warn(CAT, "%s : aucune option idéale, comportement par défaut" % boss.unit_name)
	return ai.default_attack_plan(boss, all_units)

# ============================================================
# OUTILS
# ============================================================

# Nom lisible d'un sort (ou "—" s'il manque).
func _spell_name(spell) -> String:
	return spell.spell_name if spell != null else "—"

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
