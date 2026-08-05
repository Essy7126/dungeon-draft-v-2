import { Link } from 'react-router-dom';
import { MetricCard, PageHeader, Panel, SourceDetails } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';
import { encounterForRoom, orderedRoomsForRun, selectedWavesForRoom } from '../data/selectors';
import { formatMultiplier } from '../utils/format';

function namedCounts(values: Record<string, number>): string {
  return Object.entries(values).map(([name, count]) => `${name} ×${count}`).join(', ') || 'Aucun';
}

export function RunPage() {
  const snapshot = useSnapshot();
  const index = createSnapshotIndex(snapshot);
  const run = snapshot.runs[0];
  if (!run) return <PageHeader eyebrow="Run" title="Aucune run exportée" description="Le snapshot ne contient aucune run de production." />;
  const rooms = orderedRoomsForRun(snapshot, run.id);

  return (
    <>
      <PageHeader eyebrow={`Run · ${run.id}`} title={run.name} description="Parcours de production ordonné, résolu avec la seed par défaut et présenté sans score de difficulté synthétique.">
        <span className="count-chip">seed {run.default_seed}</span>
      </PageHeader>
      <section className="metrics-grid run-metrics" aria-label="Métadonnées de la run">
        <MetricCard label="Salles" value={run.authored_room_count} tone="gold" />
        <MetricCard label="Durée cible" value={`${run.target_duration_minutes} min`} />
        <MetricCard label="Durée étendue" value={`${run.extended_duration_minutes} min`} />
        <MetricCard label="Vagues max./salle" value={run.maximum_waves_per_room} />
        <MetricCard label="Validité" value={run.validation_status} />
      </section>

      <Panel title="Progression factuelle des salles">
        <div className="table-wrap">
          <table>
            <caption>Valeurs du roster initial et des vagues sélectionnées par la seed {run.default_seed}.</caption>
            <thead><tr><th>Salle</th><th>Vagues résolues</th><th>Ennemis initiaux</th><th>PV première vague</th><th>PV dernière vague</th><th>Rôles</th><th>Invocations possibles</th><th>Plafond vivant</th></tr></thead>
            <tbody>{rooms.map((room) => {
              const encounter = encounterForRoom(snapshot, room);
              const selected = selectedWavesForRoom(snapshot, room.id);
              const first = selected[0];
              const last = selected[selected.length - 1];
              return <tr key={room.id}>
                <th scope="row"><Link to={`/rooms/${room.id}`}>{room.index}. {room.name}</Link><small>{room.map_kind} · {room.grid_width ?? '?'}×{room.grid_height ?? '?'}</small></th>
                <td>{room.resolved_default_seed_wave_count ?? 'runtime'} / {room.available_wave_count}</td>
                <td>{encounter?.initial_enemy_count ?? '—'}</td>
                <td>{first?.scaled_initial_totals.total_max_hp ?? 'runtime'}</td>
                <td>{last?.scaled_initial_totals.total_max_hp ?? 'runtime'}</td>
                <td>{encounter ? namedCounts(encounter.role_counts) : '—'}</td>
                <td>{encounter?.summon_spell_count ?? '—'}</td>
                <td>{encounter?.living_enemy_cap ?? '—'}</td>
              </tr>;
            })}</tbody>
          </table>
        </div>
      </Panel>

      <div className="room-card-grid">
        {rooms.map((room) => {
          const encounter = encounterForRoom(snapshot, room);
          const enemies = encounter ? index.initialEnemiesByEncounterId.get(encounter.id) ?? [] : [];
          const selected = selectedWavesForRoom(snapshot, room.id);
          const maximumMultiplier = Math.max(1, ...selected.flatMap((wave) => [wave.enemy_health_multiplier, wave.enemy_attack_multiplier, wave.reward_multiplier]));
          return <article className="room-card" key={room.id}>
            <p className="eyebrow">Salle {room.index}</p>
            <h2><Link to={`/rooms/${room.id}`}>{room.name}</Link></h2>
            <p>{room.map_kind} · {room.available_wave_count} profils · minimum {room.minimum_wave_count} · maximum {room.maximum_wave_count}</p>
            <p>{selected.length} vagues résolues · multiplicateur sélectionné max. {formatMultiplier(maximumMultiplier)}</p>
            <p className="muted">{enemies.map((enemy) => enemy.name).join(', ') || 'Roster non résolu'}</p>
          </article>;
        })}
      </div>
      <SourceDetails path={run.source_path} />
    </>
  );
}
