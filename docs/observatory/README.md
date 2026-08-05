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

## Périmètre V0

Le snapshot inclut le projet, les héros de production, leurs statistiques, sorts et disciplines, le catalogue d’objets, les récompenses génériques déclarées, le pool d’équipements, le contrat et les audits. Runs détaillées, salles, vagues, ennemis, architecture complète et theorycraft avancé restent explicitement reportés.
