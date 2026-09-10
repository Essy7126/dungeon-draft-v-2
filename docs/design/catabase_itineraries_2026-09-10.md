# Itinéraires de Catabase — 10 septembre 2026

Objectif demandé : plusieurs chemins cohérents, sans deux voies parallèles,
avec des choix qui changent les rencontres et les opportunités accessibles.

Décisions : catalogue v4 à largeur variable (1–4 destinations), connexions
locales, branches engagées jusqu'à une réunion ; haltes spécialisées, aperçu
des haltes accessibles et abandonnées avant la réunion ; position des glyphes
issue du graphe. Vingt seuils et l'enveloppe 14–16 combats restent conservés.
Les catalogues v2 et v3 doivent se restaurer exactement.

Fichiers : générateur d'itinéraires, catalogue/état/session d'expédition,
carte détaillée et complète, tests de route, d'économie et de navigation.

Validation terminée (Godot 4.7.1) :

- Graphe : 15 198 contrôles, 3 080 parcours complets, zéro échec ; connexions locales
  sans croisement, engagements et coût d'opportunité, brouillard préservé,
  restauration exacte v2/v3/v4. Rapport :
  `artifacts/dev/20260910-184215-catabase-itineraries-v4-fd1b5099/graph.stdout.log`.
- Sessions réelles, victoires simulées : 420 contrôles, zéro échec. Les quatre
  profils de halte sont exercés avec transactions et restauration des reçus.
- GUT strict : 58 tests, 5 584 assertions, PASS (navigation, progression, icônes,
  haltes peintes et fiabilité des sauvegardes). Sessions et rapport GUT :
  `artifacts/dev/20260910-184455-catabase-itinerary-regression-86d09bcf/`.
- Captures rendues 1280×720 et 1920×1080 : 82 contrôles chacune, zéro erreur moteur ;
  ouverture complète, sélection souris, interdiction de sauter au boss, fermeture
  Échap et conservation du défilement. Inspection visuelle détail et vue complète.
  Rapport final :
  `artifacts/dev/20260910-185119-catabase-itinerary-final-visual-retry-d0414545/`.
  Images : `artifacts/route_map/1280x720-choices/` et `1920x1080-choices/`.
  Une première capture 1080p avait des erreurs de création du cache shaders ;
  le nouveau passage utilise un chemin APPDATA temporaire court et passe sans erreur.

Les changements de tracé et de services concernent les nouvelles expéditions.
Les sauvegardes v2/v3 gardent leur graphe et leurs services universels ; ces cas
restent couverts explicitement dans les tests d'économie et de fiabilité.
Les modifications préexistantes des autres tâches sont conservées.
