# Le Seuil des Ombres — calques éditables

Ouvrir `underworld_threshold_layers.ora` dans Krita. Masquer un groupe enlève à la fois son objet et son raccord de sol. Chaque groupe sépare la silhouette et le patch qui contient son ombre. Les pixels colorés viennent strictement de l’original.

Le fond utilise le clean plate imagegen uniquement dans les zones de reconstruction. Une transition douce de quelques pixels raccorde la texture aux bords de ces zones. Hors des zones et de leur transition, le fond reste identique à la peinture originale. `props_hidden_check.png` montre le résultat sans les 3 groupes.

Les ombres sont des patches RGB opaques sur alpha binaire, pas une ombre physique translucide ou un calque Multiply. Déplacer un objet nécessite de retoucher son ombre et son raccord : le patch transporte aussi la texture de dalle. Les contours sont mesurés à la main sur la peinture. Ils ne reconstituent pas les surfaces des objets qui étaient cachées dans la peinture. La limite des sélections garde des pixels de bord déjà mélangés au décor par la peinture d’origine.

Les guides géométriques restent masqués, marqués « avant peinture — à recaler », et sont simplement redimensionnés vers 1672×941. Leurs dimensions natives sont consignées par fichier dans `guide_sources` du rapport. Le guide de profondeur est un aperçu 8 bits ; les données 16 bits originales restent dans `depth.png`. Ils ne constituent pas une recalibration de la peinture.

Reconstruction reproductible : `package_layers.py --source art/source/halts/underworld_threshold_v1/grounded`. `layer_packaging_report.json` compare les pixels de la composition relue depuis les calques de l’archive et ceux de son mergedimage, séparément.
