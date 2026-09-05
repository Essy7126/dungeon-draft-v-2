# Achille — Cour des sources · concept V1

**Statut : PROPOSITION uniquement.** Direction visuelle et plan de production ; aucun modèle, rig, clip animé ou changement runtime livré par ce document. Les images sont des concepts de référence, pas des assets déjà prêts à animer.

- [Master visuel](../../../art/source/characters/achilles/concepts/cour_des_sources_v1/achilles_master_v1.png)
- [Planche de production](../../../art/source/characters/achilles/concepts/cour_des_sources_v1/achilles_production_board_v1.png)

## Intention

Un Achille adulte, compact et athlétique, d’environ cinq têtes de haut. Il doit se détacher des dalles de calcaire doré et de la végétation olive, tout en appartenant au décor peint. Priorité à la silhouette, aux appuis et à quatre animations soignées. Dofus et Waven servent de références de lisibilité et d’économie de mouvement ; les choix ci-dessous sont propres au projet.

## Construction visuelle

- Casque de bronze ouvert sur le visage ; crête courte en terre cuite, lisible dans les quatre directions.
- Plastron central ivoire, épaules dégagées, volumes d’armure simples ; aucune gravure nécessaire à la lecture en combat.
- Tunique courte bleu pétrole, fendue en trois panneaux larges ; pas de longue cape.
- Brassards et grèves de bronze, mains épaisses, pieds larges ; articulations bien séparées.
- Lance dans la **main droite anatomique**, bouclier rond moyen bleu pétrole et bronze au **bras gauche anatomique**. Ces côtés restent constants lors des rotations.
- Dessin en aplats et plans colorés, contours sombres teintés, quelques ombres franches. Détail concentré sur le visage, le casque et la pointe de lance.
- Ivoire et bronze relient le personnage au calcaire ; bleu pétrole et terre cuite lui donnent une identité distincte des ennemis et du sol.

## Route de production recommandée

Modèle 3D stylisé avec textures peintes et matériau en aplats/toon, rendu dans le viewport orthographique existant. Cette route conserve quatre directions cohérentes, les prises d’armes et la continuité des volumes. Le raster sert de référence artistique : il ne se transforme pas automatiquement en modèle ou en rig exploitable.

Réutiliser le même personnage pour la sélection et le portrait, avec un cadrage plus grand et une pose adaptée. Conserver la cohérence des couleurs et accessoires entre interface et combat.

Le runtime actuel utilise un squelette Meshy de 24 os et un pool de 20 clips, vérifiés strictement. Il n’affiche actuellement aucune arme. Créer un **profil distinct** pour cette proposition et brancher explicitement les accessoires ; ne pas remplacer directement son GLB en supposant la compatibilité.

## Rig et accessoires

- Squelette humanoïde compact : bassin, colonne, cou/tête, clavicules, bras et jambes ; IK pour pieds et mains lors de l’animation.
- Armures en pièces rigides ou pondération très localisée ; coudes et genoux libres de se plier.
- Trois panneaux de tunique indépendants avec peu d’articulations ; crête quasi rigide. Déformations contrôlées, sans dépendre d’une simulation de tissu.
- Lance séparée attachée à un socket de main droite ; bouclier séparé fixé à l’avant-bras gauche. Contrôles de prise pour éviter glissement et pénétration des doigts.
- Repères dédiés aux pieds, à la pointe de lance, au centre du bouclier et aux départs des effets.
- Vérifier silhouette, prises et occultations dans les quatre orientations avant de détailler textures et visages.

## Quatre clips originaux

Les durées ci-dessous sont des **cibles initiales à tester**, pas des mesures de Dofus ou Waven.

| Clip | Intention | Cible de départ |
|---|---|---|
| Attente en garde | Poids posé, respiration discrète, lance stable, bouclier dégagé du visage. | Boucle de 2 à 3 s. |
| Déplacement | Pas courts et puissants, appuis francs, buste stable ; réutilisable pour l’avance avec adaptation du rythme. | Boucle de 0,55 à 0,75 s, adaptée à la vitesse réelle sur la grille. |
| Estoc de lance | Anticipation courte, poussée lisible du bassin et de l’épaule, extension nette, retour en garde. | Total de 0,65 à 0,85 s ; impact après environ 0,20 à 0,30 s. |
| Balayage | Armé lisible, rotation du buste, arc large de la lance, arrêt lourd puis récupération. | Total de 0,80 à 1,05 s ; impact après environ 0,30 à 0,45 s. |

La garde réutilise la pose d’attente avec un bref resserrement procédural et un effet de bouclier. La réaction aux dégâts est un petit recul additif/procédural ; la mort peut utiliser le fondu prévu par l’adaptateur. Ces variantes exigent encore du travail d’intégration et de réglage : elles ne sont pas fournies par les quatre clips seuls.

## Sensation de jeu et intégration

- La grille reste autoritaire sur le déplacement. Les clips sont animés sur place ; aucun root motion ne doit déplacer la cellule gameplay.
- Poser un événement d’impact unique sur chaque attaque. Déclenchement des dégâts, son, flash et traînée doivent suivre ce même événement, avec la récupération conservée après l’impact.
- Utiliser le contrat existant `cast_release_reached` et calibrer son instant pour chaque nouveau clip ; aucune synchronisation approximative fondée seulement sur une durée globale.
- Donner le poids par anticipation, accélération, arrêt et appuis. Traînées courtes, impacts localisés et secousse très légère ; le corps et la cible restent lisibles.
- Garder survol et sélection indépendants du matériau du personnage. La case dorée de sélection et l’aperçu cyan restent visibles ; ne pas recolorer tout Achille.
- Le bouclier ne doit masquer ni la tête ni le pied d’ancrage ; la lance et ses effets ne doivent pas être coupés par le viewport.

## Échelle et critères de validation

Viser d’abord une lecture de la silhouette à environ **100–150 pixels de hauteur visible**, puis ajuster sur une capture réelle de la dernière map. Le runtime configure un viewport de 384 × 384, une taille d’affichage de 96 et un facteur painted de 1,58 ; ces valeurs ne donnent pas directement la hauteur du corps à l’écran. Mesurer le corps, les armes, leur rapport à la case et le zoom réellement utilisés.

La caméra actuelle est orthographique, placée en `(3.5, 2.8, 3.5)` et orientée vers `(0, 0.85, 0)`, avec une taille de 2,6. Le cadrage pourra être adapté au nouveau profil après contrôle des quatre orientations et de l’extension maximale de la lance.

1. **Blockout sur la vraie map :** proportions, contrastes, taille à l’écran, visibilité des cases et cadrage des armes validés.
2. **Rig :** flexions propres, pieds stables, prises d’accessoires sans glissement, silhouette vérifiée dans quatre directions.
3. **Clips et impacts :** quatre clips soignés, variantes procédurales, synchronisation des effets et récupération testées dans le combat.
4. **Capture et essai jouable :** marche courte/longue, changement de direction, attaques proches/lointaines, garde et dégâts ; contrôle du rythme et de la lisibilité à la taille normale de jeu.

## Sources locales inspectées

- `C:/Users/paolo/Documents/dungeon-draft-v-2/characters/achilles/AchillesIsoUnitView.tscn` : choix du profil actif.
- `C:/Users/paolo/Documents/dungeon-draft-v-2/data/visuals/achilles/achilles_meshy_profile_v3.tres` : squelette, clips, caméra et absence d’équipement.
- `C:/Users/paolo/Documents/dungeon-draft-v-2/data/maps/painted/unit_profile_achilles.tres` : échelle painted et ombre de contact.
- `C:/Users/paolo/Documents/dungeon-draft-v-2/characters/achilles/3d/achilles_viewport_3d_backend.gd` : projection orthographique et taille du sprite rendu.
- `C:/Users/paolo/Documents/dungeon-draft-v-2/characters/achilles/3d/achilles_3d_visual.gd` : validation stricte du squelette, pool de clips et nœuds d’équipement.
- `C:/Users/paolo/Documents/dungeon-draft-v-2/characters/achilles/achilles_iso_unit_view.gd` : directions, déplacement, lancement et signal d’impact.
- `C:/Users/paolo/Documents/dungeon-draft-v-2/data/characters/achilles/animations_meshy_v3.tres` : associations actuelles entre actions et clips.

## Génération et prompts

Images créées avec l’outil intégré `image_gen.imagegen`. Prompts exacts conservés : [personnage](../../../art/source/characters/achilles/concepts/cour_des_sources_v1/generation_master_prompt.txt) et [planche](../../../art/source/characters/achilles/concepts/cour_des_sources_v1/generation_board_prompt.txt).

Le master fixe l’apparence ; la planche illustre les intentions de poses, avec de possibles écarts de proportions entre dessins. Sa vignette de combat est une projection dessinée, pas une capture du moteur.
