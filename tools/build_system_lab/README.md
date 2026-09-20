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
- `draw_class_icons.py` : source des 88 SVG historiques, conservés comme repli.
- `painted_icon_gallery.tscn` : galerie des illustrations peintes consommées par
  les catalogues, à taille d'interface. Source et prompts sous
  `assets/catabase/class_icons_painted_v1/` ; couverture dans
  `test/unit/test_class_painted_icons.gd`.
- `class_balance_probe.tscn` : combats réels des quatre classes et comparaison avec les anciens départs Cartes marteau/arc, avec `label=<dossier> seeds=2401,2402,2403`. Rapport progressif sous `artifacts/dev/<dossier>/report.json` ; attendre la sortie du processus et vérifier que les 18 cas attendus sont présents. Politique automatique gloutonne, pas de taux de victoire humain. Voir l'[audit mesuré](../../docs/design/class_balance_readability_audit_2026-09-19.md).

La sonde UI utilise `-- output=<dossier absolu>` ; la lancer avec un `APPDATA` isolé sous `artifacts/dev/` pour ses sauvegardes. Attendre la fin du processus et inspecter aussi le journal moteur : un rapport de rectangles conforme ne suffit pas à exclure une erreur d'exécution.

L'[audit de profondeur du 20 septembre](../../docs/design/card_combat_depth_audit_2026-09-20.md)
porte sur les drops Résonance actuels. La sonde conserve désormais le deck à
l'entrée des combats et après récompense. Après la fin du processus, agréger avec
`./tools/build_system_lab/analyze_card_depth.ps1 -Report artifacts/dev/<dossier>/report.json -ExpectedCases 30`
pour cinq graines ; l'analyseur rejette les rapports incomplets ou avec erreurs.
L'agrégation ne remplace pas la vérification du code de sortie et du journal moteur.

Le [complément systèmes et synergies](../../docs/design/card_systems_and_enemy_synergies_2026-09-20.md)
compare les mêmes départs avec `class_policy=survival legacy=false` : priorité
à une garde disponible sous 50 % de PV, sans changer le choix du deck. Trois
graines donnent alors 12 cas. `test/unit/test_card_synergy_ablation.gd` reprend
les tests tactiques et ajoute des comparaisons de terrain, une rupture de marque
à la mort de sa source et des diagnostics d'invocation avec kit et rencontre complets.
Les lignes `SYNERGY_ABLATION` du journal sont des observations ; le succès des
assertions de préparation ne signifie pas qu'une invocation est autorisée en run.
