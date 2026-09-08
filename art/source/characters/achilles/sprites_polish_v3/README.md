# Sources d'Achille classique — polish v3

Les onze sources retenues ont été harmonisées sur le personnage de repos original de `art/source/characters/achilles/sprites_cour_des_sources_v1`, première cellule de chaque orientation avant normalisation. Le concept général et les premières planches V3 restent des références historiques ; ils ne remplacent pas cette autorité d'identité.

Tous les fichiers sélectionnés ci-dessous possèdent un fond magenta explicite. Le détourage par script a été autorisé par l'utilisateur ; les originaux restent inchangés et sont exclus de l'import Godot par `.gdignore`. Les anciens E sur damier sont conservés uniquement pour la provenance.

| Fichier source retenu | Poses utilisées |
| --- | --- |
| `source_candidate_walk_E_harmonized.png` | 0–7 marche E ; lecture [0,1,3,2,4,5,7,6] |
| `source_candidate_bow_E_harmonized_crest.png` | Arc E ; huit poses dédiées, crête corrigée |
| `source_candidate_special_E_harmonized.png` | 12 dessins : perforante, ligne de mort, volée E |
| `source_base_N_harmonized_palette.png` | 0–7 marche N, 8–15 arc N ; correction du tissu teal |
| `source_special_N_harmonized_palette.png` | 12 dessins spéciaux N ; correction du tissu teal |
| `source_candidate_base_S_harmonized.png` | 0–7 marche S uniquement, déjà validée en combat |
| `source_candidate_base_S_reference_only_v6.png` | 8–15 arc S uniquement ; marche 0–7 exclue |
| `source_candidate_special_S_reference_only_v6.png` | 12 dessins spéciaux S depuis le sprite original seul ; arc simple corrigé |
| `source_walk_W_harmonized.png` | 0–7 marche W déjà ordonnée d'après le runtime validé ; lecture [0,1,2,3,4,5,6,7], contacts 3/7 |
| `source_base_W_harmonized.png` | 8–15 arc W uniquement ; sa marche 0–7 est exclue |
| `source_special_W_harmonized.png` | 12 dessins spéciaux W |

Ces sources fournissent 112 régions source pour 20 clips : marche, arc simple, perforante, ligne de mort et volée dans les quatre orientations. Les 28 clips hérités restent inchangés, notamment repos, réactions et Percée. Les préfixes `candidate` conservés dans certains noms retracent la production ; la sélection effective est déclarée dans `tools/achilles_polish_v3_pipeline/alignment.json` et dans le manifeste runtime.

Les planches spéciales se lisent par lignes de quatre : anticipation, pleine tension, lâcher, récupération. Les gestes spéciaux reprennent quatre poses de préparation/retour de l'arc de base ; ils ne sont pas comptés comme huit nouveaux dessins. Les fichiers de provenance voisins conservent les prompts, générations, corrections et refus. En particulier, la marche de `source_base_W_harmonized.png` a été refusée parce qu'elle reprenait un ancien guide aux contacts incorrects.

Les quatre arcs S de la dernière passe V6 ont été générés depuis la seule référence du sprite original S, sans fournir les anciennes planches de poses : cela a corrigé la largeur excessive du torse, des bras et du visage. Les essais V4/V5 restent des candidats non retenus. La marche de la nouvelle planche V6 répète la même jambe ; elle est exclue et la marche S harmonisée déjà validée reste active. Les 20 régions utilisées pour les quatre arcs S ont leurs appuis alignés et leurs cordes inspectées après détourage. Leur option `edge_despill` corrige uniquement le RGB des pixels de bord contaminés par le magenta, avec protection des rouges sombres ; l'alpha, les intérieurs hors masque et les sources originales restent inchangés. Le détail et les limites de cette estimation figurent dans le README du pipeline.

Le pipeline et le détail des ancres sont dans `tools/achilles_polish_v3_pipeline`. Le manifeste runtime fournit l'empreinte de chaque source, les suppressions de fond, les indices réellement utilisés, les racines, les origines de libération et les images normalisées. Aucune pose n'est dessinée, retournée ou déformée par script.
