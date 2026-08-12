import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { AbilityId, Cell, RunLabConfig } from '../content/schemas';
import { createDefaultConfig } from '../content/defaults';
import { importConfigJson } from '../content/content_loader';
import type { GameCommand, GameState, RunReport } from '../domain/model/types';
import { applyGameCommand, createInitialGameState } from '../domain/run/engine';
import { chooseAchillesCommand } from '../domain/ai/achilles_bot';
import { createRunReport } from '../domain/telemetry/report';
import { BattleScene, type AssetRuntimeInfo } from '../render/babylon/BattleScene';
import { clearSave, downloadJson, LAB_KEY, loadGame, loadLastReport, saveGame, saveLastReport } from '../persistence/save';
import { CombatScreen } from '../ui/screens/CombatScreen';
import { EndScreen } from '../ui/screens/EndScreen';
import { MenuScreen } from '../ui/screens/MenuScreen';
import { RewardScreen } from '../ui/screens/RewardScreen';
import { RunLabScreen } from '../ui/screens/RunLabScreen';

type UiScreen = 'menu' | 'game' | 'lab' | 'report';

const fallbackAssetInfo: AssetRuntimeInfo = { mode: 'FALLBACK', meshes: [], skeletons: [], animations: [], mapping: {}, error: null };

function initialLabConfig(): RunLabConfig {
  const raw = localStorage.getItem(LAB_KEY);
  if (raw !== null) {
    const parsed = importConfigJson(raw);
    if (parsed.ok) return parsed.config;
  }
  return createDefaultConfig(12345);
}

export function App() {
  const [state, setState] = useState<GameState>(() => createInitialGameState());
  const stateRef = useRef(state);
  const [uiScreen, setUiScreen] = useState<UiScreen>('menu');
  const [seed, setSeed] = useState(12345);
  const [labConfig, setLabConfig] = useState<RunLabConfig>(() => initialLabConfig());
  const [selectedAbility, setSelectedAbility] = useState<AbilityId | null>(null);
  const [selectedUnitId, setSelectedUnitId] = useState<string | null>(null);
  const [locked, setLocked] = useState(false);
  const [fastAnimations, setFastAnimations] = useState(true);
  const [rendererBackend, setRendererBackend] = useState('Initialisation…');
  const [assetInfo, setAssetInfo] = useState<AssetRuntimeInfo>(fallbackAssetInfo);
  const [saveMessage, setSaveMessage] = useState<string | null>(null);
  const [invalidSaveRaw, setInvalidSaveRaw] = useState<string | null>(null);
  const [lastReport, setLastReport] = useState<RunReport | null>(() => loadLastReport());
  const [startedAt, setStartedAt] = useState(0);

  useEffect(() => {
    stateRef.current = state;
  }, [state]);

  const dispatch = useCallback((command: GameCommand): boolean => {
    const result = applyGameCommand(stateRef.current, command);
    if (!result.accepted) {
      stateRef.current = result.state;
      setState(result.state);
      setSaveMessage(result.error);
      return false;
    }
    stateRef.current = result.state;
    setState(result.state);
    setSaveMessage(null);
    saveGame(result.state);
    if (result.state.run !== null && (result.state.screen === 'victory' || result.state.screen === 'defeat')) {
      const report = createRunReport(result.state, startedAt === 0 ? 0 : Math.round(performance.now() - startedAt), rendererBackend);
      setLastReport(report);
      saveLastReport(report);
    }
    if (result.events.length > 0) {
      setLocked(true);
      window.setTimeout(() => setLocked(false), fastAnimations ? 45 : Math.min(700, result.events.length * 110));
    }
    return true;
  }, [fastAnimations, rendererBackend, startedAt]);

  const startRun = useCallback((config: RunLabConfig) => {
    setLabConfig(structuredClone(config));
    setSeed(config.seed);
    setStartedAt(performance.now());
    setSelectedAbility(null);
    setSelectedUnitId(null);
    setUiScreen('game');
    dispatch({ type: 'START_RUN', seed: config.seed, config });
  }, [dispatch]);

  useEffect(() => {
    const onKey = (event: KeyboardEvent): void => {
      const target = event.target as HTMLElement | null;
      if (target?.tagName === 'INPUT' || target?.tagName === 'TEXTAREA' || target?.tagName === 'SELECT') return;
      if (uiScreen !== 'game' || stateRef.current.screen !== 'battle' || locked) return;
      const abilities: AbilityId[] = ['pursuit_thrust', 'bronze_bash', 'crossing_step', 'turning_guard'];
      const index = Number(event.key) - 1;
      if (index >= 0 && index < abilities.length) setSelectedAbility(abilities[index] ?? null);
      if (event.key === 'Escape') setSelectedAbility(null);
      if (event.code === 'Space') { event.preventDefault(); dispatch({ type: 'END_ACTIVATION', unitId: 'achilles' }); setSelectedAbility(null); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [dispatch, locked, uiScreen]);

  const onCell = useCallback((cell: Cell) => {
    if (locked || stateRef.current.screen !== 'battle') return;
    if (selectedAbility === 'crossing_step') {
      if (dispatch({ type: 'USE_ABILITY', unitId: 'achilles', abilityId: selectedAbility, targetUnitId: null, targetCell: cell })) setSelectedAbility(null);
    } else if (selectedAbility === null) {
      dispatch({ type: 'MOVE_UNIT', unitId: 'achilles', destination: cell });
    }
  }, [dispatch, locked, selectedAbility]);

  const onUnit = useCallback((unitId: string) => {
    setSelectedUnitId(unitId);
    if (locked || selectedAbility === null || selectedAbility === 'crossing_step' || selectedAbility === 'turning_guard') return;
    const unit = stateRef.current.battle?.units.find((candidate) => candidate.id === unitId);
    if (unit !== undefined && dispatch({ type: 'USE_ABILITY', unitId: 'achilles', abilityId: selectedAbility, targetUnitId: unitId, targetCell: unit.position })) setSelectedAbility(null);
  }, [dispatch, locked, selectedAbility]);

  const currentReport = useMemo(() => {
    if (state.run === null) return lastReport;
    if (lastReport?.seed === state.run.seed && lastReport.result === state.run.result) return lastReport;
    return createRunReport(state, 0, rendererBackend);
  }, [lastReport, rendererBackend, state]);

  const continueRun = (): void => {
    const loaded = loadGame();
    if (!loaded.ok) {
      setSaveMessage(loaded.error);
      setInvalidSaveRaw(loaded.raw);
      return;
    }
    setState(loaded.state);
    stateRef.current = loaded.state;
    setSeed(loaded.state.run?.seed ?? seed);
    setUiScreen('game');
    setInvalidSaveRaw(null);
    setSaveMessage('Sauvegarde reprise.');
    setStartedAt(performance.now());
  };

  const restart = (newSeed: number): void => {
    if (state.run === null) return;
    const config = structuredClone(state.run.config);
    config.seed = newSeed;
    startRun(config);
  };

  const assistActivation = (): void => {
    if (locked) return;
    for (let action = 0; action < 12 && stateRef.current.screen === 'battle'; action += 1) {
      const command = chooseAchillesCommand(stateRef.current);
      dispatch(command);
      if (command.type === 'END_ACTIVATION') break;
    }
    setSelectedAbility(null);
  };

  const exportReport = (): void => {
    const report = currentReport ?? loadLastReport();
    if (report === null) { setSaveMessage('Aucun rapport à exporter.'); return; }
    downloadJson(`achilles-run-report-${report.seed}.json`, report);
  };

  const handleBackend = useCallback((backend: string) => setRendererBackend(backend), []);
  const handleAssetInfo = useCallback((info: AssetRuntimeInfo) => setAssetInfo(info), []);

  const showGame = uiScreen === 'game' || uiScreen === 'report';
  return (
    <div className="app-shell" onContextMenu={(event) => { event.preventDefault(); setSelectedAbility(null); }}>
      {uiScreen === 'menu' && <MenuScreen seed={seed} onSeed={setSeed} onNewRun={() => startRun(createDefaultConfig(seed))} onContinue={continueRun} onLab={() => setUiScreen('lab')} onClear={() => { clearSave(); setSaveMessage('Sauvegarde effacée.'); setInvalidSaveRaw(null); }} onExportReport={invalidSaveRaw !== null ? () => downloadJson('achilles-invalid-save.json', invalidSaveRaw) : exportReport} saveMessage={saveMessage} lastReport={lastReport} />}
      {uiScreen === 'lab' && <RunLabScreen initialConfig={labConfig} onBack={() => setUiScreen('menu')} onStart={startRun} />}
      {showGame && state.battle !== null && <BattleScene state={state} selectedAbility={selectedAbility} onCell={onCell} onUnit={onUnit} onBackend={handleBackend} onAssetInfo={handleAssetInfo} />}
      {uiScreen === 'game' && state.screen === 'battle' && <CombatScreen state={state} selectedAbility={selectedAbility} selectedUnitId={selectedUnitId} locked={locked} fastAnimations={fastAnimations} onFastAnimations={setFastAnimations} onSelectAbility={(abilityId) => setSelectedAbility((current) => current === abilityId ? null : abilityId)} onMove={(cell) => dispatch({ type: 'MOVE_UNIT', unitId: 'achilles', destination: cell })} onUse={(abilityId, targetUnitId, targetCell) => { if (dispatch({ type: 'USE_ABILITY', unitId: 'achilles', abilityId, targetUnitId, targetCell })) setSelectedAbility(null); }} onEnd={() => { if (!locked) { dispatch({ type: 'END_ACTIVATION', unitId: 'achilles' }); setSelectedAbility(null); } }} onCancel={() => setSelectedAbility(null)} onMenu={() => setUiScreen('menu')} onAssist={assistActivation} />}
      {uiScreen === 'game' && state.screen === 'reward' && <RewardScreen state={state} onSelect={(rewardId) => dispatch({ type: 'SELECT_REWARD', rewardId })} onContinue={() => dispatch({ type: 'CONTINUE_TO_NEXT_ROOM' })} />}
      {uiScreen === 'game' && state.screen === 'victory' && currentReport !== null && <EndScreen kind="victory" report={currentReport} onSameSeed={() => restart(state.run?.seed ?? seed)} onNewSeed={() => restart((Date.now() % 2_147_483_646) + 1)} onMenu={() => setUiScreen('menu')} onReport={() => setUiScreen('report')} onExport={exportReport} />}
      {uiScreen === 'game' && state.screen === 'defeat' && currentReport !== null && <EndScreen kind="defeat" report={currentReport} onSameSeed={() => restart(state.run?.seed ?? seed)} onNewSeed={() => restart((Date.now() % 2_147_483_646) + 1)} onMenu={() => setUiScreen('menu')} onReport={() => setUiScreen('report')} onExport={exportReport} />}
      {uiScreen === 'report' && currentReport !== null && <EndScreen kind="report" report={currentReport} onSameSeed={() => restart(state.run?.seed ?? seed)} onNewSeed={() => restart((Date.now() % 2_147_483_646) + 1)} onMenu={() => setUiScreen('menu')} onReport={() => undefined} onExport={exportReport} />}
      {showGame && <details className="debug-panel"><summary>Diagnostic · {rendererBackend}</summary><div><span>Seed</span><code>{state.run?.seed ?? '—'}</code><span>Hash</span><code>{state.stateHashes.at(-1) ?? '—'}</code><span>Modèle</span><code>{assetInfo.mode}</code><span>Meshes</span><code>{assetInfo.meshes.join(', ') || 'procéduraux'}</code><span>Skeletons</span><code>{assetInfo.skeletons.join(', ') || 'aucun'}</code><span>Animations</span><code>{assetInfo.animations.join(', ') || 'procédurales'}</code>{assetInfo.error !== null && <><span>Erreur asset</span><code>{assetInfo.error}</code></>}</div></details>}
    </div>
  );
}
