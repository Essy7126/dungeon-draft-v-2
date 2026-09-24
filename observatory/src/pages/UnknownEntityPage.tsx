import { Link } from 'react-router-dom';

export function UnknownEntityPage({ kind, id, backTo }: { kind: string; id: string; backTo: string }) {
  return (
    <div className="state-page">
      <p className="eyebrow">Référence inconnue</p>
      <h1>{kind[0]?.toLocaleUpperCase('fr')}{kind.slice(1)} introuvable</h1>
      <p>Aucune entité ne correspond à l’identifiant <code>{id || 'vide'}</code> dans le snapshot validé.</p>
      <Link className="button" to={backTo}>Revenir à la collection</Link>
    </div>
  );
}
