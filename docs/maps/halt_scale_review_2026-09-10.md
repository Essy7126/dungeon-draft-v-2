# Échelle humaine des haltes peintes — 10 septembre 2026

Base Git : `2473c335`. Calibration et outils livrés après le retour visuel utilisateur.

## Diagnostic et choix

La Forge réutilisait `player_scale=0.52` de la Halle (largeur 1376) dans un monde de largeur 2200 : à cadrage comparable, le héros était réduit de 37,5 %. Le brief n’indiquait pas de gabarit mesurable pour les accessoires. Agrandir la caméra ne corrige pas le rapport entre le héros et le décor.

Le contrat `world.player_height_ratio` mesure la pose réelle `idle_S`, du point de pieds au sommet de la silhouette, lance et plumet compris. Ce n’est pas une taille anatomique en mètres. Le Studio et le jeu utilisent la même texture et le même ancrage. Les anciennes maps sans ce champ gardent `player_scale`.

Essais graphiques de 17 %, 22 % et 24 % à côté de l’enclume, du four et de l’arche : `artifacts/dev/20260910-145209-halt-scale-candidates-27931b21/`. Cette exécution a produit les images mais a signalé quatre objets non libérés à la fermeture ; elle ne vaut pas validation finale.

Calibration retenue pour la Forge : 24 % de la hauteur de l’image, soit environ 173 px à 720p contre 78 px avant (silhouette de référence, zoom 100 %). Marge des pieds passée de 12 à 27 unités pour accompagner ce gabarit. L’image originale reste strictement identique.

L’enclume centrale et son socle demeurent massifs par rapport à l’établi du four : c’est une proportion peinte dans l’asset, qu’un réglage global du héros ne suffit pas à corriger. La prochaine illustration doit réduire l’ensemble outil/socle, en gardant le four monumental. Ne pas inscrire la source actuelle comme conforme à une grille de proportions usuelles.

## Mise en œuvre

- Runtime : hauteur indépendante de la largeur du monde, pas proportionnels au gabarit, lumière et zoom recentrés sur le torse.
- Studio : hauteur relative réglable, marge des pieds, vrai repère Achille déplaçable par Alt+clic ; le SVG exporté contient la silhouette aux points d’approche.
- Création : défaut 22 %, conservation du réglage du plan à l’import, grille seau/enclume/porte/allée dans le brief, comparaison sur le même sol obligatoire avant affectation.

## Vérifications finales

- **41 tests GUT, 378 assertions, aucun échec ni erreur** : `artifacts/dev/20260910-150506-test-halts-7eecec56/gut-strict-report.json`. Couverture du ratio indépendant des dimensions, du gabarit réellement joué dans Explorer, de la cadence sonore, du repère Alt+clic sans mutation, de l’export SVG respectant le format et des valeurs historiques hors plage.
- **23 tests Python, aucun échec** : `artifacts/dev/20260910-150008-halt-test-14926d81/`. Valeurs invalides refusées, conservation du plan et références du brief.
- **Forge : 285 contrôles graphiques, 42 captures, 5 872 positions, zéro position hors zone, aucune erreur moteur** : `artifacts/dev/20260910-150645-halt-verify-577fbf12/`. Rendu et navigation aux deux résolutions, gabarit appliqué au vrai sprite, occultations, interactions, audio et libération des ressources.
- **Studio : capture 1600×1000, export SVG et fermeture sans erreur** : `artifacts/dev/20260910-150939-halt-scale-studio-fa003e93/`. Capture inspectée ; le champ indique 24 %, le repère est à côté de l’enclume et la marge indique 27.
- Source de la Forge inchangée : `3c7ff21be9eabcc38bb24ab3f0fc4be1ce82e8c3b3a6c3eb8c795966f325bcbf`. Empreintes manifeste, masque et courants cohérentes pour les deux maps. Scripts modifiés formatés ; `git diff --check` propre sur ce périmètre.

Les premières tentatives interrompues par le verrou moteur, l’erreur de typage du vérificateur et le chemin Windows du premier export Studio ne sont pas des validations. Leurs rapports restent conservés. La vérification finale ne signale plus les objets non libérés du premier montage de comparaison.

## Limite artistique conservée

Cette livraison corrige le gabarit joué et la méthode de création. Elle ne repeint pas les accessoires de la source. L’enclume/socle central doit être redimensionné dans une nouvelle version de l’illustration avant de qualifier les proportions du mobilier de conformes à la grille. Une architecture volontairement monumentale reste possible ; elle ne justifie pas des objets usuels géants. Le sanctuaire historique conserve son échelle tant qu’il n’a pas fait l’objet de sa propre revue visuelle.

La suite globale du dépôt n’a pas été relancée pour ce correctif ciblé. Les limites de sa précédente exécution restent décrites dans la fiche de mission.
