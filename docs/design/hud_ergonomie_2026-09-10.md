# HUD tactique — ergonomie du 10 septembre 2026

## Direction retenue

Adaptation des captures de Baldur’s Gate fournies par Paolo à la palette actuelle de Catabase : lecture de l’ordre des tours en haut, identité compacte à gauche, ressources au-dessus des actions, fin de tour séparée à droite. Les ressources sont nommées et chiffrées ; les couleurs accompagnent le texte sans le remplacer.

- Frise horizontale centrée, combattant actif en premier et titre de tour allégé sous les portraits. Tous les combattants restent présents ; la largeur s’adapte à leur nombre. Contrôles de 1, 6 et 16 cartes, rotation, clic et réduction des animations.
- Identité ramenée de 486 à 350 pixels de conception ; portrait de 110 pixels et barre de vie plus sobre.
- PA/PM affichés sous la forme `PA 6/6`, `PM 3/3`, à proximité des coûts des sorts. Texte de 13 pixels minimum, valeur zéro jamais obscurcie.
- Région des sorts élargie de 430 à 704 pixels de conception. Passer de quatre à six sorts ne réduit plus l’ensemble du HUD ; les touches 1 à 6 restent réelles et les cibles dépassent 48 pixels aux résolutions vérifiées.
- Onglets plus lisibles au-dessus des actions. Bascule sorts/objets sans déplacement de la fin de tour.
- Bouton de fin de tour bleu pétrole ; inventaire, compétences, caractéristiques et carte en dessous, cibles d’au moins 36 pixels avec noms accessibles et infobulles.
- Sept pictogrammes SVG originaux pour déplacement, PA/PM et menus ; nouvelle plaque de titre de tour. Les illustrations de sorts conservent leur source peinte.
- Cadres affinés, texture et dorures secondaires discrètes. Deux lignes réservées pour le nom de l’action et le retour de ciblage ; leur espacement suit la hauteur réelle du texte.

## Mise en œuvre

Le preset `data/ui/combat_hud_layout_run_v1_compact.tres` pilote les proportions. Les composants de ressources et de bouton principal ainsi que `combat_hud_recraft_v1.gd` portent la nouvelle présentation. Le déplacement du conteneur de ressources préserve maintenant les propriétaires de ses descendants et donc les noms uniques Godot. Les variantes neutres de diagnostic sont explicites dans la galerie et restent disponibles.

Les règles de combat, coûts, kit réel, raccourcis existants et autorité de présentation sont conservés. Les modifications antérieures du thème et les travaux concurrents restent en place.

## Validation finale

- **72 tests / 1943 assertions / 11 suites : PASS**. Résultats fusionnés par suite ; chaque échec initial est remplacé par sa réexécution réussie, sans double comptage ni masquage de diagnostic.
- **30 captures : PASS** en 1280×720 et 1920×1080 : 11 états de galerie et 4 vues Catabase par résolution.
- **158 contrôles rendus** supplémentaires : vrais clics sur les quatre menus et les onglets, noms accessibles, taille des cibles, six raccourcis, stabilité de la fin de tour, épuisement visible des PA et indisponibilité des six actions.
- Inspection visuelle des captures de ciblage bloqué, de six sorts et d’épuisement des PA. Aucun diagnostic moteur dans les quatre rapports finaux.
- `git diff --check` ciblé sans erreur ; nouvelle sonde formatée.

[Bilan et rapports sources](../../artifacts/dev/20260910-193812-hud-ergonomics-validated/summary.json) · [Empreintes](../../artifacts/dev/20260910-193812-hud-ergonomics-validated/source_hashes.json)

[HUD de six sorts en 720p](../../artifacts/dev/20260910-193411-chrome-hud-1280x720-20828ab8/captures/combat_six.png)

Les captures sont des vues de contrôle avec états explicitement préparés, pas une campagne rejouée. Le test de six emplacements répète deux définitions pour vérifier la disposition, sans modifier le kit réel. Il ne s’agit pas d’une certification d’ergonomie parfaite : une session de jeu de Paolo reste la référence pour juger le confort.

Les tentatives initiales restent dans `artifacts/dev/` : import initial des SVG, attentes anciennes de compteur/placement, viewport headless de 64 pixels, perte des propriétaires lors du déplacement de conteneur et chevauchement des messages ont été identifiés puis corrigés. Le scénario d’épuisement configure explicitement les disponibilités synthétiques de la galerie en plus de la valeur PA.
