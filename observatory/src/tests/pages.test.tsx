import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { DataErrorPage, LoadingState } from '../components/DataStates';
import { SnapshotProvider } from '../context/SnapshotContext';
import { SnapshotLoadError } from '../data/loadSnapshot';
import { AuditPage } from '../pages/AuditPage';
import { CharacterDetailPage } from '../pages/CharacterDetailPage';
import { CharactersPage } from '../pages/CharactersPage';
import { DisciplineDetailPage } from '../pages/DisciplineDetailPage';
import { DisciplinesPage } from '../pages/DisciplinesPage';
import { ItemsPage } from '../pages/ItemsPage';
import { NotFoundPage } from '../pages/NotFoundPage';
import { OverviewPage } from '../pages/OverviewPage';
import { RewardsPage } from '../pages/RewardsPage';
import { SpellsPage } from '../pages/SpellsPage';
import { SpellDetailPage } from '../pages/SpellDetailPage';
import { EnemiesPage } from '../pages/EnemiesPage';
import { EnemyDetailPage } from '../pages/EnemyDetailPage';
import { RoomDetailPage } from '../pages/RoomDetailPage';
import { RunPage } from '../pages/RunPage';
import { RunsPage } from '../pages/RunsPage';
import { snapshotFixture } from './fixture';

function renderPage(page: React.ReactNode, path = '/', routePath = '') {
  return render(<SnapshotProvider value={snapshotFixture}><MemoryRouter initialEntries={[path]}>{routePath ? <Route path={routePath}>{page}</Route> : page}</MemoryRouter></SnapshotProvider>);
}

describe('pages Observatory', () => {
  it('affiche la vue globale et les compteurs zéro', () => {
    renderPage(<OverviewPage />);
    expect(screen.getByRole('heading', { name: 'État du jeu exporté' })).toBeInTheDocument();
    expect(screen.getAllByText('0', { selector: 'strong' }).length).toBeGreaterThan(0);
    expect(screen.getByText('Domaines reportés')).toBeInTheDocument();
    expect(screen.getByText('Profils de vague de test')).toBeInTheDocument();
    expect(screen.getByText('Profils de test sélectionnés')).toBeInTheDocument();
    expect(screen.getByText('progression.xp_per_effective_cast')).toBeInTheDocument();
    expect(screen.getByText('Décisions de conception')).toBeInTheDocument();
  });

  it('affiche les personnages et leurs statistiques', () => {
    renderPage(<CharactersPage />);
    expect(screen.getByRole('link', { name: 'Élfe' })).toBeInTheDocument();
    expect(screen.getByText('100')).toBeInTheDocument();
  });

  it('filtre les sorts avec une recherche accent-insensible', async () => {
    const user = userEvent.setup();
    renderPage(<SpellsPage />);
    await user.type(screen.getByRole('searchbox', { name: 'Recherche' }), 'DEGATS');
    expect(screen.getByRole('link', { name: 'Boule de feu' })).toBeInTheDocument();
    await user.clear(screen.getByRole('searchbox', { name: 'Recherche' }));
    await user.type(screen.getByRole('searchbox', { name: 'Recherche' }), 'absent');
    expect(screen.getByText('Aucun sort trouvé')).toBeInTheDocument();
  });

  it('affiche les disciplines et leurs seuils', () => {
    renderPage(<DisciplinesPage />);
    expect(screen.getByRole('link', { name: 'Magie' })).toBeInTheDocument();
    expect(screen.getByText('XP final')).toBeInTheDocument();
  });

  it('filtre les objets et expose la compatibilité universelle', async () => {
    const user = userEvent.setup();
    renderPage(<ItemsPage />);
    expect(screen.getByText('Compatible avec tous les héros')).toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText('Type'), 'consumable');
    expect(screen.getByRole('link', { name: 'Potion de soin' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Anneau élémentaire' })).not.toBeInTheDocument();
  });

  it('sépare les récompenses déclarées et le pool', () => {
    renderPage(<RewardsPage />);
    expect(screen.getByText('Récompenses génériques déclarées')).toBeInTheDocument();
    expect(screen.getByText('Pool d’équipements de la première run')).toBeInTheDocument();
    expect(screen.getByText(/Aucun poids/)).toBeInTheDocument();
  });

  it('sépare contrat et résultats d’audit', () => {
    renderPage(<AuditPage />);
    expect(screen.getByRole('table', { name: 'Cibles comparées aux valeurs observées' })).toBeInTheDocument();
    expect(screen.getAllByText('CONTRACT.NOT_EVALUATED').length).toBeGreaterThan(0);
    expect(screen.getByText('1 occurrence')).toBeInTheDocument();
    expect(screen.getAllByText('RECOMMANDATION').length).toBeGreaterThan(0);
  });

  it('affiche la page 404 locale', () => {
    renderPage(<NotFoundPage />);
    expect(screen.getByRole('heading', { name: 'Page locale introuvable' })).toBeInTheDocument();
  });

  it('affiche une entité inconnue', () => {
    renderPage(<CharacterDetailPage />, '/characters/inconnu');
    expect(screen.getByRole('heading', { name: 'Personnage introuvable' })).toBeInTheDocument();
  });

  it('affiche une discipline inconnue', () => {
    renderPage(<DisciplineDetailPage />, '/disciplines/inconnue');
    expect(screen.getByRole('heading', { name: 'Discipline introuvable' })).toBeInTheDocument();
  });

  it('affiche la run, le roster et les profils de progression', () => {
    renderPage(<RunPage />);
    expect(screen.getByRole('heading', { name: 'Première run' })).toBeInTheDocument();
    expect(screen.getByRole('table')).toHaveTextContent('Gobelin éclaireur');
    expect(screen.getByText('Multiplicateur PV maximal sélectionné')).toBeInTheDocument();
    expect(screen.getByText('Multiplicateur d’attaque maximal sélectionné')).toBeInTheDocument();
    expect(screen.getByText('Multiplicateur de récompense maximal sélectionné')).toBeInTheDocument();
  });

  it('liste les runs avec leur nature, leur mode et leur fraîcheur', () => {
    renderPage(<RunsPage />);
    expect(screen.getByRole('heading', { name: 'Runs' })).toBeInTheDocument();
    expect(screen.getByText(/Production · Chaîne de vagues/)).toBeInTheDocument();
    expect(screen.getByText('Combats effectifs')).toBeInTheDocument();
    expect(screen.getByText('Fraîcheur')).toBeInTheDocument();
  });

  it('masque les profils et la seed pour une run en rencontre unique', () => {
    const run = {
      ...snapshotFixture.runs[0],
      flow_mode: 'single_encounter' as const,
      maximum_waves_per_room: 1,
      authored_wave_profile_count: 0,
      selected_default_seed_wave_profile_count: 0,
      minimum_played_wave_profile_count: 0,
      maximum_played_wave_profile_count: 0,
    };
    const room = {
      ...snapshotFixture.rooms[0],
      flow_mode: 'single_encounter' as const,
      available_wave_count: 0,
      wave_profile_count: 0,
      resolved_default_seed_wave_count: null,
      wave_resolution_status: 'not_applicable' as const,
      wave_resolution_method: 'not_applicable',
      wave_ids: [],
    };
    const snapshot = { ...snapshotFixture, runs: [run], rooms: [room], waves: [] };
    render(
      <SnapshotProvider value={snapshot}>
        <MemoryRouter initialEntries={['/runs/first_run']}>
          <Route path="/runs/:runId"><RunPage /></Route>
        </MemoryRouter>
      </SnapshotProvider>,
    );
    expect(screen.getByText('Aucun profil de vague.')).toBeInTheDocument();
    expect(screen.queryByText('Profils sélectionnés par la seed')).not.toBeInTheDocument();
    expect(screen.queryByText(/seed 1337/)).not.toBeInTheDocument();
  });

  it('marque clairement une run de test en chaîne de vagues', () => {
    const run = { ...snapshotFixture.runs[0], run_kind: 'test' as const, is_primary: false };
    const snapshot = { ...snapshotFixture, runs: [run] };
    render(
      <SnapshotProvider value={snapshot}>
        <MemoryRouter initialEntries={['/runs/first_run']}>
          <Route path="/runs/:runId"><RunPage /></Route>
        </MemoryRouter>
      </SnapshotProvider>,
    );
    expect(screen.getByText(/Outil de test — cette run/)).toBeInTheDocument();
    expect(screen.getByText('Profils sélectionnés par la seed')).toBeInTheDocument();
  });

  it('rend un état explicite pour une run inconnue', () => {
    renderPage(<RunPage />, '/runs/inconnue', '/runs/:runId');
    expect(screen.getByRole('heading', { name: 'Run introuvable' })).toBeInTheDocument();
  });

  it('affiche les vagues, le roster et les données runtime de la salle', () => {
    renderPage(<RoomDetailPage />, '/rooms/first_run.room.01', '/rooms/:roomId');
    expect(screen.getByRole('heading', { name: 'Salle 1 - Pont ancien' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Gobelin éclaireur/ })).toBeInTheDocument();
    expect(screen.getByRole('table')).toHaveTextContent('Base statique uniquement');
    expect(screen.getByText(/choix runtime/)).toBeInTheDocument();
    expect(screen.getByText('ACTIVE DANS CETTE RENCONTRE')).toBeInTheDocument();
  });

  it('filtre les ennemis et expose un état vide', async () => {
    const user = userEvent.setup();
    renderPage(<EnemiesPage />);
    expect(screen.getByRole('link', { name: 'Gobelin éclaireur' })).toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText('Présence'), 'summonable');
    expect(screen.getByText('Aucun ennemi trouvé')).toBeInTheDocument();
  });

  it('affiche la fiche ennemi, son IA, ses capacités et ses audits', () => {
    renderPage(<EnemyDetailPage />, '/enemies/goblin', '/enemies/:enemyId');
    expect(screen.getByRole('heading', { name: 'Gobelin éclaireur' })).toBeInTheDocument();
    expect(screen.getByText('Assaut de mêlée')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Estoc rouillé' })).toBeInTheDocument();
    expect(screen.getByText(/Aucun audit spécifique/)).toBeInTheDocument();
  });

  it('distingue la puissance d’attaque et expose toutes les statistiques du personnage', () => {
    renderPage(<CharacterDetailPage />, '/characters/elf', '/characters/:characterId');
    expect(screen.getByText('Puissance d’attaque')).toBeInTheDocument();
    expect(screen.getByText('Attaque de base active')).toBeInTheDocument();
    expect(screen.getByText('Résistance magique')).toBeInTheDocument();
    expect(screen.getByText('Multiplicateur critique')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Résistances élémentaires' })).toBeInTheDocument();
  });

  it('affiche les contraintes et effets complets d’un sort', () => {
    renderPage(<SpellDetailPage />, '/spells/elf_fireball', '/spells/:spellId');
    expect(screen.getByText('Cooldown initial')).toBeInTheDocument();
    expect(screen.getByText('Une fois par activation')).toBeInTheDocument();
    expect(screen.getByText('Dégâts de collision')).toBeInTheDocument();
    expect(screen.getByText('Téléportation derrière la cible')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Modificateurs' })).toBeInTheDocument();
  });

  it('gère une salle et un ennemi inconnus', () => {
    const { unmount } = renderPage(<RoomDetailPage />, '/rooms/inconnue', '/rooms/:roomId');
    expect(screen.getByRole('heading', { name: 'Salle introuvable' })).toBeInTheDocument();
    unmount();
    renderPage(<EnemyDetailPage />, '/enemies/inconnu', '/enemies/:enemyId');
    expect(screen.getByRole('heading', { name: 'Ennemi introuvable' })).toBeInTheDocument();
  });

  it('communique le chargement', () => {
    render(<LoadingState />);
    expect(screen.getByRole('status')).toHaveTextContent('Chargement du snapshot');
  });

  it('structure les erreurs de données et permet de réessayer', async () => {
    const user = userEvent.setup();
    let retries = 0;
    const error = new SnapshotLoadError('incompatible', 'Incompatible', 'public/data/latest.json', [{ path: '/meta', keyword: 'required', message: 'requis' }]);
    render(<DataErrorPage error={error} onRetry={() => { retries += 1; }} />);
    expect(screen.getByText('incompatible')).toBeInTheDocument();
    expect(screen.getByText('/meta')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Réessayer' }));
    expect(retries).toBe(1);
  });
});
