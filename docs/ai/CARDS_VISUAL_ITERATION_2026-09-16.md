# Cartes intégrées au HUD — itération visuelle

Statut : ITÉRATION TERMINÉE — WORKTREE_CANDIDATE, présentation vérifiée en runtime ; régressions ciblées ci-dessous. Aucun commit ni push.
Dépôt : Essy7126/dungeon-draft-v-2 ; branche main.
Référence vérifiée le 2026-09-16 : 8d5e7b9c8e68a9699ff74f813f8630f001db4a02 + modifications locales préexistantes conservées.

## Mission

Décision utilisateur : intégrer esthétiquement les cartes à la barre des sorts, harmoniser la présentation, optimiser la place et créer les assets nécessaires dans la DA dessinée. Aucun changement aux statistiques, prix, probabilités ou règles de combat dans cette itération. Aucun commit/push/changement de branche autorisé ou effectué.

## Périmètre

- HUD Recraft : montage et démontage explicites d'une vue de main dans SpellSection ; une seule paire de commandes Déplacer/Fin de tour, les ressources et les onglets objets existants.
- Vue cartes : cadres dessinés bronze/émeraude, icônes de sorts existantes, texte des coûts et conditions, états retenu/sélectionné/indisponible.
- Collection et butin : même cadre et mêmes boutons.
- Deux assets originaux générés avec le skill imagegen, mode builtin. Sources et prompts : assets/catabase/cards_drawn_v1/PROVENANCE.md.
- Probes UI : vérifier le parent réel, l'alternance cartes/objets et le démontage ; captures à 720p et 1080p dans un APPDATA isolé.

## Acceptation et cas limites

La main de six cartes et ses actions doivent tenir à 1280×720 ; HUD ≤210 px (ancien dock 252 px), pieds des acteurs au-dessus du HUD ; pas de duplication des commandes ; cartes conservées au changement d'onglet ; retour au HUD classique sans vue orpheline. Les actions continuent à utiliser les gardes de SpellCaster. Les captures doivent être inspectées, les tests ciblés effectivement exécutés. Une fixture UI n'est ni une run gagnée ni un test humain de plaisir ou de durée.

## Vérifications

- OBSERVÉ : HUD 202 px contre 252 px pour l'ancien dock (−50 px, −19,8 %). Main 182 px ; quatre, cinq et six cartes. À 720p : main `(250,520,832,182)` ; à 1080p : `(338,880,1296,182)`.
- OBSERVÉ : dernière passe `artifacts/catabase_run_balance_validation/cards_drawn_ui_release_20260916/` : **26 captures, 332 contrôles réussis, zéro erreur moteur**, 1280×720 et 1920×1080. Retenue, ciblage sans consommation, annulation de sélection, indisponibilité à zéro PA, recomposition coûtant exactement 1 PA et interdite une deuxième fois, accès au journal, objets/cartes, réserve/remplacement, achat, butin/vente visibles dans les fixtures. Cycle réel joueur → confirmation → IA → joueur ; positions de Déplacer/Fin de tour/Cartes/Objets identiques avant et après. Inspection verrouillée intégralement au-dessus du HUD. Captures de combat, ciblage, objets, indisponibilité, butin, réserve, confirmation et inspection effectivement inspectées pendant l'itération.
- OBSERVÉ : `test_catabase_cards.gd` : 16 tests / 505 assertions, PASS ; `artifacts/dev/20260916-165333-test-test_unit_test_catabase_cards.gd-9cef4db0/gut-strict-report.json`.
- OBSERVÉ : `test_recraft_combat_hud_v1.gd`, dernière passe après ajout de la régression d'inspection : **11 tests / 96 assertions, PASS** ; `artifacts/dev/20260916-171242-test-test_unit_test_recraft_combat_hud_v1.gd-fd6a8a8f/gut-strict-report.json`.
- OBSERVÉ : HUD persistant, dernière passe : **6 tests / 201 assertions, PASS** ; `artifacts/dev/20260916-170906-test-test_unit_test_persistent_run_combat_hud.gd-2b6cd7cc/gut-strict-report.json`. Montage dans SpellSection, objets/cartes, rafraîchissement du thème, démontage idempotent et restauration exacte de la géométrie classique.
- Revue du diff : aucune valeur d'équilibrage modifiée dans cette mission ; les modifications de gameplay visibles au `git diff HEAD` appartiennent aux itérations antérieures préservées.
- Bilan des trois suites ciblées : **33 tests / 802 assertions, tous réussis**. `git diff --check` sans erreur. Tous les moteurs lancés pour les validations ont terminé ; sauvegardes utilisateur isolées dans les artifacts.

## Défauts trouvés et itérations

1. Conflit de nom natif `Skin`, puis annotation `SpellData` incorrecte : corrigés (`CardSkin`, `Spell`) avant validation finale.
2. Première capture : une main de six cartes atteignait 200 px au lieu des 182 px disponibles à cause des noms d'armes sur trois lignes. Coût PA séparé, nom limité à deux lignes et détails complets au survol ; contrôle géométrique ajouté.
3. Le premier collecteur de métriques ignorait le HUD persistant, frère de la scène de test : parcours de cet arbre ajouté. Les 126 contrôles v1 ne suffisaient donc pas à prouver l'absence de débordement.
4. Bouton de sélection : état visuel lié au ciblage réel, effacé à l'annulation ; texte/infobulle CARTES préservés lors du rafraîchissement de thème.
5. Butin : deux drops occupent deux colonnes ; texte secondaire 15 px ; ajout et vente visibles sans défilement pour cette fixture à 720p.
6. Sonde de cycle complet : premier échec dû à la confirmation de fin de tour restée ouverte (PA/PM non dépensés), pas à un tour ennemi bloqué. La sonde confirme désormais par le vrai bouton ; les deux résolutions passent effectivement au tour 2 après une action IA.
7. Les anciens pseudo-percentiles `Performance.TIME_PROCESS` étaient contaminés par lecture GPU/PNG et rafraîchissement lent du compteur. Ne pas les interpréter comme performances du jeu. La sonde mesure désormais 120 intervalles entre images rendues après 1,2 s de stabilisation ; cela ne certifie toujours pas le GPU ni un combat chargé.
8. Déplacement des commandes après changement de tour : les minimums des enfants doivent être fixés **avant** les rectangles de leurs conteneurs. Ordre corrigé et comparaison de géométrie ajoutée.
9. Inspection à 1080p recouvrant les commandes hautes : marge basse optionnelle de 222 px en Cartes, disposition classique inchangée par défaut. Vérification avec inspection verrouillée aux deux résolutions.

## Mesures de présentation

Dernière passe, scène immobile sur GPU Intel local, 120 intervalles rendus après stabilisation : médiane **16,49 ms** / p95 **18,42 ms** à 720p ; **16,72 ms** / **17,32 ms** à 1080p. Ce sont des mesures de cadence observée de la sonde hors écran, pas des temps GPU isolés, un gain de performances apparié ou une promesse de 60 FPS en plein combat.

## Fichiers de cette mission

- `ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd` : API de montage et variante compacte du HUD existant.
- `ui/expedition/catabase_card_hand.gd`, `catabase_card_skin.gd`, `catabase_card_collection.gd`, `expedition_screen.gd` : main, thème partagé, collection/butin, panneau de décision Cartes.
- `ui/inspect_panel.gd` : marge basse optionnelle, sans modification de la valeur classique par défaut.
- `assets/catabase/cards_drawn_v1/` : deux PNG originaux, imports Godot et provenance/prompts.
- `test/unit/test_persistent_run_combat_hud.gd`, `test_recraft_combat_hud_v1.gd` : régressions montage/démontage, thème et inspection.
- `tools/catabase_run_balance_validation/cards_ui_probe.gd`, `studio_ui_audit.gd` : parcours réel, mesures géométriques et captures.
- `README.md`, `docs/ai/CURRENT_STATE.md`, `DECISIONS.md`, `KNOWN_ISSUES.md`, présent rapport : documentation. `BALANCE_BASELINE.md` n'est pas modifié par cette passe (aucune valeur de production changée).

Références inspectées : `AGENTS.md`, README et CURRENT_STATE ; scène et composants HUD, `ui/action_bar.gd`, `ui/player_combat_log.gd`, `battle/battle.gd`, caméra peinte, `core/expedition/catabase_cards.gd`, thème Catabase, confirmation de tour, tests et harnais existants. Les autres changements visibles dans Git préexistent à cette mission.

## Limites

- Pas de nouvelle simulation d'équilibrage nécessaire pour ces modifications de présentation ; les 132 runs de l'itération précédente ne constituent pas un nouveau test de cette interface.
- Tests visuels locaux 1280×720 et 1920×1080, souris/clavier programmatique ; pas de certification manette, ultrawide, localisation longue, ni de confort humain sur une run complète.
- Les marges sombres de la peinture à 720p restent visibles ; l'espace des dalles et des pieds d'acteurs est préservé.
- Assets créés : cadre et paquet uniquement. Icônes de sorts réutilisées, pas une illustration spécifique pour chaque carte.
- La suite élargie Catabase n'est pas relancée ici ; ses 16 échecs documentés précédemment ne sont pas déclarés corrigés.
