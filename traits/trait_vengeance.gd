# traits/trait_vengeance.gd
# ============================================================
# VENGEANCE — Trait de démonstration (et premier vrai trait).
#
# Règle : "Quand un ALLIÉ meurt, je gagne +bonus d'attaque (pour le combat)."
#
# Sert à VALIDER le moteur de traits bout en bout :
#   - abonnement au bus (unit_died)
#   - réaction conditionnelle (seulement si c'est un allié, pas l'owner)
#   - injection d'un modifier dans une stat, tracé par source_id
#   - nettoyage auto à la désactivation (via source_id)
#
# C'est ~10 lignes de logique. Aucune ligne dans battle.gd / le resolver.
# Le "5" est réglable : un .tres pourrait le porter (ici en dur pour le test).
# ============================================================

class_name TraitVengeance
extends Trait

# Valeur réglable, fournie par le TraitData.params (sinon valeur par défaut).
var attack_bonus: float = 5.0

func _trait_name() -> String:
	return "vengeance"

# Lit ses paramètres depuis le .tres : { "attack_bonus": 5.0 }.
func configure(params: Dictionary) -> void:
	attack_bonus = params.get("attack_bonus", attack_bonus)

# Abonnement : on écoute les morts sur le bus.
func _activate() -> void:
	EventBus.unit_died.connect(_on_unit_died)

# Réaction : un allié (même équipe, mais pas moi) est mort → +attaque.
func _on_unit_died(dead_unit) -> void:
	if owner == null or not owner.is_alive:
		return
	if dead_unit == owner:
		return                                   # ma propre mort ne compte pas
	if dead_unit.team != owner.team:
		return                                   # un ennemi mort ne déclenche rien
	# Injecte un bonus d'attaque PLAT, permanent pour le combat, tracé par
	# source_id → automatiquement retiré si le trait est désactivé.
	owner.attack_power.add_modifier(
		attack_bonus, Stat.ModType.FLAT, source_id, -1)
	DebugLogger.info(DebugLogger.LogCategory.COMBAT,
		"%s : %s (+%d attaque)" % [owner.unit_name, display_name, int(attack_bonus)])
