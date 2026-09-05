# Spectre errant — rendu en sprites

`SpectreGreatswordIsoUnitView.tscn` est une vue `Node2D` directement compatible
avec `battle/unit_view.gd`. Elle ne déplace pas son parent, ne modifie pas les
règles de combat et ne dessine pas d'ombre supplémentaire. L'ombre et le contour
de sélection existants restent gérés par le moteur.

## Ressources

- Profil : `res://data/visuals/spectre_greatsword/spectre_greatsword_sprite_profile_v1.tres`.
- Type du profil : `SpectreSpriteVisualProfile`.
- SpriteFrames : `res://assets/characters/spectre_greatsword/sprites_v1/spectre_sprite_frames.tres`.
- Chaque image mesure 512 × 384, avec le même `foot_anchor = (256, 320)`.
  Pour ce personnage sans pieds, ce nom partagé avec les outils représente la
  projection du corps sur le sol, sous la robe suspendue.
- Échelle de l'image : `display_scale × model_scale`, soit `0.35 × 1.05`, avant
  l'échelle de présentation peinte appliquée par UnitView.

Les quatre orientations sont dessinées : `+X = E`, `+Y = S`, `-X = W`, `-Y = N`.
Le runtime ne retourne jamais une texture en miroir.

## Clips et horloge

| État | Images par direction | Lecture |
| --- | ---: | --- |
| `idle_N/E/S/W` | 1 | Image zéro arrêtée, même pendant les demandes répétées de repos. |
| `walk_N/E/S/W` | 4 | Glissement continu à la vitesse du SpriteFrames, cible 6 images/s. La phase persiste entre cases et changements de direction. |
| `attack_N/E/S/W` | 8 | Durée totale 0,8 s. Impact à l'entrée de l'image 3 : 0,30 s avec huit poids égaux. |
| Mort | Pose de repos | Disparition douce de 0,32 s, sans rotation, déplacement ou déformation. |

L'`AnimatedSprite2D` enfant est toujours en pause. La façade choisit ses images
depuis une horloge monotone réinitialisée au début de chaque action. Elle respecte
`Engine.time_scale` et oublie le temps passé lorsque l'arbre est en pause.
L'attaque utilise les poids relatifs des images pour conserver un marqueur lié à
la vraie pose d'impact ; sa durée totale vient du profil.

Un changement de direction reçu pendant la coupe est conservé, puis appliqué au
retour au repos. Une annulation ou une mort reçue depuis le signal d'impact empêche
toute fin d'action devenue obsolète. Les signaux d'impact, de fin d'action et de fin
de mort sont émis au maximum une fois pour leur cycle.

## Contrat public

- Unité et direction : `bind_unit(unit)`, `set_facing(direction)`, `set_facing_label(label)`.
- Repos et aperçu : `play_idle()`, `play_walk()`, `play_run()`, `get_portrait_texture(direction)`.
- Trajet : `begin_path_movement_feedback(path)`, `begin_movement_feedback(from, to)`,
  `get_movement_segment_duration(path)`, `cancel_movement_feedback()`,
  `end_movement_feedback()`, `synchronize_external_movement()`.
- `update_movement_stride(step, progress)` est volontairement sans effet : aucun
  appui de pied n'est imposé au cycle de lévitation.
- Actions : `play_basic_attack()`, `play_cast()`, `play_spell_action(spell)`,
  `play_hit()`, `play_death()`, `cancel_spell_action()`, `cancel_pending_visual_actions()`.
- Signaux attendus par UnitView : `cast_release_reached`,
  `animation_finished(action_id)`, `death_animation_finished`.
- Origines : `get_default_cast_effect_origin()`, `get_logical_foot_position()`.
- Inspection : `animated_sprite`, `sprite_profile`, `get_visual_runtime_state()`,
  `get_active_backend_name()`, `get_last_backend_error()`.
- Vérification déterministe : désactiver `_process` avec `set_process(false)` puis
  appeler `advance_simulation(seconds)`. Cette API ne change pas la position.

`configure_profile(profile)` permet un profil et des SpriteFrames en mémoire pour
les outils. Le chargement refuse des orientations absentes, des comptes d'images
différents de 1/4/8, des dimensions variables et des durées invalides. Aucun ancien
personnage ne remplace silencieusement une ressource absente.
