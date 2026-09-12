# Reprise — nouveau personnage et chaîne de production Ankama

**Nouvelle instruction du 12 septembre : revenir au plus simple.** L'utilisateur
fournit une ancienne planche et demande une tentative directe de marche dessinée,
peu d'images, quatre angles, puis essai Godot. Cela remplace la priorité externe
du diagnostic ci-dessous. [Marche simple](../../art/source/characters/achilles/veilleur_walk_simple_v1/README.md) : une génération ImageGen, 7 poses réelles par vue,
10 images/s, aucun rig/intermédiaire. Import et 93 contrôles natifs réussis ;
quatre captures inspectées et WalkSimpleReview.tscn ouvert pour essai utilisateur.
Rapport : artifacts/dev/20260912-162544-veilleur-simple-6b7e1786/summary.json.
Ne pas relancer recherche, nouveaux outils ou rig pour cette demande.

12 septembre 2026. **Dernier retour : les quatre vues fonctionnent à peu près,
mais le personnage est jugé mécanique, sans vie et médiocre. Rejet artistique
explicite ; demande de reprendre la méthode.** Lire d'abord le
[diagnostic de reprise](../design/achilles/animation_reset_2026-09-12.md).
Ne pas lancer une V6 procédurale ou étendre ce cycle aux autres actions.
Le dossier pose-first précédent n'a pas été suffisamment exécuté : core rigide,
courbes génériques et contrôles techniques ont pris la place du jugement des poses.
Comparaison : `http://127.0.0.1:8734/files/animation_reset/review.html`.
Priorité : source animée convaincante et modifiable, puis adaptation témoin ;
capacité autonome proche d'Ankama non démontrée. Aucun achat/contact engagé.
La V2 reste rejetée pour le naturel
du geste ; la référence de Nicolas reste l’inspiration demandée. Les proportions de
`veilleur_proportions_v1` restent acceptées comme base, canon C, **Veilleur d’airain**.
La marche E V1 antérieure reste rejetée pour disproportion.
Lire cette fiche, puis seulement les chapitres nécessaires. Vérifier Git avant édition.

## Dernière sortie — marche quatre vues, laboratoire Godot

- [Dossier, dessins, prompts et lancement](../../art/source/characters/achilles/veilleur_walk_iso_v1/README.md).
  Aperçu : `http://127.0.0.1:8734/files/veilleur_walk_iso_v1/review.html`.
- 48 images × E/S/N/W, cycle commun 800 ms. E V5 conserve ses pixels ; son
  pivot d’affichage est recalé. S/N/W ont de vraies nouvelles pièces ImageGen,
  pas de miroir. Quatre appels : S, N, W et correction de l’écharpe S.
- Nouveaux dessins détourés, attaches annotées, tissus en surface continue.
  Bottes avec échelle uniforme constante et rotations, aucun écrasement animé.
  Corrigé : attache d’écharpe d’abord inversée, mains trop basses, pointe de
  botte W prise dans le pantalon, recouvrement insuffisant dans les revers.
- Ressources dans `assets/characters/Achilles/veilleur_walk_iso_v1/` ; lecteur
  dédié et `tools/veilleur_walk/WalkIsoReview.tscn`. Lancer `iso.ps1 open`.
  Grille forêt, Pathfinder et occlusion réels. Phase conservée aux virages,
  vitesse de marche proportionnelle à la distance du cycle. Pas de menu public.
- 234 contrôles Godot GPU réussis, rapports datés dans
  `artifacts/dev/20260912-152227-veilleur-iso-691273e2/`. Captures natives
  inspectées. 46 contrôles exports réussis ; suivi de la semelle proche sur
  17 images d’appui à plat par direction (décalage détecté : 0/1/1/0 px source,
  donc au plus 0,3 px à taille jeu). 68 contrôles navigateur réussis.
- **Revue reçue : rejet artistique du cycle et de son caractère mécanique.** Arrêt = dernière pose ; virages instantanés,
  aucun véritable idle, aucune animation de combat ajoutée. Rester sur la marche
  tant que les nouvelles silhouettes et le mouvement ne sont pas jugés.

## Sortie précédente — articulations affinées, E V5

- [Source, retouche et limites](../../art/source/characters/achilles/veilleur_walk_E_v5/README.md) ;
  revue `http://127.0.0.1:8734/files/veilleur_walk_E_v5/review.html`.
- Même cadence (48 images/800 ms), même distance (59,5 px/cycle), même squelette
  de jambes et même mouvement du corps que V4. Bottes originales rigides.
- Coudes articulés (2°–8°), léger décalage du balancement ; avant-bras proche
  devant la tunique. Longueurs conservées, mains opposées aux pieds sur le cycle.
- Raccord du pantalon par une surface continue : interpolation séparée de la
  rotation et de la projection, repères de déformation recentrés dans le tissu.
  Retrait des pinces de largeur par paliers. Zéro inversion sur le dessin aux 48 poses.
- **Un appel ImageGen intégré** pour compléter les surfaces cachées du pantalon.
  Prompt et résultat bruts conservés. Le résultat a encore un damier peint ;
  détourage logiciel déjà autorisé, limité au tissu sombre. Seuls 1741/2315 pixels
  absents des deux jambes sont ajoutés ; zéro pixel existant changé. Bottes générées
  inutilisées. Réutiliser les `leg_*_completed.png`, ne pas refaire la génération.
- Retour du pied abaissé : maximum 7,94 px contre 12,96 ; raccords de vitesse de
  position, levée et angle corrigés aux limites d’appui/retour. Pas de prétention
  de relever encore image par image le GIF de Nicolas.
- 20 contrôles export/mécanique et 26 contrôles navigateur réussis. Suivi raster
  de la semelle proche à plat sur 17 images, aucun déplacement au pixel entier
  détecté après compensation. Gros plans jambes/bras et décors inspectés.
- Le contour du genou est plus continu, mais les ombres restent déformées en 2D ;
  bottes limitées à une vue peinte. Pas de validation artistique de la V5, pas
  de nouvelle intégration Godot, une seule marche E sans équipement.

## Essai précédent — audit de la V3, correction E V4

- [Audit et source V4](../../art/source/characters/achilles/veilleur_walk_E_v4/README.md) ;
  revue `http://127.0.0.1:8734/files/veilleur_walk_E_v4/review.html`.
- Défauts V3 réellement relevés : compression des bottes jusqu’à 35 %, longueurs
  variables, confusion entre jambe lointaine en perspective et anatomie différente,
  deux inversions de calques/cycle, oscillation du corps pour compenser les pieds,
  bords de découpe visibles et cadence copiée trop directement depuis le GIF.
- V4 : bottes rigides d’origine, jambes avec un rapport anatomique commun et
  projection lointaine à 0,95, genoux en recouvrement, profondeur constante,
  talon/semelle/pointe puis retour. 48 étapes, 800 ms. Pas plus court.
- La V4 est reconstruite à partir des principes du mouvement étudié ; **ne pas
  prétendre qu’elle suit encore le relevé exact des 16 poses de Nicolas**.
  Sa construction corrige aussi la longueur limite erronée de la jambe lointaine.
  Les sept PNG sources restent identiques ; cela ne signifie pas que chaque
  silhouette projetée conserve les dimensions du dessin debout.
- Mouvement du corps : amplitude totale x/y 1,6/3,2 px, contre 15,37/19,40 px V3.
  15 contrôles fichiers/mécanique réussis : exports identiques, longueur des
  segments constante dans le plan, contacts annotés fixes et raccord de boucle.
  **Suivi raster réel** de la semelle proche sur 17 images à plat : aucun décalage
  au pixel entier détecté après compensation ; ne couvre pas les autres contacts.
- Premiers essais conservés/décrits : rendu trop accroupi rejeté ; correction
  du signe du contrôle de triangles ; première zone de suivi trop uniforme,
  remplacée par une zone avec le contour courbe du bout de botte.
- Comparaison V3/V4 à leurs cadences ou phases alignées : 23 contrôles navigateur
  réussis, six décors/versions, commandes, fichiers, ordinateur/mobile et zéro
  erreur JavaScript. Captures inspectées.
- Limites visibles : genoux encore déformés par découpe et vue unique des bottes.
  **Aucune validation artistique utilisateur**, aucune nouvelle intégration Godot.
  Une seule marche E sans équipement ; rester sur cette animation.

## Essai précédent — référence Nicolas Détrain, E V3

- [Source et limites](../../art/source/characters/achilles/veilleur_walk_E_v3/README.md) ;
  revue `http://127.0.0.1:8734/files/veilleur_walk_E_v3/review.html`.
- Référence réellement examinée : marche corps seul `puppet_8.gif` de Nicolas
  Détrain, Dofus Unity — Universal Puppet/Rig — Animation. Cycle local vérifié :
  16 images exactement répétées, 480 ms selon le GIF. Ce n’est pas une mesure
  du moteur Dofus. Fiche et images : `artifacts/dev/veilleur-nicolas-study/`.
- Repères relevés visuellement, approximatifs ; aucun rig propriétaire récupéré.
  Les directions, replis et phases guident 32 étapes. La trajectoire générique
  de la V2 ne pilote plus le pas. Pivots des chevilles placés dans les bottes,
  raccourcissement en perspective des membres et de l’axe des bottes ; aucune
  longueur projetée supérieure au maximum source. Pièces PNG originales inchangées.
- Revue synchronisée Nicolas/Veilleur, même durée, trois décors, ralenti et
  images individuelles. Les pixels Dofus servent seulement à la comparaison.
  Aucune génération d’image dans cette reprise ; une seule vue sans équipement.
- 18 contrôles navigateur réussis, 32 états synchronisés/distincts, commandes,
  cartes, ressources, ordinateur/mobile, zéro erreur JavaScript. Captures inspectées.
  APNG, WebP et atlas vérifiés contre les 32 PNG, durée 480 ms ; sources inchangées.
- Le recalage des repères de semelle garde un résidu : diamètre sur l’appui
  d’environ 2,59 px côté L et 1,89 px côté R à l’échelle de référence de 112 px.
  Ce sont des repères estimés, pas un suivi exhaustif de la semelle peinte.
- Visuellement : repli plus lisible, mais bottes épaisses et occlusions encore
  approximatives aux croisements. **Aucune validation artistique utilisateur.**
  Pas d’intégration native Godot, ni autre animation. Ne pas passer à la suivante
  en se fondant seulement sur les contrôles de fichiers ou de navigateur.

## Essai précédent — reprise du geste E V2

- `art/source/characters/achilles/veilleur_walk_E_v2/README.md` ;
  revue `http://127.0.0.1:8734/files/veilleur_walk_E_v2/review.html`.
- Repart des PNG du gabarit accepté, sans les modifier. Pas de génération
  d’image. 48 étapes en 1,1 seconde ; une direction, aucun équipement.
- Pantalons continus autour du genou, longueurs des segments et bottes conservées.
  Déformation locale du tissu ; ne pas prétendre que tout le pantalon reste rigide.
  Bassin lissé et bascule modeste du talon à la pointe.
- Erreur du test précédent identifiée puis corrigée : le bras avançait avec
  la jambe du même côté. Vérification des déplacements projetés des mains
  opposés aux jambes sur les deux poses d’appui.
- `report.json` : longueurs et sources conservées, 52 paires de repères de
  semelle contrôlées ; ces repères ne suivent pas exhaustivement les pieds peints.
  `export_report.json` : APNG et atlas identiques aux 48 PNG, durée 1100 ms.
- `verification.json` : 20 contrôles navigateur, 48 états avant/après synchronisés,
  commandes, six comparaisons de décor/version, téléchargements et affichages.
  Premier contrôle échoué conservé ; premier delta temporel négatif corrigé,
  nouvelle vérification réussie sans erreur JavaScript. Captures inspectées.
- Proportions acceptées sur la base précédente seulement ; **V2 jugée non naturelle
  par l’utilisateur**. La V3 suit sa demande d’adapter la marche de Nicolas.
  Aucun nouveau test natif Godot ni intégration campagne.

## Avancée actuelle — correction des proportions

- Source : `art/source/characters/achilles/veilleur_proportions_v1/README.md`.
  Revue : `http://127.0.0.1:8734/files/veilleur_proportions_v1/review.html`.
- Les pièces sont extraites directement de C ; pantalons et bottes d’origine,
  rotations/translations avec une échelle commune. Aucune pièce étirée pour
  atteindre un gabarit. Repères mesurés dans `landmarks.json`.
- Remontage neutre des pièces : zéro pixel changé. Longueurs des segments
  conservées. C’est une preuve de construction, pas de qualité d’animation.
- Comparaison à échelle identique, référence fixe à gauche, 24 étapes d’essai
  à droite ; affichage arrêté au chargement. Genoux et raccords encore provisoires.
  Ne pas présenter ce test comme une marche finale corrigée.
- Revue : 34 contrôles navigateur réussis ; référence inchangée entre poses,
  commandes, liens, affichages ordinateur/mobile et aucune erreur JavaScript.
- Suite : raccords et poses d’appui de cette vue, sans modifier les proportions.

## Essai rejeté — marche E V1

- Source et limites : `art/source/characters/achilles/veilleur_walk_E_v1/README.md`.
  Revue : `http://127.0.0.1:8734/files/veilleur_walk_E_v1/review.html`.
- Quatre appels ImageGen intégrés : deux planches écartées pour alternance
  incorrecte, pièces 2D, puis nettoyage d’une planche de douze poses habillées.
  Ce dernier guide transfère mieux le mouvement dans cet essai. Pas de garantie générale.
- Douze dessins RGBA, 1,1 seconde, une vue seulement, cellules natives 362²
  agrandies uniformément en 512². APNG/WebP et atlas. Construction à 48 étapes
  calculées consultable séparément ; elle reste trop visible pour une sortie finale.
- `painted_frames.kra` contient les douze dessins ; exporter les retouches vers
  `painted_frames.ora`, réellement relu par `tools/veilleur_walk/export_painted.py`.
  Calques sur planche, pas de timeline native Krita. Le dessin nettoyé n’a pas
  les mêmes pièces séparées que le guide. Ne pas confondre les deux sources.
- Contrôle navigateur : 79 vérifications réussies, zéro erreur JavaScript,
  captures ordinateur/mobile et détails sur trois décors inspectés.
  `painted_export_report.json` contrôle les douze fichiers et le cadrage.
  `native_source_report.json` : vrai Krita ORA → KRA → ORA, zéro pixel changé
  sur chacun des douze calques, positions appliquées ; fusion KRA identique.
- Défauts identifiés : genoux trop fléchis, variations des bottes, continuité
  du raccord 12 → 1 à reprendre. L’utilisateur a ensuite rejeté les jambes et
  les proportions de cette marche ; ne pas poursuivre ce gabarit.
  Les mesures des semelles annotées du guide ne valident pas les pieds repeints.
- Photomontages sur captures du jeu du 5 septembre et peinture du sanctuaire.
  Aucun nouveau test natif Godot ni intégration campagne. Aucun code public modifié.

## Livraison actuelle — Veilleur d’airain

- Source : `art/source/characters/achilles/serment_cendre_concept_v1/README.md`.
  Le dossier conserve le nom de la première piste ; le canon proposé est C.
  Six appels ImageGen intégrés, originaux et prompts conservés ; détourage
  logiciel déjà autorisé. Aucun ancien personnage utilisé comme dessin de départ.
- `candidate_c.png` : 1254² RGBA ; `veilleur_concept.kra` : concept natif à deux
  calques, image fusionnée identique au PNG. Ce n’est pas un personnage riggé.
- Vue principale adulte compacte, visage funéraire ivoire et casque bronze ;
  écharpe jade courte, tunique pétrole, genoux/coudes libres, bottes opaques.
  A et B gardés comme comparaisons, trop anatomiques/élancés. Nom de travail.
- Genou et bras levés ; torsion initiale à pieds trop ouverts conservée comme
  rejet. `pose_3_v2.png` réoriente les deux pieds, torsion du buste modeste.
  La main ouverte est un dessin de remplacement. Dos/autres directions absents.
- Preuve locale : avant/après patch de broche dans 3 images de translation
  technique ; 1795 pixels changés par image, zéro ailleurs. Vraie lecture ORA
  puis Krita 5.3.3 → KRA → ORA → reconstruction : zéro différence de pixels.
  Le lecteur applique les offsets réels. Patch de broche seulement, pas rig complet.
- Revue : `http://127.0.0.1:8734/files/serment_cendre_concept_v1/review.html`.
  Trois fonds × trois tailles (96/112/128) × trois candidats, mode silhouette,
  détail à taille native et planche des poses. Photomontages sur captures du
  jeu du 5 septembre et peinture du sanctuaire ; aucune intégration nouvelle.
- Contrôles : `artifacts/spine_trial/serment_cendre_concept_v1/verification.json`
  et `correction/report.json`. Inspection des captures et correction du débordement
  de l’illustration principale sur ordinateur/mobile. Aucun code public changé,
  tests moteur non relancés pour cette création de concept.

## Décisions

- **Cible visuelle proposée : Dofus 2 de jeu, corpus Druant 2014–2017, simplifié
  et adapté à Catabase.** Dofus 3 reste une référence de méthode. Distinguer jeux,
  séries, périodes et présentations promotionnelles. La qualité reste à démontrer.
- Reprendre la charte, les sources éditables, les substitutions dessinées, les
  gabarits d’équipement et les revues. Le système propriétaire Dofus 3 n’est pas
  reproduit et son exporteur/lecteur restent inconnus.
- Le design se choisit à taille de jeu sur nos décors. Ancien Passe-rive conservé,
  sans reconduction automatique de son canon. Objectif adulte, lisible, expressif.
- Ébaucher les poses du corps entier avant de figer le découpage. Klei documente
  des pièces avec plusieurs dessins et une bibliothèque de poses. Marche : une
  direction soignée, puis les trois autres avant idle/transitions et action.
- Choix : Krita + montage Godot + sorties sprites existantes. Ce circuit complet
  reste à tester. Animate non retenu pour le pilote ; Spine option conditionnelle.
  Aucun achat ni installation pour cette recherche.
- Lacune vérifiée : les `.ora` V2 sont des poses transformées écrites par le
  générateur ; il relit les PNG de la V1, pas ces `.ora`. Aucun aller-retour de
  retouche par ces fichiers n’est livré. Les pieds n’ont pas de substitutions
  pendant le cycle. La revue native actuelle utilise la forêt historique.
- Premier périmètre : une morphologie, quatre vues, marche, idle/transitions,
  une action expressive puis un accessoire. Pas de vestiaire universel immédiat.
- Aucun délai fiable par personnage accepté. Après deux corrections ciblées sans
  progrès sur un défaut, changer d’approche pour cette pièce et documenter pourquoi.
- Les constats et exemples conservés sont une mémoire externe ; ce travail
  n’entraîne pas les poids du modèle.

## Livrables et preuves

- [Audit actif : 15 chapitres, 18 références sélectionnées](../design/achilles/ankama_character_feasibility_2026-09-12.md).
- [Premier audit conservé](../design/achilles/ankama_character_pipeline_2026-09-12.md) ;
  ancien site sous `ankama_character_production/v1/`.
- [Version à consulter](http://127.0.0.1:8734/files/ankama_character_production/review.html),
  téléchargeable et imprimable, avec exemple interactif de coût en pixels.
- Nouveau cache documenté : `artifacts/dev/ankama-feasibility-research/README.md`.
  Dofus 2 : cinq planches sélectionnées ; Klei GDC : diapositives et bibliothèque
  examinées ; témoignages directs Kevin/Klei, Vasseur et Bourassa ; docs outils.
- Cache antérieur : `artifacts/dev/ankama-pipeline-research/README.md`.
  Les planches personnages et équipements, l’entretien Dofus Mag et le bilan
  Nindash ont été examinés. La vidéo officielle du 6 juin 2024 reste à étudier :
  transcription indisponible, aucun détail interne déduit de cette tentative.
- Construction et contrôle : `tools/ankama_research/build_report.ps1` et
  `tools/ankama_research/verify_report.mjs`.
- Rapport de contrôle : `artifacts/spine_trial/ankama_character_production/verification.json`.
  14 contrôles réussis : dossier complet, navigation, téléchargement, calcul,
  saisie invalide, neuf liens de preuves locales et archive, deux illustrations,
  affichages ordinateur/mobile et absence d’erreur JavaScript. Captures ordinateur,
  mobile et tableau de pipeline inspectés visuellement.
- Godot 4.7.1 identifié par doctor, import non vérifié, avertissement Git du contexte
  isolé conservé dans les preuves. Krita portable 5.3.3 (858d352) trouvé sous
  `artifacts/dev-tools/krita/krita-x64-5.3.3/bin/krita.exe` ; application non relancée.
- Aucune modification de code du jeu ; tests moteur non relancés pour ce dossier.
  Mémoire courte et fiche historique actualisées ; travaux existants préservés.

## Suite concrète

Examiner la marche E V2 à partir du gabarit accepté `veilleur_proportions_v1`.
Corriger le geste et les raccords restants, puis juger les pieds dessinés en
déplacement. Ne pas poursuivre la marche V1 ni modifier la morphologie pour
accommoder le geste. Les autres vues viennent après cette direction ; les
contrôles de fichiers ne valent pas acceptation des animations.

La [marche Passe-rive V2](../../art/source/characters/achilles/passe_rive_walk_unarmed_v2/README.md)
reste un essai conservé, techniquement contrôlé mais sans appréciation artistique
reçue. Ne pas reprendre ses corrections automatiquement à la place du nouveau héros.
