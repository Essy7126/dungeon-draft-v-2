import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  affectedRoomIds,
  auditEntityLink,
  filterAudits,
  groupAudits,
} from '../data/audit';
import type { Snapshot } from '../types';

const snapshot = JSON.parse(
  readFileSync(resolve('public', 'data', 'latest.json'), 'utf8'),
) as Snapshot;

describe('audit groupé sur le snapshot réel', () => {
  it('regroupe les 54 occurrences sans en supprimer aucune', () => {
    const raw = snapshot.audit_results.filter(
      (audit) => audit.rule_id === 'WAVE.ATTACK_MULTIPLIER_NO_ACTIVE_DAMAGE_SOURCE',
    );
    const group = groupAudits(raw)[0];
    expect(raw).toHaveLength(54);
    expect(group.occurrences).toHaveLength(54);
    expect(group.severity).toBe('warning');
    expect(group.truth_status).toBe('verified');
    expect(affectedRoomIds(snapshot, group)).toHaveLength(6);
  });

  it('combine recherche, sévérité, preuve, règle, domaine, entité et statut', () => {
    const result = filterAudits(snapshot.audit_results, {
      search: 'attack_power',
      severity: 'warning',
      truthStatus: 'verified',
      ruleId: 'WAVE.ATTACK_MULTIPLIER_NO_ACTIVE_DAMAGE_SOURCE',
      domain: 'waves',
      entityType: 'wave',
      status: 'open',
    });
    expect(result).toHaveLength(54);
    expect(result.every((audit) => audit.truth_status === 'verified')).toBe(true);
  });

  it('résout les liens contextuels sans inventer de route', () => {
    const waveAudit = snapshot.audit_results.find((audit) => audit.entity_type === 'wave');
    expect(waveAudit).toBeDefined();
    expect(auditEntityLink(snapshot, 'wave', waveAudit?.entity_id ?? '')).toMatch(/^\/rooms\//);
    expect(auditEntityLink(snapshot, 'unknown', 'missing')).toBeNull();
  });
});
