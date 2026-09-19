# Laboratoire du système de build

Expériences initiales pour l'[audit du 19 septembre](../../docs/design/catabase_system_audit_2026-09-19.md), puis contrôles de son intégration. Les fichiers `card_experiments.gd` et `analyze.py` restent le laboratoire historique ; le système public actuel est décrit dans [les règles de classes](../../docs/design/class_run_rules_v3.md).

- `card_experiments.gd` : huit spécimens `Spell`, exécutés par le moteur commun. La maîtrise est un paramètre expérimental, pas un système de classes intégré.
- `test/unit/test_build_system_lab.gd` : dix tests de résolution et export de faits du code actuel.
- `analyze.py` : probabilités exactes de rôles de loot, pioche, budgets des chemins et croissance du catalogue. Aucune simulation de victoire.

Depuis la racine :

```powershell
./dev.ps1 test test/unit/test_build_system_lab.gd
python tools/build_system_lab/analyze.py --validation artifacts/dev/<dossier-du-test>/summary.json
```

Résultats sous `artifacts/dev/build_system_lab/`. Passer le `summary.json` de la validation qui vient de terminer. L'analyse rejette un résultat incomplet et les sources principales modifiées depuis l'export. Les empreintes ne couvrent pas toutes les dépendances transitives du projet ; pour un autre checkout, relancer le test.

Les tests de sorts n'exercent pas la propriété des copies de cartes, le tirage, le pilotage d'une run ni son interface. Le bonus conditionnel de `finish` est figé à la création du spécimen : le reconstruire si la Prouesse change.

## Intégration jouable

- `test/unit/test_catabase_class_run.gd` : catalogue de 60 techniques, lancement dans le moteur commun, passifs, copies, maîtrises, runes, sauvegardes et 80 frontières de progression (20 profondeurs × 4 classes). Les victoires de ce dernier scénario sont injectées : il ne mesure pas l'équilibre tactique.
- `class_ui_probe.tscn` : création, préparation, vrai ciblage/alternance de tours dans le combat de production, puis scénario de victoire pour les fenêtres niveau/caractéristiques/maîtrises/butin/équipement. Captures à 1280×720 et 1920×1080, contrôles géométriques et rapport JSON.
- `draw_class_icons.py` : source des 88 SVG originaux.
- `class_balance_probe.tscn` : combats réels des quatre classes et comparaison avec les anciens départs Cartes marteau/arc, avec `label=<dossier> seeds=2401,2402,2403`. Rapport progressif sous `artifacts/dev/<dossier>/report.json` ; attendre la sortie du processus et vérifier que les 18 cas attendus sont présents. Politique automatique gloutonne, pas de taux de victoire humain. Voir l'[audit mesuré](../../docs/design/class_balance_readability_audit_2026-09-19.md).

La sonde UI utilise `-- output=<dossier absolu>` ; la lancer avec un `APPDATA` isolé sous `artifacts/dev/` pour ses sauvegardes. Attendre la fin du processus et inspecter aussi le journal moteur : un rapport de rectangles conforme ne suffit pas à exclure une erreur d'exécution.
