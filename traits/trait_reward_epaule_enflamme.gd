# traits/trait_reward_epaule_enflamme.gd
# ============================================================
# BRASSARD INCENDIAIRE — reward qui TRANSFORME un sort existant.
#
# « Coup d'épaule enflamme » (design §6, sorts évolutifs) : quand le porteur
# pousse ou percute un ennemi avec Coup d'épaule, les ennemis touchés prennent
# le statut Brûlure. Les traits ne peuvent pas poser de terrain (réservé à
# SpellCaster.cast()), donc on transforme via un STATUT appliqué directement
# à la cible — même esprit, sans avoir besoin d'accès à TerrainEffects.
# ============================================================

class_name TraitRewardEpauleEnflamme
extends Trait

const TARGET_SPELL_NAME := "Coup d'epaule"

var _status: StatusData = null

func _trait_name() -> String:
	return "trait_reward_epaule_enflamme"

func configure(params: Dictionary) -> void:
	_status = params.get("status", null)

func _activate() -> void:
	EventBus.spell_cast.connect(_on_spell_cast)

func _deactivate() -> void:
	if EventBus.spell_cast.is_connected(_on_spell_cast):
		EventBus.spell_cast.disconnect(_on_spell_cast)

func _on_spell_cast(caster, spell: Spell, report: Dictionary) -> void:
	if caster != owner or spell == null or _status == null:
		return
	if spell.spell_name.strip_edges() != TARGET_SPELL_NAME:
		return
	if not report.get("pushed", false) and not report.get("collision", false):
		return
	for u in report.get("affected_units", []):
		if u != null and u.is_alive and u.team != owner.team:
			u.apply_status(_status)
