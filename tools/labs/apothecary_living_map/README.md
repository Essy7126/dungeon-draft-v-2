# La Halle sous les racines — carte parcourable avec Achille

La scène active est `PlayableHall.tscn`. Achille peut parcourir les allées de la deuxième illustration Meshy, contourner la fontaine et rejoindre les trois étals. Elle se lance seule, sans rejoindre une run ni effectuer de transaction. `LivingHall.tscn` conserve l’étude du décor sans personnage.

La version intégrée à Catabase est `hub/merchant_hall/MerchantHall.tscn` : elle remplace L’étal du passeur à l’étape IV et reprend ses services réels. Voir `hub/merchant_hall/README.md` pour les contrôles et la validation d’intégration. Ce laboratoire conserve la version indépendante du décor.

## Essayer

Ouvrir `PlayableHall.tscn` dans Godot puis appuyer sur **F6**, ou exécuter depuis la racine :

```powershell
./tools/labs/apothecary_living_map/run_hall.ps1
```

| Contrôle | Effet |
| --- | --- |
| Clic sur une allée | Déplacer Achille ; un nouveau clic remplace sa destination |
| Clic droit | Arrêter Achille |
| 1 / 2 / 3 ou boutons Rejoindre | Rejoindre les reliques, les poteries ou l’échoppe arcanique |
| Clic dans la fontaine ou un canal | Onde locale à la position cliquée |
| Voir l’original / Tab | Comparer avec l’image inerte |
| Pause / Espace | Figer les déplacements, les pas et les effets |
| Réglages visuels | Afficher les réglages du décor |
| Eau, Lumières, Orbe, Atmosphère | Activer chaque couche séparément |
| Intensité | Doser l’animation de 0 à 150 % |
| F | Plein écran |
| H | Masquer les contrôles pour examiner toute l’image |
| Échap | Arrêter le trajet ; sinon quitter le plein écran ou retrouver les contrôles |
| F1 | Afficher les limites de navigation pour ajuster la carte |

Les boutons de couche désactivent leur animation ; les lanternes, l’eau et l’orbe restent présents dans l’illustration originale.

## Construction

### Déplacement et intégration d’Achille

Le personnage réutilise les sprites existants d’Achille avec une échelle de 0,52, une ombre de contact douce et une teinte locale ambre ou turquoise selon les lumières proches. Les images de marche avancent avec la distance parcourue au sol : elles s’arrêtent avec lui, y compris pendant une pause. Accélération et freinage adoucissent les départs et les arrivées.

`hall_walk_layout.json` définit les allées, les obstacles et les points d’approche des étals dans le repère natif de l’illustration. Le service de navigation du sanctuaire est réutilisé avec une marge de 10 pixels autour des pieds, dans une carte de navigation indépendante. L’eau et les comptoirs sont exclus ; une destination invalide ne remplace pas le trajet valide en cours. Le redimensionnement agit sur l’ensemble du monde sans modifier les coordonnées de navigation.

La fontaine comporte un détourage placé dans la couche triée par profondeur. Achille passe derrière ou devant selon la position de ses pieds. Ce détourage partage le shader animé du fond afin que l’eau continue à bouger. Les autres objets sont protégés par les limites de marche ; cette version ne comporte pas encore un découpage complet du décor en plans.

### Décor vivant

L’illustration reste une texture peinte. Un shader `canvas_item` travaille dans son repère natif pour limiter les mouvements aux matières voulues :

- **Canaux et fontaine** : reflets, petites distorsions et rides. Les masques évitent les pierres, les racines et les engrenages. Un clic crée une onde supplémentaire.
- **Lanternes** : variations indépendantes de leur lumière ambre, sans ajouter de seconde flamme sur le dessin.
- **Orbe bleu** : pulsation lente et léger mouvement de la lumière.
- **Atmosphère** : brume basse sur les bords d’eau, fines particules et gouttelettes de la fontaine. Le centre demeure lisible.

Le temps est fourni explicitement aux deux shaders et aux particules. La pause fige donc réellement l’eau, la lumière et l’atmosphère. L’intensité zéro restitue l’original. Le contrôleur gère les coordonnées d’image et l’ajustement uniforme à la fenêtre ; le décor ne change pas de proportions.

La source fait **1376 × 768 pixels**. L’affichage en Full HD utilise une interpolation douce ; il ne recrée aucun détail. Pour une version finale destinée à un grand écran ou à du zoom, l’étape suivante sera une source de plus haute définition avec les mêmes cadrage et proportions, puis une vérification des masques. Une séparation des plans et des objets permettrait ensuite d’ajouter parallaxe, déplacement d’éléments et occlusions plus précises. Une ambiance sonore discrète pourrait renforcer l’eau et les lanternes ; cet essai porte sur le mouvement visuel.

## Fichiers

- `PlayableHall.tscn`, `playable_hall.gd` : scène active, déplacement au clic et interface.
- `hall_walk_layout.json` : contours de navigation, obstacles, étals et détourage de la fontaine.
- `hall_player.gd`, `hall_actor_tint.gdshader` : animation, ombre et lumière locale d’Achille.
- `LivingHall.tscn` : étude du décor seul avec ses ressources exportées.
- `living_apothecary.gd` : contrôleur partagé des deux études, avec image, shader, titre et atmosphère configurables.
- `living_hall.gdshader` : eau, lanternes, orbe et onde interactive.
- `hall_atmosphere.gd`, `steam.gdshader` : particules et brume procédurale.
- `hall_layout.json` : surfaces d’eau cliquables et exclusions.
- `asset/map/painted/merchant/hall_v1/hall.png` : copie exacte de l’original Meshy.

`LivingApothecary.tscn` conserve la première étude. Aucun PNJ marchand ni système d’achat n’est ajouté à ces scènes.

## Vérification

### Carte parcourable

`VerifyHallWalk.tscn` vérifie le déplacement au clic, le remplacement de destination, l’arrêt au clic droit, les trajets autour de la fontaine, les trois étals, les passages étroits, les destinations interdites, la pause des pieds et des pas, ainsi que le redimensionnement en cours de trajet. Il échantillonne chaque position parcourue pour détecter les sorties de la zone navigable et les téléportations. Les captures devant et derrière la fontaine servent à contrôler visuellement l’occlusion.

```powershell
& 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 --log-file artifacts/hall_walk/runtime.log --scene res://tools/labs/apothecary_living_map/VerifyHallWalk.tscn -- --capture
& 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --log-file artifacts/hall_walk/controller_parse.log --check-only --script res://tools/labs/apothecary_living_map/playable_hall.gd
```

Exécution du 8 septembre 2026 avec Godot 4.7.1, OpenGL Compatibility : **376 vérifications réussies, 3 918 positions de déplacement contrôlées, 21 captures à 1280 × 720 et 1920 × 1080**. Le contrôle syntaxique retourne également le code 0. Rapport : `artifacts/hall_walk/verification.json`. Revue visuelle effectuée sur les captures : proportions d’Achille, pieds, ombre, passage derrière la fontaine et interface en 720p. Les journaux contiennent les limites d’accès système décrites ci-dessous ; ils ne sont pas exempts d’erreurs d’environnement.

`RecordHallWalk.tscn` capture le parcours réel d’Achille depuis le pont, autour de la fontaine puis vers l’échoppe arcanique. Exécution réussie : 288 images en 1920 × 1080, assemblées à 24 images/s dans `artifacts/hall_walk/halle_achille.mp4` (12 secondes). Les captures et vidéos sont des artefacts locaux, exclus des sources du jeu. La résolution de l’illustration reste 1376 × 768.

```powershell
& 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 1920x1080 --log-file artifacts/hall_walk/recording.log --scene res://tools/labs/apothecary_living_map/RecordHallWalk.tscn
```

### Étude du décor seul

`VerifyLivingHall.tscn` exerce les contrôles et produit des captures à 1280 × 720 et 1920 × 1080. Le probe compare les pixels à temps fixes sur les canaux, la fontaine, une lanterne, l’orbe et le sol ; il vérifie aussi les clics, l’image originale, la pause et l’intensité zéro.

```powershell
& 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 --log-file artifacts/living_hall/runtime.log --scene res://tools/labs/apothecary_living_map/VerifyLivingHall.tscn -- --capture
```

Les résultats effectifs, captures et limites d’environnement sont consignés dans `artifacts/living_hall/`. L’exécution headless seule ne valide pas le rendu des shaders.

Validation exécutée le 8 septembre 2026 avec Godot 4.7.1 et OpenGL Compatibility sur Intel Graphics : **174 vérifications réussies, 38 captures, aucune assertion en échec**. Les canaux, la fontaine, la lanterne, l’orbe et l’atmosphère présentent une variation de pixels. Le sol de contrôle reste inchangé avec l’eau seule. Original, pause et intensité zéro sont stables. Les entrées souris et clavier ont été injectées dans la scène réelle ; les pilotes de périphériques Windows ne font pas partie de ce test.

L’import moteur et le contrôle syntaxique du contrôleur ont également été exécutés et retournent le code 0. Les journaux de cet environnement restreint signalent l’accès indisponible au magasin de certificats Windows, au cache disque OpenGL et à la sauvegarde des préférences d’éditeur ; aucun de ces messages n’a empêché la compilation des shaders, les captures ou les contrôles de rendu. Les journaux sont conservés, ils ne sont pas déclarés exempts d’erreurs.

L’aperçu `artifacts/living_hall/halle_vivante.mp4` vient de **144 images réellement rendues dans Godot**, en 1920 × 1080 à 24 images/s (6 secondes), avec une onde déclenchée à 2 secondes. `RecordLivingHall.tscn` reproduit la capture. Cette résolution vidéo correspond à l’affichage agrandi de la source 1376 × 768, pas à une nouvelle illustration haute définition.

Commandes de préparation exécutées :

```powershell
& 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --headless --editor --recovery-mode --path . --import --log-file artifacts/living_hall/import.log
& 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --log-file artifacts/living_hall/parse.log --check-only --script res://tools/labs/apothecary_living_map/living_apothecary.gd
```

Références techniques : [shaders 2D de Godot](https://docs.godotengine.org/en/stable/tutorials/shaders/your_first_shader/your_first_2d_shader.html) et [filtrage des CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html).
