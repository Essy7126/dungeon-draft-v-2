export type JsonPrimitive = null | boolean | number | string;
export type JsonValue = JsonPrimitive | JsonValue[] | { [key: string]: JsonValue };

export interface EnumValue {
  value: number;
  name: string;
}

export interface ResourceReference {
  resource_type: string;
  resource_path: string;
  [key: string]: JsonValue;
}

export interface SnapshotMeta {
  schema_version: string;
  generator_version: string;
  generated_at_utc: string;
  source_game_commit: string;
  source_branch: string;
  source_worktree_dirty_before_export: boolean;
  godot_version: string;
  project_name: string;
  contract_version: string;
  manifest_version: string;
}

export interface ScopeEntry {
  domain: string;
  reason: string;
  status?: string;
  path?: string;
}

export interface SnapshotScope {
  included_domains: string[];
  deferred_domains: ScopeEntry[];
  excluded_domains: ScopeEntry[];
}

export interface SnapshotSummary {
  characters: number;
  disciplines: number;
  spells: number;
  items: number;
  generic_rewards: number;
  reward_pools: number;
  runs: number;
  rooms: number;
  waves: number;
  encounters: number;
  enemies: number;
  enemy_spells: number;
  ai_profiles: number;
  eligible_first_run_equipment: number;
  contract_conform: number;
  contract_difference: number;
  contract_unknown: number;
  contract_not_evaluated: number;
  audit_info: number;
  audit_warning: number;
  audit_blocking: number;
}

export interface ContractDecision {
  key: string;
  value: JsonValue;
  status: 'validated' | 'provisional' | 'unknown' | 'deprecated';
  source: string;
  rationale: string;
}

export interface ObservatoryContract {
  version: string;
  decisions: ContractDecision[];
}

export interface Character {
  id: string;
  name: string;
  description: string;
  role: string;
  presentation_summary: string;
  progression_summary: string;
  max_hp: number;
  max_ap: number;
  max_mp: number;
  initiative: number;
  attack_power: number;
  active_spell_slots: number;
  spell_ids: string[];
  discipline_ids: string[];
  source_path: string;
  visual_scene_path: string;
  preview_visual_scene_path: string;
}

export interface Spell {
  id: string;
  discipline_id: string;
  name: string;
  description: string;
  referenced_by_character_ids: string[];
  ap_cost: number;
  minimum_range: number;
  range: number;
  needs_line_of_sight: boolean;
  cooldown_activations: number;
  max_uses_per_combat: number;
  can_target_enemy: boolean;
  can_target_ally: boolean;
  can_target_free_cell: boolean;
  can_target_self: boolean;
  aoe_shape: EnumValue;
  aoe_size: number;
  damage: number;
  heal: number;
  shield_grant: number;
  damage_type: EnumValue;
  element: EnumValue;
  terrain_effect: ResourceReference | null;
  applied_status: ResourceReference | null;
  push_distance: number;
  pull_distance: number;
  delayed_resolution: EnumValue;
  summon: ResourceReference | null;
  summon_type: string;
  modifiers: ResourceReference[];
  source_path: string;
}

export interface DisciplineChoice {
  upgrade_id: string;
  name: string;
  description: string;
  discipline_id: string;
  rank: number;
  target_spell_id: string;
  prerequisite_ids: string[];
  excluded_ids: string[];
  modifiers: ResourceReference[];
  source_path: string;
}

export interface DisciplineRank {
  rank: number;
  required_total_xp: number;
  choices: DisciplineChoice[];
  source_path: string;
}

export interface Discipline {
  id: string;
  character_id: string;
  name: string;
  description: string;
  rank_count: number;
  total_choice_count: number;
  ranks: DisciplineRank[];
  source_path: string;
}

export interface ItemStatModifier {
  stat_id: string;
  value: number;
  modifier_type: EnumValue;
  source_path: string;
}

export interface Item {
  id: string;
  name: string;
  description: string;
  rarity: string;
  tags: string[];
  category: EnumValue;
  equipment_slot: EnumValue;
  compatible_character_ids: string[];
  stat_modifiers: ItemStatModifier[];
  spell_modifiers: ResourceReference[];
  use_effect: EnumValue;
  equippable: boolean;
  consumable: boolean;
  valid: boolean;
  pool_ids: string[];
  source_path: string;
}

export interface GenericReward {
  id: string;
  name: string;
  description: string;
  reward_type: EnumValue;
  target_policy: EnumValue;
  value: number;
  valid: boolean;
  usage_status: string;
  source_path: string;
}

export interface RewardPool {
  id: string;
  name: string;
  kind: string;
  mechanism: string;
  status: string;
  required_tag: string;
  minimum_options: number;
  item_ids: string[];
  rewards: GenericReward[];
  source_path: string;
}

export type IdentitySource = 'explicit' | 'manifest_alias' | 'resource_path' | 'ordered_parent_index';
export type IdentityStability = 'stable' | 'derived' | 'runtime_only';
export type ValidationStatus = 'valid' | 'invalid';
export type CalculationStatus = 'exact_runtime_equivalent' | 'static_base_only' | 'runtime_dependent' | 'unknown';

export interface Cell { x: number; y: number }

export interface Run {
  id: string;
  id_source: IdentitySource;
  identity_stability: IdentityStability;
  name: string;
  source_path: string;
  default_seed: number;
  target_duration_minutes: number;
  extended_duration_minutes: number;
  maximum_waves_per_room: number;
  room_ids: string[];
  authored_room_count: number;
  validation_status: ValidationStatus;
  validation_errors: string[];
}

export interface Room {
  id: string;
  id_source: IdentitySource;
  identity_stability: IdentityStability;
  run_id: string;
  index: number;
  name: string;
  source_path: string;
  background_image_path: string;
  particles_scene_path: string;
  battle_scene_path: string;
  arena_generation_profile_path: string;
  arena_visual_profile_path: string;
  grid_layout_path: string;
  painted_map_visual_data_path: string;
  map_kind: 'painted' | 'generated' | 'legacy_scene' | 'unknown';
  grid_width: number | null;
  grid_height: number | null;
  grid_dimensions_status: 'static_resource' | 'runtime_only';
  available_wave_count: number;
  minimum_wave_count: number;
  maximum_wave_count: number;
  resolved_default_seed_wave_count: number | null;
  wave_resolution_status: 'exact_production_resolver' | 'runtime_only';
  wave_resolution_method: string;
  wave_resolution_seed: number;
  wave_ids: string[];
  default_encounter_id: string;
  hero_spawn_cells: Cell[];
  enemy_spawn_cells: Cell[];
  hero_spawn_cell_count: number;
  enemy_spawn_cell_count: number;
  ultimate_reward_base_chance_percent: number;
  ultimate_reward_min_gain_per_wave: number;
  ultimate_reward_max_gain_per_wave: number;
  legacy_enemy_ids: string[];
  validation_status: ValidationStatus;
  validation_errors: string[];
}

export interface ScaledInitialTotals {
  total_max_hp: number | null;
  total_attack_power: number | null;
}

export interface Wave {
  id: string;
  id_source: IdentitySource;
  identity_stability: IdentityStability;
  room_id: string;
  index: number;
  name: string;
  source_path: string;
  source_kind: 'resource' | 'subresource' | 'historical_fallback';
  encounter_id: string;
  enemy_health_multiplier: number;
  enemy_attack_multiplier: number;
  reward_multiplier: number;
  is_mandatory_profile: boolean;
  is_optional_profile: boolean;
  is_selected_by_default_seed: boolean;
  health_multiplier_runtime_target: string;
  attack_multiplier_runtime_target: string;
  attack_multiplier_effect_status: 'effective' | 'partially_effective' | 'no_active_source_detected' | 'unknown';
  attack_multiplier_effect_evidence: string;
  scaled_initial_totals: ScaledInitialTotals;
  calculation_status: CalculationStatus;
  calculation_evidence: string;
  validation_status: ValidationStatus;
  validation_errors: string[];
}

export interface EncounterRosterEntry { enemy_id: string; count: number }
export interface EncounterBaseTotals {
  initial_enemy_count: number;
  total_max_hp: number;
  total_max_ap: number;
  total_max_mp: number;
  total_attack_power: number;
  average_initiative: number;
  maximum_initiative: number;
}

export interface Encounter {
  id: string;
  id_source: IdentitySource;
  identity_stability: IdentityStability;
  source_path: string;
  room_ids: string[];
  wave_ids: string[];
  declared_room_index: number;
  roster: EncounterRosterEntry[];
  roster_unit_entry_count: number;
  roster_count_entry_count: number;
  initial_enemy_count: number;
  expanded_initial_enemy_ids: string[];
  allowed_spawn_groups: string[];
  formation_profiles: string[];
  living_enemy_cap: number;
  shared_normal_summon_budget: number;
  shared_chief_summon_budget: number;
  disabled_ability_ids: string[];
  maximum_formation_attempts: number;
  minimum_path_distance_by_role: Record<string, number>;
  maximum_path_distance_by_role: Record<string, number>;
  summon_free_neighbor_requirement: number;
  forbidden_initial_spawn_cells: Cell[];
  forbidden_initial_spawn_cell_count: number;
  base_totals: EncounterBaseTotals;
  role_counts: Record<string, number>;
  faction_counts: Record<string, number>;
  initial_enemy_spell_count: number;
  summon_spell_count: number;
  calculation_status: CalculationStatus;
  calculation_evidence: string;
  validation_status: ValidationStatus;
  validation_errors: string[];
}

export interface EnemyReachability {
  initial_encounter_ids: string[];
  initial_room_ids: string[];
  summonable_by_spell_ids: string[];
  initial_roster: boolean;
  summon_only: boolean;
}

export interface Enemy {
  id: string;
  id_source: 'explicit' | 'resource_path';
  identity_stability: IdentityStability;
  name: string;
  description: string;
  source_path: string;
  reachability: EnemyReachability;
  team: number;
  max_hp: number;
  initiative: number;
  max_ap: number;
  max_mp: number;
  attack_power: number;
  force: number;
  armour: number;
  magic_resistance: number;
  dodge: number;
  resistances: Record<string, number>;
  critical_chance: number;
  critical_multiplier: number;
  basic_attack_enabled: boolean;
  active_spell_slots: number;
  spell_ids: string[];
  ai_behavior: EnumValue;
  combat_style: EnumValue;
  preferred_range: number;
  minimum_range: number;
  maximum_range: number;
  keep_distance: boolean;
  ai_profile_id: string;
  faction_id: string;
  tactical_role_id: string;
  linked_commander_role_id: string;
  proximity_armor_source: string;
  proximity_armor_per_living_neighbor: number;
  proximity_armor_max_neighbors: number;
  first_forced_movement_reduction_per_activation: number;
  visual_scene_path: string;
  preview_visual_scene_path: string;
  effect_tags: string[];
  validation_status: ValidationStatus;
  validation_errors: string[];
}

export interface EnemySpell {
  id: string;
  discipline_id: string;
  name: string;
  description: string;
  ap_cost: number;
  minimum_range: number;
  range: number;
  needs_line_of_sight: boolean;
  cooldown_activations: number;
  initial_cooldown: number;
  max_uses_per_combat: number;
  once_per_activation: boolean;
  can_target_enemy: boolean;
  can_target_ally: boolean;
  can_target_free_cell: boolean;
  can_target_self: boolean;
  aoe_shape: EnumValue;
  aoe_size: number;
  damage: number;
  heal: number;
  shield_grant: number;
  damage_type: EnumValue;
  element: EnumValue;
  terrain_effect: ResourceReference | null;
  applied_status: ResourceReference | null;
  push_distance: number;
  pull_distance: number;
  collision_damage: number;
  cluster_bonus_damage: number;
  ap_drain: number;
  delayed_resolution: EnumValue;
  summon: ResourceReference | null;
  summon_type: string;
  source_path: string;
  referenced_by_enemy_ids: string[];
  summon_enemy_id: string;
  summon_starting_hp: number;
  summon_max_living_team: number;
  summon_initial_cooldowns: Record<string, number>;
  condition_hp_at_or_below: number;
  requires_absent_unit_id: string;
  encounter_enabled_in_ids: string[];
  encounter_disabled_in_ids: string[];
  effect_tags: string[];
}

export interface AIProfile {
  id: string;
  source_path: string;
  strategy: { name: string; value: number; description: string };
  marked_status_id: string;
  normal_role_id: string;
  chief_role_id: string;
  commander_role_id: string;
  sentence_hp_ratio_threshold: number;
  commander_emergency_hp: number;
  summon_when_normals_below: number;
  ideal_minimum_range: number;
  ideal_maximum_range: number;
  avoid_hero_adjacency: boolean;
  prefer_living_neighbors: boolean;
  protect_commander_paths: boolean;
  commander_distance_penalty_per_cell: number;
  commander_path_block_bonus: number;
  referenced_by_enemy_ids: string[];
}

export type ContractCheckStatus = 'conform' | 'difference' | 'unknown' | 'not_evaluated';

export interface ContractCheck {
  key: string;
  target: JsonValue;
  observed_value: JsonValue;
  status: ContractCheckStatus;
  evidence: string;
  message: string;
}

export type AuditSeverity = 'info' | 'warning' | 'blocking';

export interface AuditResult {
  rule_id: string;
  severity: AuditSeverity;
  status: string;
  domain: string;
  entity_type: string;
  entity_id: string;
  message: string;
  source_path: string;
  evidence: string;
  suggested_action: string;
}

export interface Snapshot {
  meta: SnapshotMeta;
  scope: SnapshotScope;
  summary: SnapshotSummary;
  contract: ObservatoryContract;
  characters: Character[];
  disciplines: Discipline[];
  spells: Spell[];
  items: Item[];
  reward_pools: RewardPool[];
  runs: Run[];
  rooms: Room[];
  waves: Wave[];
  encounters: Encounter[];
  enemies: Enemy[];
  enemy_spells: EnemySpell[];
  ai_profiles: AIProfile[];
  contract_checks: ContractCheck[];
  audit_results: AuditResult[];
}
