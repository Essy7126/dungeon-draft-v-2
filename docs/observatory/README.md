# Dungeon Draft Observatory

Observatory produit un snapshot JSON statique et versionné des données de production de Dungeon Draft. La fondation charge uniquement des `Resource` explicitement reliées à la première run, puis exporte des données sérialisables, des contrôles du contrat de conception et des audits déterministes.

## Source de vérité

- Contrat : `docs/observatory/design_contract.json`
- Manifeste : `docs/observatory/data_source_manifest.json`
- Schéma : `tools/observatory/schemas/observatory_snapshot.schema.json`
- Snapshot : `observatory/public/data/latest.json`

L’exporteur ne lance aucune scène de gameplay, n’écrit aucune ressource de jeu et n’utilise pas les dossiers comme preuve d’activation. Les chemins `res://` restent des références techniques, jamais des URLs web.

## Export local

```powershell
& Godot --headless --path . --script res://tools/observatory/export_snapshot.gd -- --output=res://observatory/public/data/latest.json
```

Ajouter `--fail-on-blocking` pour obtenir le code de sortie `2` lorsqu’un audit bloquant est produit. Sans cette option, un snapshot structurellement valide est écrit même s’il expose un écart de conception.

## Périmètre V1

Le snapshot 2.0.0 conserve les domaines V0 et ajoute la run de production, ses salles, ses profils de vagues, les nombres résolus par la seed, les rencontres, les ennemis atteignables, leurs sorts et leurs profils d'IA. Les placements et invocations réellement joués restent runtime-only. L'architecture complète et le theorycraft avancé restent explicitement reportés.

Les méthodes, identités, agrégats et limites sont détaillés dans `run_data_v1_audit.md` et `run_data_v1.md`.

## Frontend statique V0

Le dossier `observatory/` contient l’interface React/Vite en lecture seule. Elle consomme exclusivement `observatory/public/data/latest.json`, synchronise une copie publique ignorée du schéma pour Ajv et utilise des routes hashées compatibles avec un hébergement statique. Les commandes, filtres, garanties d’accessibilité, limites et principes de sécurité sont documentés dans `observatory/README.md` et `docs/observatory/frontend_v0.md`.

Cette mission ne crée ni backend, ni authentification, ni télémétrie, ni déploiement.
