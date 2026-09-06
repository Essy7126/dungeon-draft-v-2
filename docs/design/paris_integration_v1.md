# Paris — boss final de Catabase

Paris remplace le Champion dans la cinquième et dernière rencontre, au Temple du Serment Noir. Deux spectres l’accompagnent. Il n’apparaît pas dans les quatre premières salles ; la troisième devient Le Jugement silencieux et oppose Champion + Spectre. L’identité `catabase_shadow_paris` reste stable pour les systèmes de combat, les inspecteurs et les événements.

## Combat

L’archer spectral possède 120 PV, 4 PA et 3 PM. Ses cinq sorts couvrent la flèche spectrale, le feu, la glace, l’attraction et une téléportation personnelle. Ils passent par les règles canoniques de portée, obstacles, terrain, statut et occupation. Le vortex peut attirer une cible sur une dalle dangereuse ou un téléporteur ; Pas du vortex paie ses PA et applique la dalle réellement atteinte. Le feu posé sur la glace produit la réaction d’eau existante.

Un dégât survivable qui laisse Paris strictement sous 20 % de ses PV initiaux déclenche une seule transformation : à 24/120 il reste archer, à 23/120 ou moins il devient démon. Il gagne 30 points de bouclier, sans soin ni réinitialisation des ressources, statuts, initiative ou récupération partagée. Un coup létal tue normalement. Le kit infernal contient le Fouet du Tartare, la Couronne de braises, l’Étreinte du Tartare et Pas du vortex. Les chiffres et règles détaillés se trouvent dans [paris_gameplay_v1.md](paris_gameplay_v1.md).

L’IA conserve une distance de tir en première forme, emploie ses éléments et les dangers de la map, puis recherche la portée du fouet. La transformation annule les anciennes actions incompatibles. Une entrée sur terrain qui transforme Paris suspend son animation de déplacement et replanifie la suite avec ses ressources restantes.

## Présentation

Le personnage reste entièrement en sprites : un AnimatedSprite2D, un pivot fixe et aucune scène 3D. Deux vues maîtresses par forme sont déclinées dans les quatre orientations du combat ; S/W sont des miroirs de E/N. Cette solution conserve le modèle, avec l’inversion visuelle habituelle des asymétries dans les vues miroir.

Les 72 poses sources alimentent 52 clips : repos, déplacement, attaque, canalisation, réaction, mort dans chaque forme, plus la transformation. Certaines poses à la prise d’arc incohérente restent archivées mais sont remplacées dans la lecture par un dessin valide du même geste. Le repos est fixe ; la lévitation est dessinée dans le déplacement. L’attaque dure 0,68 s, la canalisation 0,76 s et la transformation 0,90 s. Les marqueurs de release et les fins d’action proviennent de la même horloge que la lecture des images, avec respect de la pause et de la vitesse du jeu.

Les effets possèdent 32 dessins : flèche, givre, feu, vortex, impact spectral, fouet, couronne de braises et métamorphose. Ils suivent les origines et destinations réelles, les impacts avant attraction et les arrivées de téléportation. Les icônes des huit sorts proviennent des mêmes effets. Les pipelines et leurs contrôles RGBA se trouvent dans `tools/paris_sprite_pipeline/` ; les sorties utilisables sont dans `assets/characters/paris/sprites_v1/` et `assets/vfx/paris/sprites_v1/`.

La fiche ennemie annonce le seuil et affiche le kit courant. Les portraits de phase utilisent une donnée de présentation séparée, sans modifier l’UnitData partagé.

## Vérification reproductible

`tools/paris_sprite_validation/run_unit_checks.ps1 -Regression` couvre les règles de Paris et les systèmes partagés. La matrice `run_matrix.ps1` joue huit scénarios dans quatre directions : flèches, glace, feu, attraction, téléportation, approche, transformation et mort. Achille reçoit son niveau de fixture avant le combat ; les dégâts, PA, PM, déplacements et transformations suivants viennent d’actions normales. Cette matrice isolée ne constitue pas une traversée complète de la campagne.

`run_final_boss.ps1` utilise séparément la véritable salle V publiée, ses trois adversaires, ses obstacles, son terrain et ses positions de déploiement. Les mesures de repos commencent après stabilisation observée de la caméra, sans la déplacer. Les contrôles de pose restent actifs pendant cette attente. Les captures sont exécutées séparément des mesures de cadence pour distinguer le rendu enregistré du coût de lecture GPU.

Les GIF sont assemblés à partir des captures du viewport, avec leurs timestamps d’origine arrondis au centième de seconde. L’encodeur vérifie l’ordre des images et la durée après décodage. Aucun mouvement ni effet n’est redessiné dans ces preuves. Les résultats exécutés et leurs empreintes sont consignés dans le rapport `paris_combat_validation_v1.json`.

Les diagnostics connus de ressources/RID lors de la fermeture des outils Godot sont conservés dans les logs. Ils sont distingués des erreurs de scripts et de combat, qui font échouer la validation.
