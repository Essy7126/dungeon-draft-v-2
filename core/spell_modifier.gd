# core/spell_modifier.gd
# ============================================================
# SPELL MODIFIER — Une transformation de sort, en donnée (.tres).
#
# C'est l'interface des « sorts évolutifs » (design §6) : un reward comme le
# Brassard Incendiaire attache un SpellModifier à un sort ou à un porteur, et
# le pipeline de SpellCaster.cast() appelle ses hooks aux bonnes étapes.
# AUCUN code du caster à toucher pour une nouvelle transformation :
#   1. un .gd qui étend SpellModifier et surcharge le(s) hook(s) utile(s) ;
#   2. un .tres qui règle ses valeurs (statut, terrain, cible...) ;
#   3. attaché soit au sort (Spell.modifiers), soit au porteur (via un
#      TraitSpellModifier donné par un reward/une relique).
#
# Chaque hook reçoit le CastContext : le rapport en construction, les cellules
# touchées, le journal des déplacements, et l'accès grille/terrain.
# Les hooks ne sont appelés QUE pour un cast réussi (coûts payés).
# ============================================================

class_name SpellModifier
extends Resource

@export var modifier_name: String = "Modificateur"
# Filtre stable pour les nouvelles données. Le nom reste le fallback historique.
@export var target_spell_id: StringName = &""
# Filtre : nom EXACT du sort transformé. Vide = s'applique à tous les sorts.
@export var target_spell_name: String = ""

# Ce modifier s'applique-t-il à ce sort ? (filtré une fois par cast)
func applies_to(spell) -> bool:
	if spell == null:
		return false
	if target_spell_id != &"":
		return spell.get_effective_spell_id() == target_spell_id
	if target_spell_name.strip_edges() == "":
		return true
	return spell.spell_name.strip_edges() == target_spell_name.strip_edges()

# ============================================================
# HOOKS DU PIPELINE — no-op par défaut, à surcharger au besoin.
# Ordre d'appel dans un cast : costs → targets → damage → terrain
# → movement → cast_complete (juste avant l'émission du rapport).
# ============================================================

# Coûts vérifiés et payés (PA / jauge / empreinte).
func on_costs_resolved(_ctx) -> void:
	pass

# Cellules de la zone d'effet calculées, squelette du rapport posé.
func on_targets_resolved(_ctx) -> void:
	pass

# Effets directs appliqués aux unités (dégâts, soins, statuts, drains, boucliers).
func on_damage_resolved(_ctx) -> void:
	pass

# Terrains du sort (et de l'empreinte) posés sur les cellules touchées.
func on_terrain_resolved(_ctx) -> void:
	pass

# Déplacements forcés résolus (poussées + chaînes, attraction, téléport).
# ctx.movement liste chaque déplacement { "unit", "from", "to", "collision" }.
func on_movement_resolved(_ctx) -> void:
	pass

# Tout est résolu (énergie du lanceur comprise). Appelé juste AVANT
# l'émission de EventBus.spell_cast : dernier point pour amender le rapport.
func on_cast_complete(_ctx) -> void:
	pass
