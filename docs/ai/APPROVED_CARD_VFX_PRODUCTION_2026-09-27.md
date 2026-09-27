# Production des quatre dessins approuvés — 27 septembre 2026

Demande : produire A / Chaînes du Tartare, B / Jardin de givre,
C / Moisson des condamnés, D / Volée du crépuscule. Approbation explicite
reçue après les planches de `docs/design/vfx_avant_production_2026-09-27/`.

Périmètre : run Cartes historique uniquement. Silhouettes et palettes approuvées,
sources Blender reproductibles, exports RGBA, lecteur Godot et essai en combat.
Sentence et Bastion sont les références déjà acceptées ; les changements V2,
personnages et Studio présents dans Git appartiennent à d'autres travaux.

Décisions :
- Chaîne modulaire bronze, une manille à la taille ; terminaison sur le vrai
  déplacement, y compris attraction partielle ou bloquée.
- Rosettes basses sur les seules cases réellement gelées, deux tours de terrain.
- Harpé unique : bonus visuel fondé sur les PV avant dégâts, jamais après.
- Cinq flèches sur la vraie croix ; contact au sol distinct d'un ennemi touché.
- Les lecteurs n'écrivent aucune ressource de combat. Un observateur local des
  cartes expose les preuves du cast (cases, PV initiaux, déplacements) au rapport.

État initial vérifié dans Git : nombreuses modifications concurrentes ; aucune
réinitialisation, aucun reformatage global. Sources acceptées conservées.

## Production effectuée

- Sources : `tools/class_card_vfx/approved/build.py` et
  `art/source/vfx/approved_spells/approved_spells.blend` (six scènes dédiées).
- Exports : 58 PNG Blender, deux atlas animés et quatre composants modulaires.
  Empreintes et ancrages : `vfx/class_cards/approved/provenance.json`.
- Rendu : `approved/player.gd`, `approved/frost_ground.gd`, `approved/controller.gd`,
  raccordement local au routeur Cartes et à l'anticipation existante de Sentence.
- Faits : observateur `core/expedition/class_card_vfx_facts.gd`, ajouté uniquement
  aux quatre cartes dans leur fabrique. Aucune modification du moteur commun.
- Revue : `tools/class_card_vfx/approved/review.tscn`, quatre boutons et variante
  de Moisson ; commande publique Battle, capture native et parcours de reprise.

## Vérifications intermédiaires

- Rerendu du fichier Blender sauvegardé : **58/58 images RGBA identiques**.
  `artifacts/dev/class_card_vfx/approved/source_verification.json`.
- Empreintes des trois fichiers acceptés de Sentence : inchangées.
- Format des sept nouveaux scripts : PASS. Selftest du lanceur et analyseur :
  PASS (`artifacts/dev/20260927-113742-selftest--946d51c8/`).
- Première suite Cartes : 181/182 tests, seul échec sur l'isolation des sauvegardes
  modifiée par la refonte concurrente. La suite partagée suivante est passée à
  182/182 (`20260927-111951-test-cards-a6522730`). Des tests supplémentaires et un
  ajustement des proportions sont postérieurs ; validation finale encore à inscrire.
- Inspection native : manille réduite et descendue à la taille, harpé ramenée à
  environ 1,3 hauteur de la petite cible, cinq contacts de Volée distincts,
  rosettes du Jardin basses après l'éclosion. Correction du harnais de revue
  qui gelait l'animation de retrait d'un ancien terrain entre deux essais.
- Première capture complète : 210 frames et parcours de reprise effectués ;
  échec du contrôle de réentrée car il relisait l'entrée mise en cache. Le scénario
  corrigé fait sortir puis rentrer réellement l'unité. Une capture suivante a
  atteint le plafond de frames avant la fin ; elle n'est pas une validation.

## Validation finale

- **Cartes : 185/185 tests, 14 428/14 428 assertions, aucune erreur moteur**.
  Rapport partagé frais : `artifacts/dev/20260927-113726-test-cards-19e2a418/`.
  Il inclut les 16 tests du nouveau fichier (dont les six contrats hérités de
  Sentence), l'attraction partielle/bloquée, l'esquive, le seuil avant impact,
  la frontière de grille, les alliés, la restauration et la durée du givre.
- **Capture native : 312/312 contrôles, 210 images, sortie moteur 0**.
  `artifacts/dev/class_card_vfx/approved/combat/report.json` et
  `capture_manifest.json` : sources sélectionnées stables pendant la capture.
  Les quatre commandes publiques paient une fois, appliquent leurs vrais effets
  et rendent la main. Bilan et reprise réels vérifiés et inspectés.
  Après capture, `battle/battle.gd` a été modifié à 11:45 par la tâche concurrente
  (raccordements conditionnés au profil des cartes consommables). Les sources de
  ce lot VFX restent identiques au manifeste ; ces captures ne certifient pas
  le nouveau catalogue ni l'ensemble du travail concurrent.
- **Six exports Studio, pixels et durées relus à l'identique** :
  `artifacts/dev/class_card_vfx/approved/workshop_report.json`.
  Le service Studio inchangé a été exécuté dans un projet temporaire isolé,
  pendant la suite globale concurrente. Aucune importation du projet partagé.
  La pose initiale transparente de Moisson reste dans son atlas runtime ; le
  clip d'édition compte 29 dessins et consigne le décalage de 33,33 ms.
- **Animations GIF** : cinq clips natifs de 42 images / 1,4 s, et une lecture
  groupée de 210 images / 7 s. `combat/encode_report.json` vérifie les durées et
  empreintes. Seule la palette GIF est quantifiée ; cadrage et pixels source
  restent ceux du viewport Godot.

Livraison : `combat/quatre_sorts.gif`, sources Blender, documents Studio et
`tools/class_card_vfx/approved/review.tscn` pour rejouer les quatre sorts,
la Moisson renforcée et basculer entre caméra normale et détail.

## Évolution concurrente du produit

La tâche `CARTES_INTEGRATION_RUN_2026-09-27.md` remplace en parallèle le catalogue
du nouveau départ Cartes. Ce lot produit les quatre identifiants **explicitement
approuvés** (`class_g_hook`, `class_t_glacier`, `class_a_reap`, `class_r_scatter`),
conservés pour les anciennes sessions et la revue. Aucun équivalent `cc2_*` n'a
été inventé ou substitué sans dessin ni correspondance mécanique validés.
