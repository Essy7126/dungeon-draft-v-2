# Passe VFX sémantique — suivi

**Implémentation et validation terminées.** Quatre pilotes intégrés en run Cartes, rendu natif inspecté ; validation VFX isolée PASS strict, 23 tests / 1 328 assertions. Capture finale : 46 contrôles réussis, 240 images. L'encodage GIF et ses empreintes sont dans `artifacts/dev/class_card_vfx/semantics/`.

Demande : recherche + règles visuelles + premiers sorts retravaillés, run Cartes uniquement, DA éthérée. Dépôt propre au début de cette passe ; les anciens rapports du 20 septembre sont historiques.

Pilotes : Dague lancée, Braise tenace, Bûcher des ombres, Jardin de givre. Contrats visuels explicites dans `class_card_vfx_profiles.gd`, sans changement de règles, de dégâts ni de délais. Les sols suivent les cellules et la provenance réelles ; les réactions doivent changer de rendu. Les effets associés class_burn / ecosystem_ice suivent leurs états, pas une minuterie graphique.

Fichiers : `vfx/class_cards/`, tests VFX ciblés, documentation design et sonde native dans `tools/class_card_vfx/`.

Sources primaires consultées : Riot Art Education et workflow VFX 2022, Blizzard Diablo IV 2021, RiME/Simon Trümpler, SideFX flipbooks, Godot ; le pipeline interne Dofus 3 n'est pas établi par les sources publiques trouvées. Synthèse complète et choix de production : `docs/design/achilles/cards_vfx_production_2026-09-21.md`.

## Vérifications et suite

- Première suite VFX : 19/20, origine infinie normalisée au premier échantillon de dague ; corrigé avant la suite élargie.
- `./dev.ps1 test cards`, rapport `artifacts/dev/20260921-193143-test-cards-d0a581a9/gut-strict-report.json` : **78/80 tests**, **6 946/6 999 assertions**, FAIL strict. Les **23 tests VFX passent**. Échecs : `test_improvement_affects_one_copy_and_survives_reload` et `test_every_live_card_and_crest_has_distinct_painted_art`. Lire les détails GUT/JUnit dans ce même dossier. Ces deux domaines ne sont pas modifiés par la passe VFX ; aucune comparaison de référence ne permet d'attribuer ici leur cause.
- Une autre tâche modifie actuellement les catalogues d'initiation, `class_cards.gd`, `core/game_manager.gd`, la préparation des personnages et leurs tests. Ces modifications sont préservées. Les validations moteur sont sérialisées par `engine.lock`.
- Une validation Cartes effectuée parallèlement a produit `artifacts/dev/20260921-193911-test-cards-b189a342/gut-strict-report.json`, inspecté avec son JUnit : 79/82 tests, 7 073/7 127 assertions. Les 23 tests VFX passent encore. Aux deux échecs précédents s'ajoute `test_selected_deck_starts_directly_and_survives_reload` avec accès absent à `card_families`. Ce résultat n'est pas un PASS global et ne doit pas remplacer le futur contrôle VFX isolé.
- Deux captures natives complètes déjà réalisées : quatre vrais casts, vues normales et grossies, ticks réels et expirations. Inspection : givre devenu asymétrique ; feu initial trop filiforme, puis sol trop dense ; ajustement final vers une matière plus transparente et des volutes plus larges.
- Captures régénérées après les derniers changements de matière et d'échantillonnage des ticks. Les empreintes des sources finales sont dans `capture_manifest.json` et celles des images/GIF dans `encode_report.json`.
- Neuf scripts GDScript vérifiés par le formateur après édition ciblée ; syntaxe de l'encodeur vérifiée par `node --check`.
- Un rendu final a réussi ses 46 contrôles mais son export de provenance a été refusé parce qu'un catalogue de règles avait changé en parallèle. Le harnais distingue maintenant les sources VFX, obligatoirement stables, du contexte de règles dont il garde les empreintes avant/après. La sonde enregistre en plus les quatre contrats effectivement chargés (`report.casts`). Les pixels n'ont pas été retouchés pour contourner ce contrôle ; une nouvelle capture complète a ensuite été réalisée, comme détaillé ci-dessous.

## Preuves finales

- `artifacts/dev/20260921-195452-test-test_unit_test_class_card_vfx.gd-88537a2a/gut-strict-report.json` : **PASS strict**, 23/23 tests, 1 328 assertions, aucune erreur ni fuite signalée, import recovery compris. Tous les lancers du catalogue courant et les sorts adverses sont exercés ; les trois nouveaux tests couvrent les contrats pilotes et le test terrain existant vérifie également le matériau du vrai tick.
- `artifacts/dev/class_card_vfx/semantics/report.json` : **46/46 contrôles**, quatre vrais lancers, ticks de brûlure et feu de sol, maintien puis expiration réelle des durées, PV/états inchangés par la lecture seule des VFX, ordre des couches, nettoyage. Godot 4.7.1 / Forward+ / D3D12. Les quatre cases observées sur chaque terrain correspondent à une croix amputée par un obstacle réel.
- `capture_manifest.json` : sources VFX et sondes stables ; aucun changement des trois fichiers de contexte de règles pendant la dernière capture. `report.casts` conserve les lignes effectivement chargées des quatre cartes, les cellules touchées et les délais.
- Images inspectées : contact de dague, ignition et maintien de brûlure, vrai tick, disparition, feu et givre maintenus, vues à l'échelle normale. Le feu a une matière plus large et transparente ; le givre a des branches dissymétriques. Les GIF échantillonnent l'horloge des VFX, pas le coût GPU ni le rythme d'une partie complète.
- Le contrôle Catabase lancé parallèlement (`artifacts/dev/20260921-194645-test-catabase-c42ee564/gut-strict-report.json`) reste FAIL : 546 tests, 16 en échec, 76 437/76 576 assertions. Son JUnit confirme les 23 tests VFX réussis. Ce résultat plus large ne constitue pas une régression attribuée à cette passe ni un PASS global.

Suite artistique : décliner les composants après appréciation des quatre pilotes ; fiches prioritaires et critères dans le dossier de production. Aucun chantier Blender, audio, animation corporelle ou profilage GPU dense n'est présenté comme réalisé.
