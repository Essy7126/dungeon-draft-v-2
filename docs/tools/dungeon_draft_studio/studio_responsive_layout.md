# Disposition responsive du Studio

La 1.2 utilise une barre d’actions globale, un rail d’outils compact à gauche, un canvas central extensible, un inspecteur contextuel à droite et un tiroir inférieur fermé par défaut.

À 1280 px, la barre passe en libellés compacts, masque le nom de document redondant et conserve accessibles Lab, Produire, Focus et Détacher. Sous 1180 px, l’inspecteur se replie ; sous 760 px de hauteur, le tiroir reste fermé. À partir de 1500 px, les libellés complets sont restaurés.

Les presets sont :

- **Construction** : canvas et inspecteur ;
- **Calibration** : outils de transformation et tiroir ;
- **Gameplay** : validation/pathfinding et tiroir ;
- **Aperçu final** : vue Jeu sans panneaux latéraux.

`Tab` active **Focus Map** et mémorise la visibilité précédente des panneaux. Un second appui restaure exactement cet état. Les splitters, le preset, la vue et l’état Focus sont persistés avec le workspace.

## Mise à jour — refonte du Studio Terrain (24/08/2026)

Pour le domaine Terrain, les presets `Construction / Calibration / Gameplay /
Aperçu final` deviennent une préférence avancée : ils disparaissent du shell en
mode guidé. Le rail d'outils reste permanent ; la checklist n'est qu'un état
informatif et ne pilote ni le canvas ni l'inspecteur.

Règles responsive du domaine :

- sous 1 400 px de large, l'inspecteur se replie et un bouton permanent
  `Ouvrir l'inspecteur ▸` l'ouvre en tiroir par-dessus le canvas ;
- sous 760 px de haut, la bibliothèque réduit sa hauteur et la barre historique
  interne disparaît ;
- `Tab` (mode Focus) masque aussi l'en-tête Terrain et la bibliothèque,
  puis restaure exactement l'écran précédent, y compris l'accueil.

Le rail permanent, la bibliothèque et l'inspecteur défilent : leur hauteur
minimale ne peut plus repousser le canvas ou le tiroir hors de la fenêtre. Le
runner `TerrainStudioCaptureRunner` imprime pour chaque vue la ligne
`TERRAIN_STUDIO_LAYOUT`, qui donne les bornes verticales de chaque bloc, le
ratio d'occupation du canvas et le nombre d'actions primaires hors écran.
