# Mémoire courte — animation des personnages

Mise à jour : 10 septembre 2026. Lire les liens utiles seulement ; cette fiche ne remplace pas leurs preuves. Avant édition, vérifier Git et conserver les travaux en cours.

## Contrat artistique et retours utilisateur

- Personnage courant : **Passe-rive**, nouvel Achille de la famille Écho de bronze. Adulte élancé, masque ivoire, capuche pétrole, drapé jade, lance à droite anatomique et bouclier diagonal à gauche. [Canon PNG](../../art/source/characters/achilles/passe_rive_v1/reference_choisie.png).
- Bonne résolution, formes lisibles et détails mesurés ; éviter aspect enfantin, anatomie trop musclée et surcharge. Vérifier sur les décors du jeu.
- Une seule direction trois-quarts soignée d'abord, marche puis idle ; ambitions expressives et spectaculaires pour les actions suivantes.
- L'habillage 3D de la Sentinelle a été refusé malgré le progrès mécanique. Le mannequin reste une référence de mouvement.
- La marche Blender V2 a reçu un retour positif **sur le raccordement des pieds**. Ce n'est pas une validation du design final ni de toutes les animations.

## Cas à conserver

| Cas | Statut exact | Preuve / usage |
| --- | --- | --- |
| Palette Passe-rive, sorts V1 | Six gestes, 24 poses peintes, laboratoire navigateur et Godot vérifiés ; revue artistique attendue. | [Sources, timings et contrôles](../../art/source/characters/achilles/passe_rive_spells_v1/README.md). Pose forte → impact → récupération ; effets séparés. Tir en projection de lance est une proposition visuelle. |
| Marche peinte Passe-rive V1 | Appuis contestés ; audit des dessins et du guide. | [Audit](../design/achilles/passe_rive_walk_audit_2026-09-10.md). Contre-exemple à comparer aux nouvelles sorties. |
| Marche Blender Passe-rive V2 | Amélioration perçue des pieds ; mannequin éditable. | [Source et contrôles](../../art/source/blender/passe_rive_walk_v2/README.md). Référence de contacts, pas résultat peint. |
| Marche peinte Passe-rive V3 | 12 PNG RGBA, atlas et démonstration Godot livrés ; revue artistique attendue. | [Sources et vérifications](../../art/source/characters/achilles/passe_rive_walk_v3/README.md). Deux appels ImageGen ; candidat B guidé par les poses. Glissement résiduel à examiner, pas de mesure native des contacts peints. |
| Ruée Achille conservée dans l'atelier | Référence interne appréciée. | [Document source](../../art/source/sprite_workshop/achille_dash_e.json). Ne pas l'assimiler à une validation mécanique de tout le premier kit. |

## Règles réutilisables

1. Partir d'une action ou de poses sources réutilisables avant de reconstruire un rig procédural. Valider le corps entier et les occlusions.
2. Conserver le canon peint. Une génération indépendante par image peut changer costume et volumes ; un guide correct ne garantit pas son transfert.
3. Juger les **pieds peints** en déplacement. L'appui est stable dans le monde ; dans une boucle sur place, le pied recule relativement au corps.
4. Garder les côtés anatomiques, prises d'armes et perspective. Ne pas fabriquer la direction opposée par simple miroir.
5. Régler poses décisives et rythme avant les intermédiaires. Choisir le nombre de dessins selon le geste.
6. Mesurer le temps d'une correction sans dégrader le reste, en plus du temps de première génération.
7. Réutiliser [SpriteWorkshop](../../tools/sprite_workshop/README.md) pour comparaison, timing et export. Son panneau de référence de mouvement distinct reste une proposition, pas une fonction livrée.
8. Un exemple public, une documentation ou un contrôle d’export ne vaut pas réussite sur Passe-rive. Préserver les sorties originales et les échecs instructifs.
9. Sur un costume ivoire, retirer le fond par seuil de blanc peut trouer le masque et le tissu : le test sorts V1 l’a rejeté et a retenu Birefnet avec décontamination. Vérifier sur fond sombre ET clair.
10. L’impact doit utiliser le même seuil temporel que le changement de pose, y compris avec l’arrêt d’impact. Le lot sorts V1 conserve un test de cette frontière numérique.

## Prochaine décision, sans achat automatique

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
