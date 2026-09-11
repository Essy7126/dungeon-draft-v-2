import type { ResourceReference } from '../types';
import { labelModifierProperty } from '../data/translations';
import { formatValue } from '../utils/format';

export function ModifierList({ modifiers }: { modifiers: readonly ResourceReference[] }) {
  if (modifiers.length === 0) return <p className="muted">Aucun modificateur exporté.</p>;
  return (
    <ul className="modifier-list">
      {modifiers.map((modifier, index) => {
        const properties = Object.entries(modifier)
          .filter(([key]) => !['resource_type', 'resource_path'].includes(key));
        return (
          <li key={`${modifier.resource_path}-${index}`}>
            <strong>{modifier.resource_type}</strong>
            {properties.map(([key, value]) => (
              <span key={key}>{labelModifierProperty(key)} : {formatValue(value)}</span>
            ))}
            <details className="source-details">
              <summary>Valeurs et filtres techniques</summary>
              <code>{modifier.resource_path}</code>
              <pre>{JSON.stringify(modifier, null, 2)}</pre>
            </details>
          </li>
        );
      })}
    </ul>
  );
}
