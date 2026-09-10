# Première map de combat — reprise du pipeline Studio

Révision 4, 10 septembre 2026. La révision 3 masquait les dalles en reprenant
presque entièrement le fond peint ; elle est abandonnée. Cette version restaure
les 217 dalles opaques du moteur commun et produit le décor autour de leur grille.

## Production réalisée

1. Copie de travail de room_01, sans ancien fond, en mode MODULAR pour exporter
   une référence géométrique propre de 1920 × 1200.
2. ArenaArtKitExporter : grille, masques, coordonnées, gameplay, murs, profondeur,
   marqueurs, snapshot et manifeste avec empreintes. Le guide de composition
   ajoute les berges du terrain dans les mêmes coordonnées.
3. Génération par imagegen intégré, avec ce guide spatial et la peinture du
   sanctuaire émeraude comme référence directe de dessin. Roches brun-noir,
   eau bleu-vert, porte à gauche et dégagement central réservé aux vraies dalles.
4. Livraison : le générateur a fourni 1586 × 992. L’image entière a été normalisée
   explicitement par Godot/Lanczos à 1920 × 1200, sans recadrage. Les références
   du kit, les cellules et la projection n’ont pas été redimensionnées.
5. ArenaArtRoundTripService.inspect_reimport puis apply_reimport en ALL_DEFINED :
   empreintes et résolution vérifiées, transaction COMMITTED, calibration RMS 0,
   aucune recalibration demandée. Les chemins du fond et de sa ressource dérivée
   sont synchronisés dans la salle de production.
6. Contrôle en combat, correction de cinq sommets de berge (+16 pixels natifs au
   sud-est) pour soutenir entièrement la cellule (18,12) et conserver 20 pixels
   de retrait. Aucune cellule ni calibration n’a changé pendant cette correction.

Le shader de pierre partagé est revenu à sa version standard. La map utilise
sa propre palette de pierre, un raccord de terre opaque et les vrais obstacles
et fosses. Land et Water échantillonnent la même peinture enregistrée ; le shader
local d’eau anime seulement les pigments bleu-vert. Les anciens traits de berge
sont transparents pour laisser apparaître les berges dessinées. La géométrie de
ces berges reste présente et contrôlée. La brume animée reste périphérique.

## Fichiers de référence

- [Kit Studio figé](../../art/source/maps/catabase_cavern_v4/art-kit/arena_art_manifest.json)
- [Guide utilisé pour la génération](../../art/source/maps/catabase_cavern_v4/composition-guide.png)
- [Reçu de réimport](../../art/source/maps/catabase_cavern_v4/reimport-report.json)
- [Peinture livrée](../../assets/catabase/combat/cavern_v1/land_v4.png)
- [Prompt exact](../../assets/catabase/combat/cavern_v1/land_v4.prompt.txt)
- [Provenance et empreintes](../../assets/catabase/combat/cavern_v1/manifest.json)
- [Plan actif](../../data/arenas/catabase_cavern_v1/terrain_plan.json)

Le guide de génération est conservé avant la petite correction de support de
berge ; celle-ci ne touche pas l’emprise tactique. Les peintures v1/v2 et leurs
captures restent des archives. La topologie initiale est conservée : 217 sols,
12 cellules bloquées, 16 cellules de fosse, mêmes départs et règles. La projection de la révision 3 sert de base au retrait supplémentaire de6% décrit ci-dessous ; l’identifiant historique reste greek_drawn_courtyard_v1.

## Vérifications

- 11 tests stricts, 9 084 assertions, aucune erreur : topologie Catabase, matériaux
  spéciaux préservés et recalage Studio.
- Deux passes GPU en 1920 × 1080 et 1200 × 896, avant/après déplacement et garde.
- Réemploi des oracles du pipeline : geometry_checks, terrain_support_checks,
  terrain_material_checks, combat_band_checks, interaction_checks et
  framing_proportion_checks. Tous passent, sans erreur moteur de fermeture.
- 217 cellules contrôlées pour le picking ; aucune dalle coupée ou recouverte
  par le HUD. Déplacement réel et Garde d’airain exécutés, clics sur obstacles et
  fosses rejetés. Proportions stables entre les deux résolutions.
- Kit archivé revérifié avec validate_kit : fichiers, empreintes et résolution.
- Les quatre captures finales ont été inspectées visuellement : plateau visible,
  accès gauche dégagé et continuité de la peinture aux berges.

[Rapport synthétique](../../artifacts/dev/cavern-pipeline-v4/summary.json) ·
[Capture après actions, petite fenêtre](../../artifacts/dev/cavern-pipeline-v4/room-qa-1200x896/room_01_after_move_guard.png).

Portée : première salle et rencontre réelles lancées par l’API Studio de test
avec la caméra de production. Pas de victoire complète ni de validation de toute
la run. Le runner historique des cinq salles a été essayé et s’arrête avant le
combat, car son contrat attend encore exactement cinq salles ; son échec est
conservé dans artifacts/dev/cavern-pipeline-v4/1920x1080/. Il n’est pas compté
comme une validation réussie. Les contrôles réutilisés sont exécutés via
Review.tscn -- --room=res://data/rooms/odyssey/room_01.tres --production-qa
--resolution=1200x896 --capture=CHEMIN_ABSOLU.png.

## Animation de la caverne

Ajout du 10 septembre : quatre matériaux partagent une horloge locale à la scène.
La surface Water utilise le shader de remous aux coordonnées natives,
avec déplacement des reflets turquoise et caustiques mobiles. Le fond Land possède un shader dédié aux torches ; ses zones turquoise restent fixes. Les deux flammes
peintes sont déformées localement ; leur lueur vacille et des braises s’élèvent.
La brume comporte deux nappes à vitesses différentes, avec un mouvement de volutes.
Son masque laisse dégagée toute l’emprise des cases (rectangle conservateur).

L’option GameManager de réduction des mouvements fige l’horloge actuelle ; la
reprise se fait sans saut. Le processus respecte également la pause de la scène.
Aucune texture générée ni aucune cellule tactique n’a été modifiée pour ces effets.

La revue motion-review en combat compare les pixels à deux instants distants de
six secondes, vérifie l’avancement réel de l’horloge et son arrêt en mode réduit.
Les zones eau, brume et torches changent ; la zone témoin de dalle reste identique.
Les vérifications de géométrie, matériaux, cadrage, déplacement et garde sont
réexécutées en 1200 × 896 et 1920 × 1080. Rapports et captures dans
artifacts/dev/cavern-living-v1/. Le GIF de revue est échantillonné à3 images/seconde ;
les shaders du jeu sont évalués à chaque image rendue.

Correction des effets, révision animation2 : le shader d’eau est limité au plan
Water ; les reflets des murs ne sont plus interprétés comme de l’eau. La zone de
rivière basse contrôlée est identique pixel pour pixel à la révision animation1
aux instants0 et6 secondes. Les torches sont ancrées à leur base, avec une légère
ondulation latérale uniquement sur leurs pixels de feu ; la lumière fait varier
l’éclairage peint de2,5% au maximum. Le halo orange additif a été supprimé et le
nombre de braises réduit. Les rapports actuels sont dans
artifacts/dev/cavern-living-v2/.

## Retrait des berges — placement5

L’emprise de l’arène a été réduite uniformément de6% autour du point natif
(960,307), maintenant son bord haut en place. Ses limites passent de
(416,307)–(1423,951) à(449,307)–(1395,912). Une bande de terrain peint sépare
maintenant les dalles des rebords et de l’eau inférieure, visible dans les
captures de combat aux deux résolutions. Les shaders et la peinture sont inchangés.

Les cellules, obstacles, fosses et départs conservent toutes leurs coordonnées
logiques. Les axes et les pixels de calibration sont resynchronisés via le
service Studio, RMS0. Le contrôle de support relève62,53pixels natifs de retrait
minimum aux berges déclarées ; le plan impose maintenant au moins32pixels de
marge. Les bornes de placement des tests couvrent ce retrait.

11tests stricts et9084assertions passent, ainsi que les oracles GPU de géométrie,
support, bordure, matériaux, cadrage, déplacement et garde en1920×1080 et1200×896.
Preuves : artifacts/dev/cavern-inset-v1/. Kit correspondant au nouveau placement :
art/source/maps/catabase_cavern_inset_v1/art-kit/. Le kit de génération original
reste figé comme provenance artistique.
