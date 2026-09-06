# Source des effets du Dialecticien

source_effects.png est la planche ImageGen RGBA retenue. prompt_native_v2.txt contient la demande exacte de cette génération. La transparence est native ; le pipeline ne remplace aucune couleur de fond.

Les 24 dessins sont répartis en six rangées : trait d’Axiome, impact d’Axiome, Maïeutique, Aporie, Égide du Logos, Réfutation. Les quatre colonnes décrivent préparation, expansion, pic et dissipation.

Le pipeline mécanique est dans tools/philosopher_sprite_pipeline/build_effects.cjs. Les fenêtres mesurées et leurs ancres sont persistées dans effects_source_layout.json, lié au SHA-256 exact de cette source. Les rangées de soin et de bouclier dépassent une grille nominale uniforme ; leurs gouttières réelles sont donc conservées.

Revue : la source et les atlas finaux ont été affichés sur gris et sur fond clair. Le projectile pointe à droite ; les halos, feuilles et fragments sont préservés. Un nettoyage limité au pixel extérieur des fenêtres enlève 774 pixels d’alpha1, aucun alpha supérieur à1 et aucun pixel intérieur. Tous les autres pixels sont préservés avant la mise à l’échelle commune de chaque rangée.

Les cinq icônes de sorts sont des références AtlasTexture à leur troisième pose respective. Aucun autre dessin n’a été ajouté par un script.
