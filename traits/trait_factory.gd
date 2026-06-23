# traits/trait_factory.gd
# ============================================================
# TRAIT FACTORY — Fabrique un Trait configuré à partir d'un TraitData.
# Logique pure, méthode statique.
#
# Le pont entre la DONNÉE (TraitData : quel script + quels paramètres) et
# l'OBJET (une instance de Trait prête à être attachée à une unité).
#
# Aucune table de correspondance à maintenir : le TraitData pointe directement
# vers son script (option B). La fabrique l'instancie et lui passe ses params.
# ============================================================

class_name TraitFactory
extends RefCounted

# Crée une instance de Trait à partir d'un TraitData. Renvoie null si invalide.
static func create(data: TraitData) -> Trait:
	if data == null:
		push_warning("TraitFactory.create : TraitData null.")
		return null
	if data.trait_script == null:
		push_warning("TraitFactory.create : '%s' n'a pas de trait_script." % data.display_name)
		return null

	# Instancie le script référencé. On suppose qu'il hérite de Trait.
	var instance = data.trait_script.new()
	if not (instance is Trait):
		push_error("TraitFactory.create : '%s' ne produit pas un Trait." % data.display_name)
		return null

	# Mémorise le display_name pour les logs.
	instance.display_name = data.display_name

	# Applique les paramètres réglables. Le trait expose configure() pour lire
	# son dictionnaire de params ; par défaut, configure() ne fait rien.
	instance.configure(data.params)

	return instance
