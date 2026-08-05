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
import { EnemiesPage } from '../pages/EnemiesPage';
import { EnemyDetailPage } from '../pages/EnemyDetailPage';
import { RoomDetailPage } from '../pages/RoomDetailPage';
import { RunPage } from '../pages/RunPage';
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
    expect(screen.getByText('CONTRACT.NOT_EVALUATED')).toBeInTheDocument();
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

  it('affiche la run, le roster et les totaux de progression', () => {
    renderPage(<RunPage />);
    expect(screen.getByRole('heading', { name: 'Première run' })).toBeInTheDocument();
    expect(screen.getByRole('table')).toHaveTextContent('skirmisher');
    expect(screen.getByRole('table')).toHaveTextContent('80');
  });

  it('affiche les vagues, le roster et les données runtime de la salle', () => {
    renderPage(<RoomDetailPage />, '/rooms/first_run.room.01', '/rooms/:roomId');
    expect(screen.getByRole('heading', { name: 'Salle 1 - Pont ancien' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Gobelin éclaireur/ })).toBeInTheDocument();
    expect(screen.getByRole('table')).toHaveTextContent('static base only');
    expect(screen.getByText(/choix runtime/)).toBeInTheDocument();
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
