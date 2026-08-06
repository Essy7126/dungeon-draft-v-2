import { Link } from 'react-router-dom';

export function NotFoundPage() {
  return <div className="state-page"><p className="eyebrow">Erreur 404</p><h1>Page locale introuvable</h1><p>Cette route n’existe pas dans la version statique actuelle d’Observatory.</p><Link className="button" to="/overview">Revenir à la vue globale</Link></div>;
}
