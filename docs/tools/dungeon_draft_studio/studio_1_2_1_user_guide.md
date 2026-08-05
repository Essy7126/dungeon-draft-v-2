# Guide utilisateur Dungeon Draft Studio 1.2.1

## Construction dynamique

1. Ouvrez une arène dans le Studio.
2. Cliquez **Lab** ou **DYN**. Le canvas ne change pas : la palette
   Construction dynamique apparaît à droite.
3. Choisissez Terrain, Mur ou Spawn/objectif/décoration, puis peignez sur la
   grille. Un trait continu correspond à un seul undo.
4. Modifiez largeur/hauteur puis cliquez **Redimensionner le document** si
   nécessaire.
5. Cliquez de nouveau **DYN** ou sélectionnez un autre outil pour revenir au
   mode d’édition, sans perdre la session.

## Transformer la grille

1. Sélectionnez **GRILL**.
2. Glissez le corps cyan pour déplacer la grille.
3. Glissez X ou Y pour incliner/redimensionner un axe.
4. Utilisez l’anneau orange pour la rotation et le carré vert pour l’échelle.
5. Choisissez Symétrique, Conserver X ou Conserver Y, puis glissez la poignée
   violette pour modifier l’ouverture.
6. Utilisez **Centrer pivot** ou **Pivot sur O**. Le pivot ne salit pas le
   document.
7. Échap ou clic droit annule le geste en cours; changer d’outil ou perdre le
   focus produit la même restauration exacte.

## Ancres, aperçu et fenêtre détachée

Le mode **ANCR** masque le gizmo et montre uniquement les ancres/résidus. La
vue Jeu masque toutes les aides éditeur. Le workspace peut être détaché puis
réintégré : document, sélection, historique, mode et routeur restent les mêmes.

Le Lab autonome reste disponible via
`tools/labs/dynamic_arena/DynamicArenaLab.tscn`. **Envoyer au Studio** crée un
transfert vérifié; **Lab** l’importe puis ouvre le mode intégré.

