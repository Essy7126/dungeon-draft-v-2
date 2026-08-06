import { Link } from 'react-router-dom';
import { MetricCard, PageHeader, Panel, SourceDetails } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';
import { encounterForRoom, orderedRoomsForRun, selectedWavesForRoom } from '../data/selectors';
import { labelIdentityStability, labelMapKind, labelTacticalRole } from '../data/translations';
import { formatMultiplier } from '../utils/format';

function namedCounts(values: Record<string, number>): string {
  return Object.entries(values).map(([name, count]) => `${labelTacticalRole(name)} ×${count}`).join(', ') || 'Aucun';
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
      <section className="metrics-grid run-profile-metrics" aria-label="Profils de vague de la run">
        <MetricCard label="Profils de vague rédigés" value={run.authored_wave_profile_count} tone="gold" />
        <MetricCard label="Profils sélectionnés par la seed" value={run.selected_default_seed_wave_profile_count} />
        <MetricCard label="Minimum de profils joués" value={run.minimum_played_wave_profile_count} />
        <MetricCard label="Maximum de profils joués" value={run.maximum_played_wave_profile_count} />
      </section>
      <section className="metrics-grid run-multiplier-metrics" aria-label="Multiplicateurs maximaux sélectionnés">
        <MetricCard label="Multiplicateur PV maximal sélectionné" value={formatMultiplier(run.selected_health_multiplier_max)} />
        <MetricCard label="Multiplicateur de puissance d’attaque maximal sélectionné" value={formatMultiplier(run.selected_attack_multiplier_max)} detail="Cible runtime : attack_power" />
        <MetricCard label="Multiplicateur de récompense maximal sélectionné" value={formatMultiplier(run.selected_reward_multiplier_max)} />
      </section>

      <Panel title="Progression factuelle des salles">
        <div className="table-wrap">
          <table>
            <caption>Valeurs du roster initial et des profils sélectionnés par la seed {run.default_seed}.</caption>
            <thead><tr><th>Salle</th><th>Profils retenus</th><th>Ennemis initiaux</th><th>PV premier profil</th><th>PV dernier profil</th><th>Rôles</th><th>Invocations possibles</th><th>Plafond vivant</th></tr></thead>
            <tbody>{rooms.map((room) => {
              const encounter = encounterForRoom(snapshot, room);
              const selected = selectedWavesForRoom(snapshot, room.id);
              const first = selected[0];
              const last = selected[selected.length - 1];
              return <tr key={room.id}>
                <th scope="row"><Link to={`/rooms/${room.id}`}>{room.index}. {room.name}</Link><small>{labelMapKind(room.map_kind)} · {room.grid_width ?? '?'}×{room.grid_height ?? '?'}</small></th>
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
          const maximumHealthMultiplier = Math.max(1, ...selected.map((wave) => wave.enemy_health_multiplier));
          const maximumAttackMultiplier = Math.max(1, ...selected.map((wave) => wave.enemy_attack_multiplier));
          const maximumRewardMultiplier = Math.max(1, ...selected.map((wave) => wave.reward_multiplier));
          return <article className="room-card" key={room.id}>
            <p className="eyebrow">Salle {room.index}</p>
            <h2><Link to={`/rooms/${room.id}`}>{room.name}</Link></h2>
            <p>{labelMapKind(room.map_kind)} · {room.available_wave_count} profils rédigés · minimum {room.minimum_wave_count} · maximum {room.maximum_wave_count}</p>
            <p>{selected.length} profils sélectionnés par la seed</p>
            <dl className="room-multipliers">
              <div><dt>PV max.</dt><dd>{formatMultiplier(maximumHealthMultiplier)}</dd></div>
              <div><dt>Puissance d’attaque max.</dt><dd>{formatMultiplier(maximumAttackMultiplier)}</dd></div>
              <div><dt>Récompense max.</dt><dd>{formatMultiplier(maximumRewardMultiplier)}</dd></div>
            </dl>
            <p className="muted">{enemies.map((enemy) => enemy.name).join(', ') || 'Roster non résolu'}</p>
          </article>;
        })}
      </div>
      <details className="technical-details"><summary>Identité et source de la run</summary><p>Stabilité de l’identité : {labelIdentityStability(run.identity_stability)}.</p><code>{run.id}</code><SourceDetails path={run.source_path} /></details>
    </>
  );
}
