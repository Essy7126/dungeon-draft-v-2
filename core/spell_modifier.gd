# core/spell_modifier.gd
# ============================================================
# SPELL MODIFIER — Une transformation de sort, en donnée (.tres).
#
# Interface data-driven des transformations de sorts de progression.
# AUCUN code du caster à toucher pour une nouvelle transformation :
#   1. un .gd qui étend SpellModifier et surcharge le(s) hook(s) utile(s) ;
#   2. un .tres qui règle ses valeurs (statut, terrain, cible...) ;
#   3. attaché au sort ou au SpellLoadoutState par la progression.
#
# Chaque hook reçoit le CastContext : le rapport en construction, les cellules
# touchées, le journal des déplacements, et l'accès grille/terrain.
# Les hooks ne sont appelés QUE pour un cast réussi (coûts payés).
# ============================================================

@tool
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

# Bonus de portee consultable avant la validation de cible. Le retour par
# defaut conserve strictement le ciblage de tous les modifiers historiques.
func get_range_bonus(_caster, _spell) -> int:
	return 0

# Remplace la portée minimale d'un sort avant la validation de cible. Une
# valeur négative signifie « aucun override ». Lorsque plusieurs sources sont
# actives, SpellCaster retient la contrainte la plus forte pour que l'ordre des
# Resources ne puisse jamais neutraliser silencieusement un drawback.
func get_minimum_range_override(_caster, _spell) -> int:
	return -1

# Autorise un modifier data-driven à élargir le contrat de ciblage avant le
# début du cast (par exemple la branche Intercepteur de Charge).
func allows_free_cell_target(_caster, _spell) -> bool:
	return false


# Indique a la presentation qu'un sort deplace son propre lanceur. Ce contrat
# reste purement descriptif : la grille et la resolution demeurent autoritaires.
func moves_caster_during_cast(_caster, _spell) -> bool:
	return false


## Contrainte de ciblage propre à un modificateur. Elle est évaluée avant le
## lancement visuel et avant toute dépense, puis réutilisée pour les cases
## ciblables afin que gameplay et interface restent alignés.
func get_target_cell_failure_reason(
		_caster,
		_spell,
		_cell: Vector2i,
		_grid
	) -> StringName:
	return &""

# ============================================================
# HOOKS DU PIPELINE — no-op par défaut, à surcharger au besoin.
# Ordre d'appel dans un cast : costs → targets → damage → terrain
# → movement → cast_complete (juste avant l'émission du rapport).
# ============================================================

# Coût en PA vérifié et payé.
func on_costs_resolved(_ctx) -> void:
	pass

# Cellules de la zone d'effet calculées, squelette du rapport posé.
func on_area_resolved(_ctx) -> void:
	pass

# Zone finalisée ; les autres effets peuvent maintenant lire toutes les cibles.
func on_targets_resolved(_ctx) -> void:
	pass

# Second passage après que tous les modifiers ont enrichi le CastContext.
# Il permet aux effets cumulatifs (statuts d'un même arbre notamment) de
# produire une seule ressource finale, sans dépendre de l'ordre des nodes.
func on_targets_finalized(_ctx) -> void:
	pass

# Effets directs appliqués aux unités (dégâts, soins, statuts, drains, boucliers).
func on_damage_resolved(_ctx) -> void:
	pass

# Terrains du sort posés sur les cellules touchées.
func on_terrain_resolved(_ctx) -> void:
	pass

# Déplacements forcés résolus (poussées + chaînes, attraction, téléport).
# ctx.movement liste chaque déplacement { "unit", "from", "to", "collision" }.
func on_movement_resolved(_ctx) -> void:
	pass

# Tout est résolu. Appelé juste AVANT
# l'émission de EventBus.spell_cast : dernier point pour amender le rapport.
func on_cast_complete(_ctx) -> void:
	pass


func ignores_minimum_range(_caster, _spell) -> bool:
	return false
