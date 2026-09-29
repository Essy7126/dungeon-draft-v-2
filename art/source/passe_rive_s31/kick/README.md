# Coup de pied haut — finition directionnelle S31

Le geste S24 approuvé couvre désormais huit directions dessinées distinctes : E, SE, S, SW, W, NW, N, NE. Le SE historique est conservé. Aucun miroir automatique n'est employé pour les sept nouvelles vues.

Attribution : Heurt (`cc2_n04`), Repousser (`cc2_g03`), Choc de masse (`cc2_g06`), base et amélioration. Les règles, dégâts et déplacements restent ceux des cartes. Durée commune 650 ms, événement de résolution unique à 310 ms, huit positions temporelles. L'entrée et la sortie rejoignent le repos natif désarmé avec un fondu court.

## Sources et calibration

Les nouvelles planches proviennent de l'outil imagegen intégré, avec les sprites natifs de chaque direction, la séquence SE approuvée et le modèle arrière comme références. Les prompts et versions sont conservés dans `sources/`. Aucun pixel généré n'a été retouché par script. Les rectangles suivent les espaces transparents réels, pas une grille supposée parfaite.

Une échelle anatomique fixe par direction et une correction de palette par matière s'appliquent à toute la séquence. Le pied d'appui et le talon de contact disposent de repères propres. Les cellules 2 des vues S/N changent de jambe et sont exclues du montage ; une pose de reprise cohérente les remplace. NE/NW v02 remplace les premiers dos trop frontaux et conserve la chambre du genou jusqu'à la frappe : cellule 3 écartée. Les vues restent des dessins tenus, pas un mouvement 3D interpolé.

Sources retenues : `E_W_v03.png`, `SW_v02.png`, `S_N_v01.png`, `NE_NW_v02.png` et le SE S24 intact. La planche NE/NW contient huit colonnes et deux rangées ; ses silhouettes sont mesurées séparément pour conserver le talon étendu. L'outil n'a pas respecté la grille demandée, ce qui est traité par les régions et non par une retouche des pixels. Les autres versions sont des essais conservés, pas des vues additionnelles actives.

Lecteur : `characters/achilles/2d/passe_rive_kick_body.gd`. Métadonnées : `assets/characters/PasseRive/sprites_s31_kick/kick.json`. Le backend public S19 utilise cette famille dans toutes les directions, sans repli au corps neutre. La marche et le repos natifs sont conservés.

## Rejouer

- `tools/class_card_vfx/passe_rive_kick_directions/play.ps1` : trois cartes réelles et quatre directions légales de mêlée ; option `-Capture` pour les 24 cas base/amélioration.
- `tools/class_card_vfx/passe_rive_kick_directions/capture_poses.ps1` : les huit vues du backend public, taille doublée pour inspection.
- `dev.ps1 test passe-rive` : horloges, annulations, réactions, locomotion et gestes déjà intégrés.

Le banc de combat prépare une main et suspend l'IA. Il n'est pas une partie complète parcourue depuis le menu. Les quatre directions écran E/S/W/N correspondent à des cases diagonales hors portée de ces coups de mêlée : elles sont vérifiées dans le lecteur de présentation, sans modifier artificiellement la portée des cartes.

## État

Intégration directionnelle terminée et revue V1 effectuée : [preuves](VALIDATION.md), [huit directions](review/huit_directions.gif), [combat réel](review/coup_de_pied_en_combat.gif). Aucun autre geste récent n'est déclaré achevé par cette étape.
