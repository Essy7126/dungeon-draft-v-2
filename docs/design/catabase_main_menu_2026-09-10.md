# Catabase — menu principal vivant

10 septembre 2026. Demande : un menu immersif avec une illustration animée, inspiré de la composition de la référence Baldur’s Gate. **Catabase est le seul jeu public ; la run à trois est mise de côté.**

## Intégration

- `ui/TitreEcran.tscn` conserve son UID et reste le point d’entrée du projet.
- `ui/titre_ecran.gd` : titre CATABASE, Continuer si une sauvegarde existe, Nouvelle partie, Sanctuaire, Quitter ; navigation clavier et bouton de réduction des animations. Les actions sont accessibles immédiatement.
- `ui/menus/catabase_title.gdshader` : cadrage sans étirement, dérive lente et réaction douce au pointeur, brume à deux échelles et scintillement localisé. Une horloge pilotée par le script permet de figer réellement tous les effets.
- `assets/catabase/title/underworld_gate_v1.png` : illustration originale générée avec l’outil intégré imagegen ; aucune capture de Baldur’s Gate n’est utilisée comme asset.
- La sélection publique affiche les deux apparences d’Achille, toutes deux liées à Catabase. `include_archived_adventures` est un accès explicite pour les fixtures de laboratoire ; aucun contrôle du menu ne l’active. Les tests historiques restent exécutables.
- Le nom technique du projet reste inchangé pour conserver le chemin `user://` des sauvegardes existantes. Le titre de la fenêtre et l’identité visuelle affichent Catabase.

La scène conserve sa musique existante. Une image animée donne une impression de profondeur et de vie, mais ne permet pas de révéler l’envers des colonnes comme un déplacement dans un décor 3D complet.

## Atmosphère V2 — feu et brume

Amélioration demandée après la première revue utilisateur : mouvements plus riches du feu et de la brume, sans changer l’illustration ou le parcours du menu.

- Cinq foyers ancrés dans les UV de l’illustration : flammes procédurales effilées, turbulence ascendante, cœurs chauds et quelques escarbilles avec durées de vie indépendantes.
- Distorsion de chaleur au-dessus des deux grands braseros et lumière indirecte irrégulière sur la pierre. Le mélange préserve les détails peints et limite les aplats blancs.
- Trois couches de brume : remontées lointaines dans la vallée, nappes intermédiaires et filaments bas au premier plan. Chaque couche a sa direction, son échelle et sa densité ; les nappes proches prennent une légère teinte chaude vers les braseros.
- Les coordonnées des effets suivent le cadrage de l’image. L’horloge `elapsed` reste la seule source de temps : la réduction des animations fige aussi les flammes et les escarbilles.
- `fire_strength` et `fog_strength` sont réglables sur le ShaderMaterial. Le menu conserve son option simple « Animer le décor ».

Revue dédiée : `tools/title_menu/AtmosphereReview.tscn`, 96 images sur quatre secondes, contributions feu/brume vérifiées séparément et stabilité des pixels à horloge figée. Captures, aperçu animé et mesures dans `artifacts/dev/title-atmosphere-v2/`. Les mesures de durée de frame décrivent cette machine et incluent le rythme de présentation ; elles ne constituent pas un budget GPU universel.

Validation V2 finale : import recovery sans erreur, 37 contrôles de menu réussis dans chacun des deux moteurs (Forward+/D3D12 et Compatibility/OpenGL), puis 101 contrôles de la revue dédiée dont 96 exports de frames. Environ 6,07 ms par frame à 1920×1080 sur la RTX 4070 Laptop de ce poste. Rapport faisant foi : `artifacts/dev/20260910-164425-title-atmosphere-final-9dc43f5d/final-summary.json`. Le premier export a rencontré la limite de longueur du chemin du cache de shaders Windows ; la relance avec données isolées sous `artifacts/dev/av2` ne signale plus aucune erreur. Les journaux initiaux sont conservés. Aperçu réel de quatre secondes : `artifacts/dev/title-atmosphere-v2/catabase_atmosphere.webp`. Cette itération ne modifie pas le gameplay ni la sélection ; leurs suites unitaires n’ont pas été relancées.

## Variante peinte émeraude

La demande suivante conserve la composition du menu et les shaders V2, avec le traitement de la salle d’émeraude. L’image active est désormais `assets/catabase/title/underworld_gate_emerald_v1.png` (1672×941), retouchée avec l’outil intégré imagegen à partir du décor original et de `asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png` comme référence de style uniquement. Pierres bleu-gris aux contours peints, bronze patiné, mousses et atmosphère jade. La caméra de la salle d’émeraude n’est pas reprise : le menu garde sa perspective monumentale.

L’image originale `underworld_gate_v1.png` est conservée. La scène change uniquement le chemin de la texture de fond. Le shader V2 reste identique octet pour octet : SHA-256 `21da8b70929516a78d3d2b5741da5a82ddb9dcda759e65b35a971ec06e31a51c`. Les ancrages du feu ont été comparés visuellement sur les deux illustrations. Prompt exact : `assets/catabase/title/underworld_gate_emerald_v1.prompt.txt`.

Validation : import Godot 4.7.1 sans erreur, 37 contrôles de navigation/résolutions/gel des animations et 101 contrôles de la revue d’atmosphère (dont 96 captures), tous réussis. Rapport : `artifacts/dev/menu-emerald/summary.json`. Rendu Forward+/D3D12 inspecté, environ 6,06 ms/frame à 1920×1080 sur ce poste. Aperçu animé réel de quatre secondes : `artifacts/dev/menu-emerald/catabase_emerald.webp`. Aucun changement de gameplay et aucune modification de shader pendant cette variante.

## Mythologie et vent — 11 septembre 2026

L’image active est `assets/catabase/title/underworld_gate_mythology_v2.png`.
Retouche avec l’outil intégré imagegen, à partir de la peinture émeraude : les
bannières portent des symboles infernaux dorés, des grenades et des méandres grecs ;
les deux panneaux de porte représentent Hadès barbu et casqué, puis Cerbère avec
trois têtes distinctes, en bas-reliefs de bronze. Composition et foyers conservés.
Prompt exact : `assets/catabase/title/underworld_gate_mythology_v2.prompt.txt`.

L’original `underworld_gate_emerald_v1.png` reste intact et versionné, SHA-256
`3836aa58187ea7b533c994039a1d907f4b08a4a74f44ddbdef6d1747a687040d`.
Copie supplémentaire et shader V2 conservés dans `artifacts/dev/title-mythology-v3/`.
Pour revenir à l’ancienne peinture, réaffecter cette texture au fond du menu ;
mettre `wind_strength` à zéro si l’ancien rendu sans tissu animé est souhaité.

Le shader anime les tissus avec deux ondes lentes, une amplitude croissante vers
leur extrémité libre et une très légère variation de lumière dans les plis.
La sélection combine des régions en UV et la couleur du tissu pour préserver
la pierre. C’est une déformation locale de la peinture, pas une simulation de
tissu 3D. La brume proche superpose volumes et filaments transportés sur le sol,
avec une couche basse jusqu’au bord de l’écran et une teinte chaude près des feux.
L’horloge `elapsed` fige tous les nouveaux effets avec la réduction des animations.
`wind_strength` permet de régler le vent ; `camera_strength` sert notamment à
isoler les mouvements locaux lors de la revue.

La revue d’atmosphère vérifie désormais chaque bannière caméra immobile, la
stabilité de la colonne, l’arrêt de tous les effets et le déplacement de la
brume au premier plan. Les exports V3 vont dans `artifacts/dev/title-mythology-v3/`
pour conserver les preuves et captures des itérations antérieures.

Validation V3 finale : import recovery et GUT de sélection réussis (2 tests,
82 assertions), puis 37 contrôles de menu et 108 contrôles d’atmosphère dans
chacun des deux moteurs OpenGL/Compatibility et D3D12/Forward+, sans erreur ni
fuite à la fermeture. Rapport :
`artifacts/dev/title-mythology-v3/run-20260911-210311/summary.json`.
GUT : `artifacts/dev/20260911-205846-test-test_unit_test_catabase_selection_launch.gd-6900c542/gut-strict-report.json`.
Captures inspectées : menu 1920×1080, brume isolée à deux instants et illustration.
96 images exportées sur quatre secondes ; aperçu `artifacts/dev/title-mythology-v3/catabase_mythology.webp`.
Environ 6,06 ms/frame à 1920×1080 sur cette machine ; pas une garantie de budget
GPU pour d’autres configurations. Les validations CI sont conservées ; la suite
globale et les smokes d’éditeurs sans rapport avec ce changement ne sont pas relancés.

Les premiers essais restent archivés : un import restreint a rencontré des
erreurs d’accès Windows, puis le banc titre a signalé une libération tardive du
MP3. L’import avec accès nécessaires et l’arrêt explicite du lecteur suivi de
quelques frames avant la fermeture des bancs ont permis les passages finaux propres.

## Corrections V4 — Cerbère, drapeau droit et brume gauche

Suite à la revue utilisateur du 11 septembre, l’image active devient
`assets/catabase/title/underworld_gate_mythology_v3.png` : retouche locale avec
l’outil intégré imagegen pour retirer une oreille surnuméraire de Cerbère.
La V2 reste intacte, avec une copie supplémentaire dans
`artifacts/dev/title-mythology-v4/`. Prompt :
`assets/catabase/title/underworld_gate_mythology_v3.prompt.txt`.

Le drapeau droit ne sélectionne plus seulement les pixels rouges : le tissu
et ses broderies dorées utilisent la même déformation continue, plus lente et
moins ample. La déformation décroît avant le bord intérieur du tissu, faute de
peinture du décor caché derrière lui ; la modulation de luminosité est supprimée
à droite. Le drapeau gauche conserve son réglage précédent.

La brume proche entre les rochers gauches reçoit une couche propre, composée
de volumes et de filaments en déplacement ascendant. Les zones de brume déjà
peintes et la luminosité servent de masque pour garder les rochers sombres
immobiles. `rock_fog_strength` règle cette contribution ; `fog_strength` et
la réduction des animations continuent de contrôler toute la brume.

La revue exporte les états de vent et de brume gauche séparément, vérifie
le mouvement de la broderie, la contribution dans les poches gauches et la
préservation des rochers sombres. Les captures V4 restent séparées des V3.

Validation finale V4 : import et GUT sélection réussis (2 tests, 82 assertions),
37 contrôles titre et 117 contrôles atmosphère réussis dans chacun des moteurs
OpenGL et D3D12, sans erreur ni fuite. Rapport final :
`artifacts/dev/title-mythology-v4/run-20260911-211705/summary.json`.
GUT : `artifacts/dev/20260911-211414-test-test_unit_test_catabase_selection_launch.gd-9ade8bb3/gut-strict-report.json`.
Gros plans inspectés : six oreilles de Cerbère, broderie et bord du drapeau droit,
brume gauche isolée. Aperçu de 96 frames / 4 secondes :
`artifacts/dev/title-mythology-v4/catabase_corrected.webp`.
Le premier passage a détecté un voile sur certaines pierres bleues ; le masque
final combine couleur et limite de profondeur devant les rochers.

## Vérifications et reprise

Import Godot 4.7.1 et test `test/unit/test_catabase_selection_launch.gd` : PASS, 2 tests, 82 assertions. Rapport : `artifacts/dev/20260910-160253-test-test_unit_test_catabase_selection_launch.gd-55909610/gut-strict-report.json`.

Revue native : `tools/title_menu/TitleMenuReview.tscn` ; captures et rapport dans `artifacts/dev/catabase-title-review/`. Elle vérifie les résolutions 1280×720, 1200×896, 1920×1080 et 2560×1080, le gel des pixels avec réduction des animations, leur variation en mode animé, les clics réels titre → sélection → retour et la conservation d’un checkpoint illisible.

Validation finale : **PASS, 55 tests et 2 046 assertions**, 7 suites ciblées, import Godot recovery sans erreur. Rapport strict : `artifacts/dev/20260910-161730-catabase-title-final-adfe354c/gut-strict-report.json`. La suite groupée avait révélé une fuite dans les fixtures de `test_philosopher_gameplay.gd` ; leur nettoyage utilise maintenant `isolated_battlefield_cleanup.gd` et libère les historiques de combat, comme les autres suites de monstres. Le second passage strict ne signale plus de fuite.

Revue rendue : **37 contrôles réussis** en Compatibility/OpenGL puis en **Forward+/D3D12**. Le rapport final et les journaux `forward.*` sont dans `artifacts/dev/catabase-title-review/`, sans erreur moteur. Captures inspectées visuellement : 1920×1080, 1200×896, sélection publique et notice de reprise. `ui/titre_ecran.gd` et `tools/title_menu/review_title.gd` ont été formatés avec le formateur du projet et sa vérification de structure.

Pour voir les animations : ouvrir le projet et lancer F5, ou `ui/TitreEcran.tscn` avec F6. L’option « Animer le décor » doit être activée. La revue de captures commence volontairement avec cette option désactivée pour vérifier la stabilité des pixels.

Les validations CI existantes sont conservées ; la suite globale et les smokes d’éditeurs sans rapport avec ce menu n’ont pas été relancés. Le dépôt contient de nombreux travaux en cours indépendants : ne pas réinitialiser ni reformater globalement.

## Prompt final — outil intégré imagegen

Use case: stylized-concept. Create an original cinematic main menu background illustration for Catabase, a Greek mythological underworld tactical game. Landscape 16:9, ideally 2560x1440. Full bleed artwork only, absolutely no text, logo, borders, buttons or UI. Epic monumental ancient Greek gate descending into the underworld, massive weathered Doric columns and carved bronze doors at center-right, broad stone stairs descend toward a distant turquoise mist-filled threshold, warm amber braziers at the lower right illuminate aged limestone, subtle hanging red cloth. Foreground dark stone silhouette frames the scene, enormous architecture and layered depth. Leftmost 38 percent mostly deep shadow, atmospheric low-detail empty space reserved for title and vertically stacked menu controls. Focus and richest detail at x=68 percent y=45 percent. Painterly high quality premium fantasy game concept art, hand-painted readable volumes and exquisite stone and bronze materials, petrol blue shadows, muted turquoise spectral atmosphere, controlled warm amber highlights. Mood solemn, mysterious and inviting, beautiful Greek underworld, no giant skull, no medieval Gothic, no modern elements, no characters required. Restrained ground fog, crisp architecture, no excessive particles. This single still will later be animated with slow camera drift, fog and light shaders.
