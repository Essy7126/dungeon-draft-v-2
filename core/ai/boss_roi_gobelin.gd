# core/ai/boss_roi_gobelin.gd
# ============================================================
# BOSS — LE ROI GOBELIN (exemple de comportement de boss).
# Montre le pattern à reproduire pour tout futur boss.
#
# Deux mécaniques, toutes deux RÉGLABLES dans le .tres :
#   1. COUP SIGNATURE : tous les N tours, lance un sort puissant (AoE)
#      sur les héros, au lieu d'attaquer normalement.
#   2. ENRAGE : une seule fois, quand ses PV passent sous un seuil,
#      il gagne un bonus d'attaque permanent.
# Le reste du temps : comportement agressif standard (mêlée).
# ============================================================

class_name BossRoiGobelin
extends BossBehavior

@export_group("Coup signature")
# Le sort puissant lancé périodiquement (idéalement une AoE).
@export var signature_spell: Spell = null
# Tous les combien de tours il lance ce coup (3 = un tour sur trois).
@export var signature_every: int = 3

@export_group("Enrage")
# Ratio de PV sous lequel le boss s'enrage (0.5 = 50%).
@export var enrage_threshold: float = 0.5
# Bonus d'attaque à l'enrage (0.5 = +50%, en pourcentage).
@export var enrage_attack_bonus: float = 0.5

# --- État interne (propre à CE boss, remis à zéro à chaque combat). ---
# Ces variables ne sont pas @export : à la duplication du comportement
# pour chaque instance de boss, elles repartent à leur valeur par défaut.
var _turn_count: int = 0
var _enraged: bool = false

func decide(boss, all_units, ai) -> Array:
	_turn_count += 1

	# --- Mécanique 1 : ENRAGE (une seule fois, sous le seuil de PV). ---
	if not _enraged and boss.get_hp_ratio() <= enrage_threshold:
		_enraged = true
		boss.attack_power.add_modifier(enrage_attack_bonus, Stat.ModType.PERCENT, "enrage", -1)
		boss.stats_changed.emit(boss)
		DebugLogger.warn(DebugLogger.LogCategory.AI, "%s entre en rage (+%d%% attaque)" % [boss.unit_name, int(enrage_attack_bonus*100)])
		print("%s entre en RAGE ! (+%d%% attaque)" % [boss.unit_name, int(enrage_attack_bonus * 100)])

	# --- Mécanique 2 : COUP SIGNATURE (tous les N tours). ---
	if signature_spell != null and _turn_count % signature_every == 0:
		if boss.current_ap >= signature_spell.ap_cost:
			var cell = ai.find_target_cell_for_spell(boss, signature_spell)
			if cell != Vector2i(-1, -1):
				DebugLogger.info(DebugLogger.LogCategory.AI, "%s prépare son coup signature" % boss.unit_name)
				print("%s prépare son coup signature !" % boss.unit_name)
				return [{ "type": "cast", "spell": signature_spell, "cell": cell }]

	# --- Sinon : comportement agressif standard (réutilise EnemyAI). ---
	return ai.default_attack_plan(boss, all_units)
