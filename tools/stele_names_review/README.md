# La stèle des noms — halte du Léthé, étape IV

Une rive funéraire ouverte sur l'eau, sous un grand saule : le chemin relie
la barque brune à trois bancs à un mémorial sculpté du passeur Charon.
Des pierres de noms partiellement immergées, une offrande et trois lanternes
évoquent le Styx. La peinture conserve le langage Émeraude / Étal du passeur,
avec une composition de repos distincte des deux quais de combat précédents.

La source de 1672 × 941 est conservée sans retouche, avec le prompt exact et
le plan d'échelle dans `art/source/halts/stele_names_v1/`. `calibrate.py` décrit
les contours, les points d'approche et les matériaux dessinés manuellement
sur cette source. Achille conserve un gabarit H/image de 0,18 ; la stèle est
un monument d'environ 2,4 hauteurs de corps, les autres accessoires sont bas.
Les chemins suivent les dalles sèches et contournent les masses peintes.

Les reflets de l'eau sont atténués localement et disparaissent progressivement
vers le lointain ; la coque, les pierres et les lanternes restent protégées.
Les nouveaux réglages du shader sont optionnels et gardent les valeurs des
autres haltes. L'approche d'un lieu déjà atteint consomme désormais le trajet
nul : refermer puis relire la même stèle ne bloque plus le personnage.

Après essai utilisateur, le feuillage couvre treize contours de saule et de
roseaux, avec une oscillation lente d'environ trois pixels source. Les trois
lampes utilisent maintenant `enclosed: true` : centre recalé sur le verre,
scintillement du foyer et halo chaud, sans distorsion de l'armature ni braises.
Leur phase différente évite un clignotement synchronisé.

Le binding utilise le titre exact, le type `lore` et la profondeur IV. Il
fonctionne des deux côtés du miroir de graine et pour les parcours sauvegardés
compatibles. Il n'affecte ni les identités, ni les connexions du parcours.

## Ouvrir et reconstruire

```powershell
./tools/stele_names_review/open.ps1
python art/source/halts/stele_names_v1/calibrate.py
./tools/halt_workshop/halt.ps1 prepare -Map res://data/halts/stele_names_v1.json
./tools/halt_workshop/halt.ps1 verify -Map res://data/halts/stele_names_v1.json
./tools/stele_names_review/verify_motion.ps1
./dev.ps1 test halts
```

Le lanceur ouvre la vraie halte `d04_2`, graine 2401, avec les victoires
antérieures simulées et des données utilisateur isolées. F8 ferme l'essai.
Cliquer la stèle fait approcher Achille pour lire le récit ; cliquer la barque
permet de poursuivre le parcours. La halte réutilise le service de récit existant.

## Contrôle de production

Depuis la racine, avec PowerShell 7.2+ :

```powershell
./tools/stele_names_review/verify.ps1 -GodotPath C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe
```

Le lanceur prend le verrou commun `artifacts/dev/engine.lock`, vérifie la version
du moteur puis l'import, et isole `APPDATA` et `LOCALAPPDATA` dans un nouveau
dossier de preuves sous `artifacts/dev/`. Il refuse un résultat sans rapport,
sans captures, avec erreur moteur, ou avec une exécution incomplète. Ne pas
lancer la scène avec F6 : le contrôle exige cette isolation.

Le script réutilise les attentes de scènes, les captures et les vérifications
HUD de `tools/halt_workshop/verify_production_halt.gd`. Le checkpoint initial
vient de `tools/run_explorer/route_explorer_fixture.gd` : chemin réel de la
graine 2401 vers `d04_2`, dont le titre doit être **La stèle des noms**.

Le test ouvre `ExpeditionHalt` avec le vrai `GameManager`, vérifie le manifeste
`res://data/halts/stele_names_v1.json`, les deux lieux d'interaction, l'affichage
en 1920 × 1080 et 1280 × 720, puis réalise les actions suivantes :

- Approche de la stèle avec `interactions.request(0)` et le déplacement normal.
- Clic souris sur le service récit : exactement 20 oboles, un passage secret
  à venir et un reçu unique, enregistrés par l'économie existante.
- Fermeture et réouverture : bouton utilisé désactivé, clic sans nouveau gain,
  requête de service répétée refusée par le pont de session.
- Retour au parchemin et reprise par `GameManager.resume_expedition` depuis
  le checkpoint réellement écrit ; mêmes oboles, secret et reçu.
- Approche de la barque avec `interactions.request(1)`, clic sur le départ,
  retour à la phase `map` et halte terminée une seule fois.

`production_verification.json` conserve chaque contrôle, les trajets mesurés,
les transitions et les chemins des captures. `summary.json` résume l'exécution.
Les captures de la scène, du dialogue et du reçu doivent ensuite être inspectées
visuellement : le test ne juge pas seul la peinture, l'échelle, la qualité des
shaders ou le confort des trajectoires. Le départ utilise la transition normale
de la halte ; il ne simule pas une navigation libre de la barque.

## Lanternes et végétation : contrôle GPU

```powershell
./tools/stele_names_review/verify_motion.ps1 -GodotPath C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe
```

Le contrôle réutilise le runtime et la capture de l'atelier, avec le même verrou
moteur, import, version et données utilisateur isolées. Il observe le shader
réel sans modifier ses paramètres artistiques ni les masques. Les échantillons
restent fixés dans les pixels de la source 1672 × 941 et sont projetés dans
chaque viewport : trois vitrages, trois rideaux de saule, trois touffes de
roseaux et une hampe claire, deux dalles, le tronc, la coque et un rocher.

À 720p et 1080p, chaque couche est capturée seule aux temps 0 ; 0,45 ; 0,90 ;
1,35 ; 1,80 ; 2,25 ; 2,70 ; 3,15 secondes, en mouvement normal puis réduit.
Les contrôles comparent la luminance de chaque vitrage, le changement des
feuilles, l'immobilité des témoins et la baisse d'amplitude en mouvement réduit.
La corrélation des gradients des lanternes cherche un déplacement de leur
armature, indépendamment du niveau global de lumière. Pause et original doivent
produire deux images identiques. Les captures de contexte réactivent toutes les
couches et Achille pour la revue finale.

`motion_verification.json` conserve les mesures et seuils, chaque assertion,
les rectangles effectivement échantillonnés et les empreintes des sources.
Le lanceur compose les 60 planches temporelles annotées listées dans
`contact_sheets.json`, y compris quand des contrôles GPU échouent.
`motion_summary.json` refuse une capture, séquence ou planche manquante.
L'agrandissement des crops conserve les pixels par voisin le plus proche.

L'inspection visuelle des planches reste nécessaire : la corrélation teste une
translation en pixels entiers et une ressemblance de contours, pas l'absence
absolue de toute déformation sous le pixel. Ce contrôle mesure le shader ; il
ne remplace pas le parcours de production décrit plus haut.

## Preuves de la première livraison du 12 septembre 2026

- Préparation finale PASS :
  `artifacts/dev/20260912-114853-halt-prepare-0d1edcfc/summary.json`.
- GPU PASS : **271 contrôles, 42 captures, 4 168 positions mesurées, aucune
  sortie du sol**, aux deux résolutions :
  `artifacts/dev/20260912-114858-halt-verify-ac068403/summary.json`.
- Production PASS : **96 contrôles, 8 captures**, récompense unique,
  fermeture/réouverture, checkpoint repris et départ effectif :
  `artifacts/dev/20260912-115107-stele-names-production-d776ba53/summary.json`.
  Approches mesurées : stèle 4,25 s ; retour à la barque 4,35 s ; relecture
  immédiate à position inchangée. Les temps sont simulés par pas de 1/60 s.
- Régression des haltes PASS : **49 tests, 1 141 assertions**, sans tests
  ignorés ni erreurs :
  `artifacts/dev/20260912-115359-test-halts-c12dcf29/gut-strict-report.json`.
- Atelier Python PASS : **26 tests** :
  `artifacts/dev/20260912-115049-stele-water-contract-python/unittest.log`.

Captures inspectées : arrivée, stèle, promenade à droite, vue propre, dialogue
720p, reçu 1080p et départ. La coque est entière, les appuis du personnage sont
sur les dalles, le récit et les boutons tiennent dans les deux formats. La
stèle plus grande que le guide initial est conservée comme monument ; la
révision de l'eau retire la rupture de masque visible au lointain.

Source SHA-256 :
`9853e8770b7d4b9989f65fb316abd7b73a66d4fd219d136d75fb044ef72c9f0a`.
Manifeste testé (texte UTF-8 normalisé LF) :
`2e32e40b9a5fa818fab95651d165bd5ffcfda60ef017ba82491ec2e1a6a32f06`.
La première QA de production a échoué sur le trajet nul ; son rapport
`artifacts/dev/20260912-113542-stele-names-production-49c5f629` est conservé
comme historique, et ne constitue pas la preuve finale.

## Révision végétation et lanternes après essai

Le traitement des torches ouvertes déformait les cadres et éclairait trop peu
les vitrages. Les centres sont recalés sur les trois fenêtres lumineuses,
avec des rayons limités au verre. Le shader `enclosed` module le foyer et
l'éclairage alentour sans décalage UV de l'armature. Les contours de feuilles
du premier plan sont séparés pour épargner dalle et rocher ; une hampe claire
sur la rive gauche est maintenant animée. Les réglages de l'eau sont conservés.

- Préparation finale PASS :
  `artifacts/dev/20260912-122058-halt-prepare-088c27c8/summary.json`.
- Animation GPU PASS : **254 contrôles, 74 captures, 60 planches temporelles** :
  `artifacts/dev/20260912-122059-stele-names-motion-9a49b4d8/motion_summary.json`.
  Trois vitrages, sept groupes végétaux, cinq témoins fixes, réduction des
  mouvements, pause et original, aux deux résolutions. L'armature des lanternes
  garde une corrélation de contours sans translation. Les nouvelles pierres
  témoins sont fixes et la hampe ajoutée présente une variation visible.
- Suite haltes PASS : **52 tests et 1 265 assertions** :
  `artifacts/dev/20260912-121540-test-halts-104eedd0/gut-strict-report.json`.
- Atelier Python PASS : **29 tests** :
  `artifacts/dev/20260912-120543-stele-foliage-lantern-contract-python/unittest.log`.

Les planches des trois lampes, du saule, des roseaux et des pierres ont été
inspectées. Le premier passage du nouveau test temporel a signalé une
comparaison entre tableaux JSON flottants et entiers : correction de la
comparaison numérique, sans diminution des seuils d'animation ou de stabilité.
Le rapport échoué est conservé sous `20260912-120932-stele-names-motion-cf02dbc1`.

Le manifeste de cette révision est
`ac1c1ee42b4068c22eecf90f6a16561451c63b04069e8f6a1bad58d5a821f09a`.
Peinture et carte de courant sont inchangées. Provenance et empreintes de la
révision : `art/source/halts/stele_names_v1/shader_review.json`.
