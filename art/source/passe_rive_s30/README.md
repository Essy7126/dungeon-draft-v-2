> Historique SE S30. Les huit orientations sont maintenant intégrées et validées dans [Restauration S31](../passe_rive_s31/renew/README.md).

# Passe-Rive — Seconde aurore S30

Prototype validé le 28 septembre 2026. Animation du corps et VFX produits avec l'outil intégré `image_gen`, puis calés dans le lecteur Godot. La génération et les retouches des dessins utilisent imagegen ; les scripts Python mesurent les pixels et assemblent les captures du moteur.

## Livrables et attributions

| Carte actuelle | Geste | Résolution | Durée |
| --- | --- | --- | --- |
| `cc2_i01` Seconde aurore, base/améliorée | Inspiration, grande ouverture asymétrique, retombée | 450 ms, pose 6 | 1 120 ms |
| `cc2_l02` Grâce du bronze, base/améliorée | Ouverture moins haute, plus brève | 250 ms, pose 4 | 820 ms |

Les douze poses SE sont dans [renew.png](../../../assets/characters/PasseRive/sprites_s30/renew.png). La variante brève en sélectionne neuf. Les huit dessins de lumière et de bronze sont dans [vfx.png](../../../assets/characters/PasseRive/sprites_s30/vfx.png). [Métadonnées de calage et empreintes](../../../assets/characters/PasseRive/sprites_s30/renew.json).

Les sept autres directions utilisent l'incantation directionnelle existante, recalée sur les mêmes temps de résolution, avec les nouveaux VFX. Elles ne réutilisent pas abusivement le corps SE. Seule la vue SE dispose de la nouvelle chorégraphie à deux bras et de points de paumes relevés sur ses dessins ; les autres vues conservent un effet autour du corps. Les miroirs historiques du geste de secours restent historiques, pas une nouvelle production anatomique.

Le repos et la marche natifs restent les références : 214 pixels de stature source, échelle du profil, correction horizontale fixe 0,85 pour ce nouvel atlas, ancrage du pied mesuré, palette par matière. Un bref raccord entre le dessin et l'idle natif ferme la séquence. Les poses dessinées gardent de petites différences de vêtement et de capuche ; identité parfaite au pixel près non certifiée.

## VFX et règles

- Les faibles lueurs avant l'ouverture expriment la préparation. Le grand éclat de vitalité exige un soin réel positif du rapport confirmé ; aucun grand éclat à PV pleins.
- Les trois facettes transitoires de bronze exigent une augmentation réelle de garde ; aucune facette ajoutée si la garde est déjà au plafond.
- Les traînées SE suivent les paumes. Les couches sont ordonnées dans le même plan de rendu que le personnage pour éviter leur découpage par les dalles.
- Le lecteur possède ces effets de lancement : les grandes pulsations génériques sont écartées uniquement pendant ce lancement. Chiffres de soin/garde et indicateur de garde persistante restent actifs.
- Aucune règle, quantité de soin, coût ou fin d'activation modifiée. Le combat attend déjà la récupération visuelle avant de terminer l'activation de Seconde aurore. Grâce du bronze conserve son activation.
- Annulation, mort, changement de mode et arrêt nettoient les effets ; aucun nouvel effet ne résout le gameplay une seconde fois.

## Sources

- [Prototype approuvé](seconde_aurore_concept_v01.png) et [prompt du prototype](prompt_concept_v01.txt).
- [Prompt des douze poses](prompt_sequence_v01.txt), sortie originale `exec-3c4ae459-e438-4252-a046-019525d27a9b.png`, copie inchangée dans l'atlas runtime.
- [Premier prompt VFX](prompt_vfx_v01.txt), variante non retenue : marges insuffisantes. [Correction retenue](prompt_vfx_v02.txt), sortie `exec-e06d1f59-5aea-4612-b82c-b2fef693262b.png`, copie inchangée dans l'atlas runtime.
- Les originaux de génération restent conservés dans le dossier generated_images de cette conversation ; le jeu charge seulement les copies du projet.

## Vérification et essai

[Validation et rapports](VALIDATION.md). [Capture animée](review/seconde_aurore_en_jeu.gif), [planche des raccords](review/raccord_en_jeu.png), [provenance des captures](review/provenance.json).

Depuis la racine du jeu :

```powershell
./tools/class_card_vfx/passe_rive_s30/play.ps1
./tools/class_card_vfx/passe_rive_s30/play.ps1 -Capture
./dev.ps1 test passe-rive
```

La scène de revue utilise le vrai Battle, les vrais sorts, coûts et consommations, ainsi que la fin de tour du runtime Cartes. Main préparée, IA ennemie en pause et écritures de checkpoint désactivées uniquement dans cette fixture. Le GIF montre Seconde aurore de base, caméra agrandie 2,4 fois pour l'inspection ; ce n'est pas une simulation de fluidité à partir des quatre poses du prototype.
