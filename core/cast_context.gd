# core/cast_context.gd
# ============================================================
# CAST CONTEXT — L'état d'un cast en cours de résolution.
#
# Construit en tête de SpellCaster.cast(), enrichi par chaque étape du
# pipeline, et passé aux hooks des SpellModifier. Le `report` qu'il porte
# est LE contrat avec l'UI, les logs et les modificateurs : mêmes clés et valeurs
# qu'avant le découpage en pipeline — ne jamais y renommer quoi que ce soit.
#
# `movement` est un journal INTERNE au pipeline (il n'entre pas dans le
# report) : chaque déplacement forcé résolu (poussée, chaîne, attraction,
# téléport) y est consigné pour que les modifiers puissent réagir à la
# case d'arrivée sans re-deviner ce qui a bougé.
# ============================================================

class_name CastContext
extends RefCounted

# --- Entrées du cast ---
var caster: Unit = null
var spell: Spell = null
var cell: Vector2i = Vector2i.ZERO
var action_id: StringName = &""
var cast_id: StringName = &""

# --- Coûts calculés par _resolve_costs ---
var ap_cost: int = 0

# --- État de résolution ---
var report: Dictionary = {}
var affected_cells: Array = []
var damage_bonus_by_cell: Dictionary = {} # Vector2i -> int, propre au cast
var damage_result_by_unit: Dictionary = {} # Unit -> DamageResult, interne
var heal_bonus_by_unit: Dictionary = {} # Unit -> int, propre au cast
var additional_statuses_by_unit: Dictionary = {} # Unit -> Array[StatusData]
var additional_shield_by_unit: Dictionary = {} # Unit -> int
var additional_push_by_unit: Dictionary = {} # Unit -> int (cases exactes)
var push_distance_override_by_unit: Dictionary = {} # Unit -> distance totale
var collision_damage_bonus: int = 0
var collision_damage_override: int = -1
var collision_damage_resolved: bool = false
# Agrégats génériques des arbres. Les modifiers écrivent pendant
# on_targets_resolved puis matérialisent un seul statut/terrain final pendant
# le passage de finalisation.
var skill_tree_status_specs_by_unit: Dictionary = {}
var skill_tree_status_groups_finalized: Dictionary = {}
var skill_tree_damage_groups_by_cell: Dictionary = {}
var skill_tree_damage_groups_finalized: bool = false
var skill_tree_terrain_spec: Dictionary = {}
var skill_tree_terrain_finalized: bool = false
var primary_target: Unit = null
var failed: bool = false
var costs_committed: bool = false
var resolved: bool = false

# --- Modificateurs actifs de ce cast (sort + lanceur) ---
var modifiers: Array = []

# --- Accès moteur pour les modifiers (poser un terrain, lire la grille) ---
var grid: GridData = null
var terrain: TerrainEffects = null

# --- Journal des déplacements forcés : { "unit", "from", "to", "collision" } ---
var movement: Array = []
var state_before_by_unit: Dictionary = {}
