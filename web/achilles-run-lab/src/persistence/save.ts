import { z } from 'zod';
import { RunLabConfigSchema, SAVE_VERSION } from '../content/schemas';
import type { GameState, RunReport } from '../domain/model/types';

export const SAVE_KEY = 'dungeon-draft-achilles-web-run-lab-save-v1';
export const LAB_KEY = 'dungeon-draft-achilles-web-run-lab-config-v1';
export const REPORT_KEY = 'dungeon-draft-achilles-web-run-lab-report-v1';

const CellSchema = z.object({ x: z.number().int(), y: z.number().int() });
const UnitStateSchema = z.object({
  id: z.string(), definitionId: z.string(), name: z.string(), team: z.enum(['HERO', 'ENEMY']), position: CellSchema,
  hp: z.number().min(0), maxHp: z.number().positive(), armor: z.number(), shield: z.number().min(0),
  ap: z.number().min(0), mp: z.number().min(0), maxAp: z.number().min(0), maxMp: z.number().min(0),
  usedAbilities: z.array(z.string()), lastActionTag: z.enum(['NONE', 'STEP', 'SPEAR', 'SHIELD', 'GUARD']), statuses: z.array(z.literal('STAGGERED')),
  guardCounterDamage: z.number().nullable(), agileRefundUsed: z.boolean(), alive: z.boolean(),
});
const BattleStateSchema = z.object({
  roomId: z.string(), roomName: z.string(), roomPosition: z.number().int().min(0), round: z.number().int().positive(),
  grid: z.object({ width: z.number().int().positive(), height: z.number().int().positive(), blockedCells: z.array(CellSchema), reinforcementSpawnCells: z.array(CellSchema) }),
  units: z.array(UnitStateSchema), reinforcementTriggered: z.boolean(),
});
const MetricsSchema = z.object({
  rounds: z.number().int().min(0),
  abilityUsage: z.object({ pursuit_thrust: z.number().int().min(0), bronze_bash: z.number().int().min(0), crossing_step: z.number().int().min(0), turning_guard: z.number().int().min(0) }),
  damageDealt: z.number().min(0), damageTaken: z.number().min(0), apSpent: z.number().min(0), apUnused: z.number().min(0),
  mpSpent: z.number().min(0), mpUnused: z.number().min(0), invalidCommandCount: z.number().int().min(0),
});
const RunStateSchema = z.object({
  seed: z.number().int().positive(), rngState: z.number().int().nonnegative(), config: RunLabConfigSchema,
  activeRoomIds: z.array(z.string()).min(1), currentRoomPosition: z.number().int().min(0),
  persistentHeroHp: z.number().min(0), persistentHeroMaxHp: z.number().positive(),
  acquiredRewards: z.array(z.string()), result: z.enum(['IN_PROGRESS', 'WON', 'LOST']), metrics: MetricsSchema,
});
const GameStateSchema = z.object({
  saveVersion: z.literal(SAVE_VERSION), contentVersion: z.string(), engineVersion: z.string(),
  screen: z.enum(['menu', 'battle', 'reward', 'victory', 'defeat', 'report']), run: RunStateSchema,
  battle: BattleStateSchema.nullable(), rewardOffer: z.array(z.string()), acceptedCommands: z.array(z.unknown()),
  stateHashes: z.array(z.string()), eventLog: z.array(z.unknown()),
});
const SaveEnvelopeSchema = z.object({
  saveVersion: z.literal(SAVE_VERSION),
  savedAt: z.string(),
  state: GameStateSchema,
});

export type SaveLoadResult =
  | { ok: true; state: GameState }
  | { ok: false; error: string; raw: string | null };

export function saveGame(state: GameState): void {
  if (state.run === null) return;
  const envelope = { saveVersion: SAVE_VERSION, savedAt: new Date().toISOString(), state };
  localStorage.setItem(SAVE_KEY, JSON.stringify(envelope));
}

export function loadGame(): SaveLoadResult {
  const raw = localStorage.getItem(SAVE_KEY);
  if (raw === null) return { ok: false, error: 'Aucune sauvegarde locale.', raw: null };
  try {
    const parsed = SaveEnvelopeSchema.safeParse(JSON.parse(raw) as unknown);
    if (!parsed.success) {
      const issue = parsed.error.issues[0];
      return { ok: false, error: `Sauvegarde incompatible à ${issue?.path.join('.') ?? '$'} : ${issue?.message ?? 'format invalide'}`, raw };
    }
    return { ok: true, state: parsed.data.state as GameState };
  } catch (error) {
    return { ok: false, error: `Sauvegarde corrompue : ${error instanceof Error ? error.message : String(error)}`, raw };
  }
}

export function clearSave(): void {
  localStorage.removeItem(SAVE_KEY);
}

export function saveLastReport(report: RunReport): void {
  localStorage.setItem(REPORT_KEY, JSON.stringify(report));
}

export function loadLastReport(): RunReport | null {
  const raw = localStorage.getItem(REPORT_KEY);
  if (raw === null) return null;
  try { return JSON.parse(raw) as RunReport; } catch { return null; }
}

export function downloadJson(filename: string, data: unknown): void {
  const blob = new Blob([typeof data === 'string' ? data : JSON.stringify(data, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}
