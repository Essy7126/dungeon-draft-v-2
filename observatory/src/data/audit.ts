import type { AuditResult, AuditSeverity, Snapshot, TruthStatus } from '../types';
import { createSnapshotIndex, type SnapshotIndex } from './indexes';
import { normalizeSearch } from './selectors';

export interface AuditFilters {
  search: string;
  severity: '' | AuditSeverity;
  truthStatus: '' | TruthStatus;
  ruleId: string;
  domain: string;
  entityType: string;
  status: string;
}

export interface AuditGroup {
  key: string;
  rule_id: string;
  severity: AuditSeverity;
  truth_status: TruthStatus;
  occurrences: AuditResult[];
  entity_ids: string[];
  domains: string[];
  entity_types: string[];
}

export const EMPTY_AUDIT_FILTERS: AuditFilters = {
  search: '',
  severity: '',
  truthStatus: '',
  ruleId: '',
  domain: '',
  entityType: '',
  status: '',
};

const snapshotIndexes = new WeakMap<Snapshot, SnapshotIndex>();

function cachedIndex(snapshot: Snapshot): SnapshotIndex {
  const existing = snapshotIndexes.get(snapshot);
  if (existing) return existing;
  const created = createSnapshotIndex(snapshot);
  snapshotIndexes.set(snapshot, created);
  return created;
}

export function filterAudits(
  audits: readonly AuditResult[],
  filters: AuditFilters,
): AuditResult[] {
  const query = normalizeSearch(filters.search);
  return audits.filter((audit) => {
    const haystack = normalizeSearch([
      audit.rule_id,
      audit.message,
      audit.evidence,
      audit.suggested_action,
      audit.domain,
      audit.entity_type,
      audit.entity_id,
      ...audit.affected_entity_ids,
    ].join(' '));
    return (!query || haystack.includes(query))
      && (!filters.severity || audit.severity === filters.severity)
      && (!filters.truthStatus || audit.truth_status === filters.truthStatus)
      && (!filters.ruleId || audit.rule_id === filters.ruleId)
      && (!filters.domain || audit.domain === filters.domain)
      && (!filters.entityType || audit.entity_type === filters.entityType)
      && (!filters.status || audit.status === filters.status);
  });
}

export function groupAudits(audits: readonly AuditResult[]): AuditGroup[] {
  const groups = new Map<string, AuditGroup>();
  for (const audit of audits) {
    const key = `${audit.rule_id}::${audit.severity}::${audit.truth_status}`;
    const group = groups.get(key);
    if (group) {
      group.occurrences.push(audit);
      group.entity_ids.push(audit.entity_id, ...audit.affected_entity_ids);
      group.domains.push(audit.domain);
      group.entity_types.push(audit.entity_type, audit.affected_entity_type);
    } else {
      groups.set(key, {
        key,
        rule_id: audit.rule_id,
        severity: audit.severity,
        truth_status: audit.truth_status,
        occurrences: [audit],
        entity_ids: [audit.entity_id, ...audit.affected_entity_ids],
        domains: [audit.domain],
        entity_types: [audit.entity_type, audit.affected_entity_type],
      });
    }
  }
  return [...groups.values()].map((group) => ({
    ...group,
    entity_ids: [...new Set(group.entity_ids.filter(Boolean))].sort(),
    domains: [...new Set(group.domains.filter(Boolean))].sort(),
    entity_types: [...new Set(group.entity_types.filter(Boolean))].sort(),
  })).sort((left, right) =>
    right.occurrences.length - left.occurrences.length
    || left.rule_id.localeCompare(right.rule_id),
  );
}

export function auditEntityLink(
  snapshot: Snapshot,
  entityType: string,
  entityId: string,
): string | null {
  const index = cachedIndex(snapshot);
  if (entityType === 'wave') {
    const roomId = index.wavesById.get(entityId)?.room_id;
    return roomId ? `/rooms/${roomId}` : null;
  }
  if (entityType === 'room' && index.roomsById.has(entityId)) return `/rooms/${entityId}`;
  if (entityType === 'enemy' && index.enemiesById.has(entityId)) return `/enemies/${entityId}`;
  if (entityType === 'spell') {
    if (index.spells.has(entityId)) return `/spells/${entityId}`;
    const enemyId = index.enemySpellsById.get(entityId)?.referenced_by_enemy_ids[0];
    return enemyId ? `/enemies/${enemyId}` : null;
  }
  if (entityType === 'enemy_spell') {
    const enemyId = index.enemySpellsById.get(entityId)?.referenced_by_enemy_ids[0];
    return enemyId ? `/enemies/${enemyId}` : null;
  }
  if (entityType === 'character' && index.characters.has(entityId)) return `/characters/${entityId}`;
  if (entityType === 'item' && index.items.has(entityId)) return `/items/${entityId}`;
  if (entityType === 'discipline' && index.disciplines.has(entityId)) return `/disciplines/${entityId}`;
  if (entityType === 'encounter') {
    const roomId = index.encountersById.get(entityId)?.room_ids[0];
    return roomId ? `/rooms/${roomId}` : null;
  }
  if (entityType === 'run' && index.runsById.has(entityId)) return '/run';
  return null;
}

export function affectedRoomIds(snapshot: Snapshot, group: AuditGroup): string[] {
  if (!group.entity_types.includes('wave')) return [];
  const index = cachedIndex(snapshot);
  return [...new Set(group.entity_ids.flatMap((id) => {
    const roomId = index.wavesById.get(id)?.room_id;
    return roomId ? [roomId] : [];
  }))].sort();
}
