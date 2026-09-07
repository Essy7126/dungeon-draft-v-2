# Mage philosophe : vue de combat en sprites

`PhilosopherMageIsoUnitView.tscn` est la vue canonique de `philosopher_mage`.
Elle utilise un seul `AnimatedSprite2D`, les silhouettes dessinées de l'atlas
et le pivot au sol `(256, 320)` sur chaque toile transparente `512 × 384`.
Le modèle ne retourne jamais ses textures en miroir. La scène n'ajoute ni
rotation, ni écrasement, ni déplacement au dessin : la bataille reste seule
responsable de sa position sur la carte.

| Action | Durée | Déclenchement du sort |
| --- | ---: | ---: |
| Attaque / Axiome | 0,64 s | 0,32 s |
| Soin / Maïeutique | 0,80 s | 0,40 s |
| Contrôle / Aporie, Réfutation | 0,72 s | 0,36 s |
| Bouclier / Égide | 0,64 s | 0,32 s |
| Coup reçu | 0,24 s | Aucun |
| Mort | 0,52 s puis fondu 0,12 s | Aucun |

Les valeurs se règlent dans `PhilosopherSpriteVisualProfile`. Chaque sort
possède anticipation, libération et récupération ; `cast_release_reached`
transmet la libération au combat une seule fois. Un pas de temps important
échantillonne d'abord cette pose avant de notifier le combat. Une annulation
ou une mort depuis ce signal ne peut pas terminer une ancienne action.

La marche prend 0,30 s par case et une demi-foulée par segment. Son avancement
vient de `update_movement_stride(step_index, progress)` ; un personnage qui
ne se déplace plus ne continue pas à piétiner. Les sept images de marche
restent continues aux changements de case et de direction. Le repos conserve
une pose fixe, sans déplacement des pieds ou oscillation synthétique.

Les coups confirmés utilisent `EventBus.hit_resolved`. Ils ne coupent jamais
un sort engagé, une marche, ni une réaction déjà commencée. La mort joue
ses poses complètes avant son fondu et son signal unique de retrait.

`get_visual_runtime_state()` expose animation, image, progression, phase de
marche, action, libération, réaction et mort pour les outils de validation.
`advance_simulation(seconds)` permet une lecture déterministe lorsque
`set_process(false)` a désactivé l'horloge réelle. La pause de l'arbre remet
l'horloge à zéro pour éviter de rattraper le temps écoulé à la reprise.

Vérification : `test/unit/test_philosopher_sprite_runtime.gd` couvre les
directions, l'ancrage, la foulée, les cinq sorts réels, les signaux uniques,
les annulations, les coups confirmés, la mort et la pause de l'horloge.

Le profil de proportions `painted_visual_profile` est exporte par la scene.
`UnitView` l'utilise uniquement lorsqu'une presentation de carte ne possede
pas de profil correspondant au mage. Le profil de carte reste prioritaire ;
son multiplicateur global, les limites d'echelle et les donnees d'ombre de
contact restent applicables. Cette mise a l'echelle ne deplace jamais la racine
ni le pivot des pieds et respecte la desactivation explicite des options peintes.

Les mouvements imposes par la bataille utilisent `synchronize_external_movement`
pour recaler le suivi de position avant le retour au repos. Le saut d'un vortex
ne produit ainsi aucune foulee supplementaire ; le prochain mouvement reprend
le pilotage par distance. Le test de teleportation exerce ce contrat sur la vraie
`UnitView`, y compris le pivot des pieds.

Le runner adverse attend la disparition effective du bandeau de debut de tour
avant de planifier et lancer le premier geste. Il conserve seulement le temps
d'introduction encore visible ; une fermeture de scene ou la mort de l'acteur
annule cette attente. Un bandeau bloque est ferme apres quatre secondes actives.
Le contrat est couvert par `test/unit/test_enemy_turn_banner_gate.gd`.
