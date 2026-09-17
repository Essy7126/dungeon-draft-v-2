# Passe-rive — nouvelles poses de combat

> Rectification du 13 septembre : l’attente armée forcée de ce lot a été retirée
> après le signalement utilisateur. Le repos retrouve sa boucle native dans tous
> les contextes. Voir l’[audit et ses nouvelles preuves](passe_rive_animation_audit_2026-09-13.md).
> Les décisions et résultats ci-dessous décrivent la livraison antérieure.

Début : 2026-09-13 ; référence Git initiale 744f179460553f2a4d92200a16291ee2357e2bcd.

Demande : créer les assets nécessaires après comparaison avec les animations de Crâ (vidéo YouTube 7zgOw8emVwA). Conserver le personnage et le gameplay ; distinguer attente armée, tir rapide, tir chargé et tir aérien.

État : première version intégrée et contrôlée en combat. L’utilisateur a répondu
« Oui, utilise un script pour préparer les sprites ». Aucun accord restant à obtenir.

## Livrables et décisions

- 128 dessins ImageGen, huit orientations indépendantes, 16 poses par planche.
  Corrections du tir aérien SW et d’un arc dupliqué NE. Les premières sorties au
  faux damier ont été remplacées par des sources à fond magenta.
- Sources et prompts : `art/source/passe_rive/combat_v2/`, exclu de Godot par
  `.gdignore`. Préparation reproductible : `tools/passe_rive_autosprite/build_combat_v2.py`.
- Huit atlas RGBA 1536², canevas 384², appui (192,330), échelle constante par
  direction ; cordes d’arc évidées, RGB des bords décontaminé. Les 128 cadrages
  passent les assertions de préparation. Aucun des 66 PNG originaux n’est modifié.
- `assets/characters/PasseRive/combat_v2/sprite_frames.tres` conserve les 120 clips
  natifs et ajoute 32 clips. Le manifeste consigne SHA-256, poses et géométrie.
- Attente armée tenue, activée après l’initialisation différée de la vue de combat.
  L’exploration conserve sa boucle d’attente native. Les tirs commencent et finissent
  sur exactement la même pose armée.
- Tir rapide : 0,58 s, lâcher à 0,20 s. Tir chargé bas (perçant/ligne) : 1,05 s,
  lâcher à 0,58 s. Tir aérien (volée) : 1,10 s, lâcher à 0,52 s, envol/réception.
  Le backend partagé échantillonne les poids autour du marqueur, y compris après
  une image lente. Les annulations ne publient pas de fin ou de lâcher tardif.
- La vue Passe-rive ajoute une courbe de projectile au tir aérien. Le VFX calcule
  position et tangente des flèches et traînées ; ses extrémités, ses cibles et
  l’attente de confirmation des dégâts restent celles du combat.
- Les sondes de capture attendent le nom réel de la pose armée et les animations
  d’effets choisies par la présentation (volée, ligne), avec contrôle de la courbe.

## Preuves de ce lot

- **PASS strict : 12 tests, 6 276 assertions**, aucun diagnostic moteur :
  `artifacts/dev/20260913-174451-passe-rive-autosprite-a20b7169/gut-strict-report.json`.
  Hash/alpha, conservation des clips natifs, 8 directions, appuis, annulations,
  marqueur unique, variantes/sauvegarde et mouvements.
- **PASS parcours public, 16 contrôles** :
  `artifacts/dev/passe_rive_autosprite/entry/report.json`. Sélection, Seuil,
  marche/course natives et arrivées ; APPDATA isolé à chaque lancement.
- **PASS tir rapide sans captures**, `shot_E_timing/runtime_validation.json` dans
  `artifacts/dev/passe_rive_autosprite/` : lâcher 200,599 ms, fin 581,231 ms,
  un lâcher, une fin, une cible touchée et retour `combat_idle_SE`.
- **PASS captures chargées**, `chiron_shot_E_visual/runtime_validation.json` :
  lâcher 593,715 ms, fin 1 051,589 ms, trois victimes réelles, appui sans dérive.
- **PASS captures aériennes**, `volley_shot_S_visual/runtime_validation.json` :
  lâcher 520,687 ms, fin 1 126,630 ms, courbe visible, trois victimes réelles,
  retour `combat_idle_SW` sans déplacement de l’appui. Les mesures graphiques
  incluent la surcharge des captures et ne remplacent pas les tests du marqueur.
- Inspection des images moteur : silhouette entière, pose chargée basse, saut
  au-dessus de l’ombre fixe, flèches courbes, retour armé. Planche des huit
  directions inspectée : `artifacts/dev/passe_rive_combat_v2/pose_review.png`.
  Aperçu comparatif : `combat_comparison_SE.gif` dans ce même dossier.
- Contrôle de format des quatre scripts spécifiques Passe-rive et `git diff
  --check` réussis. Aucun formatage global du dépôt.

## Limites conservées explicitement

La suite élargie reste **FAIL : 165 / 168 tests réussis**, six assertions en échec
dans trois tests `test_catabase_threshold.gd`, plus 8 textures RID / 177 ressources
signalées à la fermeture :
`artifacts/dev/20260913-164847-passe-rive-autosprite-e34d3cd5/gut-strict-report.json`.
Les mêmes trois cas d’entrée et les mêmes quantités de ressources figuraient déjà
dans le rapport v1. Ils concernent le chantier de préparation d’expédition en
cours ; les erreurs ne sont ni ignorées ni présentées comme un succès.

La sélection Passe-rive + VFX exécute 35 tests / 6 574 assertions, tous réussis,
mais son verdict strict reste FAIL pour ces ressources à la fermeture :
`artifacts/dev/20260913-165145-passe-rive-autosprite-661d5805/gut-strict-report.json`.
Le nouveau test de trajectoire et les tests existants confirment les positions
initiale/finale, la traînée courbe et l’absence d’impact anticipé.

Première version artistique : attente armée fixe ; E/W proches des trois quarts ;
moins d’intermédiaires que les cycles originaux, donc fluidité inférieure à la
référence Dofus. Les origines d’effets par direction sont des réglages visuels.
Les clips de déplacement restent sans arc ; les nouveaux dessins concernent les
tirs et l’attente, pas une nouvelle locomotion armée.

Travail concurrent préservé : progression Catabase, `README.md`, préparation et
UI d’expédition, tests associés et `docs/ai/catabase_guided_progression_work.md`.
Les premiers rapports échoués (test alpha et sondes attendant les anciens noms)
restent accessibles dans `artifacts/dev/` ; seuls les rapports nommés PASS
ci-dessus constituent les vérifications finales correspondantes.
