# Paris : deux formes, un seul personnage de combat

`ParisIsoUnitView.tscn` utilise un seul `AnimatedSprite2D`. Le socle de lecture est
celui du Dialecticien : horloge monotone respectant pause et vitesse du jeu,
marqueur de libération unique, annulation et mort sûres. Aucun modèle 3D ou
étirement du corps n’est ajouté. Les angles opposés utilisent un miroir
horizontal contrôlé, propre à Paris.

Les trois banques attendues sont `frames_spectral.tres`, `frames_infernal.tres`
et `frames_transform.tres` dans `assets/characters/paris/sprites_v1/`.

| Famille | Dessins par angle natif et forme | Durée |
| --- | ---: | --- |
| Repos | 1 | Pose fixe |
| Déplacement | 4 | Progression par distance ; 0,30 s par segment |
| Flèche / fouet | 4 | 0,68 s ; libération à 0,34 s |
| Incantation | 3 | 0,76 s ; libération à 0,38 s |
| Touché | 2 | 0,24 s |
| Mort | 2 | 0,64 s + 0,16 s de fondu |
| Transformation | 4, communs aux deux formes | 0,90 s |

Deux angles natifs sont dessinés et conservés comme références du modèle : E
(trois-quarts de face vers la droite) et N (trois-quarts de dos vers la droite).
S réutilise les textures E avec un miroir horizontal ; W réutilise les textures
N de la même manière. Ce choix conserve exactement la silhouette, le costume
et les armes entre les quatre directions jouables. La main porteuse et la
broche asymétrique sont donc visuellement inversées selon la caméra ; il ne
s’agit pas de quatre vues dessinées indépendamment.

Les ressources exposent toujours 48 clips de forme et quatre clips de
transition. Toutes les images partagent le canevas 512×384 et l’ancrage logique `(256, 320)`. La lévitation du spectre est dessinée dans ses
poses ; le runtime ne fait pas monter et descendre son socle au repos. Les pieds
du démon utilisent le même ancrage de case. Le miroir est appliqué après chaque
échantillon de pose, y compris pendant les changements de direction différés,
les réactions et la mort. Les origines de flèche et de fouet sont symétriques
entre E/S et N/W ; le pivot horizontal reste au centre du canevas.

La vue écoute `Unit.combat_form_changed(unit, old_form, new_form)` et lit
`combat_form_id` dès sa liaison. La logique de combat reste propriétaire du
seuil et du kit. La transition n’émet jamais `cast_release_reached`. Si elle
survient pendant une action engagée, la récupération se termine avant sa
révélation. Les actions suivantes attendent la fin de la transition. Une mort
l’interrompt immédiatement ; une annulation stabilise la forme déjà décidée
par le combat et libère les attentes une seule fois.

`UnitView` fournit une attente annulable indépendante des sorts, dont le délai
de secours respecte la pause et `Engine.time_scale`. `EnemyTurnRunner` recalcule
le plan uniquement lorsque la forme change, par exemple après l’entrée sur une
dalle de feu. Il utilise alors les PA et PM réellement restants, avec le plafond
habituel de quatre actions.

Le profil peint `unit_profile_paris.tres` est appliqué par défaut sur les maps
enregistrées. Paris ne figure plus dans la famille des squelettes ; un réglage
explicite de map conserve sa priorité.

Vérifications dédiées : `test_paris_sprite_runtime.gd`,
`test_paris_sprite_vfx.gd` et `test_paris_visual_phase_lifecycle.gd`. Les résultats
d’exécution et les captures de combat sont conservés par le rapport de
validation de Paris.
