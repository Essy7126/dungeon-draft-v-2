# Paris — boss final de Catabase

Paris remplace le Champion dans la cinquième et dernière rencontre, au Temple du Serment Noir. Deux spectres l’accompagnent. Il n’apparaît pas dans les quatre premières salles ; la troisième devient Le Jugement silencieux et oppose Champion + Spectre. L’identité `catabase_shadow_paris` reste stable pour les systèmes de combat, les inspecteurs et les événements.

## Combat

L’archer spectral possède 120 PV, 4 PA et 3 PM. Ses cinq sorts couvrent la flèche spectrale, le feu, la glace, l’attraction et une téléportation personnelle. Ils passent par les règles canoniques de portée, obstacles, terrain, statut et occupation. Le vortex peut attirer une cible sur une dalle dangereuse ou un téléporteur ; Pas du vortex paie ses PA et applique la dalle réellement atteinte. Le feu posé sur la glace produit la réaction d’eau existante.

Un dégât survivable qui laisse Paris strictement sous 20 % de ses PV initiaux déclenche une seule transformation : à 24/120 il reste archer, à 23/120 ou moins il devient démon. Il gagne 30 points de bouclier, sans soin ni réinitialisation des ressources, statuts, initiative ou récupération partagée. Un coup létal tue normalement. Le kit infernal contient le Fouet du Tartare, la Couronne de braises, l’Étreinte du Tartare et Pas du vortex. Les chiffres et règles détaillés se trouvent dans [paris_gameplay_v1.md](paris_gameplay_v1.md).

L’IA conserve une distance de tir en première forme, emploie ses éléments et les dangers de la map, puis recherche la portée du fouet. La transformation annule les anciennes actions incompatibles. Une entrée sur terrain qui transforme Paris suspend son animation de déplacement et replanifie la suite avec ses ressources restantes.

## Présentation

Le personnage reste entièrement en sprites : un AnimatedSprite2D, un pivot fixe et aucune scène 3D. Deux vues maîtresses par forme sont déclinées dans les quatre orientations du combat ; S/W sont des miroirs de E/N. Cette solution conserve le modèle, avec l’inversion visuelle habituelle des asymétries dans les vues miroir.

Les 72 poses sources alimentent 52 clips : repos, déplacement, attaque, canalisation, réaction, mort dans chaque forme, plus la transformation. Certaines poses à la prise d’arc incohérente restent archivées mais sont remplacées dans la lecture par un dessin valide du même geste. Le repos est fixe ; la lévitation est dessinée dans le déplacement. L’attaque dure 0,68 s, la canalisation 0,76 s et la transformation 0,90 s. Les marqueurs de release et les fins d’action proviennent de la même horloge que la lecture des images, avec respect de la pause et de la vitesse du jeu.

Les effets possèdent 32 dessins : flèche, givre, feu, vortex, impact spectral, fouet, couronne de braises et métamorphose. Ils suivent les origines et destinations réelles, les impacts avant attraction et les arrivées de téléportation. Les icônes des huit sorts proviennent des mêmes effets. La production et ses contrôles RGBA sont décrits dans le [pipeline du personnage](../../tools/paris_sprite_pipeline/README.md) et le [pipeline des effets](../../tools/paris_sprite_pipeline/README_effects.md). Les sorties utilisables sont dans `assets/characters/paris/sprites_v1/` et `assets/vfx/paris/sprites_v1/`.

La fiche ennemie annonce le seuil et affiche le kit courant. Les portraits de phase utilisent une donnée de présentation séparée, sans modifier l’UnitData partagé.

## Vérification reproductible

[run_unit_checks.ps1](../../tools/paris_sprite_validation/run_unit_checks.ps1), avec l’option `-Regression`, couvre les règles de Paris et les systèmes partagés. La matrice [run_matrix.ps1](../../tools/paris_sprite_validation/run_matrix.ps1) joue huit scénarios dans quatre directions : flèches, glace, feu, attraction, téléportation, approche, transformation et mort. Achille reçoit son niveau de fixture avant le combat ; les dégâts, PA, PM, déplacements et transformations suivants viennent d’actions normales. Cette matrice isolée ne constitue pas une traversée complète de la campagne.

[run_final_boss.ps1](../../tools/paris_sprite_validation/run_final_boss.ps1) utilise séparément la véritable salle V publiée, ses trois adversaires, ses obstacles, son terrain et ses positions de déploiement. Les mesures de repos commencent après stabilisation observée de la caméra, sans la déplacer. Les contrôles de pose restent actifs pendant cette attente. Les captures sont exécutées séparément des mesures de cadence pour distinguer le rendu enregistré du coût de lecture GPU.

Les GIF sont assemblés à partir des captures du viewport, avec leurs timestamps d’origine arrondis au centième de seconde. L’encodeur vérifie l’ordre des images et la durée après décodage. Aucun mouvement ni effet n’est redessiné dans ces preuves. L’[agrégateur](../../tools/paris_sprite_validation/summarize_validation.cjs) écrit `paris_combat_validation_v1.json` seulement lorsque les 32 cas de la matrice, la véritable salle finale et le reçu GUT sont complets et valides. Ce rapport distingue les faits des combats, les tests unitaires et les empreintes des preuves ; il ne convertit pas une matrice partielle en réussite.

Les diagnostics connus de ressources/RID lors de la fermeture des outils Godot sont conservés dans les logs. Ils sont distingués des erreurs de scripts et de combat, qui font échouer la validation.


Pour ce lot, les logs GUT finaux attestent **30 scripts, 298 tests réussis sur 298 et 17 224 assertions**, en 25,996 s. Le reçu de l’agrégateur recoupe ces totaux avec les 30 résultats par script et conserve les SHA-256 de `artifacts/paris_sprite_validation_v1/gut_final/stdout.log` et `stderr.log`. Il conserve aussi les huit diagnostics connus de fermeture ; aucun diagnostic runtime non reconnu n’apparaît dans ces deux logs. Les suites incluent Paris, ses origines de sorts et son HUD de phase, ainsi que les régressions Catabase, mage, Achille, spectre, terrain, déplacement et transitions de salle.

Les pipelines Node ont également passé **30 tests** lors de la vérification finale : [extraction et atlas du personnage](../../tools/paris_sprite_pipeline/build.test.cjs), [séparation des dessins sources](../../tools/paris_sprite_pipeline/segmentation.test.cjs) et [effets/icônes RGBA](../../tools/paris_sprite_pipeline/build_effects.test.cjs). Ce résultat est distinct des tests GUT et des combats filmés.

La matrice finale passe **32 combats sur 32**, et la vérification séparée de la salle V passe avec Paris et ses deux spectres. Les **huit sorts** ont réellement été choisis dans ce lot, dont l'Étreinte du Tartare. Le [rapport de combat](paris_combat_validation_v1.json) conserve leurs actions, coûts, dégâts et effets observés. Cette couverture décrit les combats exécutés ; les huit scénarios ne forcent pas systématiquement huit sorts distincts.

## Captures du jeu

La [salle V](paris/media/paris_final_room_v1.png) montre le déploiement sur le Temple du Serment Noir avec son roster canonique. L'[extrait de transformation](paris/media/paris_transform_v1.gif) provient du duel isolé de validation : les quatre poses de métamorphose, le premier fouet, la Couronne de braises puis le retour au repos. Le cadrage fixe a été élargi pour contenir le recul par téléportation et la silhouette du fouet. Les pixels proviennent du viewport ; aucun mouvement intermédiaire n'a été inventé.

Le [reçu d'encodage](paris/media/paris_transform_v1.encode_report.json) vérifie les images et timestamps de cet extrait continu. Les captures et les mesures sans capture sont des lancements séparés.
