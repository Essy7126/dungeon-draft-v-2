# Audit des animations de Passe-rive — 13 septembre 2026

Demande : l’arc reste sorti lorsque Passe-rive ne fait rien ; retrouver l’idle
d’origine et examiner les autres animations. Référence de départ :
`1355493dcd84248b451577affcea3e3dc9b24340`.

## Résultat principal

**Corrigé : la vue de combat forçait une attente armée fixe à son initialisation.**
Le backend remplaçait alors tous les échantillons de repos par
`combat_idle_<direction>`, image zéro. Ce choix ajouté au lot précédent empêchait
la boucle native de jouer, même après la fin d’un déplacement, d’une action ou
d’une réaction. Ce n’était pas une animation de tir bloquée : l’état logique
était bien au repos, mais il sélectionnait la mauvaise ressource.

La surcharge de l’initialisation et le mode de repos armé ont été supprimés dans
`characters/achilles/passe_rive_autosprite_view.gd` et
`characters/achilles/2d/passe_rive_autosprite_backend.gd`. Le backend hérite à
nouveau de l’idle original : 25 images, 12,5 images/s, cycle de deux secondes.
La pose armée est conservée dans les atlas comme dessin de préparation des tirs.
Aucun PNG ni réglage de dégâts, de portée ou de coût n’a été modifié.

Les anciens tests validaient explicitement la pose armée ; ils ont été remplacés
par des contrôles du repos original. Un nouveau test instancie la véritable vue
de production après son initialisation différée, vérifie ses huit orientations,
les requêtes de repos répétées, les fins d’action, les annulations et les réactions.
La sonde de combat exige désormais une boucle native qui avance, en plus de
l’ancrage stable. `AnimatedSprite2D.is_playing() == false` est normal ici : le
backend échantillonne lui-même les images.

## Constats restants, par priorité

| Priorité | Constat vérifié | Conséquence et travail à prévoir |
| --- | --- | --- |
| P2 | 12 sorts classés `strike` sont dirigés vers `bow_quick`, notamment Frappe du Péléide, Crochet et Frappe d’ouverture. | Un coup de mêlée prend la forme d’un tir. Prévoir une animation de frappe puis une association explicite par famille. Le combat réel reproduit ce décalage sur Frappe du Péléide. |
| P2 | 8 sorts classés `guard` aboutissent à `dodge`, y compris Second souffle (`gesture=restore`, soin). | Protection, soin et esquive n’ont pas de geste distinct. Créer au minimum une garde et un geste de récupération/soin. |
| P2 | Les sources du saut classique ne couvrent que W et SW ; les six autres orientations utilisent leur esquive native. | Les 7 sorts dirigés vers `jump` (balayages/Fauchage/Moisson et variantes) changent de nature selon l’orientation. Compléter le saut et créer un balayage adapté. Le **tir aérien `bow_air` possède bien huit orientations**. |
| P2 | Les trois nouveaux tirs commencent et finissent sur une pose armée ; l’idle et la locomotion sont sans arc. | L’arc apparaît/disparaît au raccord. L’idle correct est restauré, mais il manque encore les gestes pour sortir/ranger l’arme. Éviter de masquer ce manque en imposant l’arc au repos. |
| P2 | La comparaison des poses de repos montre un angle de visage différent en E/W entre les dessins natifs et les dessins armés : profil natif, davantage de face dans le nouveau lot. Le rendu NE du nouveau lot est aussi moins net. | Le changement de planche fait varier le personnage au début/à la fin des tirs. Harmoniser les angles et les contours à partir des poses natives ; cette appréciation visuelle ne constitue pas une mesure d’angle de caméra. |
| P3 | L’aperçu de sélection joue directement `attack_N/E/S/W`, issu des anciennes planches. | Le bouton d’attaque ne montre pas les trois tirs réellement utilisés en combat. Aligner l’aperçu sur les gestes de production et proposer les huit orientations. |
| P3 | Les nouveaux tirs ont 5, 6 et 8 dessins distincts pour rapide, chargé et aérien (6, 8 et 9 étapes avec répétitions). | Les gestes sont différenciés, mais les quelques poses ne suffisent pas à démontrer une fluidité équivalente à la référence vidéo. Retoucher les raccords et les intermédiaires avant d’augmenter simplement la cadence. |

Les associations sont observées sur les **94 entrées du catalogue d’expédition**,
sans équipement ni maîtrises de personnage. Le détail exporté distingue 38
entrées `generic` elles aussi envoyées vers `bow_quick` : elles demandent une
revue par effet, sans les assimiler automatiquement à des frappes de mêlée.
Ces nombres décrivent le catalogue audité, pas un équipement simultané de 94 sorts.

Sources de ces constats : `PasseRiveAutoSpriteBackend.action_for`,
`data/visuals/achilles/achilles_spell_visual_resolver.gd`, le manifeste natif,
`tools/passe_rive_autosprite/build_combat_v2.py`,
`ui/selection/character_selection_screen.gd::_clip_for_pose` et
`ui/characters/character_preview_3d.gd::play_clip`.

## Couverture des animations

| Famille | Couverture / comportement observé |
| --- | --- |
| Repos | 8 orientations natives, 25 images ; corrigé et vérifié avant/après. |
| Marche / course | 8 orientations, cycles de 11 / 7 images extraits des planches de 25 ; avance liée à la distance, phase conservée au virage. |
| Tir rapide / chargé / aérien | 8 orientations chacun ; durées 0,58 / 1,05 / 1,10 s ; lâchers 0,20 / 0,58 / 0,52 s. Départ et fin émis une seule fois même sur une image lente. |
| Dash | 8 orientations ; boucle de déplacement puis récupération à l’arrivée ; annulation testée. |
| Impact / esquive | 8 orientations, planches distinctes ; retour au repos testé. |
| Mort | 8 orientations, 19 images sélectionnées ; état terminal, fin unique après fondu, ne retourne pas à l’idle. |
| Saut classique / garde / balayage | Ressources de substitution présentes ; limites visuelles décrites ci-dessus. |

152 noms de clips ne signifient donc pas 152 animations uniques : plusieurs sont
des alias des mêmes planches. Les 66 planches originales conservent leurs
empreintes, transparences et régions dans la ressource combinée.

## Vérifications de ce correctif

- Import Godot et validation stricte : **13 tests, 6 589 assertions, PASS**,
  aucune erreur moteur. Rapport :
  `artifacts/dev/20260913-190638-passe-rive-autosprite-0dfe4a32/gut-strict-report.json`.
- Sonde avant : `artifacts/dev/passe_rive_animation_audit/before/runtime.json`.
  Les huit orientations restaient sur une seule image `combat_idle_*`.
- Sonde après : `artifacts/dev/passe_rive_animation_audit/after/runtime.json`.
  Chaque idle parcourt ses 25 images en 2,5 s ; les **88 retours** (11 cas × 8
  orientations) retrouvent `idle_<direction>`, sans action en attente.
  Les horloges sont avancées de manière déterministe ; ce n’est pas une mesure
  de fluidité sur une machine ni une simulation complète de bataille.
- Combat réel, scénario `combo`, direction de grille E (visuel SE) : **PASS**.
  Déplacement, garde, dash et frappe ; retour natif visible sur la capture finale.
  `artifacts/dev/passe_rive_autosprite/combo_E_visual/runtime_validation.json`
  et `courtyard_final_rest.png` ; captures inspectées visuellement.
- Les trois périodes de repos du scénario combo montrent chacune 9 indices
  d’image sur environ 0,65 s ; erreur d’ancrage et dérive mesurées : 0 px.
- Combat réel, `hit_death`, grille W : **PASS**, 7 impacts reçus dont 6 retours
  d’impact non létal vers l’idle ; aucun marqueur d’attaque parasite. Une seule
  fin de mort, alpha nul à la fin, vue retirée ensuite.
  `artifacts/dev/passe_rive_autosprite/hit_death_W_visual/runtime_validation.json`.
- Combat réel, tir aérien avec kit `volley`, grille S (visuel SW) : **PASS**,
  `artifacts/dev/passe_rive_autosprite/volley_shot_S_visual/runtime_validation.json`.
  Les captures vérifient le raccord au repos et le combat ; leur coût de lecture
  GPU ne permet pas de conclure sur la cadence normale de rendu.
- Comparaison automatisée : `artifacts/dev/passe_rive_animation_audit/comparison.json`,
  **88/88**, et `idle_comparison.png` / `idle_comparison.gif`. Ces deux visuels
  sont des reconstitutions depuis les atlas avec leurs pivots, agrandies hors
  moteur ; ils distinguent la pose armée fixe et la boucle native retrouvée.

Les autres modifications simultanées du dépôt concernent la progression de
Catabase et sont laissées à leur tâche. La suite générale du moteur n’a pas été
relancée pour cette suppression de comportement propre à Passe-rive.

## Suite recommandée

1. Conserver l’idle original comme référence de personnage.
2. Produire les gestes manquants : mêlée, garde, soin, sortie/rangement d’arc,
   puis les six orientations manquantes du saut classique.
3. Associer chaque famille de sort au geste adéquat ; partager cette association
   avec l’aperçu de sélection.
4. Revoir les raccords à vitesse réelle sur les huit directions, puis valider
   les marqueurs, les appuis et les annulations en combat.
