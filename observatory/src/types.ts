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
  contract_checks: ContractCheck[];
  audit_results: AuditResult[];
}
