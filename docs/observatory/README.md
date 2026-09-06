# Dungeon Draft Observatory

- Statut : **CURRENT**
- Branche : `feature/observatory-live-v1-2`
- Commit de référence : HEAD contenant ce document ; `meta.source_game_commit` publie le SHA Git exact de l’export.
- Date UTC : `2026-08-06`
- Validation : export propre, GUT Observatory, Ajv, chaîne frontend et automatisation LAN.

Observatory produit un snapshot JSON statique et versionné des données de production et des outils de test explicitement déclarés de Dungeon Draft. La fondation charge uniquement des `Resource` reliées aux deux racines du manifeste, puis exporte des données sérialisables, des contrôles du contrat de conception et des audits déterministes.

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

## Périmètre V1.2

Le snapshot 3.0.0 distingue la run de production `single_encounter` de la run de test `wave_chain`, publie `primary_run_id` et sépare les compteurs. Les placements et invocations réellement joués restent runtime-only.

Les contrats courants sont détaillés dans `truth_model.md`, `freshness_contract.md`, `run_flow_v1_2.md`, `automation_v1_2.md` et `live_deployment_contract.md`.

## Frontend statique V0 et V1

Le dossier `observatory/` contient l’interface React/Vite en lecture seule. Elle consomme exclusivement `observatory/public/data/latest.json`, synchronise une copie publique ignorée du schéma pour Ajv et utilise des routes hashées compatibles avec un hébergement statique. La V1 ajoute les routes Run, Salle, Ennemis et Ennemi sans modifier les routes V0. Les commandes, filtres, garanties d’accessibilité, limites et principes de sécurité sont documentés dans `observatory/README.md`, `docs/observatory/frontend_v0.md` et `docs/observatory/frontend_v1.md`.

La V1.2 ajoute un serveur LAN Node en lecture seule et une publication Windows atomique. Elle ne crée ni backend d’écriture, ni authentification, ni télémétrie, ni runner auto-hébergé. L’installation permanente reste suspendue jusqu’à la fusion dans `main`.
