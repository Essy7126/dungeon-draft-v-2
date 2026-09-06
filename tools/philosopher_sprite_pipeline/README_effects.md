# Effets en sprites du Dialecticien

L’extracteur build_effects.cjs réutilise les contrôles alpha et la géométrie validés pour Achille. Il lit une planche RGBA générée, extrait ses vrais pixels, applique une échelle commune aux quatre phases de chaque rangée et assemble un atlas. Il ne dessine, ne recolore, ne retourne et ne détoure aucune image.

Source attendue : art/source/vfx/philosopher_mage/sprites_v1/source_effects.png.

| Rangée | Animation | Usage | Temps du burst |
| --- | --- | --- | ---: |
| 1 | bolt | Trait horizontal d’Axiome, orienté à droite | 0,20 s |
| 2 | impact | Impact confirmé d’Axiome | 0,24 s |
| 3 | heal | Maïeutique | 0,48 s |
| 4 | control | Aporie | 0,30 s puis pose tenue |
| 5 | shield | Égide du Logos | 0,30 s puis pose tenue |
| 6 | repel | Réfutation | 0,34 s |

Chaque rangée contient quatre dessins. Le runtime reste propriétaire des horloges : les effets persistants gardent la troisième pose tant que le statut ou la source de bouclier existe. Les effets ne changent aucune donnée de combat.

## Extraction et transparence

En mode strict, la source contient quatre colonnes et six rangées de cellules carrées. Le pipeline rejette les fonds opaques, les cellules vides, toute coupe sur des pixels non transparents et les dimensions incohérentes.

Pour une planche aux espacements irréguliers, effects_source_layout.json peut déclarer six bandes verticales, les cinq limites de colonnes par rangée et les centres des 24 dessins. Ce fichier est lié au SHA-256 exact de la source. Toutes les fenêtres sont contiguës ; elles couvrent la source sans omettre de pixels. Les centres sont mesurés et revus manuellement, sans recentrage automatique par phase.

Le helper commun tools/achilles_kit_sprite_pipeline/effects_source_layout.cjs valide les fenêtres. Une correction explicitement déclarée peut seulement effacer le pixel extérieur d’une fenêtre si son alpha ne dépasse pas 32. Un pixel plus fort sur la coupe est toujours bloquant. Aucun pixel intérieur n’est modifié, même s’il appartient à un halo très faible ou à une étincelle détachée.

Un carré commun centré autour de l’ancre de chaque phase devient une zone de 232 × 232 pixels, entourée de 12 pixels transparents dans une cellule finale de 256 × 256. Les sommes alpha et histogrammes prouvent l’absence de perte supplémentaire avant rééchantillonnage Lanczos3. Les 24 régions de l’atlas sont vérifiées octet pour octet.

## Sorties et reproduction

Depuis la racine :

    node tools/philosopher_sprite_pipeline/build_effects.cjs --inspect
    node tools/philosopher_sprite_pipeline/build_effects.cjs
    node --test tools/philosopher_sprite_pipeline/build_effects.test.cjs tools/philosopher_sprite_pipeline/build_effects_icons.test.cjs

Le mode --inspect n’écrit rien. --source, --output et --layout permettent une inspection isolée, avec un dossier de sortie obligatoirement intérieur au projet.

Sorties dans assets/vfx/philosopher_mage/sprites_v1 :

- effects.png : atlas RGBA 1024 × 1536.
- effects.tres : six animations sans boucle.
- icons/{axiom,refutation,mending,aporia,aegis}.tres : AtlasTexture de la troisième pose correspondante, sans recoloration ni nouveau dessin.
- manifest.json : empreintes source/atlas, rectangles et centres, bilans de nettoyage, marges alpha, cadences et mapping des icônes.
- preview_effects_light.jpg, preview_effects_gray.jpg, preview_effects_dark.jpg : aperçus de revue, jamais utilisés dans le combat.

Toutes les vérifications de la source et de l’assemblage passent avant la première écriture de production. Les tests emploient exclusivement des fixtures synthétiques et vérifient les refus, la conservation des éléments isolés, le déterminisme, les phases, les icônes, la transparence et les transformations communes.

## Revue de la source retenue

SHA-256 source : 6feef8c931afd7d0699118a0939b0a383dbfefd729168d048efc2df92de95050.

Bandes mesurees : [0,258], [258,492], [492,798], [798,992], [992,1276], [1276,1536]. Colonnes 0/256/512/768/1024 ; ancres de la grille originale conservees. Nettoyage autorise limite a alpha1 : 774 pixels retires, somme alpha 774 sur 50 844 234 (0,00152%). Aucun pixel plus opaque et aucun pixel interieur modifies. Marge alpha finale minimale 13 pixels.

Les apercus sur fonds clair et gris ont ete examines : phases separees, halos et particules presents, projectile dirige a droite, formes de protection stables. Les 12 tests Node passent.
