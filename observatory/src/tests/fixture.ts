import type { Snapshot } from '../types';

export const snapshotFixture: Snapshot = {
  meta: {
    schema_version: '1.0.0', generator_version: '1.0.0', generated_at_utc: '2026-08-05T12:00:00', source_game_commit: 'abc123456789', source_branch: 'feature/test', source_worktree_dirty_before_export: false, godot_version: '4.7.1', project_name: 'Dungeon Draft v2', contract_version: '1.0.0', manifest_version: '1.0.0',
  },
  scope: {
    included_domains: ['characters', 'spells', 'items'],
    deferred_domains: [{ domain: 'rooms', reason: 'Détail reporté.', status: 'deferred' }],
    excluded_domains: [{ domain: 'debug', reason: 'Hors production.', path: 'res://debug' }],
  },
  summary: {
    characters: 1, disciplines: 1, spells: 1, items: 2, generic_rewards: 1, reward_pools: 2, eligible_first_run_equipment: 1, contract_conform: 1, contract_difference: 0, contract_unknown: 0, contract_not_evaluated: 1, audit_info: 1, audit_warning: 0, audit_blocking: 0,
  },
  contract: { version: '1.0.0', decisions: [{ key: 'combat.base_ap', value: 6, status: 'validated', source: 'Mission', rationale: 'Référence.' }] },
  characters: [{
    id: 'elf', name: 'Élfe', description: 'Héroïne de test.', role: 'Polyvalente', presentation_summary: 'Quatre voies.', progression_summary: 'Une discipline', max_hp: 100, max_ap: 6, max_mp: 3, initiative: 10, attack_power: 20, active_spell_slots: 4, spell_ids: ['elf_fireball'], discipline_ids: ['mage'], source_path: 'res://data/elf.tres', visual_scene_path: 'res://characters/elf.tscn', preview_visual_scene_path: '',
  }],
  spells: [{
    id: 'elf_fireball', discipline_id: 'mage', name: 'Boule de feu', description: 'Inflige des dégâts de feu.', referenced_by_character_ids: ['elf'], ap_cost: 3, minimum_range: 1, range: 5, needs_line_of_sight: true, cooldown_activations: 0, max_uses_per_combat: 0, can_target_enemy: true, can_target_ally: false, can_target_free_cell: true, can_target_self: false, aoe_shape: { value: 1, name: 'cross' }, aoe_size: 2, damage: 20, heal: 0, shield_grant: 0, damage_type: { value: 1, name: 'magical' }, element: { value: 1, name: 'fire' }, terrain_effect: { resource_type: 'TerrainEffectData', resource_path: 'res://terrain/fire.tres' }, applied_status: null, push_distance: 0, pull_distance: 0, delayed_resolution: { value: 0, name: 'none' }, summon: null, summon_type: '', modifiers: [], source_path: 'res://spells/fireball.tres',
  }],
  disciplines: [{
    id: 'mage', character_id: 'elf', name: 'Magie', description: 'Maîtrise élémentaire.', rank_count: 2, total_choice_count: 1, ranks: [{ rank: 1, required_total_xp: 0, choices: [], source_path: 'res://disciplines/mage1.tres' }, { rank: 2, required_total_xp: 5, choices: [{ upgrade_id: 'mage_power', name: 'Puissance', description: 'Ajoute des dégâts.', discipline_id: 'mage', rank: 2, target_spell_id: 'elf_fireball', prerequisite_ids: [], excluded_ids: [], modifiers: [{ resource_type: 'SpellModDamage', resource_path: 'res://mods/power.tres', damage_bonus: 5 }], source_path: 'res://upgrades/power.tres' }], source_path: 'res://disciplines/mage2.tres' }], source_path: 'res://disciplines/mage.tres',
  }],
  items: [
    { id: 'anneau', name: 'Anneau élémentaire', description: 'Renforce les sorts.', rarity: 'rare', tags: ['accessory', 'first_run_equipment_reward'], category: { value: 2, name: 'accessory' }, equipment_slot: { value: 1, name: 'ring' }, compatible_character_ids: [], stat_modifiers: [{ stat_id: 'armure', value: -2, modifier_type: { value: 0, name: 'flat' }, source_path: 'res://items/ring.tres::armour' }], spell_modifiers: [], use_effect: { value: 0, name: 'none' }, equippable: true, consumable: false, valid: true, pool_ids: ['first_run_equipment'], source_path: 'res://items/ring.tres' },
    { id: 'potion', name: 'Potion de soin', description: 'Rend des points de vie.', rarity: 'common', tags: ['consumable'], category: { value: 1, name: 'consumable' }, equipment_slot: { value: 0, name: 'none' }, compatible_character_ids: ['elf'], stat_modifiers: [], spell_modifiers: [], use_effect: { value: 1, name: 'heal' }, equippable: false, consumable: true, valid: true, pool_ids: [], source_path: 'res://items/potion.tres' },
  ],
  reward_pools: [
    { id: 'generic', name: 'Génériques', kind: 'generic_declared', mechanism: 'static', status: 'declared_and_referenced', required_tag: '', minimum_options: 0, item_ids: [], rewards: [{ id: 'heal', name: 'Soin', description: 'Soigne le groupe.', reward_type: { value: 0, name: 'team_heal' }, target_policy: { value: 0, name: 'team' }, value: 0.2, valid: true, usage_status: 'declared_and_referenced_by_service', source_path: 'res://rewards/heal.tres' }], source_path: 'res://services/rewards.gd' },
    { id: 'first_run_equipment', name: 'Équipements', kind: 'equipment_first_run', mechanism: 'seeded_deck_without_replacement', status: 'eligible_catalog', required_tag: 'first_run_equipment_reward', minimum_options: 1, item_ids: ['anneau'], rewards: [], source_path: 'res://services/equipment.gd' },
  ],
  contract_checks: [
    { key: 'combat.base_ap', target: 6, observed_value: 6, status: 'conform', evidence: 'UnitData.max_ap', message: 'Conforme.' },
    { key: 'progression.xp', target: 1, observed_value: null, status: 'not_evaluated', evidence: 'Aucune preuve statique.', message: 'Non évalué.' },
  ],
  audit_results: [{ rule_id: 'CONTRACT.NOT_EVALUATED', severity: 'info', status: 'open', domain: 'contract', entity_type: 'contract_check', entity_id: 'progression.xp', message: 'Cible non évaluée.', source_path: 'docs/observatory/design_contract.json', evidence: 'Aucune preuve.', suggested_action: 'Exporter une preuve.' }],
};
