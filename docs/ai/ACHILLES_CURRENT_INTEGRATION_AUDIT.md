# Achille — audit d’intégration Odyssée

Date : 2026-08-23
Statut : **CURRENT — VISUAL_VALIDATION_PASS**

## Verdict

Le candidat V3 remplace le corps canonique et ses animations retargetées par le
modèle Meshy direct. Le même asset fournit un mesh skinné, un rig de 24 os et
20 animations Meshy natives. Le routage de L’Odyssée, les statistiques et les
quatre capacités d’Achille ne changent pas.

Les contrôles ciblés et de régression sont verts. Le full-flow graphique final
des trois salles passe sur le commit d'implémentation `37c6f5f846fa`, avec 13
captures inspectées. La V3 et son recalibrage sont validés visuellement.

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
- Marche : `Walking` pour un chemin de 1 à 5 cases, vitesse de clip 75 % et
  durée visuelle de 0,40 s par case.
- Course : `run_fast_3_inplace` à partir de 6 cases, 0,20 s par case.
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

- Le profil V3 emploie `render_display_size = 96.0` avec une caméra
	orthographique 2,6. Le profil peint emploie `base_visual_scale = 1.72`, un
	minimum de 1,5 et un maximum de 1,9.
- Les trois présentations produisent des échelles finales de 1,806 dans la
	forêt, 1,8576 dans le volcan et 1,892 dans l’espace.
- Ces valeurs sont calibrées sur les trois héros de production (Elfe, Mage et
	Guerrier). Les identifiants `odyssey_skirmisher`, `odyssey_guard` et
	`odyssey_champion` sont reliés aux profils peints ; leurs scènes compensent
	leur cadrage natif afin de rester à ±5 % de la hauteur rendue d'Achille.
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

- Tests ciblés proportions/V3/locomotion/Odyssée et squelettes : 61/61 tests,
  1 102 assertions.
- Studio d'animations : 19/19 tests, 208 assertions.
- Binding SHA-exact : 34/34 tests, 643 assertions.
- Full-flow graphique post-calibrage : **PASS**, 3/3 salles et 13/13 captures
  sur `d165b8023d08`.
- Hauteurs d'Achille mesurées : 111,97 px dans la forêt, 111,92 px dans le
  volcan et 117,30 px dans l'espace. Les trois familles ennemies restent à
  ±5 % dans la régression de proportions.
- `Idle_11` reste actif après une boucle complète ; `Walking` est sélectionné
  jusqu'à 5 cases et `run_fast_3_inplace` à partir de 6 cases.

## Limites restantes

- Juger les appuis, transitions et clips à forte translation après
  neutralisation locale lors d'une future revue vidéo.
- Conserver le fondu de mort et le portrait 2D tant que la source Meshy ne
  fournit pas de remplacements dédiés.
- Améliorer ultérieurement l'éclairage ou la teinte de sélection : le modèle
  paraît sombre/bleuté, sans que cela n'affecte sa lisibilité tactique.
