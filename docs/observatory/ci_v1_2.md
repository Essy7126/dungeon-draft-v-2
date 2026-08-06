# CI Observatory V1.2

Le workflow `.github/workflows/observatory-ci.yml` s’exécute sur un runner
GitHub hébergé `ubuntu-latest` pour les pull requests vers `main`, les pushes
sur `main` et les lancements manuels. Il dispose uniquement de
`contents: read`, annule les exécutions obsolètes de la même référence et ne
publie rien sur le LAN.

## Toolchain vérifiée

`tools/observatory/toolchain.json` épingle Node 24 LTS, Chromium et le binaire
Linux officiel Godot 4.7.1 stable. Son SHA-256 provient du champ `digest` de
l’asset publié par l’API GitHub officielle Godot, pas du binaire local. Le
workflow télécharge cette URL puis exécute `sha256sum -c` avant toute exécution.

Les seules actions sont `actions/checkout`, `actions/setup-node` et
`actions/upload-artifact`, toutes référencées par un SHA Git complet résolu
depuis leurs tags V4 officiels le 6 août 2026. Aucun secret de dépôt, action
tierce, runner auto-hébergé, `pull_request_target`, commit ou push automatique
n’est utilisé.

## Validations et artefacts

La CI importe Godot, génère le snapshot, vérifie sa provenance, lance GUT
Observatory puis la suite complète. `known_gut_failures.json` contient les 15
échecs historiques constatés sur 849 tests : le wrapper lit JUnit, accepte la
disparition d’un échec connu et refuse tout nouvel identifiant, rapport absent,
XML illisible ou liste de tests incomplète.

Après `npm ci` et l’installation de Chromium, `npm run check` exécute Ajv,
ESLint, TypeScript, Vitest, build, Playwright et Axe. L’artefact regroupe le
snapshot, le rapport d’audit, `dist`, les manifests de validation et les
rapports GUT/Playwright ; aucun de ces résultats générés n’est committé.
