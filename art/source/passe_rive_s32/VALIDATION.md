# Validation Recentrage — 30 septembre 2026

Intégré dans le backend public de Passe-Rive et attribué uniquement à `cc2_n08`. Le rapport de résolution conserve maintenant le retour réel de `draw_cards()` dans `cards_drawn`. Le routeur confirme les glyphes du geste au lieu d'ajouter l'ancien effet générique de protection. Aucun coût ni règle de pioche modifié.

## Preuves

| Vérification | Résultat | Rapport |
| --- | --- | --- |
| Régression Passe-Rive : gestes, locomotion, marqueurs, palettes, interruptions | 82 tests / 26 024 assertions, PASS | `artifacts/dev/20260930-214545-test-passe-rive-eaa0a87d/gut-strict-report.json` |
| Recentrage après dernières corrections visuelles | 4 tests / 3 589 assertions, PASS | `artifacts/dev/20260930-220349-test-test_unit_test_passe_rive_s32.gd-438ecbf9/gut-strict-report.json` |
| Cartes réelles, backend et routeur publics | 40 lancers / 988 contrôles, PASS | `artifacts/dev/passe-rive-recenter-cards-20260930-220123/report.json` |
| Sources immuables, régions, pivots, mains, horloge et hauteur | 8 vues / 96 créneaux, PASS | `source_audit.json` |

Les 40 lancers couvrent huit orientations × cinq situations : base (2 cartes), amélioration (3), une seule copie disponible (1), pioche vide (0), main pleine avant consommation (1 place libérée). Les contrôles comparent les UID de cartes avant/après, le rapport, la quantité de glyphes, le PA consommé, l'absence de soin/protection/déplacement et le retour au repos. Refus sans PA vérifié séparément.

Les tests ciblés couvrent les deux versions dans huit vues, le franchissement exact du marqueur et un grand pas de simulation, toutes les poses dans trois tailles de profil, les confirmations absentes/dupliquées/erronées et les interruptions avant/après résolution (annulation, changement de mode, mort, arrêt du lecteur).

La grille est capturée directement dans Godot à ×2, sur deux fonds. Les captures de combat utilisent la vraie scène Battle et des cartes préparées, avec l'IA suspendue ; il ne s'agit pas d'une run complète depuis le menu. Les chemins et métriques des médias finaux figurent dans `review/provenance.json`.

## Revue visuelle et reprises

- Vue ouest refaite : plus de réduction progressive des jambes en fin de planche.
- Vue nord refaite : stature et longueur des jambes conservées.
- Occlusions des bras reprises dans les vues arrière ; clavicule droite et main réceptrice gauche respectées.
- Vue nord-ouest remplacée après comparaison Godot, car son premier buste était trop massif.
- Maintien de la paume NW au créneau 7 pour éviter une réouverture intempestive.
- Fondu de sortie réduit de 140 à 60 ms pour limiter les doubles contours.
- Deux derniers créneaux S remplacés par le repos dessiné, pour relever la tête avant le fondu natif. Ce dernier ajustement de récupération est vérifié par les tests ciblés et la capture finale ; il ne change pas la pose de résolution des 40 lancers.

Échelle constante par direction, variation de hauteur des silhouettes inférieure à 2 %, sans correction d'échelle par image. Palette calibrée sur les matières natives. Les plis et contours ne sont pas identiques pixel à pixel entre illustrations ; les glyphes peuvent être partiellement masqués par le corps dans les vues arrière.

Les scripts nouveaux et le backend public passent le contrôle de format et de structure. Le formateur global du routeur signale une divergence structurelle sur son contenu existant : aucune réécriture globale appliquée ; seuls le branchement n08 et son accesseur ont été ajoutés, puis vérifiés dans Godot. Contrôle Git des espaces sur le travail de cette étape effectué. Modifications UI/progression de l'autre tâche conservées.
