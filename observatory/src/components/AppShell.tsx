import type { ReactNode } from 'react';
import { NavLink } from 'react-router-dom';
import { FreshnessIndicator } from './FreshnessIndicator';

const navigation = [
  ['Vue globale', '/overview'],
  ['Runs', '/runs'],
  ['Ennemis', '/enemies'],
  ['Personnages', '/characters'],
  ['Sorts', '/spells'],
  ['Disciplines', '/disciplines'],
  ['Objets', '/items'],
  ['Récompenses', '/rewards'],
  ['Audit', '/audit'],
] as const;

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="app-shell">
      <a className="skip-link" href="#main-content">Aller au contenu</a>
      <header className="topbar">
        <div className="brand-mark" aria-hidden="true">DD</div>
        <div>
          <p className="eyebrow">Outil de conception</p>
          <p className="brand-title">Dungeon Draft Observatory</p>
        </div>
        <FreshnessIndicator />
      </header>
      <nav className="sidebar" aria-label="Navigation principale">
        <p className="nav-label">Explorer</p>
        {navigation.map(([label, path]) => (
          <NavLink key={path} to={path} className="nav-link" activeClassName="active">
            <span className="nav-dot" aria-hidden="true" />
            {label}
          </NavLink>
        ))}
        <div className="nav-note">Snapshot statique<br />Lecture seule</div>
      </nav>
      <main id="main-content" className="main-content" tabIndex={-1}>
        {children}
      </main>
    </div>
  );
}
