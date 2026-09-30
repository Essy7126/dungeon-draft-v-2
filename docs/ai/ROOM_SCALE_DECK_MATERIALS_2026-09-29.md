# Échelle, matières et lisibilité du deck — 29 septembre 2026

## Demande et périmètre

Corriger Passe-Rive trop grand, poursuivre l’étude des interfaces de référence,
puis ajuster le jeu en restant dans une direction sobre, brune et moderne.
Aucun changement de statistiques, de règles des cartes, de butin ou de sauvegarde.
Les modifications concurrentes du HUD tactique et du Prototype v1 sont conservées.

## Références réellement regardées

- Capture officielle de l’inventaire DOFUS 3, ouverte dans le navigateur :
  https://support.ankama.com/hc/article_attachments/30670877916561
  Contexte Ankama : https://support.ankama.com/hc/fr/articles/30236552776593--DOFUS-Lancement-DOFUS-3-0
  Observation : cadre extérieur fin, bandeau/tabs, grille encaissée, grands visuels
  et zones stables pour le personnage, le rangement et les actions.
- Capture de deck Monster Train, dossier de presse de lancement (2020, pas une
  prétention sur l’interface actuelle) :
  https://www.cosmocover.com/wp-content/uploads/2020/02/MonsterTrain-Beta-screenshot-16-2048x857.png
  Contexte : https://www.cosmocover.com/newsroom/good-shepherd-entertainment-shiny-shoes-roguelike-card-battler-monster-train-launches-may-21-on-steam/
  Observation : coût toujours au même endroit, illustration généreuse, nom et
  texte hiérarchisés, cadre donnant à chaque carte son identité.

Décisions de design propres au projet : matière d’ombre brune plutôt que palette
bleue ; petits accents bronze ; rareté et éléments indépendants du fond ; la
fiche détaillée reste fixe à côté du deck. Aucun asset de ces jeux n’est repris.

## Cause et correction d’échelle

L’adaptateur Passe-Rive divisait sa taille par la transformation du parent pour
maintenir 100 pixels à 900p. Le HUD réduisait le terrain et les ennemis mais le
héros annulait cette réduction. Cette compensation est supprimée.

- Combat : profil source 214 × 0,44, calibration de grille et présentation de la
  salle conservées. Zoom et cadrage agissent sur toute la scène.
- Haltes : hauteur humaine définie dans le manifeste Studio, convertie vers les
  214 pixels source de Passe-Rive. Une halte peut cadrer plus près qu’un combat ;
  on ne lui impose plus une hauteur écran identique dans tous les décors.
- Aucun recadrage d’atlas, pivot de pied, geste ou shader de palette modifié.
- Le banc S23 vérifie le rapport au terrain, le zoom manuel et le redimensionnement.
  Son ancienne attente de hauteur écran fixe est remplacée. Un premier essai du
  nouveau test supposait à tort un facteur local de 1 dans toutes les salles :
  il inclut maintenant le multiplicateur artistique prévu par UnitView.

## Interface intégrée

- Deux nouveaux assets vectoriels originaux dans `asset/ui/player_materials/` :
  fonds à grain discret, léger éclairage supérieur, double filet bronze et coins
  sobres ; neuf zones pour ne pas étirer les angles.
- Matière partagée par les colonnes du dossier et les fiches de survol ; fond
  translucide des cartes pour conserver sélection, focus et couleurs de rareté.
- Illustration de réserve agrandie de 54 à 68 px ; liste compacte du deck gardée.
- Titres deck et réserve différenciés ; tri indépendant des deux zones par coût,
  nom ou rareté, sans déplacer ni consommer de copie.
- Coût en PA bleu dans la main ; accès « Deck » nommé explicitement.
- Les fonds et enfants restent passifs : la totalité de la carte reste cliquable.

## Vérifications

- Import + tests des 96 faces : PASS, 2 tests, 1 733 assertions.
  `artifacts/dev/20260929-233026-test-test_unit_test_consumable_cards_visual_identity.gd-1ca953ef/gut-strict-report.json`
- HUD réel : PASS à 1280×720 et 1600×900, 24 captures ; main de 5/7 cartes,
  versions normales/améliorées, survol clavier et souris, absence de recouvrement
  de la main, cartes désactivées et lancer réel.
  `artifacts/dev/20260929-233213-combat-readability-9aa0fac6/report.json`
- Dossier/butin : PASS, 34 captures aux deux résolutions. Trois tris contrôlés
  dans chacune des deux zones ; état sauvegardé identique avant/après tri.
  Transferts, filtres, équipements, progression et reprise restent contrôlés.
  `artifacts/dev/20260929-233740-player-dossier-ed5d7600/report.json`
- Échelle : PASS, 97 contrôles, neuf salles de combat et huit haltes.
  `artifacts/dev/passe-rive-s23-20260929-233702/report.json`
  Mesures détaillées : `rooms.json`, images `room_*.png` dans le même dossier.
- Passe-Rive + calibrations : PASS strict, 102 tests, 22 702 assertions.
  `artifacts/dev/20260929-234139-passe-rive-runtime-9ddcf4e1/gut-strict-report.json`
  Lancement runtime isolé : un autre travail détenait le verrou d’import, donc
  réutilisation documentée des véritables logs/processus d’import du premier test
  de cette demande. Aucun nouvel import concurrent ni réussite simulée. La suite
  GUT et les scripts de calibration sont tous réexécutés, puis analysés strictement.
- Inspection visuelle effectuée : main de sept cartes à 720p, collection à 720p,
  caractéristiques à 720p, salle peinte d’entrée et seuil avec dialogue.
- `git diff --check` : aucune erreur. Formatage structurel des fichiers GDScript
  concernés effectué ; les lignes longues du banc ont été divisées pour éviter
  un défaut du formateur sur les expressions chaînées.

Les captures prouvent ces résolutions et ces parcours, pas une validation complète
de tout le jeu. Les scènes de mesure S23 utilisent des données de laboratoire ;
la capture HUD utilise également le vrai parcours Cartes et un ennemi actif.
