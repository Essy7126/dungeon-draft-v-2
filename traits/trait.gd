# traits/trait.gd
# ============================================================
# TRAIT — La classe de base de TOUS les traits. Logique pure.
#
# Un trait est une RÈGLE DE RÉACTION : "quand TEL événement se produit,
# fais TELLE chose". C'est la brique technique commune sous TOUTES les idées
# de design : reliques, artefacts, sources d'énergie, détournement de classe,
# scars. Chacune de ces choses est un trait (ou un petit groupe de traits).
#
# Comment ça marche :
#   - Un trait est ATTACHÉ à une unité (son `owner`).
#   - À l'activation, il S'ABONNE aux signaux du bus qui l'intéressent.
#   - Il réagit dans ses handlers.
#   - À la désactivation, il se DÉSABONNE proprement (déséquiper une relique,
#     fin d'une scar...).
#
# ------------------------------------------------------------
# POUR CRÉER UN TRAIT CONCRET :
#   1. Crée un fichier traits/<nom>.gd qui `extends Trait`.
#   2. Surcharge _activate() : abonne-toi aux signaux du bus voulus.
#   3. Écris tes handlers (la logique "fais CECI").
#   4. (Optionnel) un .tres porte les VALEURS réglables (combien de Rage...).
#   Objectif : ~10 lignes de logique. Si tu dois toucher battle.gd, c'est raté.
# ------------------------------------------------------------
# RÈGLE D'OR (rappel) : un trait ne lit jamais une stat pour en nourrir une
# autre en direct. S'il doit faire "Puissance += 10% Armure", il SNAPSHOTE
# (lit la valeur à l'instant T) et injecte un modifier classique. Jamais de
# dépendance stat→stat directe (risque de boucle infinie).
# ============================================================

class_name Trait
extends RefCounted

# L'unité qui porte ce trait. Renseigné à l'attachement.
var owner = null

# Nom lisible (vient du TraitData.display_name). Pour les logs et tooltips.
var display_name: String = "Trait"

# Identifiant de source unique pour ce trait : sert à retirer proprement
# les modifiers qu'il a injectés dans des stats (via remove_modifiers_from).
# Ex : "trait_lame_vorace#3". Généré à l'attachement.
var source_id: String = ""

# Drapeau interne : le trait est-il actuellement actif (abonné au bus) ?
var _active: bool = false

# Compteur global pour générer des source_id uniques.
static var _next_uid: int = 0

# ============================================================
# CYCLE DE VIE — géré par le TraitHolder, pas appelé à la main.
# ============================================================

# Attache le trait à une unité et l'active.
func attach(p_owner) -> void:
	owner = p_owner
	if source_id == "":
		source_id = "%s#%d" % [_trait_name(), Trait._next_uid]
		Trait._next_uid += 1
	activate()

# Active le trait : abonnement au bus. Idempotent (pas de double abonnement).
func activate() -> void:
	if _active:
		return
	_active = true
	_activate()

# Désactive le trait : désabonnement + nettoyage des modifiers injectés.
func deactivate() -> void:
	if not _active:
		return
	_active = false
	_deactivate()
	# Retire automatiquement tout modifier que ce trait aurait posé sur une
	# stat de son owner, grâce au source_id. Le trait n'a rien à nettoyer
	# manuellement tant qu'il utilise source_id comme source de ses modifiers.
	_cleanup_modifiers()

# ============================================================
# À SURCHARGER DANS LES TRAITS CONCRETS
# ============================================================

# Lit les paramètres réglables venus du TraitData.params.
# À surcharger dans un trait concret pour récupérer ses valeurs :
#   func configure(params): attack_bonus = params.get("attack_bonus", 5.0)
# Par défaut : ne fait rien (le trait garde ses valeurs en dur). (override)
func configure(_params: Dictionary) -> void:
	pass

# Abonnements au bus. Exemple dans un trait concret :
#   EventBus.critical_hit.connect(_on_crit)
# (override)
func _activate() -> void:
	pass

# Désabonnements éventuels. Souvent inutile : si le trait est libéré (plus
# aucune référence), Godot déconnecte seul. À surcharger seulement si besoin
# d'un nettoyage explicite. (override)
func _deactivate() -> void:
	pass

# Nom lisible du trait (pour les logs / source_id). À surcharger.
func _trait_name() -> String:
	return "trait"

# ============================================================
# OUTILS POUR LES TRAITS CONCRETS
# ============================================================

# Retire de toutes les stats de l'owner les modifiers posés par ce trait.
# Appelé à la désactivation. Couvre les stats de base, défensives et résistances.
func _cleanup_modifiers() -> void:
	if owner == null:
		return
	# owner expose _all_durational_stats() (liste centralisée des Stat).
	if owner.has_method("_all_durational_stats"):
		for stat in owner._all_durational_stats():
			stat.remove_modifiers_from(source_id)
