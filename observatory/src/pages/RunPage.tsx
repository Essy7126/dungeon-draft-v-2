import { useMemo } from 'react';
import { Link, useParams } from 'react-router-dom';
import { MetricCard, PageHeader, Panel, SourceDetails } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';
import {
  encounterForRoom,
  orderedRoomsForRun,
  selectedWavesForRoom,
} from '../data/selectors';
import { labelIdentityStability, labelMapKind, labelTacticalRole } from '../data/translations';
import { formatMultiplier } from '../utils/format';
import { UnknownEntityPage } from './UnknownEntityPage';

const flowLabels = {
  single_encounter: 'Rencontre unique',
  wave_chain: 'Chaîne de vagues',
  unknown: 'Mode inconnu',
} as const;

function namedCounts(values: Record<string, number>): string {
  return Object.entries(values)
    .map(([name, count]) => `${labelTacticalRole(name)} ×${count}`)
    .join(', ') || 'Aucun';
}

export function RunPage() {
  const { runId } = useParams<{ runId?: string }>();
  const snapshot = useSnapshot();
  const index = useMemo(() => createSnapshotIndex(snapshot), [snapshot]);
  const selectedRunId = runId ?? snapshot.primary_run_id;
  const run = index.runsById.get(selectedRunId);
  if (!run) return <UnknownEntityPage kind="run" id={selectedRunId} backTo="/runs" />;

  const rooms = orderedRoomsForRun(snapshot, run.id);
  const isWaveChain = run.flow_mode === 'wave_chain';

  return (
    <>
      <Link className="back-link" to="/runs">← Toutes les runs</Link>
      <PageHeader
        eyebrow={`${run.run_kind === 'production' ? 'Production' : 'Outil de test'} · ${run.id}`}
        title={run.name}
        description={`Mode : ${flowLabels[run.flow_mode]}. Données statiques issues de la Resource déclarée.`}
      >
        {isWaveChain ? <span className="count-chip">seed {run.default_seed}</span> : null}
      </PageHeader>

      {run.run_kind === 'test' ? (
        <p className="test-tool-warning" role="note">
          Outil de test — cette run et ses profils de vague ne décrivent pas la production.
        </p>
      ) : null}

      <section className="metrics-grid run-metrics" aria-label="Métadonnées de la run">
        <MetricCard label="Mode" value={flowLabels[run.flow_mode]} tone="gold" />
        <MetricCard label="Salles" value={run.authored_room_count} />
        <MetricCard label="Combats effectifs" value={run.effective_combat_count} />
        <MetricCard label="Durée cible" value={`${run.target_duration_minutes} min`} />
        <MetricCard label="Validité" value={run.validation_status} />
      </section>

      {isWaveChain ? (
        <>
          <section className="metrics-grid run-profile-metrics" aria-label="Profils de vague de la run de test">
            <MetricCard label="Profils de vague rédigés" value={run.authored_wave_profile_count} tone="gold" />
            <MetricCard label="Profils sélectionnés par la seed" value={run.selected_default_seed_wave_profile_count} />
            <MetricCard label="Minimum de profils joués" value={run.minimum_played_wave_profile_count} />
            <MetricCard label="Maximum de profils joués" value={run.maximum_played_wave_profile_count} />
          </section>
          <section className="metrics-grid run-multiplier-metrics" aria-label="Multiplicateurs maximaux sélectionnés">
            <MetricCard label="Multiplicateur PV maximal sélectionné" value={formatMultiplier(run.selected_health_multiplier_max)} />
            <MetricCard label="Multiplicateur d’attaque maximal sélectionné" value={formatMultiplier(run.selected_attack_multiplier_max)} />
            <MetricCard label="Multiplicateur de récompense maximal sélectionné" value={formatMultiplier(run.selected_reward_multiplier_max)} />
          </section>
        </>
      ) : (
        <Panel title="Contrat de production">
          <p><strong>Aucun profil de vague.</strong> Chaque salle valide produit exactement une rencontre, sans tirage par seed ni multiplicateur de vague.</p>
        </Panel>
      )}

      <Panel title={isWaveChain ? 'Salles et profils de test' : 'Salles et rencontres de production'}>
        <div className="table-wrap">
          <table>
            <caption>
              {isWaveChain
                ? `Profils rédigés et sélectionnés par la seed ${run.default_seed}.`
                : 'Rencontres, rosters, cartes et récompenses de la run principale.'}
            </caption>
            <thead>
              {isWaveChain ? (
                <tr><th>Salle</th><th>Profils</th><th>Sélectionnés</th><th>Bornes</th><th>Rencontre</th><th>Roster</th></tr>
              ) : (
                <tr><th>Salle</th><th>Rencontre</th><th>Roster</th><th>Carte</th><th>Récompense</th><th>Données runtime-only</th></tr>
              )}
            </thead>
            <tbody>{rooms.map((room) => {
              const encounter = encounterForRoom(snapshot, room);
              const enemies = encounter ? index.initialEnemiesByEncounterId.get(encounter.id) ?? [] : [];
              const selected = selectedWavesForRoom(snapshot, room.id);
              return isWaveChain ? (
                <tr key={room.id}>
                  <th scope="row"><Link to={`/rooms/${room.id}`}>{room.index}. {room.name}</Link></th>
                  <td>{room.wave_profile_count}</td>
                  <td>{selected.length}</td>
                  <td>{room.minimum_wave_count}–{room.maximum_wave_count}</td>
                  <td><code>{encounter?.id || 'fallback historique'}</code></td>
                  <td>{enemies.map((enemy) => enemy.name).join(', ') || 'Runtime'}</td>
                </tr>
              ) : (
                <tr key={room.id}>
                  <th scope="row"><Link to={`/rooms/${room.id}`}>{room.index}. {room.name}</Link></th>
                  <td><code>{encounter?.id || 'Non résolue'}</code></td>
                  <td>{encounter ? namedCounts(encounter.role_counts) : 'Runtime'}</td>
                  <td>{labelMapKind(room.map_kind)} · {room.grid_width ?? '?'}×{room.grid_height ?? '?'}</td>
                  <td>{room.ultimate_reward_base_chance_percent}% + {room.ultimate_reward_min_gain_per_wave}–{room.ultimate_reward_max_gain_per_wave}</td>
                  <td>{room.grid_dimensions_status === 'runtime_only' ? 'Dimensions de grille' : 'Aucune'}</td>
                </tr>
              );
            })}</tbody>
          </table>
        </div>
      </Panel>

      <div className="room-card-grid">
        {rooms.map((room) => {
          const encounter = encounterForRoom(snapshot, room);
          const enemies = encounter ? index.initialEnemiesByEncounterId.get(encounter.id) ?? [] : [];
          const selected = selectedWavesForRoom(snapshot, room.id);
          return (
            <article className="room-card" key={room.id}>
              <p className="eyebrow">Salle {room.index}</p>
              <h2><Link to={`/rooms/${room.id}`}>{room.name}</Link></h2>
              <p>{labelMapKind(room.map_kind)} · {room.effective_combat_count} combat{room.effective_combat_count > 1 ? 's' : ''}</p>
              {isWaveChain ? (
                <>
                  <p>{room.wave_profile_count} profils · {selected.length} sélectionnés · bornes {room.minimum_wave_count}–{room.maximum_wave_count}</p>
                  <dl className="room-multipliers">
                    <div><dt>PV max.</dt><dd>{formatMultiplier(Math.max(1, ...selected.map((wave) => wave.enemy_health_multiplier)))}</dd></div>
                    <div><dt>Attaque max.</dt><dd>{formatMultiplier(Math.max(1, ...selected.map((wave) => wave.enemy_attack_multiplier)))}</dd></div>
                    <div><dt>Récompense max.</dt><dd>{formatMultiplier(Math.max(1, ...selected.map((wave) => wave.reward_multiplier)))}</dd></div>
                  </dl>
                </>
              ) : (
                <p>Rencontre <code>{encounter?.id || 'non résolue'}</code> · récompense de base {room.ultimate_reward_base_chance_percent}%.</p>
              )}
              <p className="muted">{enemies.map((enemy) => enemy.name).join(', ') || 'Roster résolu au runtime'}</p>
            </article>
          );
        })}
      </div>
      <details className="technical-details">
        <summary>Identité et source de la run</summary>
        <p>Stabilité de l’identité : {labelIdentityStability(run.identity_stability)}.</p>
        <code>{run.id}</code>
        <SourceDetails path={run.source_path} />
      </details>
    </>
  );
}
