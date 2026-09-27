# Sélection du personnage — reprise du 25 septembre 2026

Demande : reprendre la lisibilité et la mise en scène de Dofus 3 dans la DA de Catabase.

## Décisions

- Conserver les trois apparences et les quatre classes du jeu, sans inventer de serveur ni de personnage persistant.
- Cartes : choix à gauche, aperçu animé à droite, cinq étapes en haut ; le deck et la difficulté restent visibles.
- Réutiliser le sanctuaire peint, les portraits et les icônes du catalogue. Socle transparent original créé avec imagegen (`assets/catabase/selection/hero_pedestal_v1.png`, prompt dans le fichier `.md` voisin). Aucun changement des règles de combat.
- Préserver le remplacement protégé des sauvegardes et le départ via le GameManager existant.

## Fichiers

- `ui/selection/cards_character_setup.gd` : composition, portraits, aperçu, résumé, navigation.
- `ui/selection/character_selection_screen.gd` : raccord Sanctuaire et retour par Échap.
- `tools/character_selection/selection_cards_review.gd` et scène : clics réels, trois résolutions, construction personnalisée et transfert au départ.
- `ui/selection/selection_hero_stage.gd` : intégration du socle sans capture des entrées.

## État à la reprise

Le lot du 24 septembre figure déjà dans HEAD. Rapport historique :
`artifacts/dev/selection-20260924-v2/report.json`, 216 contrôles et 30 captures.
Les proportions, captures et validations ont été repris dans la suite ci-dessous.
Les modifications S19 et les recherches de conception présentes dans Git sont étrangères à cette tâche.

## Vérifications du 25 septembre

- `test selection` : 50 tests / 1 138 assertions, PASS (`20260925-185649-test-selection-9ed202c3`).
- `test cards` : 97 tests / 9 427 assertions, PASS (`20260925-185932-test-cards-9a95bac3`).
- Parcours visuel intermédiaire : 249 contrôles / 33 captures en 1280×720, 1920×1080 et 1200×896, PASS (`selection-20260925-final`). Ce rapport précède le remplacement du socle provisoire par l'illustration.
- Le contrôle vérifie maintenant la véritable substitution de carte (retrait givre, ajout garde), les revisites de classe, Échap, les trois apparences classiques et le transfert intégral du départ.
- Le formateur signale une divergence structurelle sur `cards_character_setup.gd` ; sa réécriture automatique est refusée. Les deux petits scripts de présentation/validation sont formatés ; les scripts restent vérifiés par Godot.

## État final

- Dernière suite sélection : 50 tests / 1 138 assertions, PASS (`20260925-191137-test-selection-2741fa4d`). Import du socle effectué.
- Dernier parcours : **324 contrôles et 33 captures, PASS**, `artifacts/dev/selection-20260925-verified/report.json` ; aucun ERROR/SCRIPT ERROR dans le journal moteur.
- Chaque clic contrôle l'émission effective de `pressed`. Le harnais transmet mouvement et clic au viewport sans déplacer le pointeur du bureau, pour éviter qu'un événement natif coupe un clic en deux. Un essai intermédiaire non valide (`selection-20260925-painted`) est conservé et n'est pas compté comme preuve de succès.
- Captures inspectées : apparences à 720p/1080p, classe, effets de carte, résumé et mode Classique. Dimensions supplémentaires 1200×896 pour vérifier le centrage.
- Le PNG original transparent et le prompt imagegen sont conservés dans le projet. Aucun changement des règles de combat, des sauvegardes ni des assets S19 en cours ailleurs.

## Références

- Captures Dofus fournies par l'utilisateur : galerie, sélection visible, grand aperçu, bouton de départ prioritaire.
- [Ankama — apparences dans Dofus 3](https://support.ankama.com/hc/fr/articles/47823763118097--DOFUS-L-interface-de-cosm%C3%A9tique-et-d-apparence) : distinction visuelle entre personnage et apparence ; consultation le 24 septembre.
- `docs/current/product.md` et `content.md` : parcours et contenu public faisant autorité.
