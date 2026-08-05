# Disposition responsive du Studio

La 1.2 utilise une barre d’actions globale, un rail d’outils compact à gauche, un canvas central extensible, un inspecteur contextuel à droite et un tiroir inférieur fermé par défaut.

À 1280 px, la barre passe en libellés compacts, masque le nom de document redondant et conserve accessibles Lab, Produire, Focus et Détacher. Sous 1180 px, l’inspecteur se replie ; sous 760 px de hauteur, le tiroir reste fermé. À partir de 1500 px, les libellés complets sont restaurés.

Les presets sont :

- **Construction** : canvas et inspecteur ;
- **Calibration** : outils de transformation et tiroir ;
- **Gameplay** : validation/pathfinding et tiroir ;
- **Aperçu final** : vue Jeu sans panneaux latéraux.

`Tab` active **Focus Map** et mémorise la visibilité précédente des panneaux. Un second appui restaure exactement cet état. Les splitters, le preset, la vue et l’état Focus sont persistés avec le workspace.
