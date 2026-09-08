# La Halle sous les racines dans Catabase

La Halle remplace la présentation de **L’étal du passeur**, le marchand de l’étape IV (`d04_1`), après les trois premiers combats. Choisir cette destination ouvre directement `MerchantHall.tscn` avec Achille, les canaux animés et la fontaine. Les autres haltes gardent leur présentation.

## Jouer

Lancer Catabase, terminer les trois premiers combats puis choisir **L’étal du passeur** sur le parchemin. Une sauvegarde déjà située dans cette halte reprend également dans la Halle. Ouvrir la scène seule sans expédition affiche un message d’accès ; aucun personnage ni stock fictif n’est créé.

| Action | Contrôle |
| --- | --- |
| Déplacer Achille | Clic sur le sol |
| Arrêter son trajet | Clic droit |
| Découvrir un objet | Clic sur un étal, boutons Reliques/Poteries/Arcanes ou touches 1/2/3 |
| Repos et mémoire | Boutons correspondants ou touches 4/5 |
| Acheter ou utiliser un service | Confirmation dans le panneau ouvert après l’approche |
| Consulter la carte, le kit et l’équipement | Carte et préparatifs ; Revenir dans la Halle conserve la halte ouverte |
| Terminer la halte | Reprendre la route |
| Menu du jeu | Menu ou Échap ; Échap ferme d’abord un panneau ou arrête un trajet |
| Plein écran / interface | F / H |

Les trois achats, le repos à 45 oboles (30 % des PV maximum) et la mémoire gratuite (+20 oboles et découverte) utilisent les services existants. Le même service ne peut pas être acheté deux fois. Le repos est désactivé si les PV sont déjà au maximum. Aucun PNJ marchand n’a été ajouté.

## Progression et sauvegarde

- `GameManager.choose_expedition_node()` engage toujours la destination, attribue sa progression une seule fois, initialise son stock et enregistre son entrée avant d’ouvrir la Halle.
- Le graphe, ses titres, identifiants et empreintes restent inchangés. « La Halle sous les racines » est un titre de présentation ; les anciennes sauvegardes restent compatibles.
- `GameManager.use_catabase_hub_service()` reste l’unique autorité pour les achats, PV, oboles, découvertes et reçus. Ouvrir un panneau ou revenir de la carte ne renouvelle aucun objet.
- `leave_merchant_hall()` réclame `leave_hub`, sauvegarde puis rejoint le parchemin à l’étape V. Un échec d’écriture maintient la scène et propose la récupération sans rejouer l’action déjà appliquée.
- Une sauvegarde réussie par une autre action après un départ échoué permet également de retrouver la carte. La scène vérifie qu’elle est encore affichée avant cette récupération, pour éviter une deuxième transition.
- Reprendre une sauvegarde réinitialise seulement la position visuelle d’Achille au pont d’entrée. Aucun nouveau champ de sauvegarde n’est requis.

## Construction

`merchant_hall.gd` réutilise `tools/labs/apothecary_living_map/playable_hall.gd` pour le décor, la navigation, les pas, l’ombre et l’occlusion de la fontaine. Il remplace l’interface et les entrées de l’étude par les services et transitions de Catabase. Les fenêtres d’inventaire, de pause et d’erreur de sauvegarde suspendent les interactions de la carte.

La source reste `asset/map/painted/merchant/hall_v1/hall.png`, en 1376 × 768. L’affichage est ajusté uniformément à la fenêtre. Le laboratoire `PlayableHall.tscn` conserve sa version indépendante pour travailler le rendu sans transaction.

## Validation exécutée le 8 septembre 2026

Godot 4.7.1, rendu OpenGL Compatibility sur Intel Graphics : **250 vérifications d’intégration réussies, 23 captures en 1280 × 720 et 1920 × 1080, 832 positions de déplacement contrôlées sans sortie de la zone navigable**. Le test restaure une vraie session dans la scène de production, exerce services, confirmations souris, inspection, retour des préparatifs, sauvegardes, reprises, départs et erreurs d’écriture. Les trois victoires de préparation sont simulées ; ce test ne rejoue pas les combats.

Les sauvegardes de test sont isolées dans `artifacts/merchant_hall/`. Le test vérifie que l’empreinte de la sauvegarde du joueur n’a pas changé. Rapport : `artifacts/merchant_hall/verification.json`. Journal : `artifacts/merchant_hall/integration_opengl.log`. Les captures d’arrivée, achat, repos, reprise, préparatifs et erreur de départ ont été inspectées visuellement.

```powershell
$godot = 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
& $godot --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 --log-file artifacts/merchant_hall/integration_opengl.log --scene res://tests/expedition/MerchantHallIntegration.tscn -- --capture
```

Les trois suites de non-régression ont également réussi : **27 tests, 5 837 assertions**, code de sortie 0. Elles couvrent les frontières de sauvegarde, le Sanctuaire et les 17 destinations artistiques existantes.

```powershell
$gutArgs = @('--headless', '--path', '.', '--log-file', 'artifacts/merchant_hall/regression.log', '--script', 'res://addons/gut/gut_cmdln.gd', '--', '-gconfig=', '-gexit', '-gdisable_colors', '-gtest=res://test/unit/test_reliability_expedition_lifecycle.gd', '-gtest=res://test/unit/test_sanctuary_session.gd', '-gtest=res://test/unit/test_catabase_halt_art.gd')
& $godot @gutArgs
```

Aucune erreur de script, de compilation ou d’analyse dans les journaux finaux. L’environnement restreint signale toutefois l’accès indisponible aux certificats Windows et au cache disque OpenGL ; les journaux ne sont pas présentés comme exempts d’erreurs système. Le rendu des shaders et les occlusions disposent en outre de leurs probes dédiés dans le laboratoire. Aucun export de distribution ni nouvelle validation de l’équilibrage des combats n’a été effectué pour cette intégration.
