# Passe-Rive — référence d’apparence S23

Une même référence pilote désormais la taille à l’écran et la palette de Passe-Rive. Les dessins d’attaque approuvés et les cycles de déplacement natifs sont conservés. Les dernières preuves et les limites vérifiées sont dans `VALIDATION.md`.

## Échelle entre salles

`passe_rive_appearance.gd` définit 214 pixels de stature source et une stature de lecture de 100 pixels à 1600 × 900. Elle devient 90 pixels dans le banc 1440 × 950, selon le facteur commun de mise à l’échelle de la fenêtre. Il s’agit de la stature de référence debout, pas de la hauteur d’une pose accroupie ou d’une arme levée.

En combat Cartes, le visuel compense les calibrations de grille, de salle et de caméra lors du cadrage initial, des changements de disposition du HUD et des redimensionnements. Le zoom volontaire reste un zoom de toute la scène. Les haltes et le seuil utilisent la même référence ; les réglages historiques de taille de leurs manifestes restent applicables aux autres personnages.

La cadence de marche suit toujours la distance au sol à l’échelle du personnage. La ruée garde son départ, son trajet et sa réception à l’arrivée réelle.

## Palette commune

Le repos SE natif est la référence pour cinq matières : tissu bleu, cape sauge, cuir, or et ivoire. `build_passe_rive_palette.py` mesure les sources sans réécrire les PNG. Il produit des centres et corrections RGB constants par atlas. Le shader applique une interpolation continue entre ces matières, ce qui évite les points colorés provoqués par des seuils abrupts. Les contours sombres et les variations de modelé restent visibles.

Exploration, repos, marche, ruée et attaques utilisent ce même shader. La teinte sombre spécifique aux haltes est supprimée pour Passe-Rive ; la lumière des torches et de l’eau devient un accent limité. Chaque acteur possède son propre matériau afin de ne pas transmettre ses paramètres à un autre acteur.

## Proportions et raccords

La hauteur d’un rectangle transparent ne définit pas la taille d’un personnage. Les premiers essais de repérage de capuche ont parfois inclus une lame ; ils sont conservés comme diagnostics, pas comme mesures anatomiques certifiées. Une seconde mesure suit la surface médiane des vêtements, avec une marge pour les membres ouverts. Elle sert d’aide au recalage constant d’un atlas. Une correction de plus de 10 % est plafonnée : les captures ont montré qu’une réduction de 20–25 % rapetissait la tête. Le point de départ des VFX suit le même recalage que le corps.

Les poses ne sont jamais redimensionnées individuellement au fil de l’action. Les différences de silhouette dues à une flexion ou à l’écartement des bras restent des mouvements. Le fondu entre le repos et l’attaque a été testé puis retiré : il faisait apparaître deux silhouettes semi-transparentes. Les planches de contrôle montrent les poses sans masquer ces différences.

Cette intégration ne redessine pas les capuches, visages ou vêtements. La cohérence de dessin absolue ne peut pas être certifiée par une égalité d’échelle, une couleur moyenne ou un taux de tests passés.

## Contrat pour les prochaines animations

1. Prendre les huit vues natives du même Passe-Rive comme planche maître. Garder la capuche, le visage, la largeur des membres et la découpe des vêtements. Les poses 3D éventuelles ne servent que de référence de mouvement.
2. Construire anticipation, action, contact, amorti et retour autour de cette identité. Prévoir de vraies poses de raccord vers le repos existant. Réutiliser le même dessin neutre à l’entrée et à la sortie ; produire les dessins intermédiaires nécessaires.
3. Verrouiller la caméra, l’échelle source, le point au sol et la palette pour toute la séquence. Exporter les armes et VFX séparément autant que possible. Une arme ou un effet ne participe jamais à la mesure de stature.
4. Vérifier tête, col, bassin et appuis sur la séquence complète, à taille de jeu et agrandie. Une correction d’échelle importante ou une tête qui change de volume impose une reprise du dessin, pas une compensation automatique par frame.
5. Comparer repos → marche → sort → repos et ruée dans les salles réelles. Confirmer sens, contacts, couleurs, absence de doubles silhouettes et maintien de la cadence. Puis effectuer le parcours préparation → combat avec IA → victoire → reprise disque.

## Outils reproductibles

```powershell
python tools/class_card_vfx/build_passe_rive_palette.py --check
python tools/class_card_vfx/build_passe_rive_registration.py --check
python tools/class_card_vfx/audit_passe_rive_palette.py --check
./tools/class_card_vfx/play_passe_rive_s23.ps1
./tools/class_card_vfx/play_passe_rive_s19.ps1 -Locomotion -Capture
./tools/class_card_vfx/play_passe_rive_flow.ps1
```

Le contrôle S23 produit les sept gestes sur cinq angles sources, les raccords échantillonnés et les salles réelles. Les directions opposées partagent les miroirs déjà établis. Le second banc vérifie les vrais déplacements et lancers, avec leurs règles et événements de combat.

`build_passe_rive_s23_review.py DOSSIER_CAPTURE DOSSIER_REVUE` assemble une revue HTML avec lecture, pause, défilement image par image, cinq planches directionnelles et les dix-sept salles. Le GIF conserve une palette d'encodage commune pour éviter un scintillement introduit par la compression. Cet assemblage utilise exclusivement les captures du moteur ; il ne modifie aucun sprite source.

Références techniques consultées : [transformations CanvasItem](https://docs.godotengine.org/en/4.6/classes/class_canvasitem.html), [shader CanvasItem et modulation](https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/canvas_item_shader.html). Les choix artistiques ci-dessus sont propres au projet.
