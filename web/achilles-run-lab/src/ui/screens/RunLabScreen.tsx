import { useEffect, useState } from 'react';
import { createDefaultConfig } from '../../content/defaults';
import { importConfigJson, validateConfig } from '../../content/content_loader';
import type { AbilityDefinition, EnemyId, RunLabConfig } from '../../content/schemas';
import { LAB_KEY, downloadJson } from '../../persistence/save';

interface RunLabScreenProps {
  initialConfig: RunLabConfig;
  onBack: () => void;
  onStart: (config: RunLabConfig) => void;
}

type AbilityNumericField = 'baseDamage' | 'maxRange' | 'shield' | 'collisionDamage' | 'counterDamage';

export function RunLabScreen({ initialConfig, onBack, onStart }: RunLabScreenProps) {
  const [config, setConfig] = useState<RunLabConfig>(() => structuredClone(initialConfig));
  const [json, setJson] = useState(() => JSON.stringify(initialConfig, null, 2));
  const [errors, setErrors] = useState<string[]>([]);

  useEffect(() => {
    localStorage.setItem(LAB_KEY, JSON.stringify(config));
  }, [config]);

  const updateAbility = (index: number, field: AbilityNumericField, value: number): void => {
    setConfig((current) => {
      const next = structuredClone(current);
      const ability = next.abilities[index];
      if (ability !== undefined) ability[field] = Math.max(0, Math.round(value));
      return next;
    });
  };

  const updateEnemy = (index: number, field: 'maxHp' | 'armor', value: number): void => {
    setConfig((current) => {
      const next = structuredClone(current);
      const enemy = next.enemies[index];
      if (enemy !== undefined) enemy[field] = Math.max(field === 'maxHp' ? 1 : 0, Math.round(value));
      return next;
    });
  };

  const moveRoom = (index: number, delta: number): void => {
    setConfig((current) => {
      const next = structuredClone(current);
      const destination = index + delta;
      const room = next.rooms[index];
      if (room === undefined || destination < 0 || destination >= next.rooms.length) return current;
      next.rooms.splice(index, 1);
      next.rooms.splice(destination, 0, room);
      return next;
    });
  };

  const runValidation = (): RunLabConfig | null => {
    const result = validateConfig(config);
    if (!result.ok) { setErrors(result.errors); return null; }
    setErrors([]);
    return result.config;
  };

  const exportConfig = (): void => {
    const valid = runValidation();
    if (valid === null) return;
    const serialized = JSON.stringify(valid, null, 2);
    setJson(serialized);
    downloadJson(`achilles-run-lab-${valid.seed}.json`, serialized);
  };

  const importConfig = (): void => {
    const result = importConfigJson(json);
    if (!result.ok) { setErrors(result.errors); return; }
    setConfig(result.config);
    setErrors([]);
  };

  const abilityLabel = (ability: AbilityDefinition, field: AbilityNumericField): string => {
    if (field === 'baseDamage') return 'Dégâts';
    if (field === 'maxRange') return 'Portée';
    if (field === 'shield') return 'Bouclier';
    if (field === 'collisionDamage') return 'Collision';
    return 'Riposte';
  };

  return (
    <main className="lab-screen" data-testid="run-lab">
      <header className="lab-header"><button type="button" onClick={onBack}>← Menu</button><div><p className="eyebrow">OUTIL DE COMPOSITION DATA-DRIVEN</p><h1>Run Lab</h1></div><button type="button" className="primary" onClick={() => { const valid = runValidation(); if (valid !== null) onStart(valid); }} data-testid="lab-start">Lancer cette configuration →</button></header>
      <p className="lab-warning">EXPÉRIMENTAL — les résultats du bot et les valeurs du Lab ne constituent pas une validation d’équilibrage de production.</p>
      {errors.length > 0 && <div className="schema-errors" role="alert"><strong>Configuration refusée</strong>{errors.map((error) => <code key={error}>{error}</code>)}</div>}
      <div className="lab-layout">
        <section className="lab-column run-settings">
          <h2>Paramètres de run</h2>
          <label>Seed<input type="number" min="1" value={config.seed} onChange={(event) => setConfig({ ...config, seed: Math.max(1, Number(event.target.value) || 1) })} data-testid="lab-seed" /></label>
          <label>Difficulté <b>{config.difficulty.toFixed(2)}×</b><input type="range" min="0.75" max="2" step="0.05" value={config.difficulty} onChange={(event) => setConfig({ ...config, difficulty: Number(event.target.value) })} /></label>
          <label>Soin inter-salles <b>{Math.round(config.healPercent * 100)}%</b><input type="range" min="0" max="0.5" step="0.01" value={config.healPercent} onChange={(event) => setConfig({ ...config, healPercent: Number(event.target.value) })} /></label>
          <div className="locked-rule"><span>PA / PM</span><strong>6 / 3</strong><small>Verrouillés dans la V1</small></div>
          <h2>Capacités</h2>
          {config.abilities.map((ability, abilityIndex) => (
            <details key={ability.id}><summary>{ability.name}<span>{ability.baseDamage} dégâts · {ability.maxRange} portée</span></summary>
              <div className="numeric-grid">
                {(['baseDamage', 'maxRange', 'shield', 'collisionDamage', 'counterDamage'] as const).map((field) => <label key={field}>{abilityLabel(ability, field)}<input type="number" min="0" value={ability[field]} onChange={(event) => updateAbility(abilityIndex, field, Number(event.target.value))} data-testid={`ability-edit-${ability.id}-${field}`} /></label>)}
              </div>
            </details>
          ))}
          <h2>Ennemis</h2>
          {config.enemies.map((enemy, enemyIndex) => <div className="enemy-editor" key={enemy.id}><strong>{enemy.name}</strong><label>PV<input type="number" value={enemy.maxHp} min="1" onChange={(event) => updateEnemy(enemyIndex, 'maxHp', Number(event.target.value))} data-testid={`enemy-hp-${enemy.id}`} /></label><label>Armure<input type="number" value={enemy.armor} min="0" onChange={(event) => updateEnemy(enemyIndex, 'armor', Number(event.target.value))} /></label></div>)}
        </section>
        <section className="lab-column rooms-editor">
          <div className="section-heading"><div><h2>Composition des salles</h2><p>{config.rooms.filter((room) => room.active).length} salle(s) active(s)</p></div></div>
          {config.rooms.map((room, roomIndex) => (
            <article key={room.id} className={room.active ? '' : 'inactive'} data-testid={`lab-room-${roomIndex}`}>
              <div className="room-editor-head"><span className="room-index">{String(roomIndex + 1).padStart(2, '0')}</span><div><strong>{room.name}</strong><small>{room.objective}</small></div><label className="switch"><input type="checkbox" checked={room.active} onChange={(event) => setConfig((current) => { const next = structuredClone(current); const target = next.rooms[roomIndex]; if (target !== undefined) target.active = event.target.checked; return next; })} /> Active</label><div className="reorder"><button type="button" aria-label="Monter la salle" onClick={() => moveRoom(roomIndex, -1)}>↑</button><button type="button" aria-label="Descendre la salle" onClick={() => moveRoom(roomIndex, 1)}>↓</button></div></div>
              <div className="entries">
                {room.enemies.map((entry, entryIndex) => (
                  <div key={`${entry.enemyId}-${entryIndex}`}>
                    <select value={entry.enemyId} onChange={(event) => setConfig((current) => { const next = structuredClone(current); const target = next.rooms[roomIndex]?.enemies[entryIndex]; if (target !== undefined) target.enemyId = event.target.value as EnemyId; return next; })}>{config.enemies.map((enemy) => <option key={enemy.id} value={enemy.id}>{enemy.name}</option>)}</select>
                    <label>× <input type="number" min="0" max="12" value={entry.count} onChange={(event) => setConfig((current) => { const next = structuredClone(current); const target = next.rooms[roomIndex]?.enemies[entryIndex]; if (target !== undefined) target.count = Math.max(0, Math.round(Number(event.target.value))); return next; })} /></label>
                    <button type="button" onClick={() => setConfig((current) => { const next = structuredClone(current); next.rooms[roomIndex]?.enemies.splice(entryIndex, 1); return next; })}>Supprimer</button>
                  </div>
                ))}
                <button type="button" className="add-entry" onClick={() => setConfig((current) => { const next = structuredClone(current); next.rooms[roomIndex]?.enemies.push({ enemyId: 'spearman', count: 1 }); return next; })}>+ Ajouter une entrée ennemie</button>
              </div>
            </article>
          ))}
        </section>
        <section className="lab-column json-editor">
          <h2>Import / export</h2><p>Le JSON est validé avec les mêmes schémas que le moteur et le simulateur.</p>
          <textarea value={json} onChange={(event) => setJson(event.target.value)} spellCheck={false} aria-label="Configuration JSON" data-testid="lab-json" />
          <div className="json-actions"><button type="button" onClick={importConfig} data-testid="lab-import">Importer le JSON</button><button type="button" onClick={exportConfig}>Exporter le JSON</button><button type="button" onClick={() => { const restored = createDefaultConfig(config.seed); setConfig(restored); setJson(JSON.stringify(restored, null, 2)); setErrors([]); }}>Restaurer les défauts</button></div>
        </section>
      </div>
    </main>
  );
}
