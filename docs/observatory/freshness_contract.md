# Contrat de fraîcheur du snapshot

- Statut : **CURRENT**
- Branche : `feature/observatory-live-v1-2`
- Commit de référence : HEAD contenant ce document ; comparaison locale avec le SHA du snapshot.
- Date UTC : `2026-08-06T10:45:38Z`
- Validation : dépôts Git temporaires couvrant `current`, `stale` et `unknown`.

`observatory/scripts/generate-build-meta.mjs` produit localement `public/generated/build_meta.json`, ignoré par Git. Aucune API distante n’est appelée par le navigateur.

Le script compare l’arbre du commit source du snapshot à HEAD puis à `origin/main` lorsqu’il existe. Git retourne les chemins en UTF-8, délimités par NUL, avec `core.quotepath=false`. Les chemins `observatory/**`, `docs/observatory/**`, `tools/observatory/**`, `test/unit/observatory/**` et les workflows Observatory `.github/workflows/ci.yml` / `.github/workflows/observatory-ci.yml` sont exclus du calcul métier. Les autres chemins sont classés par les racines du manifeste et des préfixes explicites.

| Statut | Condition |
|---|---|
| `current` | Aucun chemin hors Observatory ne diffère. |
| `stale` | Au moins un chemin hors Observatory diffère. |
| `diverged` | Une référence Git existe mais ne partage aucune base comparable. |
| `unknown` | Git, le snapshot ou le commit source est indisponible. |

Un snapshot en retard indique seulement des chemins différents. Observatory ne prétend pas connaître leur effet fonctionnel avant un nouvel export.
