# Mémoire courte — animation des personnages

Mise à jour : 12 septembre 2026. Lire les liens utiles seulement ; cette fiche ne remplace pas leurs preuves. Avant édition, vérifier Git et conserver les travaux en cours.

## Contrat artistique et retours utilisateur

- **Retour sur la marche simple : « problèmes au niveau du passage des pieds sinon le reste est correct ».** Préserver le reste. Demande actuelle : identifier un outil de correction locale. La planche suggère des poses de jambes trop similaires et un passage insuffisamment décrit ; examiner ordre/timing puis remplacer les dessins nécessaires. Krita documente lecture image par image et pelure d'oignon. Aucun correctif ni installation réalisés pour cette question.

- **Instruction la plus récente : marche simple dessinée en une tentative, quatre angles et Godot.** L'utilisateur préfère les premières générations et fournit une planche. [Essai simple](../../art/source/characters/achilles/veilleur_walk_simple_v1/README.md) : une génération, sept poses par vue, 10 images/s, pas d'interpolation ni rig. Import et 93 contrôles natifs réussis, captures des quatre vues inspectées, essai Godot ouvert. Avis artistique à recevoir. Cette demande remplace la priorité de chercher un animateur extérieur ; conserver l'ancien diagnostic comme historique.

- **Dernier retour : Veilleur quatre vues rejeté artistiquement ; reprendre la méthode.** Le personnage est jugé mécanique et sans vie malgré le fonctionnement technique. Lire le [diagnostic du 12 septembre](../design/achilles/animation_reset_2026-09-12.md). Ne pas continuer une nouvelle version du cycle procédural. Tête/torse/bassin réunis, poses peu contrastées, réussite des contrôles surévaluée dans la progression. Priorité : une source de mouvement convaincante, modifiable et utilisable légalement, puis une adaptation témoin. Qualité autonome proche d'Ankama non démontrée ; pilote artistique défini, aucune prestation engagée. Les avis « attendu » ci-dessous sont historiques et remplacés pour Veilleur ISO.

- **Demande actuelle : quatre angles de marche et essai en jeu après E V5.** [Veilleur quatre vues](../../art/source/characters/achilles/veilleur_walk_iso_v1/README.md) : 48 images par direction, 800 ms. E V5 conservée, S/N/W dessinées avec ImageGen, aucune inversion par miroir. Écharpe S corrigée sur la bonne épaule, bottes rigides, appuis partagés. Laboratoire `tools/veilleur_walk/WalkIsoReview.tscn`, vraie grille forêt/Pathfinder, clics et flèches, phase conservée dans les virages. 234 contrôles natifs GPU, 46 exports et 68 navigateur réussis. Avis artistique attendu ; marche seule, arrêt en dernière pose et virages instantanés. Les trois vues ne sont plus à produire de zéro. Les paragraphes suivants sont historiques.

- **Dernière demande : continuer d’améliorer la marche après V4.** [V5](../../art/source/characters/achilles/veilleur_walk_E_v5/README.md) : coudes articulés, raccord de genou continu, retour du pied plus bas et transitions de vitesse adoucies. Cadence/squelette/appuis/distance du socle V4 conservés. Un appel ImageGen pour zones cachées du pantalon, résultat et prompt conservés ; damier retiré localement, seulement 1741/2315 pixels manquants ajoutés, zéro pixel existant changé, bottes générées inutilisées. Réutiliser les jambes complétées. 20 contrôles exports/mécanique et 26 navigateur ; gros plans et décors inspectés. Pas de validation artistique ni nouvelle intégration Godot. Rester sur une marche E avant les autres vues.

- **Dernière demande : auto-audit et correction de la V3 du Veilleur.** [V4 et audit](../../art/source/characters/achilles/veilleur_walk_E_v4/README.md) : compression des bottes supprimée, profondeur constante, appuis construits, genoux en recouvrement, corps stabilisé, 48 images/800 ms. La jambe lointaine n’est plus traitée comme une anatomie différente ; les PNG d’origine restent inchangés. Il s’agit d’une adaptation reconstruite, pas du relevé exact du GIF de Nicolas. 15 contrôles d’exports/mécanique et suivi réel du bout de botte proche sur 17 images à plat ; aucun décalage au pixel entier sur cette zone. Genoux encore marqués par la découpe et rotation des bottes limitée. Pas d’acceptation artistique, pas de nouvelle intégration Godot ; une seule marche E. [Fiche de reprise](ankama_character_pipeline_work.md).

- **Étape précédente : marche du Veilleur depuis la référence de Nicolas Détrain.** La V2 est jugée non naturelle ; l’utilisateur demande une marche similaire au modèle Dofus identifié. Conserver la [base de proportions](../../art/source/characters/achilles/veilleur_proportions_v1/README.md) du [canon C](../../art/source/characters/achilles/serment_cendre_concept_v1/README.md). La V1 reste rejetée pour disproportion. Nouvelle [adaptation E V3](../../art/source/characters/achilles/veilleur_walk_E_v3/README.md) : repères manuels du GIF corps seul de Nicolas, cycle vérifié de 16 images/480 ms, 32 étapes du Veilleur, repli et perspective des jambes, chevilles dans les bottes. Sources PNG inchangées ; projections peuvent raccourcir les pièces. Comparaison synchronisée, 18 contrôles navigateur et exports vérifiés. Croisements des bottes encore approximatifs, glissement résiduel des repères d’appui jusqu’à 2,59 px à l’échelle 112 px ; aucune validation artistique. Une vue, aucun équipement, aucune nouvelle intégration Godot. [Fiche de reprise](ankama_character_pipeline_work.md), [audit](../design/achilles/ankama_character_feasibility_2026-09-12.md). Passe-rive conservé.

- **Règle de production conservée : une animation à la fois, dans ses quatre vues, contrôlée et corrigée avant la suivante.** Une direction soignée en premier, puis les autres angles de la même animation. Les lots isométriques existants restent des brouillons. Voir [historique Passe-rive](passe_rive_in_game_work.md).

- **Dernier essai conservé : marche ordinaire sans armes V2.** [Sources, corrections et limites](../../art/source/characters/achilles/passe_rive_walk_unarmed_v2/README.md), quatre vues, 60 images/vue, 267 contrôles Godot GPU réussis ; **appréciation artistique non reçue**. Les repères de construction ne constituent pas un suivi exhaustif des pieds peints. Idle et transitions absents. La nouvelle recherche prime sur la poursuite automatique de cet essai.

- Ancien personnage : **Passe-rive**, Achille de la famille Écho de bronze. Adulte élancé, masque ivoire, capuche pétrole, drapé jade, lance à droite anatomique et bouclier diagonal à gauche. [Canon historique PNG](../../art/source/characters/achilles/passe_rive_v1/reference_choisie.png).
- Bonne résolution, formes lisibles et détails mesurés ; éviter aspect enfantin, anatomie trop musclée et surcharge. Vérifier sur les décors du jeu.
- Une seule direction trois-quarts soignée d'abord, marche puis idle ; ambitions expressives et spectaculaires pour les actions suivantes.
- L'habillage 3D de la Sentinelle a été refusé malgré le progrès mécanique. Le mannequin reste une référence de mouvement.
- La marche Blender V2 a reçu un retour positif **sur le raccordement des pieds**. Ce n'est pas une validation du design final ni de toutes les animations.
- Après le Tir céleste, l’utilisateur juge les animations « vraiment pas mal ». Pour le Trait d’ivoire, il demande expressément une exception locale au canon élancé : bras de traction plus musclé pendant la charge, arc robuste ivoire, jambe arrière fléchie et jambe avant étendue.

## Cas à conserver

| Cas | Statut exact | Preuve / usage |
| --- | --- | --- |
| Fauche V1 | Touche 0, huit poses, impact 300 ms, geste 800 ms ; tests navigateur/Godot réussis, revue artistique attendue. | [Sources et contrôles](../../art/source/characters/achilles/passe_rive_fauche_v1/README.md). Main droite au talon, bouclier dans le dos, rotation et balancier du bassin. Traînée en deux profondeurs. Cadrage 1152×768 / pivot (576,662), à conserver dans les exports. |
| Moisson vitale V1 | Touche 9, six poses sans arme, émission du torse à 620 ms, geste 1200 ms. | [Sources et contrôles](../../art/source/characters/achilles/passe_rive_vital_harvest_v1/README.md). Bras bas, torse en avant/tête en arrière, paumes vertes, courte lévitation et traînée rouge vers la cible ; effets séparés des poses. |
| Trait d’ivoire à l’arc V1 | Touche 8, six poses, charge tenue 1000 ms, décoche à 1620 ms. | [Sources et contrôles](../../art/source/characters/achilles/passe_rive_ivory_bow_v1/README.md). Tremblement local du bras calculé, appui arrière et transformation de l’arc ; pas de rig 3D. |
| Tir céleste à l’arc V1 | Six poses ajoutées sur 7, tension 300 ms, projectile à la décoche 550 ms ; retour à l’arc. | [Sources et contrôles](../../art/source/characters/achilles/passe_rive_bow_v1/README.md). Bras d’arc vers le haut, coude opposé en arrière, buste penché en arrière. Changement d’équipement instantané dans l’atelier. |
| Palette Passe-rive, sorts V1 | Six gestes, 24 poses peintes, laboratoire navigateur et Godot vérifiés ; revue artistique attendue. | [Sources, timings et contrôles](../../art/source/characters/achilles/passe_rive_spells_v1/README.md). Pose forte → impact → récupération ; effets séparés. Tir en projection de lance est une proposition visuelle. |
| Marche peinte Passe-rive V1 | Appuis contestés ; audit des dessins et du guide. | [Audit](../design/achilles/passe_rive_walk_audit_2026-09-10.md). Contre-exemple à comparer aux nouvelles sorties. |
| Marche Blender Passe-rive V2 | Amélioration perçue des pieds ; mannequin éditable. | [Source et contrôles](../../art/source/blender/passe_rive_walk_v2/README.md). Référence de contacts, pas résultat peint. |
| Marche peinte Passe-rive V3 | 12 PNG RGBA, atlas et démonstration Godot livrés ; revue artistique attendue. | [Sources et vérifications](../../art/source/characters/achilles/passe_rive_walk_v3/README.md). Deux appels ImageGen ; candidat B guidé par les poses. Glissement résiduel à examiner, pas de mesure native des contacts peints. |
| Ruée Achille conservée dans l'atelier | Référence interne appréciée. | [Document source](../../art/source/sprite_workshop/achille_dash_e.json). Ne pas l'assimiler à une validation mécanique de tout le premier kit. |

## Règles réutilisables

1. Partir d'une action ou de poses sources réutilisables avant de reconstruire un rig procédural. Valider le corps entier et les occlusions.
2. Une fois le nouveau design retenu, conserver son canon. Une génération indépendante par image peut changer costume et volumes ; un guide correct ne garantit pas son transfert.
3. Juger les **pieds peints** en déplacement. L'appui est stable dans le monde ; dans une boucle sur place, le pied recule relativement au corps.
4. Garder les côtés anatomiques, prises d'armes et perspective. Ne pas fabriquer la direction opposée par simple miroir.
5. Régler poses décisives et rythme avant les intermédiaires. Choisir le nombre de dessins selon le geste.
6. Mesurer le temps d'une correction sans dégrader le reste, en plus du temps de première génération.
7. Réutiliser [SpriteWorkshop](../../tools/sprite_workshop/README.md) pour comparaison, timing et export. Son panneau de référence de mouvement distinct reste une proposition, pas une fonction livrée.
8. Un exemple public, une documentation ou un contrôle d’export ne vaut pas réussite sur Passe-rive. Préserver les sorties originales et les échecs instructifs.
9. Sur un costume ivoire, retirer le fond par seuil de blanc peut trouer le masque et le tissu : le test sorts V1 l’a rejeté et a retenu Birefnet avec décontamination. Vérifier sur fond sombre ET clair.
10. L’impact doit utiliser le même seuil temporel que le changement de pose, y compris avec l’arrêt d’impact. Le lot sorts V1 conserve un test de cette frontière numérique.
11. Une arme qui tourne largement peut nécessiter un cadre plus large et un pivot propre au geste : conserver l’échelle du corps, adapter l’export et le rendu, vérifier aussi le retour idle. La traînée suit les pointes peintes et respecte les occlusions devant/derrière.
12. **Réparation partielle** : une correction de pieds ne doit pas régénérer le masque, le torse ou les armes déjà satisfaisants. Tester un masque local, une piste de correction propagée, ou une pièce rigide indépendante selon le défaut. Ce sont des méthodes candidates, pas des résultats déjà obtenus sur Passe-rive. [Recherche et essai préparé du 11 septembre](../design/achilles/passe_rive_partial_repairs_2026-09-11.md).
13. Le suivi optique doit pouvoir échouer explicitement. Sur la marche isométrique E, un suivi local de quatre images montre une dérive surtout verticale ; un réglage de vitesse seul ne la supprime pas. Le suivi est perdu au croisement suivant : ne pas extrapoler la mesure au cycle complet et ne pas confondre repère de chaussure et point réel de contact.
14. **Source animable stable** : éprouver d’abord quelques poses du corps entier, puis construire les pièces et remplacements selon leurs besoins. Une articulation seule ne résout ni les formes cachées ni le raccourci. Le pilote doit aussi prouver un retour de retouche ; la marche E précède S/N/W, puis idle/transitions.
15. Les références Dofus étudiées montrent un travail de charte, gabarits et marionnette commune. Distinguer Adobe Animate (fabrication attestée), Unity (moteur) et les outils internes non documentés publiquement. La compétence Spine d'un ancien animateur Ankama ne prouve pas que Dofus utilise Spine.
16. Cadence du jeu, délais d'un GIF et nombre de poses originales sont différents. Dans deux GIF de marche étudiés, 16 images à 30 ms se répètent exactement ; cela ne donne pas le nombre de dessins manuels ni une recette universelle pour notre marche.
17. **Ankama, dossier complet du 12 septembre** : gabarits d’équipements avec attaches, superpositions, masquages et parties rigides/souples ; marionnette commune soumise à une compatibilité morphologique ; revues artistiques et essais moteur. Nindash combine images complètes et marionnettes selon le besoin. Les détails propriétaires du lecteur/exporteur Dofus 3 restent inconnus. Ne pas confondre jeux, séries et périodes.
18. **Audit du circuit actuel** : `build_walk.py` lit les PNG de la V1 et écrit les `.ora` V2 comme instantanés de pose ; il ne relit pas ces `.ora`. Aucune retouche expérimentale réalisée pour ce constat de code. Les pieds conservent leur dessin pendant le cycle. Le laboratoire natif affiche la forêt historique, pas les décors émeraude actuels. Ces lacunes sont explicitées dans l’audit consolidé.
19. **Progression** : un héros et une morphologie ; prouver correction locale, quatre vues de marche, puis idle/transitions, action expressive et accessoire. Mesurer le temps des corrections acceptées avant toute estimation de série. Deux retouches ciblées sans progrès motivent un changement d’approche local, pas une génération complète supplémentaire.

## Reprise actuelle, sans achat automatique

Priorité : appliquer le [diagnostic après rejet du Veilleur](../design/achilles/animation_reset_2026-09-12.md). Un nouveau cycle et son adaptation doivent prouver la qualité artistique et la correction locale avant les déclinaisons. L'ancien dossier était pertinent sur les poses, mais notre exécution n'a pas rempli cette promesse. Les essais existants sont conservés. Le transfert Genjutsu reste non soumis ; aucune autorisation de consommation reçue. Les pistes suivantes sont historiques.

## Historique des pistes et essais

L'utilisateur a ensuite autorisé la production avec les outils disponibles, puis
une palette complète de sorts à essayer en jouant. La
[palette de six sorts V1](../../art/source/characters/achilles/passe_rive_spells_v1/README.md)
est livrée avec 24 poses, PNG/atlas, chronologies et laboratoires navigateur/Godot.
Elle réutilise la marche V3. Prochaine étape : juger les gestes et les raccords
dans cet essai avant d’élargir aux autres directions ou à la campagne.
Ludo demandait une connexion et aucun job Higgsfield n'a été soumis ; la demande
explicite d'utilisation de sa génération gratuite reste sans réponse. Le dossier
de recherche ci-dessous conserve des pistes, pas des outils déjà validés.

Le [dossier de recherche](../design/achilles/sprite_generation_research_2026-09-10.md) recommande de tester **Ludo** : preset de marche, puis guide Blender seulement si nécessaire, puis une correction précise. Capacités documentées, exemples publics observés ; aucun résultat Passe-rive validé. PixelLab et Retro Diffusion sont davantage orientés pixel art. Les gros modèles vidéo locaux ne sont pas la première piste sur les 8 Go de VRAM mesurés.

La [bibliothèque de références](../tools/sprite_motion_references_2026-09-09.md) distingue source repérée, mouvement examiné, adaptation testée et adaptation approuvée. Y ajouter quelques clips annotés plutôt qu'un corpus massif non évalué.

Cette mémoire est externe au modèle : lire des animations ne change pas ses poids. Un éventuel entraînement de style ou de mouvement serait un projet distinct, avec données adaptées et mesures sur des personnages/actions non vus.
