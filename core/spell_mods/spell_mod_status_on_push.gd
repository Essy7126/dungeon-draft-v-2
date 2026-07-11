# core/spell_mods/spell_mod_status_on_push.gd
# ============================================================
# MODIFIER : STATUT SUR POUSSÉE — « X enflamme les ennemis poussés/percutés ».
#
# Premier SpellModifier concret (migration du Brassard Incendiaire) : quand le
# sort ciblé a poussé ou percuté (report.pushed / report.collision), applique
# le statut réglé à chaque ennemi touché encore vivant. Mêmes conditions et
# même population de cibles que l'ancien trait TraitRewardEpauleEnflamme,
# désormais servies par le hook on_movement_resolved du pipeline.
# ============================================================

class_name SpellModStatusOnPush
extends SpellModifier

@export var status: StatusData = null

func on_movement_resolved(ctx) -> void:
	if status == null:
		return
	if not ctx.report.get("pushed", false) and not ctx.report.get("collision", false):
		return
	for u in ctx.report.get("affected_units", []):
		if u != null and u.is_alive and u.team != ctx.caster.team:
			u.apply_status(status)
