import { useEffect, useRef } from 'react';
import '@babylonjs/loaders/glTF';
import {
  Animation,
  ArcRotateCamera,
  Color3,
  DirectionalLight,
  Engine,
  HemisphericLight,
  MeshBuilder,
  PointerEventTypes,
  Scene,
  ShadowGenerator,
  StandardMaterial,
  TransformNode,
  Vector3,
  WebGPUEngine,
  type AbstractEngine,
  type AbstractMesh,
} from '@babylonjs/core';
import { ImportMeshAsync } from '@babylonjs/core/Loading/sceneLoader';
import type { AbilityId, Cell } from '../../content/schemas';
import type { GameState, UnitState } from '../../domain/model/types';
import { legalAbilityPreviews, legalMoveCells } from '../../domain/rules/legal_actions';
import { findPath, occupiedKeys, sameCell } from '../../domain/grid/grid';

export interface AssetRuntimeInfo {
  mode: 'GLB' | 'FALLBACK';
  meshes: string[];
  skeletons: string[];
  animations: string[];
  mapping: Record<string, string>;
  error: string | null;
}

interface BattleSceneProps {
  state: GameState;
  selectedAbility: AbilityId | null;
  onCell: (cell: Cell) => void;
  onUnit: (unitId: string) => void;
  onBackend: (backend: string) => void;
  onAssetInfo: (info: AssetRuntimeInfo) => void;
}

interface SceneContext {
  engine: AbstractEngine;
  scene: Scene;
  camera: ArcRotateCamera;
  tileLayer: TransformNode;
  unitLayer: TransformNode;
  assetRoot: TransformNode | null;
  assetLoaded: boolean;
  roomId: string | null;
}

const bronze = Color3.FromHexString('#c88b48');
const heroBlue = Color3.FromHexString('#477da1');

function material(scene: Scene, name: string, color: Color3, emissive = Color3.Black()): StandardMaterial {
  const value = new StandardMaterial(name, scene);
  value.diffuseColor = color;
  value.emissiveColor = emissive;
  value.specularColor = new Color3(0.12, 0.1, 0.08);
  return value;
}

function cellPosition(cell: Cell): Vector3 {
  return new Vector3(cell.x - 5.5, 0, cell.y - 5.5);
}

async function createEngine(canvas: HTMLCanvasElement): Promise<{ engine: AbstractEngine; backend: string }> {
  const forcedWebGl = new URLSearchParams(window.location.search).get('renderer') === 'webgl';
  if (!forcedWebGl) {
    try {
      if (await WebGPUEngine.IsSupportedAsync) {
        const webGpu = new WebGPUEngine(canvas, { antialias: true });
        await webGpu.initAsync();
        return { engine: webGpu, backend: 'WebGPU' };
      }
    } catch {
      // WebGPU is opportunistic; WebGL 2 remains the guaranteed path.
    }
  }
  const webGl = new Engine(canvas, true, { preserveDrawingBuffer: true, stencil: true, disableWebGL2Support: false });
  return { engine: webGl, backend: webGl.webGLVersion >= 2 ? 'WebGL 2' : 'WebGL 1 (dégradé)' };
}

function buildGrid(context: SceneContext, state: GameState): void {
  const battle = state.battle;
  if (battle === null) return;
  context.tileLayer.dispose(false, true);
  context.tileLayer = new TransformNode('tile-layer', context.scene);
  for (let y = 0; y < battle.grid.height; y += 1) {
    for (let x = 0; x < battle.grid.width; x += 1) {
      const cell = { x, y };
      const blocked = battle.grid.blockedCells.some((candidate) => sameCell(candidate, cell));
      const tile = MeshBuilder.CreateBox(`tile-${x}-${y}`, { width: 0.94, depth: 0.94, height: blocked ? 0.85 : 0.08 }, context.scene);
      tile.parent = context.tileLayer;
      tile.position = cellPosition(cell).add(new Vector3(0, blocked ? 0.42 : -0.04, 0));
      tile.metadata = { kind: 'cell', cell, blocked };
      tile.material = material(context.scene, `tile-mat-${x}-${y}`, blocked ? Color3.FromHexString('#282d32') : ((x + y) % 2 === 0 ? Color3.FromHexString('#34383a') : Color3.FromHexString('#2b3033')));
      tile.receiveShadows = true;
    }
  }
  context.roomId = battle.roomId;
}

function createHealthBars(scene: Scene, unit: UnitState, parent: TransformNode): void {
  const y = unit.definitionId === 'achilles' ? 1.85 : 1.65;
  const back = MeshBuilder.CreateBox(`hp-back-${unit.id}`, { width: 0.9, height: 0.08, depth: 0.05 }, scene);
  back.parent = parent;
  back.position = new Vector3(0, y, 0);
  back.material = material(scene, `hp-back-mat-${unit.id}`, Color3.FromHexString('#3a1517'));
  const ratio = Math.max(0.001, unit.hp / unit.maxHp);
  const fill = MeshBuilder.CreateBox(`hp-fill-${unit.id}`, { width: 0.9 * ratio, height: 0.085, depth: 0.055 }, scene);
  fill.parent = parent;
  fill.position = new Vector3(-0.45 * (1 - ratio), y, -0.03);
  fill.material = material(scene, `hp-fill-mat-${unit.id}`, Color3.FromHexString('#c2544e'), Color3.FromHexString('#3b0f0c'));
  if (unit.shield > 0) {
    const shieldRatio = Math.min(1, unit.shield / unit.maxHp);
    const shield = MeshBuilder.CreateBox(`shield-bar-${unit.id}`, { width: 0.9 * shieldRatio, height: 0.05, depth: 0.06 }, scene);
    shield.parent = parent;
    shield.position = new Vector3(-0.45 * (1 - shieldRatio), y + 0.1, -0.03);
    shield.material = material(scene, `shield-mat-${unit.id}`, Color3.FromHexString('#58a9cc'), Color3.FromHexString('#153748'));
  }
}

function tagUnitMeshes(root: TransformNode, unitId: string): void {
  for (const mesh of root.getChildMeshes()) mesh.metadata = { kind: 'unit', unitId };
}

function createProceduralAchilles(scene: Scene, parent: TransformNode): TransformNode {
  const root = new TransformNode('procedural-achilles', scene);
  root.parent = parent;
  const body = MeshBuilder.CreateCylinder('achilles-body', { height: 1.1, diameterTop: 0.52, diameterBottom: 0.68 }, scene);
  body.parent = root;
  body.position.y = 0.82;
  body.material = material(scene, 'achilles-body-mat', heroBlue, Color3.FromHexString('#081924'));
  const helmet = MeshBuilder.CreateSphere('achilles-helmet', { diameter: 0.48, segments: 12 }, scene);
  helmet.parent = root;
  helmet.position.y = 1.55;
  helmet.material = material(scene, 'achilles-helmet-mat', bronze, Color3.FromHexString('#28190b'));
  const crest = MeshBuilder.CreateBox('achilles-crest', { width: 0.12, height: 0.45, depth: 0.34 }, scene);
  crest.parent = root;
  crest.position = new Vector3(0, 1.92, 0);
  crest.material = material(scene, 'achilles-crest-mat', Color3.FromHexString('#8e3434'));
  const shield = MeshBuilder.CreateCylinder('achilles-shield', { height: 0.1, diameter: 0.78, tessellation: 24 }, scene);
  shield.parent = root;
  shield.rotation.z = Math.PI / 2;
  shield.position = new Vector3(-0.48, 0.9, 0);
  shield.material = material(scene, 'achilles-shield-mat', bronze, Color3.FromHexString('#2f1d0b'));
  const spear = MeshBuilder.CreateCylinder('achilles-spear', { height: 2.45, diameter: 0.065, tessellation: 8 }, scene);
  spear.parent = root;
  spear.position = new Vector3(0.48, 1.05, 0);
  spear.rotation.z = -0.12;
  spear.material = material(scene, 'achilles-spear-mat', Color3.FromHexString('#a88d65'));
  const idle = new Animation('procedural-idle', 'position.y', 24, Animation.ANIMATIONTYPE_FLOAT, Animation.ANIMATIONLOOPMODE_CYCLE);
  idle.setKeys([{ frame: 0, value: 0 }, { frame: 12, value: 0.05 }, { frame: 24, value: 0 }]);
  root.animations = [idle];
  scene.beginAnimation(root, 0, 24, true);
  return root;
}

function createEnemy(scene: Scene, unit: UnitState, parent: TransformNode): TransformNode {
  const root = new TransformNode(`enemy-${unit.id}`, scene);
  root.parent = parent;
  const isBrute = unit.definitionId === 'brute' || unit.definitionId === 'elite_brute';
  const isCenturion = unit.definitionId === 'centurion';
  const scale = isCenturion ? 1.2 : isBrute ? 1.08 : 0.9;
  const body = MeshBuilder.CreateCylinder(`enemy-body-${unit.id}`, { height: 1.25 * scale, diameterTop: 0.52 * scale, diameterBottom: 0.72 * scale, tessellation: 10 }, scene);
  body.parent = root;
  body.position.y = 0.68 * scale;
  const bodyColor = unit.definitionId === 'archer' ? Color3.FromHexString('#6d7652') : unit.definitionId === 'elite_brute' ? Color3.FromHexString('#693b43') : isCenturion ? Color3.FromHexString('#7c5632') : Color3.FromHexString('#5f6062');
  body.material = material(scene, `enemy-body-mat-${unit.id}`, bodyColor, unit.definitionId === 'elite_brute' || isCenturion ? Color3.FromHexString('#24100e') : Color3.Black());
  const head = MeshBuilder.CreateSphere(`enemy-head-${unit.id}`, { diameter: 0.42 * scale, segments: 10 }, scene);
  head.parent = root;
  head.position.y = 1.48 * scale;
  head.material = material(scene, `enemy-head-mat-${unit.id}`, Color3.FromHexString('#9b8d77'));
  const weapon = unit.definitionId === 'archer'
    ? MeshBuilder.CreateTorus(`enemy-bow-${unit.id}`, { diameter: 0.78, thickness: 0.055, tessellation: 18 }, scene)
    : MeshBuilder.CreateCylinder(`enemy-weapon-${unit.id}`, { height: isBrute ? 1.35 : 1.9, diameter: isBrute ? 0.14 : 0.055, tessellation: 8 }, scene);
  weapon.parent = root;
  weapon.position = new Vector3(0.45 * scale, 0.9 * scale, 0);
  if (unit.definitionId !== 'archer') weapon.rotation.z = -0.15;
  weapon.material = material(scene, `enemy-weapon-mat-${unit.id}`, isCenturion ? bronze : Color3.FromHexString('#756b5d'));
  if (unit.definitionId === 'elite_brute' || isCenturion) {
    const ring = MeshBuilder.CreateTorus(`elite-ring-${unit.id}`, { diameter: 0.95 * scale, thickness: 0.06, tessellation: 24 }, scene);
    ring.parent = root;
    ring.rotation.x = Math.PI / 2;
    ring.position.y = 0.05;
    ring.material = material(scene, `elite-ring-mat-${unit.id}`, bronze, bronze.scale(0.45));
  }
  return root;
}

function updateTiles(context: SceneContext, state: GameState, selectedAbility: AbilityId | null): void {
  const moves = legalMoveCells(state);
  const previews = selectedAbility === null ? [] : legalAbilityPreviews(state, selectedAbility);
  const legalCells = previews.flatMap((preview) => preview.targetCell === null ? [] : [preview.targetCell]);
  for (const mesh of context.tileLayer.getChildMeshes()) {
    const data = mesh.metadata as { cell?: Cell; blocked?: boolean } | null;
    if (data?.cell === undefined || !(mesh.material instanceof StandardMaterial)) continue;
    const move = moves.some((cell) => sameCell(cell, data.cell ?? { x: -1, y: -1 }));
    const target = legalCells.some((cell) => sameCell(cell, data.cell ?? { x: -1, y: -1 }));
    mesh.material.emissiveColor = target ? Color3.FromHexString('#6f3f0e') : move ? Color3.FromHexString('#183b32') : data.blocked === true ? Color3.FromHexString('#101215') : Color3.FromHexString('#11171b');
    mesh.material.diffuseColor = data.blocked === true ? Color3.FromHexString('#343a40') : target ? Color3.FromHexString('#d49a56') : move ? Color3.FromHexString('#4b8b75') : Color3.FromHexString('#52595f');
  }
}

function highlightHoveredPath(context: SceneContext, state: GameState, cell: Cell): void {
  if (state.battle === null) return;
  const hero = state.battle.units.find((unit) => unit.id === 'achilles');
  if (hero === undefined) return;
  const path = findPath(state.battle.grid, hero.position, cell, occupiedKeys(state.battle.units, hero.id));
  if (path === null || path.length > hero.mp) return;
  for (const mesh of context.tileLayer.getChildMeshes()) {
    const data = mesh.metadata as { cell?: Cell } | null;
    if (data?.cell !== undefined && path.some((pathCell) => sameCell(pathCell, data.cell ?? { x: -1, y: -1 })) && mesh.material instanceof StandardMaterial) {
      mesh.material.diffuseColor = Color3.FromHexString('#78b49e');
      mesh.material.emissiveColor = Color3.FromHexString('#214d40');
    }
  }
}

function updateUnits(context: SceneContext, state: GameState, selectedAbility: AbilityId | null): void {
  context.unitLayer.dispose(false, true);
  context.unitLayer = new TransformNode('unit-layer', context.scene);
  if (state.battle === null) return;
  const legalTargets = selectedAbility === null ? [] : legalAbilityPreviews(state, selectedAbility).flatMap((preview) => preview.targetUnitId === null ? [] : [preview.targetUnitId]);
  const forceFallback = new URLSearchParams(window.location.search).get('model') === 'fallback';
  for (const unit of state.battle.units.filter((candidate) => candidate.alive)) {
    if (unit.definitionId === 'achilles' && context.assetLoaded && context.assetRoot !== null && !forceFallback) {
      context.assetRoot.setEnabled(true);
      context.assetRoot.position = cellPosition(unit.position);
      context.assetRoot.position.y = 0.05;
      createHealthBars(context.scene, unit, context.assetRoot);
      continue;
    }
    const root = unit.definitionId === 'achilles' ? createProceduralAchilles(context.scene, context.unitLayer) : createEnemy(context.scene, unit, context.unitLayer);
    root.position = cellPosition(unit.position);
    if (legalTargets.includes(unit.id)) {
      for (const mesh of root.getChildMeshes()) {
        if (mesh.material instanceof StandardMaterial) mesh.material.emissiveColor = bronze.scale(0.65);
      }
    }
    createHealthBars(context.scene, unit, root);
    tagUnitMeshes(root, unit.id);
  }
  if ((forceFallback || !context.assetLoaded) && context.assetRoot !== null) context.assetRoot.setEnabled(false);
}

async function loadAchillesAsset(context: SceneContext, onInfo: (info: AssetRuntimeInfo) => void): Promise<void> {
  const forceFallback = new URLSearchParams(window.location.search).get('model') === 'fallback';
  if (forceFallback) {
    onInfo({ mode: 'FALLBACK', meshes: [], skeletons: [], animations: ['procedural-idle', 'procedural-walk', 'procedural-attack', 'procedural-guard', 'procedural-hit'], mapping: { idle: 'procedural-idle', walk: 'procedural-walk', attack: 'procedural-attack' }, error: null });
    return;
  }
  try {
    const result = await ImportMeshAsync('/assets/achilles/achilles.glb', context.scene);
    const root = new TransformNode('achilles-glb-root', context.scene);
    const imported = new Set(result.meshes);
    for (const mesh of result.meshes) {
      if (mesh.parent === null || !imported.has(mesh.parent as AbstractMesh)) mesh.parent = root;
      mesh.metadata = { kind: 'unit', unitId: 'achilles' };
      if (mesh.name !== '__root__') mesh.material = material(context.scene, `achilles-glb-mat-${mesh.name}`, heroBlue, Color3.FromHexString('#10232d'));
    }
    let minY = Number.POSITIVE_INFINITY;
    let maxY = Number.NEGATIVE_INFINITY;
    for (const mesh of result.meshes) {
      mesh.computeWorldMatrix(true);
      const bounds = mesh.getBoundingInfo().boundingBox;
      minY = Math.min(minY, bounds.minimumWorld.y);
      maxY = Math.max(maxY, bounds.maximumWorld.y);
    }
    const sourceHeight = maxY - minY;
    const normalizedScale = Number.isFinite(sourceHeight) && sourceHeight > 0.001 ? 1.8 / sourceHeight : 1;
    root.scaling = new Vector3(normalizedScale, normalizedScale, normalizedScale);
    root.rotationQuaternion = null;
    root.rotation.y = Math.PI;
    context.assetRoot = root;
    context.assetLoaded = true;
    const animationNames = result.animationGroups.map((group) => group.name);
    const find = (patterns: string[]): string => animationNames.find((name) => patterns.some((pattern) => name.toLowerCase().includes(pattern))) ?? '';
    const mapping = { idle: find(['idle']), walk: find(['walk', 'run']), attack: find(['attack', 'strike']) };
    const idleGroup = result.animationGroups.find((group) => group.name === mapping.idle) ?? result.animationGroups[0];
    idleGroup?.start(true);
    onInfo({ mode: 'GLB', meshes: result.meshes.map((mesh) => mesh.name), skeletons: result.skeletons.map((skeleton) => skeleton.name), animations: animationNames, mapping, error: null });
  } catch (error) {
    context.assetLoaded = false;
    onInfo({ mode: 'FALLBACK', meshes: [], skeletons: [], animations: ['procedural-idle', 'procedural-walk', 'procedural-attack', 'procedural-guard', 'procedural-hit'], mapping: { idle: 'procedural-idle', walk: 'procedural-walk', attack: 'procedural-attack' }, error: error instanceof Error ? error.message : String(error) });
  }
}

export function BattleScene({ state, selectedAbility, onCell, onUnit, onBackend, onAssetInfo }: BattleSceneProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const contextRef = useRef<SceneContext | null>(null);
  const callbacksRef = useRef({ onCell, onUnit });
  const stateRef = useRef(state);
  const selectedRef = useRef(selectedAbility);
  useEffect(() => {
    callbacksRef.current = { onCell, onUnit };
  }, [onCell, onUnit]);
  useEffect(() => {
    stateRef.current = state;
    selectedRef.current = selectedAbility;
  }, [selectedAbility, state]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (canvas === null) return;
    let removeKeyListener: (() => void) | null = null;
    void (async () => {
      const created = await createEngine(canvas);
      if (!canvas.isConnected) { created.engine.dispose(); return; }
      onBackend(created.backend);
      const scene = new Scene(created.engine);
      scene.clearColor.set(0.035, 0.045, 0.055, 1);
      const camera = new ArcRotateCamera('camera', -Math.PI / 4, 0.92, 16.5, new Vector3(0, 0, 0), scene);
      camera.lowerRadiusLimit = 10;
      camera.upperRadiusLimit = 23;
      camera.lowerBetaLimit = 0.55;
      camera.upperBetaLimit = 1.2;
      camera.attachControl(canvas, true);
      camera.wheelPrecision = 35;
      camera.panningSensibility = 900;
      new HemisphericLight('ambient', new Vector3(0, 1, 0), scene).intensity = 0.74;
      const key = new DirectionalLight('key', new Vector3(-0.7, -1, -0.45), scene);
      key.position = new Vector3(7, 12, 8);
      key.intensity = 1.35;
      const shadow = new ShadowGenerator(1024, key);
      shadow.useBlurExponentialShadowMap = true;
      const context: SceneContext = { engine: created.engine, scene, camera, tileLayer: new TransformNode('tile-layer', scene), unitLayer: new TransformNode('unit-layer', scene), assetRoot: null, assetLoaded: false, roomId: null };
      contextRef.current = context;
      if (stateRef.current.battle !== null) {
        buildGrid(context, stateRef.current);
        updateTiles(context, stateRef.current, selectedRef.current);
        updateUnits(context, stateRef.current, selectedRef.current);
      }
      scene.onPointerObservable.add((pointer) => {
        if (pointer.type === PointerEventTypes.POINTERMOVE && selectedRef.current === null && pointer.pickInfo?.pickedMesh !== null) {
          updateTiles(context, stateRef.current, selectedRef.current);
          const hover = pointer.pickInfo?.pickedMesh?.metadata as { kind?: string; cell?: Cell } | null;
          if (hover?.kind === 'cell' && hover.cell !== undefined) highlightHoveredPath(context, stateRef.current, hover.cell);
          return;
        }
        if (pointer.type !== PointerEventTypes.POINTERPICK || pointer.pickInfo?.pickedMesh === null) return;
        const data = pointer.pickInfo?.pickedMesh?.metadata as { kind?: string; unitId?: string; cell?: Cell } | null;
        if (data?.kind === 'unit' && data.unitId !== undefined) callbacksRef.current.onUnit(data.unitId);
        else if (data?.kind === 'cell' && data.cell !== undefined) callbacksRef.current.onCell(data.cell);
      });
      const keyListener = (event: KeyboardEvent): void => {
        if (event.key.toLowerCase() === 'q') camera.alpha -= Math.PI / 8;
        if (event.key.toLowerCase() === 'r') camera.alpha += Math.PI / 8;
      };
      window.addEventListener('keydown', keyListener);
      removeKeyListener = () => window.removeEventListener('keydown', keyListener);
      created.engine.runRenderLoop(() => scene.render());
      const resize = (): void => created.engine.resize();
      window.addEventListener('resize', resize);
      scene.onDisposeObservable.add(() => window.removeEventListener('resize', resize));
      await loadAchillesAsset(context, onAssetInfo);
      if (stateRef.current.battle !== null) updateUnits(context, stateRef.current, selectedRef.current);
    })();
    return () => {
      removeKeyListener?.();
      contextRef.current?.scene.dispose();
      contextRef.current?.engine.dispose();
      contextRef.current = null;
    };
  }, [onAssetInfo, onBackend]);

  useEffect(() => {
    const context = contextRef.current;
    if (context === null || state.battle === null) return;
    if (context.roomId !== state.battle.roomId) buildGrid(context, state);
    updateTiles(context, state, selectedAbility);
    updateUnits(context, state, selectedAbility);
  }, [state, selectedAbility]);

  return <canvas ref={canvasRef} className="battle-canvas" aria-label="Grille tactique 3D" data-testid="battle-canvas" />;
}
