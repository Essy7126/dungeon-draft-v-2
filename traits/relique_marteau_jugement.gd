# traits/relique_marteau_jugement.gd
# ============================================================
# RELIQUE — Marteau du Jugement
#
# C'est la relique de test centrale de Dungeon Draft :
# elle DÉTOURNE la Foi — normalement défensive — en attaque sacrée.
#
# Mécanique :
#   Quand le porteur DÉPENSE de la Foi (sort consommateur),
#   il emmagasine un bonus de dégâts sacrés = Foi_dépensée × ratio.
#   Ce bonus est appliqué à sa PROCHAINE attaque sous forme
#   de dégâts sacrés purs (ignore la défense) en coup secondaire.
#
# Ce que le joueur doit ressentir :
#   "Je ne dépense plus ma Foi juste pour défendre.
#    Maintenant, chaque dépense de Foi prépare un burst sacré."
#
# Paramètre :
#   conversion_ratio : float = 0.3
#   (30 Foi dépensés → 9 dégâts sacrés sur le prochain coup)
# ============================================================

class_name ReliqueMarteauJugement
extends Trait

var conversion_ratio: float = 0.3   # % de Foi convertie en dégâts sacrés
var _sacred_bonus: int = 0           # bonus emmagasiné, consommé au prochain coup

func _trait_name() -> String:
	return "relique_marteau_jugement"

func configure(params: Dictionary) -> void:
	conversion_ratio = params.get("conversion_ratio", conversion_ratio)

func _activate() -> void:
	EventBus.energy_spent.connect(_on_energy_spent)
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _deactivate() -> void:
	if EventBus.energy_spent.is_connected(_on_energy_spent):
		EventBus.energy_spent.disconnect(_on_energy_spent)
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)

# ============================================================
# ACCUMULATION — quand le porteur dépense de la Foi
# ============================================================

func _on_energy_spent(unit, energy_id: String, amount: float) -> void:
	if unit != owner:
		return
	if energy_id != "foi":
		return                        # seule la Foi alimente le Marteau
	var bonus := int(amount * conversion_ratio)
	if bonus <= 0:
		return
	_sacred_bonus += bonus
	DebugLogger.debug(DebugLogger.LogCategory.STATS,
		"%s : Marteau du Jugement emmagasine %d dégâts sacrés (%.0f Foi × %.0f%%)" \
		% [owner.unit_name, bonus, amount, conversion_ratio * 100])

# ============================================================
# DÉCHARGE — sur la prochaine attaque du porteur
# On efface le bonus AVANT d'appeler take_damage pour éviter
# toute boucle récursive (le coup secondaire ne déclenche pas
# une autre décharge).
# ============================================================

func _on_damage_dealt(target, attacker, _amount, _category, _element, _is_crit) -> void:
	if attacker != owner or _sacred_bonus <= 0:
		return
	if target == null or not target.is_alive:
		return

	var bonus := _sacred_bonus
	_sacred_bonus = 0               # consommé avant take_damage

	DebugLogger.info(DebugLogger.LogCategory.COMBAT,
		"%s : Marteau du Jugement — %d dégâts sacrés sur %s" \
		% [owner.unit_name, bonus, target.unit_name])

	# Coup sacré : ignore la défense, élément HOLY, non esquivable
	target.take_damage(
		bonus, owner,
		Spell.DamageType.MAGICAL, Spell.Element.HOLY,
		{ "ignore_defense": true, "cannot_be_dodged": true }
	)
