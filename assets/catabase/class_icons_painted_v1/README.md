# Illustrations d'interface Catabase · v1

Créées le 20 septembre 2026 avec l'outil imagegen intégré, depuis nos images de
braise et de cuirasse émeraude. Aucune image de Dofus/Waven n'est incorporée.

112 illustrations peintes réparties dans huit atlas, plus six silhouettes SVG
de cases vides. Les atlas sources sont conservés sans retouche de leurs pixels.
Les prompts exacts sont conservés dans `prompts.json`, `relics_prompt.txt` et
`armors_prompt.txt`.

| Atlas | Grille | Usage |
|---|---|---|
| assassin / gardien / arpenteur / thaumaturge | 4 × 4 chacun | 15 techniques puis l'emblème de classe |
| equipment | 6 × 4 | Colonnes : arme, torse, accessoire, tête, ceinture, pieds ; lignes : les quatre classes |
| runes | 2 × 2 | Tranchant, pierre, voile, vigueur |
| relics | 4 × 4 | Six reliques, quatre consommables, six armes classiques |
| armors | 2 × 2 | Airain, Sceau, Lin gravé, Tenue de traverse |

Les identifiants stables et leur ordre sont explicités dans
`core/expedition/class_icon_catalog.gd`. Les textures sont chargées à la demande,
puis partagées par le catalogue, le deck, la main, le reçu et l'inventaire.
Les régions ont des marges de sécurité ; les lignes de reliques sont mesurées
sur la peinture, qui n'a pas un espacement parfaitement uniforme.
Pas de chiffres incrustés : PA, portée, quantité, palier et état équipé sont
dessinés par l'interface depuis les règles actuelles.

Conserver les paramètres d'import et inclure ce dossier dans les exports du jeu.
Contrôle de couverture : `test/unit/test_class_painted_icons.gd`.
Galerie à taille réelle : `tools/build_system_lab/painted_icon_gallery.tscn`.
