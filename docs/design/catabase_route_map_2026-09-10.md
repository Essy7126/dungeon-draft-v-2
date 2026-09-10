# Carte de la descente — 10 septembre 2026

Objectif : ouvrir tout le parcours, remplacer les deux couloirs parallèles par
des bifurcations et jonctions, rendre les symboles et leur légende lisibles.
Référence fournie : carte de Slay the Spire. Habillage conservé : parchemin
et iconographie grecque de Catabase.

Décisions : vue détaillée avec chemins aérés ; vue d'ensemble plein écran,
vingt seuils visibles et légende persistante ; sélection sans départ implicite.
Les inconnues et secrets restent soumis aux aperçus du modèle de route.
Le graphe v3 ajoute une jonction diagonale alternée entre chaque paire de voies.
Les sauvegardes v2 régénèrent leur graphe d'origine, sans changer le parcours.

Fichiers : core/expedition/expedition_route_{catalog,state}.gd,
ui/expedition/expedition_{map_canvas,route_view,route_overview}.gd,
tests/expedition/route_state_test.gd et probe dédié de carte.

Vérifications terminées pour la carte (voir ci-dessous). Les modifications préexistantes du thème et de
l'écran d'expédition appartiennent à d'autres travaux ; ne pas les écraser.

## Résultat et preuves

- Graphe : 384 258 assertions, 127 008 parcours complets, zéro échec.
  Test `tests/expedition/route_state_test.gd`, incluant les jonctions sur
  32 graines et les allers-retours de sauvegardes v2.
- Intégration de session : 301 assertions, zéro échec ; victoires simulées.
  Rapports : `artifacts/dev/20260910-161628-route-map-review-9c5e3f63/`.
- Validation finale : import recovery sans erreur et six suites GUT ciblées,
  59 tests / 4 274 assertions, verdict strict PASS.
  Rapport : `artifacts/dev/20260910-162406-route-map-final-80cac6cc/gut-strict-report.json`.
- Captures finales 1280×720 et 1920×1080 : 69 contrôles chacune, zéro erreur ;
  inspection visuelle effectuée, clic réel de sélection, Échap, maintien du
  défilement et de l'état de route. Images : `artifacts/route_map/`.
- Le probe élargi de build a exécuté ses 1 000 assertions sans échec fonctionnel,
  mais échoue au contrôle strict de fermeture (409 objets, 168 ressources et
  8 textures non libérés). Son code n'utilise pas la route ni ses vues ; le
  problème de fermeture n'a pas été corrigé dans cette tâche.
- Un premier import via le harnais CI sans recovery a aussi signalé des
  ressources d'éditeur non libérées ; la validation finale ci-dessus réutilise
  l'import recovery documenté pour les commandes de développement.

Le graphe v3 concerne les nouvelles runs. Les anciennes runs restent chargeables
avec leurs connexions exactes ; toutes bénéficient des améliorations visuelles.
Aucun changement des règles de combat, des coûts ou des récompenses.
## Pictogrammes dessinés — deuxième passe

À la demande de Paolo, remplacement des marqueurs réalistes de la carte par
douze pictogrammes SVG originaux : contours épais, légèrement irréguliers,
encre unie, sans relief ni médaillon. Sources : `assets/catabase/route_drawn/`.
La carte, la légende et la fiche partagent `map_icon` / `map_node_icon` et le
filtre existant des destinations inconnues. Les peintures de l'inventaire
restent accessibles par leur catalogue habituel.

Les cercles servent aux choix disponibles, à la sélection et à la position.
Les autres glyphes sont dessinés directement sur le parchemin.

Validation : import recovery sans erreur ; 19 tests / 2 858 assertions,
verdict strict PASS. Captures 720p et 1080p : 69 contrôles chacune, zéro erreur,
revue visuelle de la vue détaillée, de la légende et de la carte entière.
Rapport : `artifacts/dev/20260910-163146-route-drawn-icons-022f9868/summary.json`.

## Symbolique propre à Catabase — troisième passe

Retour de Paolo : la série précédente ressemblait trop à Slay the Spire.
Les douze dessins ont été remplacés par des signes liés à Catabase :
aspis et lance, casque grec, arc de Pâris, olivier, balance, autel à degrés,
stèle, profils face à face, amphore, spirale du Léthé, racines et sandale.
La légende nomme la spirale et les indications textuelles ont été actualisées.
Les règles de navigation restent inchangées.

Validation : import recovery et suite des assets, 11 tests / 791 assertions,
PASS strict. Capture 720p : 69 contrôles, PASS ; capture 1080p relancée après
erreurs d'initialisation OpenGL : 69 contrôles, PASS et aucun message moteur.
Les deux rendus ont été inspectés visuellement.
Rapports :
- artifacts/dev/20260910-175900-catabase-greek-route-signs-04fb7a40/
- artifacts/dev/20260910-180103-greek-route-1080-review-61fdbb7a/
