# units/stats.gd
# ============================================================
# MOTEUR DE STAT — Une stat avec base + modificateurs.
# Logique pure. Réutilisable pour TOUTE stat : PV, initiative, PA, PM, attaque...
#
# Formule de calcul (standard de l'industrie) :
#   valeur = (base + somme des modificateurs PLATS) × (1 + somme des POURCENTAGES)
#
# Les modificateurs plats s'appliquent d'abord, puis les pourcentages.
# C'est l'ordre qui donne des résultats cohérents et prévisibles.
# ============================================================

class_name Stat
extends RefCounted

# Type de modificateur :
# FLAT    = valeur absolue ajoutée   (+5 initiative, -20 PV)
# PERCENT = pourcentage multiplicatif (+0.20 = +20%, -0.20 = -20% anti-heal)
enum ModType { FLAT, PERCENT }

# ============================================================
# DONNÉES
# ============================================================

var base_value: float          # Valeur de base, jamais modifiée par les bonus
var _modifiers: Array = []      # Liste des modificateurs actifs

# Signal émis dès que la stat change (ajout/retrait de mod, changement de base).
# L'UI peut s'y connecter pour se rafraîchir automatiquement.
signal changed

# ============================================================
# CONSTRUCTION
# Stat.new(15) crée une stat de base 15.
# ============================================================

func _init(initial_base: float = 0.0) -> void:
	base_value = initial_base

# ============================================================
# AJOUT / RETRAIT DE MODIFICATEURS
# ============================================================

# Ajoute un modificateur à la stat.
# value    : la valeur (ex: 5 pour +5, ou 0.20 pour +20%)
# type     : ModType.FLAT ou ModType.PERCENT
# source   : identifiant texte de l'origine (ex: "boss_meduse", "bottes_hermes")
#            permet de retrouver et retirer ce mod plus tard
# duration : nombre de tours de vie. -1 = permanent.
func add_modifier(value: float, type: ModType, source: String, duration: int = -1) -> void:
	_modifiers.append({
		"value": value,
		"type": type,
		"source": source,
		"duration": duration,
	})
	changed.emit()

# Retire TOUS les modificateurs venant d'une source donnée.
# Ex: remove_modifiers_from("boss_meduse") enlève tous ses malus d'un coup.
func remove_modifiers_from(source: String) -> void:
	var before = _modifiers.size()
	_modifiers = _modifiers.filter(func(m): return m["source"] != source)
	if _modifiers.size() != before:
		changed.emit()

# Retire tous les modificateurs (reset complet des bonus/malus).
func clear_modifiers() -> void:
	if not _modifiers.is_empty():
		_modifiers.clear()
		changed.emit()

# ============================================================
# GESTION DE LA DURÉE (modificateurs temporaires)
# À appeler au début de chaque tour de l'unité.
# Décrémente les durées et retire les modificateurs expirés.
# ============================================================

func tick_durations() -> void:
	var changed_something = false
	# On parcourt à l'envers pour pouvoir retirer sans casser l'index.
	for i in range(_modifiers.size() - 1, -1, -1):
		var mod = _modifiers[i]
		# -1 = permanent, on ne touche pas.
		if mod["duration"] == -1:
			continue
		mod["duration"] -= 1
		if mod["duration"] <= 0:
			_modifiers.remove_at(i)
			changed_something = true
	if changed_something:
		changed.emit()

# ============================================================
# CALCUL DE LA VALEUR EFFECTIVE
# C'est ici que la formule s'applique.
# ============================================================

func get_value() -> float:
	var flat_sum := 0.0
	var percent_sum := 0.0

	for mod in _modifiers:
		if mod["type"] == ModType.FLAT:
			flat_sum += mod["value"]
		else:
			percent_sum += mod["value"]

	# (base + plats) × (1 + pourcentages)
	var result = (base_value + flat_sum) * (1.0 + percent_sum)
	return result

# Version arrondie en entier, pratique pour PV, PA, PM, initiative.
func get_int() -> int:
	return int(round(get_value()))

# ============================================================
# OUTILS DE LECTURE (debug, UI)
# ============================================================

# Retourne la liste des modificateurs actifs (pour afficher un tooltip détaillé).
func get_modifiers() -> Array:
	return _modifiers.duplicate()

# Y a-t-il un modificateur venant de cette source ?
func has_source(source: String) -> bool:
	for mod in _modifiers:
		if mod["source"] == source:
			return true
	return false
