# Observatory V1.2 — provenance d'intégration

## Ancrage

- Branche de travail : `feature/observatory-live-v1-2`
- Base distante vérifiée : `origin/main`
- Commit de base : `296f17c7c76626f1d2acd3cc5e650daf356d8ba8`
- Worktree isolé : `output/observatory-live-v1-2`

Le worktree principal et ses modifications locales ne sont pas utilisés par cette
intégration.

## Provenance V1.1

Les commits Observatory exclusifs ci-dessous ont été relus puis appliqués dans
l'ordre sur la base courante. Leur diff est limité aux chemins Observatory,
documentation et outillage associés.

| Commit source | Rôle |
| --- | --- |
| `a800c7892613092` | fondations de l'Observatory |
| `e5738bd902303e` | contrat et export des données |
| `6784436a8e304b` | interface frontend initiale |
| `bbc865d6933053` | stabilisation de l'export |
| `6af0caa6bb508e` | modèle de run V1 |
| `e93a63404369de` | audit et vérité statique |
| `b9e5a0161fc88c` | stabilisation V1.1 |
| `688b7408aff38b` | frontend V1.1 |

La tête de provenance vérité V1.1 est `b9e5a0161fc88c` et la tête frontend
V1.1 est `688b7408aff38b`. L'intégration n'a produit aucun conflit et n'a modifié
aucun fichier de gameplay.

## Baseline avant adaptation V1.2

- Godot : `4.7.1.stable.official.a13da4feb`
- GUT : `9.7.1`
- Node.js : `v26.3.1`
- npm : `11.16.0`
- Frontend : lint, typecheck, 57 tests unitaires et build réussis.
- Playwright : 28 tests réussis sur 29 ; le seul échec est le test de fraîcheur
  attendu après le réalignement sur `main`.
- GUT Observatory V1.1 : 46 tests réussis sur 48 ; les deux attentes obsolètes
  portent sur la sémantique wave-only et seront remplacées par les assertions
  dual-flow V1.2.
- GUT complet : 832 tests réussis sur 848. Les échecs non-Observatory existants
  seront identifiés par rapport XML et confinés dans une politique de baseline
  explicite ; aucun nouvel échec ne sera accepté.

Cette baseline est descriptive. Elle ne remplace ni les preuves de validation
V1.2 ni la provenance Git enregistrée dans le snapshot généré.
