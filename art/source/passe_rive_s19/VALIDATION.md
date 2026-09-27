# Validation du 25 septembre 2026

Intégration active dans les combats Cartes de la variante Passe-Rive.

| Contrôle | Résultat / preuve locale |
|---|---|
| Régression du lecteur historique | 13 tests, 6 589 assertions ; `artifacts/dev/20260924-184909-test-test_unit_test_passe_rive_autosprite.gd-e69043c5/summary.json` |
| Synchronisation S19 | 4 tests, 545 assertions ; `artifacts/dev/20260925-185441-test-test_unit_test_passe_rive_s19.gd-62098d2c/summary.json` |
| Suite Cartes finale | 98 tests, 9 445 assertions, aucune erreur moteur ; `artifacts/dev/20260925-190459-test-cards-62c27c5b/summary.json` |
| Combat natif D3D12 | 14 sorts, 178 contrôles, captures inspectées ; `artifacts/dev/passe-rive-s19-20260925-native-03/` |
| Parcours réel | Préparation, 8 sorts joués, 3 déplacements, victoire contre l'IA, bilan et reprise du fichier de sauvegarde ; `artifacts/dev/passe-rive-s19-20260925-flow/appdata/s19_flow_report.json` |
| Lanceur et sélection des tests | `artifacts/dev/20260925-191219-selftest--ce15003e/summary.json` |
| Intégrité des images | 14 PNG identiques aux originaux ; `integrity.json` |

Les captures natives vérifient anticipation, contact et récupération des sept
cartes, cinq initiations, miroir, maintien et retrait du sceau. Les tests du
routeur exécutent une vraie volée sur deux ennemis avec un allié dans la croix :
deux impacts seulement, aucun sur l'allié ou les cases vides. Les échecs, esquives
et doubles comptes rendus ne créent pas d'impacts supplémentaires.

Défauts corrigés pendant l'intégration : encodage UTF-8 des métadonnées ; miroir
par transformation complète ; provenance visuelle du sceau depuis le compte rendu
confirmé (son état peut avoir une source nulle). Le scénario d'essai synchronise
les positions après son placement initial pour éviter une fausse marche. Les
captures restent en mémoire pendant les gestes pour ne pas les faire sauter lors
de l'encodage PNG.

L'arène utilise les règles et le circuit d'action de Battle, avec IA suspendue,
positions/main préparées et ressources réinitialisées. Le contrôle de parcours
`passe_rive_s19_flow.tscn` utilise au contraire l'IA normale et les ressources
réelles ; il ne force ni victoire, ni dégâts, ni PA. Ses intentions sont pilotées
par le script d'essai, pas par un clic humain. Les sauvegardes sont isolées.

Les limites artistiques sont listées dans le README de ce dossier. La suite
globale du dépôt n'est pas déclarée validée par ces résultats ciblés.
