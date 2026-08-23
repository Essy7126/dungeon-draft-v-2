# Achille — audit d’intégration Odyssée

Date : 2026-08-23
Statut : **WORKTREE_CANDIDATE — VALIDATION_GRAPHIQUE_PENDING**

## Verdict

Le candidat V3 remplace le corps canonique et ses animations retargetées par le
modèle Meshy direct. Le même asset fournit un mesh skinné, un rig de 24 os et
20 animations Meshy natives. Le routage de L’Odyssée, les statistiques et les
quatre capacités d’Achille ne changent pas.

Les contrôles ciblés et de régression sont verts. Le full-flow graphique final
n’a toutefois pas encore été exécuté : ce document ne qualifie donc pas encore
la V3 de validation visuelle finale ni de production publiée.

## Source et contrat 3D

- Asset :
  `res://assets/characters/Achilles/3d/achilles_meshy_animation_pool_v3.glb`.
- SHA-256 :
  `95F634EF49B04F8A01FC4B13D223F75DC3B2C7AA01CB2319194D078BF1D02FEE`.
- Contenu : un mesh skinné, un matériau, une texture et un rig de 24 os.
- Pool : exactement 20 animations natives partageant ce rig ; aucun retarget.
- Les assets V1 et V2 restent présents, inchangés, comme historiques.
- Le modèle n’embarque aucun équipement. Les clips prévus autour d’une arme
  restent exploitables comme mouvements, mais les contacts d’arme ne peuvent
  pas être considérés comme finalisés.

## Repos, locomotion et actions

- Repos : `Idle_11` en boucle.
- Marche : `Walking` pour un chemin de 1 à 5 cases.
- Course : `run_fast_3_inplace` à partir de 6 cases.
- Impact : `Hit_Reaction_1`.
- Lancement générique : `mage_soell_cast_7`.
- Frappe de lance : `Left_Slash`.
- Percée : `run_fast_3_inplace`.
- Balayage : `Charged_Upward_Slash`.
- Garde d’airain : `Sword_Parry_Backward_2`.

La grille reste l’autorité du déplacement. Les translations locales des clips
sont neutralisées selon leur profil runtime, et Percée resynchronise la vue sur
la cellule de grille résolue.

## Présentation et dimensions

- Le profil V3 emploie `render_display_size = 78.0` avec une caméra
  orthographique 2,6. Le profil peint emploie `base_visual_scale = 1.0`, un
  minimum de 1,0 et un maximum de 1,15.
- Les trois présentations produisent des échelles finales de 1,05 dans la
  forêt, 1,08 dans le volcan et 1,10 dans l’espace.
- Ces valeurs remplacent le calibrage V2 1,974 / 2,0 / 2,0, trop grand en jeu.
- Le corps de grille et l’aperçu 3D utilisent la V3. Le portrait du HUD reste
  l’illustration 2D historique.

## Contrat de jeu conservé

- Trois salles de L’Odyssée et un seul héros Achille.
- 110 PV, 14 initiative, 6 PA, 3 PM et 18 puissance.
- Frappe de lance, Percée, Balayage et Garde d’airain gardent leurs coûts,
  portées, effets et handlers de ciblage.
- La source ne contient aucun clip de mort ; le fondu de l’adaptateur reste le
  rendu prévu.
- Aucun équipement runtime n’est activé.

## Validation actuelle

- Suite dédiée au runtime Meshy V3 : 4/4 tests, 38 assertions.
- Calibration réelle : 5/5 tests, 218 assertions.
- Régression élargie : 79/79 tests, 2 532 assertions.
- Full-flow graphique final : **NON EXÉCUTÉ**.
- Revue des captures, proportions dans les trois cartes, repos, marche/course
  et quatre sorts en conditions réelles : **PENDING**.

## Limites à fermer avant promotion

- Exécuter le full-flow graphique V3 dans les trois salles et inspecter ses
  captures.
- Confirmer visuellement l’échelle 1,05 / 1,08 / 1,10, l’ancrage aux pieds et
  le cadrage des animations les plus amples.
- Vérifier que `Idle_11` ne ressemble plus à une attaque répétée et que
  `Walking` est bien sélectionnée pour les déplacements ordinaires.
- Juger les appuis, transitions et clips à forte translation après
  neutralisation locale.
- Conserver le fondu de mort et le portrait 2D tant que la source Meshy ne
  fournit pas de remplacements dédiés.
