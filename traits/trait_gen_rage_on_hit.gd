# traits/trait_gen_rage_on_hit.gd
# ============================================================
# GÉNÉRATEUR — "Quand JE frappe, je gagne de la Rage."
#
# C'est un GÉNÉRATEUR au sens du pitch : il ne coûte rien, son rôle est de
# LANCER le moteur. Le Guerrier frappe → sa Rage monte → il pourra dépenser.
#
# Écoute damage_dealt sur le bus. Ce signal est émis sur la CIBLE, avec
# l'attaquant en paramètre : le trait vérifie donc "est-ce MON owner qui a
# frappé ?" avant de produire.
#
# Paramètres (.tres) : { "rage_per_hit": 15.0 }
# ============================================================

class_name TraitGenRageOnHit
extends Trait

# Rage générée par coup porté. Réglable via TraitData.params.
var rage_per_hit: float = 15.0

func _trait_name() -> String:
	return "gen_rage_on_hit"

func configure(params: Dictionary) -> void:
	rage_per_hit = params.get("rage_per_hit", rage_per_hit)

func _activate() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)

# target = qui encaisse, attacker = qui frappe. On ne réagit que si c'est
# NOTRE owner qui a porté le coup (et qu'il est vivant et a une énergie).
func _on_damage_dealt(_target, attacker, _amount, _category, _element, _is_crit) -> void:
	if attacker != owner:
		return
	if owner == null or not owner.is_alive or not owner.has_energy():
		return
	owner.generate_energy(rage_per_hit, source_id)
	DebugLogger.debug(DebugLogger.LogCategory.STATS,
		"%s génère %d Rage (frappe)" % [owner.unit_name, int(rage_per_hit)])
