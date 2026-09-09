# Dungeon Draft — contexte de travail

- Projet Godot 4.7.1 / GDScript ; versions dans `tools/dev/toolchain.json`.
- État du produit : `README.md`. Lire ensuite seulement les références utiles.
- Combat : `battle/`, règles : `core/`, définitions : `data/`, présentation : `ui/` et `characters/`.
- Édition de contenu : `addons/dungeon_draft_arena_studio/`. Réutiliser ses services.
- Tests unitaires : `test/unit/`. Scénarios : `tests/` et `tools/*validation/`.

## Opérations communes (PowerShell 7.2+)

- `./dev.ps1 doctor` : moteur, dépendances et outils ; ne valide pas l'import.
- `./dev.ps1 context mot_cle` : chemins pertinents sans charger leur contenu.
- `./dev.ps1 test smoke|monsters|terrain|studio|all` ou un chemin exact de test.
- `./dev.ps1 capture inventory|hud` : captures et contrôles, inspection visuelle à compléter.
- `./dev.ps1 inspect res://...tres` et `references` : propriétés et graphe Studio.
- `./dev.ps1 format` vérifie ; `-Write` applique aux fichiers sélectionnés.
- Guide et limites : `tools/dev/README.md`.

## Contexte et preuves

- Cibler les recherches par dossier/symbole. Lire les dépendances nécessaires au comportement.
- Les sources, rapports complets et contrôles restent accessibles ; un résumé n'est pas une preuve nouvelle.
- Les sorties complètes vont dans `artifacts/dev/`. Lire le résumé puis les détails pertinents.
- Une exécution incomplète, zéro test ou un rapport absent ne vaut jamais succès.
- Conserver les validations obligatoires de la CI ; élargir les tests pour le moteur commun.
- Préserver les modifications en cours des autres tâches. Ne pas reformater le dépôt entier.
- Pour une tâche longue, conserver une courte fiche avec décisions, fichiers, vérifications et suite ; vérifier sa fraîcheur dans Git.
- Pas de délégation par défaut. Aucune économie de tokens ne justifie d'omettre une validation nécessaire.
