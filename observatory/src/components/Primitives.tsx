import type { ReactNode } from 'react';
import type { AuditSeverity, ContractCheckStatus } from '../types';

const statusLabels: Record<ContractCheckStatus, string> = {
  conform: 'Conforme',
  difference: 'Écart',
  unknown: 'Inconnu',
  not_evaluated: 'Non évalué',
};

export function StatusBadge({ status }: { status: ContractCheckStatus }) {
  return <span className={`badge badge--${status.replace('_', '-')}`}><span aria-hidden="true">●</span> {statusLabels[status]}</span>;
}

const severityLabels: Record<AuditSeverity, string> = {
  info: 'Information',
  warning: 'Avertissement',
  blocking: 'Bloquant',
};

export function SeverityBadge({ severity }: { severity: AuditSeverity }) {
  return <span className={`badge badge--${severity}`}><span aria-hidden="true">●</span> {severityLabels[severity]}</span>;
}

export function EffectBadge({ children }: { children: ReactNode }) {
  return <span className="effect-badge">{children}</span>;
}

export function PageHeader({ eyebrow, title, description, children }: { eyebrow: string; title: string; description: string; children?: ReactNode }) {
  return (
    <header className="page-header">
      <div>
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        <p className="page-description">{description}</p>
      </div>
      {children && <div className="page-header__aside">{children}</div>}
    </header>
  );
}

export function MetricCard({ label, value, tone = 'neutral', detail }: { label: string; value: number | string; tone?: string; detail?: string }) {
  return (
    <article className={`metric-card metric-card--${tone}`}>
      <p>{label}</p>
      <strong>{value}</strong>
      {detail && <small>{detail}</small>}
    </article>
  );
}

export function EmptyState({ title, children }: { title: string; children: ReactNode }) {
  return <div className="empty-state" role="status"><strong>{title}</strong><p>{children}</p></div>;
}

export function VisualPlaceholder() {
  return <div className="visual-placeholder" role="img" aria-label="Visuel non exporté"><span aria-hidden="true">◇</span><p>Visuel non exporté dans la V0</p></div>;
}

export function SourceDetails({ path }: { path: string }) {
  return <details className="source-details"><summary>Source technique</summary><code>{path}</code></details>;
}

export function Panel({ title, children, className = '' }: { title: string; children: ReactNode; className?: string }) {
  return <section className={`panel ${className}`}><h2>{title}</h2>{children}</section>;
}
