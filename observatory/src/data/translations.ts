import type {
  CalculationStatus,
  IdentityStability,
  TruthStatus,
} from '../types';
import type { FreshnessStatus } from './buildMeta';

const aiStrategies: Record<string, string> = {
  FORMATION_MELEE: 'Assaut en formation',
  GUARDIAN_CHIEF: 'Chef gardien',
  RANGED_COMMANDER: 'Commandement à distance',
  melee: 'Mêlée',
};

const tacticalRoles: Record<string, string> = {
  skeleton_centurion: 'Centurion squelette',
  skeleton_chief: 'Chef squelette',
  skeleton_normal: 'Squelette de ligne',
  skirmisher: 'Éclaireur',
};

const damageTypes: Record<string, string> = {
  magical: 'Magiques',
  physical: 'Physiques',
};

const elements: Record<string, string> = {
  none: 'Aucun',
  fire: 'Feu',
  ice: 'Glace',
  lightning: 'Foudre',
  shadow: 'Ombre',
  holy: 'Sacré',
  earth: 'Terre',
};

const resistanceKeys: Record<string, string> = {
  '0': 'Neutre',
  '1': 'Feu',
  '2': 'Glace',
  '3': 'Foudre',
  '4': 'Ombre',
  '5': 'Sacré',
  '6': 'Terre',
  ...elements,
};

const calculations: Record<CalculationStatus | string, string> = {
  exact_runtime_equivalent: 'Équivalent runtime exact',
  static_base_only: 'Base statique uniquement',
  runtime_dependent: 'Dépend du runtime',
  unknown: 'Inconnu',
};

const multiplierStatuses: Record<string, string> = {
  effective: 'Effectif',
  partially_effective: 'Partiellement effectif',
  no_active_source_detected: 'Aucune source active détectée',
  unknown: 'Inconnu',
};

const effectTags: Record<string, string> = {
  damage: 'Dégâts',
  heal: 'Soin',
  shield: 'Bouclier',
  terrain: 'Terrain',
  status: 'Statut',
  push: 'Poussée',
  pull: 'Attraction',
  summon: 'Invocation',
  delayed: 'Résolution différée',
  commander: 'Commandement',
  control: 'Contrôle',
  forced_movement: 'Déplacement forcé',
  mark: 'Marque',
  melee: 'Mêlée',
  ranged: 'Distance',
  summoner: 'Invocateur',
  tank: 'Défense',
  support: 'Soutien',
};

const mapKinds: Record<string, string> = {
  painted: 'Carte peinte',
  generated: 'Carte générée',
  legacy_scene: 'Scène historique',
  unknown: 'Inconnu',
};

const sourceKinds: Record<string, string> = {
  resource: 'Ressource',
  subresource: 'Sous-ressource',
  historical_fallback: 'Fallback historique',
};

const identityStabilities: Record<IdentityStability | string, string> = {
  stable: 'Stable',
  derived: 'Dérivée',
  runtime_only: 'Runtime uniquement',
};

const truthStatuses: Record<TruthStatus, string> = {
  observed: 'OBSERVÉ',
  verified: 'VÉRIFIÉ',
  design_decision: 'DÉCISION DE CONCEPTION',
  recommendation: 'RECOMMANDATION',
  non_certified: 'NON CERTIFIÉ',
};

const freshnessStatuses: Record<FreshnessStatus, string> = {
  current: 'Snapshot courant',
  stale: 'Snapshot en retard',
  diverged: 'Snapshot divergent',
  unknown: 'Fraîcheur inconnue',
};

const modifierProperties: Record<string, string> = {
  damage_percent: 'Bonus de dégâts',
  range_bonus: 'Bonus de portée',
  push_bonus: 'Bonus de poussée',
  healing_and_shield_percent: 'Bonus de soin et de bouclier',
  target_spell_id: 'Sort ciblé',
};

const auditRules: Record<string, string> = {
  'WAVE.ATTACK_MULTIPLIER_NO_ACTIVE_DAMAGE_SOURCE': 'Multiplicateur de puissance d’attaque sans source de dégâts active',
  'IDENTITY.DERIVED_OBSERVATORY_ID': 'Identifiant Observatory dérivé',
  'CONTRACT.NOT_EVALUATED': 'Contrat non évalué',
};

const encounterAbilityStatuses: Record<string, string> = {
  active: 'ACTIVE DANS CETTE RENCONTRE',
  disabled: 'DÉSACTIVÉE DANS CETTE RENCONTRE',
  conditional: 'CONDITIONNELLE',
  unknown: 'INCONNUE',
};

export function humanizeIdentifier(value: string): string {
  const words = value.replaceAll('.', ' ').replaceAll('_', ' ').trim().toLocaleLowerCase('fr');
  return words ? words.charAt(0).toLocaleUpperCase('fr') + words.slice(1) : 'Non renseigné';
}

function translated(dictionary: Record<string, string>, value: string): string {
  return dictionary[value] ?? humanizeIdentifier(value);
}

export const labelAiStrategy = (value: string) => translated(aiStrategies, value);
export const labelTacticalRole = (value: string) => translated(tacticalRoles, value);
export const labelDamageType = (value: string) => translated(damageTypes, value);
export const labelElement = (value: string) => translated(elements, value);
export const labelResistance = (value: string) => translated(resistanceKeys, value);
export const labelCalculationStatus = (value: string) => translated(calculations, value);
export const labelMultiplierStatus = (value: string) => translated(multiplierStatuses, value);
export const labelEffectTag = (value: string) => translated(effectTags, value);
export const labelMapKind = (value: string) => translated(mapKinds, value);
export const labelSourceKind = (value: string) => translated(sourceKinds, value);
export const labelIdentityStability = (value: string) => translated(identityStabilities, value);
export const labelTruthStatus = (value: TruthStatus) => truthStatuses[value];
export const labelFreshnessStatus = (value: FreshnessStatus) => freshnessStatuses[value];
export const labelModifierProperty = (value: string) => translated(modifierProperties, value);
export const labelAuditRule = (value: string) => translated(auditRules, value);
export const labelEncounterAbilityStatus = (value: string) => translated(encounterAbilityStatuses, value);
