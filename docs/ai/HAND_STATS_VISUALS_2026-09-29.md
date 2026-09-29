# Main et caractéristiques — repères visuels

## Contrat utilisé

Lecture fraîche de `README.md`, `docs/current/prototype_v1.md`, de l'état des cartes,
de l'éditeur de progression et des calculs réels. Les éléments sont maintenant
effectifs : les décisions antérieures au Prototype v1 sur leur absence sont périmées.
Pas de changement d'équilibrage, de sauvegarde ou de dépenses dans ce passage.

## Réalisation

- Main : cadre et nom de rareté issus du même reçu que le butin ; affinité de
  classe, coût, portée et éléments. Pictogrammes originaux en SVG, 15 fichiers.
- Main agrandie à la hauteur déjà utilisée par les faces détaillées. Cinq et sept
  cartes contrôlées ; cartes inactives lisibles ; les enfants restent passifs.
- Infobulles élargies et compactées pour ne pas recouvrir la main. Contrôle des
  48 sorts de base et de leurs 48 versions améliorées au clavier et à la souris.
- Caractéristiques : PV roses, PA bleus, PM verts, ressources/résistances en
  tuiles ; six maîtrises colorées avec détail investissement/équipement au survol.
- Éditeur : onglets Éléments/Aptitudes, symboles cohérents, chiffres avant validation.
  Les transactions atomiques existantes et le verrou en combat restent inchangés.
- Fiche de deck : reprise des mêmes symboles. Les noms restent présents pour
  que la couleur ne soit jamais le seul repère.

## Fichiers / vérifications

`player_stat_symbols.gd`, `consumable_combat_card_view.gd`, `catabase_card_hand.gd`,
`consumable_player_dossier.gd`, `consumable_progression_editor.gd` et
`asset/ui/player_symbols/`. Harnais : `readability_capture.gd`, `dossier_capture.gd`.
Test ajouté : `test_consumable_cards_visual_identity.gd`.

Capture combat finale : `artifacts/dev/20260929-222110-combat-readability-58c88ace/`
— PASS aux deux résolutions 1280×720 / 1600×900, 24 captures, aucun diagnostic.
Inspection visuelle faite sur la main à sept cartes et l'infobulle détaillée.
Les captures intermédiaires ont révélé et corrigé un symbole neutre qui débordait,
des infobulles trop hautes et un conteneur d'identité trop étroit.

Test de texte ciblé : 3 tests, 348 assertions, strict PASS dans
`artifacts/dev/20260929-221458-test-test_unit_test_consumable_cards_readability.gd-3d95409d/`.
Un lancement isolé de la suite Prototype v1 a échoué au chargement de Battle
(`Could not resolve class`), sans erreur à l'import ; contrôle dans la suite complète
et captures publiques effectuées ensuite. Ce résultat isolé n'est pas compté comme réussi.

Capture dossier finale : `artifacts/dev/20260929-222717-player-dossier-0d8aebb9/`
— PASS, 34 captures, deux résolutions, aucun diagnostic. Les six maîtrises sont
visibles sur deux rangées en 720p. Répartition, confirmation, persistance et onglets
contrôlés. Format ciblé et vérification de diff sans erreur.

Suite Cartes : `artifacts/dev/20260929-222242-test-consumable-v2-68581b70/` :
197/198 tests passés, dont les 12 tests Prototype v1. L'unique erreur vient du
nouveau harnais qui ajoutait `Unit` (une Resource) comme Node. Ligne retirée ;
relance ciblée ci-dessous. Ne pas présenter ce premier rapport comme un PASS global.

Relance corrigée : `artifacts/dev/20260929-223006-visual-identity-runtime-8a0e4e97/`
— 2/2 tests, 1 637 assertions, code 0, aucun diagnostic. Contrôle des 96 faces
à largeur réduite et des correspondances élémentaires sans mutation du catalogue.
Exécution runtime sans nouvel import, le verrou étant occupé par une autre tâche.
