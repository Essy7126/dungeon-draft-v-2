# Guides géométriques de la halte

Ces fichiers proviennent des triangles évalués de la collection Threshold grounded generated,
projetés avec la caméra orthographique actuelle. Ils ne sont pas déduits de l’illustration.
Toutes les images ont la résolution du rendu courant, origine en haut à gauche.
Échantillonnage au centre du pixel, sans antialiasing ni transformation colorimétrique.

- depth.png : vrai Z caméra en PNG gris 16 bits, proche blanc, loin sombre, fond 0.
  Pour v>0 : mètres = depth_min_m + (65535-v)/65534 × depth_span_m (guides.json).
  depth_metres.npy garde directement les float32 métriques, fond NaN.
- normals.png : RGBA8, RGB = 0.5 × normale + 0.5, alpha=présence de géométrie.
  Repère caméra : +X droite, +Y haut, +Z vers la caméra ; normales géométriques
  des triangles, sans lissage ni retournement des faces arrière.
- object_ids.png : identifiants RGB8 exacts ; palette dans object_palette.json.
  Charger comme données sans filtrage/colorimétrie pour retrouver les identifiants.
- coverage.png : masque visible de toute la géométrie.
- layers/<groupe>.png : groupe isolé avec alpha binaire, autres groupes retirés,
  couleur d’objet sans éclairage convertie en sRGB. Ce sont des guides de découpe,
  pas des calques de l’illustration finale ni le rendu Workbench éclairé.
- masks/<groupe>_visible.png : portion réellement visible dans la scène complète.

Les surfaces cachées dans un groupe restent cachées par ce groupe. Les modificateurs
sont ceux du graphe évalué de la vue courante ; instances/non-mesh sont refusés.
Les contours peuvent différer du rendu Workbench antialiasé d’environ un pixel.
Le script ne modifie aucun objet, réglage, matériau ou image Blender et n’enregistre
pas le .blend. Les maillages temporaires sont libérés même en cas d’erreur.
guides.json est installé en dernier et porte les empreintes du jeu de fichiers.
