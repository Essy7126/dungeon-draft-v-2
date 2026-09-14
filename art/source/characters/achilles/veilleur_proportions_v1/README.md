# Veilleur — correction des proportions

Retour suivant de l’utilisateur, 12 septembre : **« Le test de proportion passe
à peu près, la marche n’est pas encore bonne mais les proportions sont bonnes »**.
Conserver ce gabarit. Acceptation des proportions uniquement, pas du mouvement.

12 septembre 2026. Retour utilisateur : « Les jambes ne sont plus du tout les
mêmes et la disproportion est flagrante ». La marche E V1 est **rejetée**, pas
une base artistique à poursuivre ou une animation en attente d’approbation.

## Correction effectuée

Les pièces proviennent directement de `serment_cendre_concept_v1/candidate_c.png`.
Aucune nouvelle génération d’image pour cette correction. Les pantalons, les
revers ivoire et les bottes conservent leur dessin. Pas d’étirement de pièces :
translations et rotations à l’échelle commune 0,32. Les longueurs sont annotées
sur le modèle dans `landmarks.json`, et non reprises d’un squelette générique.

Le gabarit rejeté dimensionnait les jambes indépendamment du costume. Ici,
la cuisse et le mollet proches annotés sur le dessin mesurent environ 39,6 et
42,3 pixels à l’échelle de sortie. Ce sont des mesures projetées de la pose,
pas des proportions anatomiques universelles ni une longueur 3D.

`tools/veilleur_walk/canonical_parts.py` produit un test de construction à 24
étapes et une comparaison avec la référence toujours affichée à la même échelle.
Les images sources des pièces et les repères restent accessibles ici.

## Preuve et limites

Le remontage des pièces à leur position d’origine redonne le PNG de référence
sans différence de pixels. Les transformations conservent les longueurs annotées.
`report.json` expose ces contrôles et leur périmètre.

Cette preuve concerne le modèle et la géométrie des pièces. **Elle ne valide
pas la marche.** Les raccords des genoux, les occlusions et le déroulé des pieds
restent provisoires. De petits raccords de tissu sont ajoutés derrière les
articulations pendant le test ; les bottes ne sont pas synthétisées. Il n’y a
ni nouvelle intégration Godot, ni autres directions. La comparaison s’ouvre
arrêtée pour examiner d’abord le respect du dessin.

Revue : <http://127.0.0.1:8734/files/veilleur_proportions_v1/review.html>.

Suite : terminer les raccords et les poses d’appui de cette direction, sans
modifier les proportions pour accommoder le mouvement. Pas de régénération
complète du personnage pour lisser un défaut d’articulation.
