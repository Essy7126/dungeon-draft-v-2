# Spectre à l’épée à deux mains — master visuel V1

Statut : document de direction visuelle initial. Les quatre orientations, les trois animations et la présence ennemie sont désormais livrées ; voir le [bilan d'intégration V1](spectre_greatsword_integration_v1.md) pour les ressources et les vérifications en combat.

## Modèle retenu

[Dessin de référence final](../../art/source/characters/spectre_greatsword/concepts/cour_des_sources_v1/spectre_master_v4.png), généré avec l’outil ImageGen intégré. Le fichier PNG 1024 × 1536 possède un vrai canal alpha ; son fond n’est pas un damier dessiné.

- Capuche large à pointe recourbée, ouverture noire profonde sans visage, crâne ni yeux lumineux.
- Col drapé gris cendre, torse et ceinture anthracite, manches déchirées et gants sombres.
- Quatre grandes masses de tissu suspendues. Pas de pieds visibles : la lévitation se lit dans le vide entre la robe et l’ombre.
- Une seule grande épée, lame droite sombre à tranchant acier clair, garde simple et poignée longue tenue à deux mains.
- Dans cette vue, main à droite de l’image près de la garde, main à gauche près du pommeau. Préserver cette prise dans les futures vues ; ne pas inverser l’image pour simuler une autre orientation.
- Contours sombres et grands aplats gris pour rester lisible sur les dalles dorées. Pas de fumée ou de particules incorporées autour du corps.

Le dessin a été inspecté en grand et réduit à 140 px de hauteur sur un aplat proche du calcaire de la map. Cela valide seulement sa lecture graphique, pas son échelle ou son occultation dans un combat exécuté par Godot. La version finale fixe les repères : les autres essais conservés ne constituent pas des vues du même atlas.

## Trois animations à préparer

| Animation | Intention | Cible initiale |
|---|---|---|
| Garde | Pose canonique stable, épée suspendue, robe au-dessus d’une ombre fixe. Pas de balancement continu du corps. | 1 pose ; respiration du tissu seulement si nécessaire ensuite |
| Glissement | Translation portée par la grille, buste légèrement incliné et grands pans qui suivent. Pas de pas ni de root motion. | 4 poses, phase continue entre les cases |
| Coupe lourde | Armé lisible, accélération de la lame, arrêt net et retour exact à la garde. Les deux mains restent solidaires de la poignée. | 6–8 poses, 0,65–0,80 s ; impact vers 0,25–0,30 s |

Ces durées sont des cibles de production à tester, pas des animations déjà livrées. Un effet de lame ou d’impact pourra utiliser des sprites séparés, comme Garde d’airain.

## Contraintes de préparation et d’intégration

Conserver une ancre de projection au sol indépendante du bas de robe et de la pointe de l’épée. Référence du pipeline d’Achille : toile 512 × 384, ancre (256, 320), échelle commune à toutes les poses. Vérifier que l’armé et l’extension de la grande épée tiennent dans cette toile ; si nécessaire, agrandir toutes les toiles avant l’export, sans réduire le personnage seulement pendant sa frappe.

Préparer quatre directions N/E/S/W séparément, en conservant capuche, pans, gants, prise et géométrie de l’épée. Dans le contrat actuel, E/S montrent les vues de face et N/W les vues de dos. Garder l’ombre indépendante dans le moteur ; celle dessinée sous ce master sert à expliquer la lévitation et ne doit pas produire une double ombre lors de l’intégration.

Une scène visuelle `Node2D` dédiée peut utiliser le contrat de `UnitView` : liaison à l’unité, orientation, repos, déplacement, attaque et signaux de fin. Le marqueur `cast_release_reached` doit déclencher l’impact une seule fois. La cellule et la translation restent sous le contrôle de `Battle` ; le dessin n’écrit ni statistiques ni position logique.

Références relues : [UnitView](../../battle/unit_view.gd), [profil d’Achille](../../data/visuals/achilles/achilles_cour_des_sources_sprite_profile_v1.tres), [pipeline de sprites](../../tools/achilles_sprite_pipeline/README.md).

## Sources

[Prompt exact du master final](../../art/source/characters/spectre_greatsword/concepts/cour_des_sources_v1/generation_final_prompt_v4.txt) et [manifeste](../../art/source/characters/spectre_greatsword/concepts/cour_des_sources_v1/concept_manifest.json). Génération et retouches réalisées avec ImageGen intégré, sans API ni CLI de secours. Les scripts locaux ont servi uniquement à copier les fichiers et inspecter taille, alpha et réduction de lecture.
