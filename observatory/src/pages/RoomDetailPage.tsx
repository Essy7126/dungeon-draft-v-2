import { Link, useParams } from 'react-router-dom';
import { EnemySpellCard } from '../components/EnemySpellCard';
import { PageHeader, Panel, SourceDetails } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';
import { compareRoomToPrevious, encounterForRoom, orderedWavesForRoom } from '../data/selectors';
import { formatMultiplier, formatPercent } from '../utils/format';
import { UnknownEntityPage } from './UnknownEntityPage';

function signed(value: number): string { return value > 0 ? `+${value}` : String(value); }

export function RoomDetailPage() {
  const { roomId = '' } = useParams<{ roomId?: string }>();
  const snapshot = useSnapshot();
  const index = createSnapshotIndex(snapshot);
  const room = index.roomsById.get(roomId);
  if (!room) return <UnknownEntityPage kind="salle" id={roomId} backTo="/run" />;
  const waves = orderedWavesForRoom(snapshot, room.id);
  const encounter = encounterForRoom(snapshot, room);
  const comparison = compareRoomToPrevious(snapshot, room);
  const initialEnemies = encounter ? index.initialEnemiesByEncounterId.get(encounter.id) ?? [] : [];
  const enemySpells = [...new Map(initialEnemies.flatMap((enemy) => (index.enemySpellsByEnemyId.get(enemy.id) ?? []).map((spell) => [spell.id, spell] as const))).values()];

  return (
    <>
      <Link className="back-link" to="/run">← Toute la run</Link>
      <PageHeader eyebrow={`Salle ${room.index} · ${room.map_kind}`} title={room.name} description={`${room.available_wave_count} profils de vague disponibles, ${room.resolved_default_seed_wave_count ?? 'nombre runtime'} retenus avec la seed ${room.wave_resolution_seed}.`}>
        <span className="count-chip">{room.grid_width ?? '?'} × {room.grid_height ?? '?'}</span>
      </PageHeader>

      <div className="two-column">
        <Panel title="Rencontre initiale">
          {encounter ? <>
            <dl className="stats-table">
              <div><dt>Ennemis initiaux</dt><dd>{encounter.initial_enemy_count}</dd></div><div><dt>Plafond vivant</dt><dd>{encounter.living_enemy_cap}</dd></div>
              <div><dt>PV de base</dt><dd>{encounter.base_totals.total_max_hp}</dd></div><div><dt>Attaque de base</dt><dd>{encounter.base_totals.total_attack_power}</dd></div>
              <div><dt>Budget invocation</dt><dd>{encounter.shared_normal_summon_budget} / {encounter.shared_chief_summon_budget}</dd></div><div><dt>Sorts d’invocation</dt><dd>{encounter.summon_spell_count}</dd></div>
            </dl>
            <ul className="linked-list">{encounter.roster.map((entry) => {
              const enemy = index.enemiesById.get(entry.enemy_id);
              return <li key={entry.enemy_id}>{enemy ? <Link to={`/enemies/${enemy.id}`}><strong>{enemy.name}</strong><span>×{entry.count} · {enemy.tactical_role_id}</span></Link> : <span className="unknown-ref">Référence inconnue : {entry.enemy_id}</span>}</li>;
            })}</ul>
          </> : <p className="unknown-ref">Rencontre de référence introuvable.</p>}
        </Panel>
        <Panel title="Récompense ultime">
          <dl className="stats-table">
            <div><dt>Chance de base</dt><dd>{formatPercent(room.ultimate_reward_base_chance_percent)}</dd></div>
            <div><dt>Gain par vague</dt><dd>{room.ultimate_reward_min_gain_per_wave}–{room.ultimate_reward_max_gain_per_wave} points</dd></div>
            <div><dt>Cases héros</dt><dd>{room.hero_spawn_cell_count}</dd></div><div><dt>Cases ennemies</dt><dd>{room.enemy_spawn_cell_count}</dd></div>
          </dl>
          <p className="budget-note">Ces valeurs sont les paramètres exportés. Observatory ne calcule aucune probabilité finale non prouvée.</p>
        </Panel>
      </div>

      {comparison && <Panel title={`Écart factuel avec ${comparison.previousRoom.name}`}>
        <dl className="comparison-grid"><div><dt>PV initiaux</dt><dd>{signed(comparison.hpDelta)}</dd></div><div><dt>Attaque initiale</dt><dd>{signed(comparison.attackDelta)}</dd></div><div><dt>Ennemis</dt><dd>{signed(comparison.enemyCountDelta)}</dd></div><div><dt>Plafond vivant</dt><dd>{signed(comparison.livingCapDelta)}</dd></div></dl>
      </Panel>}

      <Panel title="Vagues">
        <div className="table-wrap"><table>
          <caption>Profils disponibles ; « oui » identifie ceux sélectionnés par la seed de production.</caption>
          <thead><tr><th>Vague</th><th>Profil</th><th>Sélection</th><th>Rencontre</th><th>PV</th><th>Attaque</th><th>Récompense</th><th>Totaux théoriques</th><th>Statut</th></tr></thead>
          <tbody>{waves.map((wave) => <tr key={wave.id}><th scope="row">{wave.index}. {wave.name}</th><td>{wave.is_mandatory_profile ? 'Obligatoire' : wave.is_optional_profile ? 'Optionnel' : 'Hors plage'}</td><td>{wave.is_selected_by_default_seed ? 'Oui' : 'Non'}</td><td><code>{wave.encounter_id}</code></td><td>{formatMultiplier(wave.enemy_health_multiplier)}</td><td>{formatMultiplier(wave.enemy_attack_multiplier)}<small className="cell-note">{wave.attack_multiplier_effect_status.replaceAll('_', ' ')}</small></td><td>{formatMultiplier(wave.reward_multiplier)}</td><td>{wave.scaled_initial_totals.total_max_hp ?? 'runtime'} PV · {wave.scaled_initial_totals.total_attack_power ?? 'runtime'} attaque</td><td>{wave.calculation_status.replaceAll('_', ' ')}</td></tr>)}</tbody>
        </table></div>
        <details className="technical-details wave-calculations"><summary>Formules, hypothèses et preuves des calculs</summary>
          <ul className="calculation-list">{waves.map((wave) => <li key={wave.id}><strong>{wave.name}</strong><span>PV de base de la rencontre × {formatMultiplier(wave.enemy_health_multiplier)} ; attack_power de base × {formatMultiplier(wave.enemy_attack_multiplier)}.</span><span>Statut : {wave.calculation_status.replaceAll('_', ' ')}. Preuve : {wave.calculation_evidence}</span><code>{wave.source_path}</code></li>)}</ul>
        </details>
      </Panel>

      {enemySpells.length > 0 && <Panel title="Capacités ennemies de la rencontre"><div className="enemy-spell-grid">{enemySpells.map((spell) => <EnemySpellCard key={spell.id} spell={spell} />)}</div></Panel>}

      <details className="technical-details"><summary>Détails techniques et contraintes de placement</summary>
        <dl className="key-values">
          <div><dt>Résolveur</dt><dd><code>{room.wave_resolution_method}</code></dd></div><div><dt>Scène de combat</dt><dd><code>{room.battle_scene_path}</code></dd></div><div><dt>Layout</dt><dd><code>{room.grid_layout_path || 'Non exporté'}</code></dd></div>
          <div><dt>Profils de formation</dt><dd>{encounter?.formation_profiles.join(', ') || 'Aucun'} (choix runtime)</dd></div><div><dt>Cases initiales interdites</dt><dd>{encounter?.forbidden_initial_spawn_cell_count ?? '—'}</dd></div><div><dt>Tentatives max.</dt><dd>{encounter?.maximum_formation_attempts ?? '—'}</dd></div>
          <div><dt>Distance minimale / rôle</dt><dd>{JSON.stringify(encounter?.minimum_path_distance_by_role ?? {})}</dd></div><div><dt>Distance maximale / rôle</dt><dd>{JSON.stringify(encounter?.maximum_path_distance_by_role ?? {})}</dd></div><div><dt>Capacités désactivées</dt><dd>{encounter?.disabled_ability_ids.join(', ') || 'Aucune'}</dd></div>
        </dl>
      </details>
      <SourceDetails path={room.source_path} />
    </>
  );
}
