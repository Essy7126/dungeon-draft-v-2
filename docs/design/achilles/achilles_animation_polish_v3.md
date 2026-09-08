# Achille classique — continuité artistique et animations V3

La scène canonique utilise maintenant `achilles_polish_sprite_profile_v3.tres`. La marche et les quatre gestes d'arc disposent de 20 clips dans les quatre orientations. Les 28 autres clips gardent leurs dessins précédents, notamment le repos, les coups reçus et la Percée.

## Modèle et fabrication

L'autorité artistique est le sprite de repos réellement utilisé en jeu dans chaque orientation, avant normalisation : `sprites_cour_des_sources_v1`. Le visage adulte, le volume du casque, les contours, le plastron ivoire, le tissu teal et le bronze servent de références. Le grand concept peint et les premières planches plus massives ne remplacent pas ce modèle.

La correction de face S utilise finalement le seul repos original comme référence d'image. Les retouches V4/V5 guidées par les anciennes planches conservaient trop de leur carrure ; elles ont été écartées. Les quatre arcs S V6 sont retenus. La marche V6 répétait un même appui et reste exclue ; la marche S harmonisée déjà validée est conservée.

Les [sources et leur sélection](../../../art/source/characters/achilles/sprites_polish_v3/README.md) décrivent 11 feuilles retenues, 112 régions dessinées et leurs références dans les clips. Les prompts et provenances adjacents retracent l'utilisation d'OpenAI ImageGen intégré. Le détourage par script a été explicitement autorisé par Paolo. Le pipeline recadre, détoure et redimensionne uniformément ; il ne redessine ni ne déforme le personnage. Les quatre arcs S utilisent aussi une récupération RGB des franges magenta, limitée aux deux pixels de bord contaminés. Elle conserve strictement leur alpha, les silhouettes et les origines ; les autres couleurs restent protégées.

## Mouvement et combat

La marche suit la distance réellement parcourue. Chaque case utilise un demi-cycle, avec alternance des appuis, poids des images conservés et phase préservée aux changements de direction. Le repos reste fixe. L'ancre au sol et l'échelle du personnage sont communes aux clips ; les poses agenouillées conservent leur hauteur propre.

| Geste d'arc | Durée | Lâcher |
| --- | ---: | ---: |
| Tir simple | 0,74 s | 0,34 s |
| Tir précis / perforant | 0,78 s | 0,38 s |
| Tir de puissance / ligne | 0,86 s | 0,44 s |
| Volée | 0,84 s | 0,42 s |

Les origines des projectiles sont mesurées sur la main au lâcher pour chaque geste et orientation. Le contrôleur de combat garde la propriété du déplacement de Percée et des dégâts. La ruée ne reçoit pas une seconde translation par le sprite.

Les quatre sorts historiques et leurs maîtrises restent pris en charge. Les 42 identifiants du catalogue d'expédition ont aussi une [présentation explicite](achilles_spell_presentation_v3.md), pour que les racines et cartes apprises sélectionnent réellement les nouveaux gestes. Douze tirs disposent d'un vol de 0,20 s géré par le scheduler avant l'impact. Coûts, portée, dégâts, cibles et achats restent ceux du catalogue.

Les effets physiques utilisent les nouveaux dessins de flèche et d'impact. Feu et glace réemploient les sprites existants de Paris ; les soins confirmés utilisent ceux du philosophe. La foudre dispose de huit dessins supplémentaires. La couleur du corps ne change pas avec l'élément du sort.

## Contrôles et limites

Le [rapport des 23 scénarios historiques](achilles_animation_polish_validation_v3.json) et le [rapport des sept scénarios d'expédition](achilles_expedition_animation_validation_v3.json) contiennent les résultats observés. Ils décrivent des combats réels sur terrain enregistré, avec préparation précombat déclarée, achats légaux, marche payée et lancement des vrais sorts. Ils ne représentent pas une campagne complète.

Les reprises ciblées après la dernière correction S sont indiquées explicitement dans le rapport, sans compter deux fois les mêmes scénarios. Les captures visuelles sont séparées des mesures de cadence sans lecture GPU. Leur encodage conserve les horodatages, avec arrondi au centième pour le GIF, et vérifie l'ordre des images à pleine résolution.

Les bornes alpha servent à vérifier le placement ; elles ne prouvent pas l'anatomie des appuis. Les comparatifs et les captures de jeu ont donc aussi été inspectés. Les diagnostics de ressources/RID à la fermeture restent conservés dans les logs ; cette passe ne les présente pas comme corrigés.

Reproduction : [lanceurs de validation](../../../tools/achilles_animation_polish_v3_validation/README.md), [pipeline du corps](../../../tools/achilles_polish_v3_pipeline/README.md) et [pipeline des effets](../../../tools/achilles_polish_v3_pipeline/README_effects.md).

## Livraison finale

Le [reçu final](achilles_animation_polish_delivery_v3.json) fixe les empreintes des ressources et rassemble les résultats : 146/146 tests Godot, 14/14 tests du corps, 8/8 tests des effets, 3/3 tests foudre et trois contrôles de l’encodage. Les 23 scénarios historiques et les sept scénarios d’expédition passent. La dernière capture S est prise après le nettoyage RGB des franges.

[Aperçu réel : marche et arc S](media/achilles_classic_walk_bow_S.gif) · [Aperçu réel : foudre E](media/achilles_lightning_E.gif). Les rapports d’encodage voisins conservent les durées et les vérifications de l’ordre des images.
