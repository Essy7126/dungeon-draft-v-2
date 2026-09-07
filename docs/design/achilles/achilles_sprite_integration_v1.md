# Achille en sprites — intégration Cour des Sources V1

Date : 5 septembre 2026. Remplacement du visuel canonique d’Achille par un personnage 2D dessiné, avec trois états et quatre orientations. Aucun modèle 3D d’Achille n’est requis pour ce chemin.

## Assets et fabrication

- [SpriteFrames livré](../../../assets/characters/Achilles/sprites_cour_des_sources_v1/achilles_sprite_frames.tres)
- [Manifeste des sources, cadrages et hashes](../../../assets/characters/Achilles/sprites_cour_des_sources_v1/manifest.json)
- [Script et guide de reconstruction](../../../tools/achilles_sprite_pipeline/README.md)
- [Sources et prompts ImageGen](../../../art/source/characters/achilles/sprites_cour_des_sources_v1/)

Les quatre orientations sont dessinées séparément. Aucune symétrie horizontale ne change le côté du bouclier ou de la lance. Les sources proviennent de l’outil intégré ImageGen ; le pipeline Node/Sharp effectue uniquement l’extraction, le nettoyage des débris d’alpha, le recalage et l’assemblage des atlas.

Les cellules de sortie mesurent 512 × 384 pixels, avec une ancre commune en (256, 320). L’espace horizontal protège l’extension complète de la lance, sans réduire le personnage pendant son attaque. Les sources originales restent conservées.

## Repos, cadence et appuis

| État | Images utilisées | Cadence |
|---|---|---|
| Repos | Une pose stable par direction | Lecteur arrêté sur idle0 ; aucune oscillation des pieds ou du corps. |
| Déplacement | Huit poses par direction | Quatre poses par case, synchronisées au tween de déplacement : 0,28 seconde en marche (14,29 images/s), 0,20 en course (20 images/s). |
| Estoc | Huit positions temporelles par direction, avec tenue à l’impact et retour à idle0 | 12 images/s ; durée nominale 0,667 seconde ; impact à l’entrée de l’image 3, soit 0,25 seconde après le départ. |

Une horloge de présentation compte le temps depuis le lancement de chaque déplacement. Elle évite que le premier pas consomme le temps de préparation de la frame précédente ; elle respecte la pause et la vitesse temporelle du moteur. L’interpolation et le signal de fin restent fournis par Tween.

Le déplacement de la grille est seul responsable du trajet du personnage. Le sprite ne produit pas de root motion. Une marche explicite reste active entre les segments du trajet. Le même tween pilote la position et la phase du pas ; la dernière pose de chaque case est un appui dessiné. L’arrivée resynchronise la dernière position pour éviter une reprise de marche parasite.

Les poses immobiles et d’attaque sont recalées sur leur contact au sol. Les poses de marche conservent leur élévation de pied pendant les phases aériennes ; elles ne sont pas étirées pour toucher artificiellement le sol. Une petite ombre de contact indépendante reste sous l’ancre.

## Corrections de cohérence

- Les poses de repos redessinées changeaient trop la silhouette : elles sont remplacées par la pose fixe de référence.
- L’estoc avant droit comportait deux pointes de lance : une nouvelle série à une seule pointe est utilisée.
- L’estoc arrière gauche a été régénéré pour obtenir une extension réelle du bras et de l’arme.
- L’anticipation avant gauche ambiguë sur le bras porteur a été écartée.
- Les cycles de marche sont décalés, sans modifier leurs pixels, pour placer les contacts aux images 3 et 7. Un arrêt après une case ne coupe plus la pose aérienne.
- Le budget visuel de Percée couvre son déplacement le plus long ; le contrôleur termine le visuel à l’arrivée, sans allonger le trajet.
- Les fins d’attaque reviennent directement au même idle0 ; aucun dessin de repos différent n’est intercalé.
- La taille est calibrée par groupe source, avec contrôle des proportions ; aucun redimensionnement indépendant par pose ne gonfle le corps pendant une flexion.
- Le HUD, l’ordre de tour et les aperçus emploient les mêmes sprites. Le portrait du HUD est un recadrage de l’atlas, sans nouveau dessin.

## Intégration

La [scène canonique](../../../characters/achilles/AchillesIsoUnitView.tscn) sélectionne explicitement SPRITE_2D. Le [profil](../../../data/visuals/achilles/achilles_cour_des_sources_sprite_profile_v1.tres) contient l’échelle, l’ancre, les durées et le marqueur d’impact. L’ancien chemin 3D reste disponible aux anciennes fixtures de test qui le demandent explicitement.

Les signaux de lancement, d’impact et de fin sont protégés contre les doubles émissions et les annulations pendant un callback. La mort annule les actions et termine par un fondu. Les règles, coûts, cibles et dégâts restent ceux des sorts existants.

La Garde utilise le repos et son événement de sort ; Percée réutilise le déplacement. **Balayage réutilise l’estoc dans cette première livraison à trois animations** : il ne possède pas encore de dessin de balayage dédié.

## Vérification

[Guide des tests et du vrai combat](../../../tools/achilles_sprite_validation/README.md).

La validation graphique utilise le combat de la Cour des Sources : déploiement, déplacement par GridView, Garde, puis attaque légale et retour au contrôle. Elle mesure aussi la stabilité au repos avant et après les actions. Les captures et rapports se trouvent dans `artifacts/achilles_sprite_validation_v1/`.

Les mesures de cadence sans capture sont séparées des captures visuelles : une lecture GPU ou une compression PNG peut ralentir ponctuellement le processus de capture et ne doit pas être interprétée comme la cadence normale du jeu.

Résultats finaux :

- **86 tests graphiques et 2 163 assertions réussis**, code de sortie 0. [Rapport GUT](../../../artifacts/achilles_sprite_validation_v1/gut_delivery/gut.junit.xml).
- [Dernier parcours de combat](../../../artifacts/achilles_sprite_validation_v1/runtime_delivery/runtime_validation.json) : `ok: true`, code de sortie 0. [Capture finale](../../../artifacts/achilles_sprite_validation_v1/runtime_delivery/courtyard_idle.png).

- Parcours sur la vraie map : déploiement, deux cases, Garde, Coup de lance et retour au contrôle réussis ; coûts PA/PM et événements d’impact/fin conformes.
- [Mesure graphique sans capture](../../../artifacts/achilles_sprite_validation_v1/timing_clock_final/runtime_validation.json) : deux cases en **570,904 ms** pour 560 ms nominales. Les sept intervalles de poses consécutives sont compris entre **66,699 et 72,749 ms**, moyenne **70,615 ms** pour 70 ms prévues.
- Estoc : **672,009 ms**, impact à **247,839 ms** depuis le départ de l’animation, à l’image 3 ; une seule émission de dégâts et de fin.
- Repos avant/après : 108 échantillons par période, environ 0,654 seconde, image 0 arrêtée, **0 pixel de dérive** des pieds et de l’ancre.
- Appuis de fin de case contrôlés sur les pixels opaques des dessins, dans les quatre orientations. Contacts compris entre y=318 et y=321 pour une ancre y=320. Les quatre atlas sont restés strictement identiques lors du remappage des pas.

Les mesures décrivent ce parcours sur cette machine ; elles ne constituent pas un benchmark matériel général. Les traces initiales restent conservées, notamment le diagnostic du premier delta trop long avant correction. Un essai intermédiaire a aussi relevé une translation du canvas entier pendant le repos (ancre relative correcte et aucune modification des poses) ; les derniers essais sur canvas stable n’ont pas ce déplacement.

La validation graphique GUT est distincte du vérificateur strict d’import. Celui-ci a conservé un verdict FAIL pour les diagnostics de ressources non libérées à la fermeture de l’importeur Godot, famille déjà signalée dans la documentation du projet. Le lanceur de combat relève également des ressources non libérées à sa fermeture. Ces diagnostics ne sont pas corrigés par cette intégration de personnage et restent visibles dans les journaux.
