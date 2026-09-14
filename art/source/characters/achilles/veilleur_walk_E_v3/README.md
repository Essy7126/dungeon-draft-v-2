# Veilleur — marche d’après la référence de Nicolas Détrain

12 septembre 2026. L’utilisateur trouve le pas de la V2 non naturel et demande
de repartir réellement de la marche du modèle de Nicolas identifié dans l’audit.
Les proportions de `veilleur_proportions_v1` restent la base artistique acceptée.

## Référence utilisée

Nicolas Détrain, [Dofus Unity — Universal Puppet/Rig — Animation](https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation).
Le [profil de l’auteur](https://www.behance.net/nicolasdetrain) a été retrouvé à
nouveau. La page directe n’a pas été relue en ligne pendant cette reprise ; les
GIF et documents déjà conservés dans le projet ont servi à l’analyse.

Fichier local : `artifacts/dev/dofus-research/puppet_8.gif`, marche corps seul,
première orientation. Les images 0–15 sont exactement répétées en 16–31 : le
cycle retenu est vérifié, 16 délais de 30 ms, total **480 ms**. Ce délai décrit
le GIF publié, pas la cadence du moteur de Dofus. La version équipée a servi
de comparaison visuelle initiale ; le mouvement retenu provient du corps seul.

La fiche `artifacts/dev/veilleur-nicolas-study/source.json` conserve l’URL,
l’empreinte et l’intervalle. `annotated_cycle.png` montre les repères superposés.
Les repères de `reference_landmarks.json` sont des **estimations manuelles**
visuelles ; aucun rig, os ou fichier source du studio n’a été récupéré.

## Adaptation réalisée

- Les directions cuisse/mollet, le repli, les orientations de pied, les bras
  et le mouvement du buste proviennent de ces repères, interpolés périodiquement.
  La précédente trajectoire générique des pieds n’est pas le pilote de cette V3.
- 32 étapes exportées, à la même durée de 480 ms. La revue synchronise les
  16 images de référence avec les 32 étapes du Veilleur. Il ne s’agit pas de
  32 dessins supplémentaires du studio ni d’un modèle entraîné.
- Une jambe repartant en profondeur peut se raccourcir à l’écran : longueurs
  projetées plafonnées au dessin de référence, largeur des bandes conservée.
  Le raccourcissement de la botte suit celui du mollet, avec une limite de 0,65.
  Ce sont des adaptations 2D de perspective, pas une garantie de volume 3D exact.
- Les chevilles tournent désormais à l’intérieur des bottes, au lieu d’être
  confondues avec les attaches du pantalon en haut des revers. Le dessin source
  est identique ; les pivots et la projection changent.
- Le raccord du pantalon reste continu. Les fragments résiduels de pantalon
  sous le calque du buste ont été retirés dans `core_clean.png`, sans modifier
  le gabarit accepté ni les fichiers source de la version précédente.
- Un recalage périodique du corps ajuste les appuis et estime la distance de
  déplacement sur la diagonale isométrique. Ce recalage garde un résidu mesuré,
  exposé dans `report.json` ; il n’est pas décrit comme un verrouillage parfait.

## Sources et sorties

`tools/veilleur_walk/walk_v3_reference.py` lit les annotations et les pièces
du Veilleur via `source_rig.py`. `source_lock.json` conserve leurs empreintes,
les pivots internes des bottes et les longueurs maximales. `motion.json` conserve
les poses calculées. Aucune nouvelle génération d’image dans cette reprise.

Les 32 PNG RGBA 512², l’APNG, le WebP et l’atlas sont dans
`artifacts/spine_trial/veilleur_walk_E_v3`. Les images Dofus restent dans les
références d’étude et ne sont pas utilisées comme pixels du personnage exporté.

Revue : <http://127.0.0.1:8734/files/veilleur_walk_E_v3/review.html>.

## Statut et limites

Nouvelle adaptation à examiner, **aucune acceptation artistique reçue**.
Les points sous les vêtements sont estimés ; certaines occlusions et projections
restent approximatives. Vérifier le pas, les croisements et les revers sur les
images réelles, pas seulement les repères. Une seule orientation, sans équipement.

Le comparatif sur trois décors utilise les captures de combat du 5 septembre
et la peinture du sanctuaire. Ce sont des photomontages ; ni nouvelle intégration
Godot, ni idle, ni transitions, ni autres directions ne sont revendiqués.

`report.json` porte sur le recalage et les projections, `export_report.json`
sur les fichiers, `verification.json` sur la revue. Les tests du moteur commun
n’ont pas été relancés : aucun code du parcours public n’est modifié.

Contrôles effectués : 18 vérifications navigateur réussies, 32 états synchronisés
et distincts, commandes, décors, liens, ordinateur/mobile, zéro erreur JavaScript.
Captures inspectées. APNG et atlas identiques aux PNG ; WebP identique sur les
pixels visibles, 32 images et 480 ms pour les deux boucles. Sept pièces sources
inchangées, longueurs projetées sous leur maximum et raccourcissement des bottes
compris entre 0,65 et 1.

Le diamètre cumulé des repères d’appui est de 2,59 px côté L et 1,89 px côté R
à l’échelle où la référence debout mesure 112 px. Cette mesure complète le résidu
entre deux étapes ; elle ne prouve pas une semelle parfaitement stable. Le repli
est plus lisible, mais les grosses bottes et leurs croisements restent moins nets
que dans la référence. L’appréciation artistique de l’utilisateur reste attendue.

Demande suivante : auto-audit et correction. L’audit V4 a identifié des défauts
plus importants que cette première revue : variations excessives de volume,
anatomie/perspective confondues, deux inversions de profondeur par cycle, corps
recalé trop fortement, découpes visibles. Consulter `veilleur_walk_E_v4/README.md`.
Les contrôles V3 restent des preuves de leur périmètre, pas une validation artistique.
