import { describe, expect, it } from 'vitest';
import {
  labelAiStrategy,
  labelAuditRule,
  labelCalculationStatus,
  labelEffectTag,
  labelElement,
  labelIdentityStability,
  labelMapKind,
  labelMultiplierStatus,
  labelResistance,
  labelSourceKind,
  labelTacticalRole,
  labelTruthStatus,
} from '../data/translations';

describe('traductions Observatory centralisées', () => {
  it('traduit les enums métier et conserve un fallback lisible', () => {
    expect(labelCalculationStatus('static_base_only')).toBe('Base statique uniquement');
    expect(labelMultiplierStatus('no_active_source_detected')).toBe('Aucune source active détectée');
    expect(labelEffectTag('forced_movement')).toBe('Déplacement forcé');
    expect(labelTacticalRole('skeleton_centurion')).toBe('Centurion squelette');
    expect(labelAiStrategy('RANGED_COMMANDER')).toBe('Commandement à distance');
    expect(labelElement('lightning')).toBe('Foudre');
    expect(labelResistance('2')).toBe('Glace');
    expect(labelMapKind('legacy_scene')).toBe('Scène historique');
    expect(labelSourceKind('historical_fallback')).toBe('Fallback historique');
    expect(labelIdentityStability('runtime_only')).toBe('Runtime uniquement');
    expect(labelTruthStatus('design_decision')).toBe('DÉCISION DE CONCEPTION');
    expect(labelAuditRule('UNKNOWN_RULE')).toBe('Unknown rule');
  });
});
