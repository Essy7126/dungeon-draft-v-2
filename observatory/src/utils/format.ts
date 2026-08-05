import type { JsonValue } from '../types';

export function formatDate(value: string): string {
  const date = new Date(value.endsWith('Z') ? value : `${value}Z`);
  return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat('fr-FR', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'UTC' }).format(date);
}

export function formatValue(value: JsonValue): string {
  if (value === null) return 'Non renseigné';
  if (typeof value === 'boolean') return value ? 'Oui' : 'Non';
  if (typeof value === 'number') return new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 }).format(value);
  if (typeof value === 'string') return value || 'Non renseigné';
  return JSON.stringify(value);
}

export function theoreticalApBudget(maxAp: number, apCost: number): number | null {
  if (apCost <= 0) return null;
  return Math.floor(maxAp / apCost);
}

export function uniqueSorted(values: readonly string[]): string[] {
  return [...new Set(values.filter(Boolean))].sort((left, right) => left.localeCompare(right, 'fr'));
}
