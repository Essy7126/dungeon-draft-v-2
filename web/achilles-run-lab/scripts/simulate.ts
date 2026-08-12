import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { createDefaultConfig } from '../src/content/defaults';
import { validateConfig } from '../src/content/content_loader';
import type { RunLabConfig } from '../src/content/schemas';
import { chooseAchillesCommand } from '../src/domain/ai/achilles_bot';
import type { GameState, RunReport } from '../src/domain/model/types';
import { applyGameCommand, createInitialGameState } from '../src/domain/run/engine';
import { createRunReport } from '../src/domain/telemetry/report';

interface Options { runs: number; seed: number; configPath: string | null; out: string | null; difficulty: number | null }
interface SimulationError { seed: number; message: string; screen: string; round: number | null; hash: string | null }

function parseOptions(args: string[]): Options {
  const read = (name: string): string | null => { const index = args.indexOf(name); return index >= 0 ? args[index + 1] ?? null : null; };
  return {
    runs: Math.max(1, Number.parseInt(read('--runs') ?? '1', 10)),
    seed: Math.max(1, Number.parseInt(read('--seed') ?? '12345', 10)),
    configPath: read('--config'),
    out: read('--out'),
    difficulty: read('--difficulty') === null ? null : Number(read('--difficulty')),
  };
}

async function loadConfig(options: Options): Promise<RunLabConfig> {
  const input: unknown = options.configPath === null ? createDefaultConfig(options.seed) : JSON.parse(await readFile(options.configPath, 'utf8')) as unknown;
  const result = validateConfig(input);
  if (!result.ok) throw new Error(`Configuration invalide :\n${result.errors.join('\n')}`);
  const config = structuredClone(result.config);
  config.seed = options.seed;
  if (options.difficulty !== null) config.difficulty = options.difficulty;
  const revalidated = validateConfig(config);
  if (!revalidated.ok) throw new Error(`Difficulté ou configuration invalide :\n${revalidated.errors.join('\n')}`);
  return revalidated.config;
}

function runSingle(baseConfig: RunLabConfig, seed: number): { report: RunReport | null; error: SimulationError | null } {
  const config = structuredClone(baseConfig);
  config.seed = seed;
  let state: GameState = createInitialGameState();
  const started = applyGameCommand(state, { type: 'START_RUN', seed, config });
  if (!started.accepted) return { report: null, error: { seed, message: started.error, screen: state.screen, round: null, hash: null } };
  state = started.state;
  let commandCount = 0;
  let commandsThisActivation = 0;
  let priorRound = state.battle?.round ?? null;
  const MAX_COMMANDS_PER_ACTIVATION = 20;
  const MAX_COMMANDS_PER_COMBAT = 700;
  const MAX_COMMANDS_PER_RUN = 2500;
  const commandsByRoom = new Map<number, number>();
  try {
    while (state.run?.result === 'IN_PROGRESS') {
      commandCount += 1;
      if (commandCount > MAX_COMMANDS_PER_RUN) throw new Error(`Limite par run dépassée (${MAX_COMMANDS_PER_RUN}).`);
      const room = state.run.currentRoomPosition;
      const roomCommands = (commandsByRoom.get(room) ?? 0) + 1;
      commandsByRoom.set(room, roomCommands);
      if (roomCommands > MAX_COMMANDS_PER_COMBAT) throw new Error(`Limite du combat ${room + 1} dépassée (${MAX_COMMANDS_PER_COMBAT}).`);
      const round = state.battle?.round ?? null;
      if (round !== priorRound || state.screen !== 'battle') { commandsThisActivation = 0; priorRound = round; }
      commandsThisActivation += 1;
      if (state.screen === 'battle' && commandsThisActivation > MAX_COMMANDS_PER_ACTIVATION) throw new Error(`Limite d’activation dépassée (${MAX_COMMANDS_PER_ACTIVATION}).`);
      const command = chooseAchillesCommand(state);
      const result = applyGameCommand(state, command);
      if (!result.accepted) throw new Error(`Commande bot rejetée : ${result.error} — ${JSON.stringify(command)}`);
      state = result.state;
    }
    return { report: createRunReport(state, 0, 'HEADLESS'), error: null };
  } catch (error) {
    return { report: null, error: { seed, message: error instanceof Error ? error.message : String(error), screen: state.screen, round: state.battle?.round ?? null, hash: state.stateHashes.at(-1) ?? null } };
  }
}

function percentile(values: number[], ratio: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((left, right) => left - right);
  return sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * ratio) - 1)] ?? 0;
}

const options = parseOptions(process.argv.slice(2));
const config = await loadConfig(options);
const reports: RunReport[] = [];
const errors: SimulationError[] = [];
for (let index = 0; index < options.runs; index += 1) {
  const result = runSingle(config, options.seed + index);
  if (result.report !== null) reports.push(result.report);
  if (result.error !== null) errors.push(result.error);
}
const wins = reports.filter((report) => report.result === 'WON').length;
const losses = reports.filter((report) => report.result === 'LOST').length;
const rounds = reports.map((report) => report.rounds);
const average = (values: number[]): number => values.length === 0 ? 0 : values.reduce((sum, value) => sum + value, 0) / values.length;
const sumMap = (selector: (report: RunReport) => Record<string, number>): Record<string, number> => reports.reduce<Record<string, number>>((result, report) => { for (const [key, value] of Object.entries(selector(report))) result[key] = (result[key] ?? 0) + value; return result; }, {});
const deathsByRoom: Record<string, number> = {};
for (const report of reports.filter((candidate) => candidate.result === 'LOST')) deathsByRoom[String(report.roomReached)] = (deathsByRoom[String(report.roomReached)] ?? 0) + 1;
const rewardPickRates: Record<string, number> = {};
for (const report of reports) for (const reward of report.rewards) rewardPickRates[reward] = (rewardPickRates[reward] ?? 0) + 1;
for (const key of Object.keys(rewardPickRates)) rewardPickRates[key] = (rewardPickRates[key] ?? 0) / Math.max(1, reports.length);
const aggregate = {
  notice: 'BOT HEURISTIQUE V1 — ces résultats ne remplacent pas des playtests humains.',
  runs: options.runs,
  wins,
  losses,
  winRate: wins / Math.max(1, reports.length),
  averageRounds: average(rounds),
  p50Rounds: percentile(rounds, 0.5),
  p90Rounds: percentile(rounds, 0.9),
  averageRemainingHp: average(reports.map((report) => report.remainingHp)),
  deathsByRoom,
  abilityUsage: sumMap((report) => report.abilityUsage),
  rewardPickRates,
  averageApUnused: average(reports.map((report) => report.apUnused)),
  averageMpUnused: average(reports.map((report) => report.mpUnused)),
  invalidCommandCount: reports.reduce((sum, report) => sum + (report.commands.length < 0 ? 1 : 0), 0),
  simulationErrors: errors,
};
if (Object.values(aggregate).some((value) => typeof value === 'number' && Number.isNaN(value))) throw new Error('NaN détecté dans le rapport agrégé.');
process.stdout.write(`${aggregate.notice}\n${JSON.stringify(aggregate, null, 2)}\n`);
if (options.out !== null) {
  const outputPath = path.resolve(options.out);
  await mkdir(path.dirname(outputPath), { recursive: true });
  await writeFile(outputPath, `${JSON.stringify({ aggregate, runs: reports }, null, 2)}\n`, 'utf8');
}
if (errors.length > 0) process.exitCode = 1;
