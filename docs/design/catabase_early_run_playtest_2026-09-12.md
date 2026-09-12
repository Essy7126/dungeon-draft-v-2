# Catabase — première passe jouée des trois entrées

12 septembre 2026. Demande : tester et ajuster les salles avec les personnages existants, sans créer de personnage supplémentaire.

## Périmètre et intention

Douze destinations de combat aux profondeurs II, III, V et VI ont une composition propre. Les parcours sont éprouvés de I jusqu'à la victoire au premier carrefour VII. Les affrontements I et VII restent les points de référence existants ; cette passe ne prétend pas équilibrer VIII–XX.

Le choix d'entrée doit changer la décision prise en combat. Le butin ne détermine plus la famille ennemie de ces douze destinations. Les rôles réutilisent les unités et visuels existants : aucune nouvelle silhouette ou nouveau personnage.

| Voie | Problème posé | Réponses accessibles à Achille |
|---|---|---|
| Puits | Attaques de feu, impact préparé, entrave légère qui gêne l'approche | Approcher à une case, rompre une ligne de vue, attirer un lanceur, choisir quel adversaire interrompre |
| Porte | Un garde protège des archers ; la protection remplace sa frappe | Déplacer le garde, séparer ses voisins, engager un archer au contact, profiter du tour de protection |
| Barque | Des molosses mobiles soutenus par un soigneur aux ressources finies | Concentrer les dégâts, isoler un poursuivant, atteindre le soigneur, temporiser après épuisement des soins |
| Confluence | Garde physique et lanceur préparant un impact | Réutiliser ensemble les réponses apprises sur les branches précédentes |

## Réglages effectivement livrés

- **Fournaise du puits** : préparation d'un impact de feu à la prochaine activation, coefficient de Prouesse 1,8, sans brûlure persistante. La cible est suivie, mais une portée devenue invalide ou une ligne de vue coupée annule la résolution. Portée 2–5 : le contact est une réponse. Une activation initiale d'attente ; la résolution consomme l'activation du lanceur.
- **Cendre entravante** : attaque réduite, coefficient 0,65, puis −1 PM pendant une activation. Aucun retrait de PA et aucun étourdissement. Attente initiale et délai de trois activations entre usages.
- **Égide du portique** : protège le garde et ses alliés adjacents à hauteur de 20 % des PV maximum du garde pendant deux activations. Deux usages, délai de trois activations, coût égal à tous ses PA. Il choisit donc entre protéger et frapper.
- **Officiant des salles d'eau** : seulement deux soins par combat, un allié obligatoire, aucun soin sur lui-même. Soigner remplace son attaque. Valeur de base 10 avant les réglages de salle.
- Garde : 10 d'armure, 2 PM. Archers, officiants et lanceurs précoces : 2 PM ; molosses : 3 PM. Une attaque par activation. Les multiplicateurs de salle complètent ces valeurs de base.
- Les unités de cette ouverture perdent leur réduction du premier déplacement forcé. Crochet et Heurt peuvent ainsi réellement déplacer un adversaire d'une case. L'ancrage des rangs ultérieurs reste inchangé.

Les variantes sont construites sur des ressources indépendantes. Les sorts partagés des autres rencontres conservent leurs valeurs et leurs effets.

## Les douze salles

Les facteurs ci-dessous complètent la progression existante ; ce ne sont pas des statistiques finales fixes.

| Profondeur | Destination | Composition | PV × | Attaque × |
|---|---|---|---:|---:|
| II | La sente des oliviers | Rejeton, fondeur | 1,10 | 0,85 |
| II | Le portique des oboles | Garde, archer | 1,00 | 0,90 |
| II | Les traces du Léthé | Molosse, officiant | 1,15 | 0,90 |
| III | Les guetteurs du bosquet | Conducteur, fondeur | 1,05 | 0,90 |
| III | La garde des sources | Rejeton, fondeur, conducteur | 0,78 | 0,70 |
| III | Les percepteurs d'airain | Garde, deux archers | 0,85 | 0,78 |
| III | Les lances oubliées | Deux molosses, officiant | 0,85 | 0,75 |
| V | Le gué des serments | Garde, fondeur | 0,95 | 0,90 |
| V | Les roseaux du tireur | Molosse, officiant, archer | 0,85 | 0,75 |
| VI | L'atrium des cendres | Garde, fondeur, archer | 0,85 | 0,78 |
| VI | Les gardiens du foyer | Conducteur, fondeur, rejeton | 0,90 | 0,78 |
| VI | Les duellistes du gué | Deux molosses, officiant | 0,95 | 0,80 |

Deux défauts ont également été corrigés pendant les essais :

1. **Terrain d'eau** : quatre cases de lave héritées du modèle provoquaient des brûlures permanentes dans Les duellistes du gué. Elles sont redevenues du sol normal via le sérialiseur Arena Studio et son pont de synchronisation. Aucune refonte géométrique.
2. **Connexions inversées** : certaines graines inversaient les destinations visuellement mais recalculaient les raccordements avec des arrondis différents. Une entrée pouvait changer de famille à l'étape suivante. La révision 5 inverse désormais aussi les connexions prévues entre les destinations. Les sauvegardes de révision 4 conservent leur ancien graphe et restent rechargeables ; commencer une nouvelle run pour bénéficier de cette correction de topologie.

## Mesures et interprétation

### Combats indépendants

Banc utilisant les grilles et formations de production, EnemyAI, SpellCaster, TurnQueue et les services de timing des terrains et statuts. Douze salles × trois kits légaux précoces × trois graines (2401, 42, 777). Chaque salle commence à PV pleins, au niveau prévu, sans équipement ; les points ultérieurs restent non dépensés.

| Mesure | Référence avant réglage | Après réglage |
|---|---:|---:|
| Cas exécutés | 36, graine 2401 | 108, trois graines |
| Victoires | 34/36 | 108/108 |
| Plus longue durée observée | 14 activations d'Achille | 10 activations d'Achille |

Les anciens échecs concernaient Airain à l'atrium et au gué final. Un premier réglage conservait encore une défaite au gué : l'inspection a révélé la lave héritée. Le second réglage corrige ce terrain et borne les protections.

Les nouveaux sorts sont effectivement utilisés par l'IA sur les 108 cas : 64 préparations de fournaise, 27 cendres, 46 égides, 27 soins. Le banc observe 19 préparations bloquées à leur résolution.

**Le tir reste très avantageux.** Dans ce banc, le chasseur perd en moyenne 16,5 % de ses PV et termine en 4,44 activations, contre 28,4 % et 6,75 pour le briseur, 29,6 % et 7,50 pour Airain. Ce sont des résultats de cette politique automatisée et de ces équipements, pas une mesure générale de puissance des branches.

La politique d'Achille est volontairement simple : dégâts par PA, opportunités d'élimination, quelques effets, déplacement vers une cible accessible et Garde. Elle n'utilise pas intelligemment Percée ni une planification sur plusieurs tours. Les victoires démontrent la jouabilité de ces cas, **pas une difficulté idéale ni le plaisir ressenti**.

### Parcours continus dans les scènes réelles

Le second outil joue déploiement, déplacements, sorts, fins de tour, IA, récompenses, achats de maîtrises et halte via les interfaces du jeu. Aucun gain de combat forcé et aucune recharge artificielle des PV/PA. Les PV persistent ; les soins de progression et les récompenses restent actifs. Priorité aux attributs de vitalité et aux provisions ; aucun équipement acheté.

Les trois parcours, sur la graine 2401, réussissent chacun six combats et une halte jusqu'à VII :

| Entrée et orientation de build | Activations d'Achille I–VII | PV à la récompense VII |
|---|---:|---:|
| Puits, briseur | 33 | 82/360 |
| Porte, chasseur | 35 | 97/360 |
| Barque, Airain | 34 | 172/360 |

Ces trois parcours utilisent des builds différents : ils ne permettent pas de classer la difficulté intrinsèque des voies. Leurs équipements de sorts évoluent avec les achats légaux et diffèrent des kits figés du banc indépendant. Le puits et la porte empruntent ensuite la confluence, tandis que la barque garde ses salles d'eau jusqu'à VI.

Les PV enregistrés à l'écran de récompense comprennent les effets de l'expérience et des passages de niveau. Ils ne correspondent donc pas exactement aux PV au dernier coup du combat. La halte IV figure dans le journal avec `victory: false` parce qu'elle n'est pas un combat.

## Reproduction et preuves

Depuis la racine du projet, avec Godot 4.7.1 :

```powershell
./dev.ps1 test monsters
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tools/catabase_monster_validation/EarlyRunPlaytest.tscn -- label=verification seeds=2401,42,777
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tools/catabase_monster_validation/EarlyRunLiveProbe.tscn -- route=puits kit=briseur
```

Changer la dernière paire en `route=porte kit=chasseur` ou `route=barque kit=airain`. Le parcours réel écrit sa sauvegarde dans son dossier d'artefacts, sans utiliser la sauvegarde habituelle du joueur. Exécuter les processus Godot successivement et conserver les journaux.

- Référence : `artifacts/dev/early_run_playtest/baseline_v1/report.json`.
- Comparaison finale : `artifacts/dev/early_run_playtest/tuned_v2/report.json`.
- Parcours réels : `artifacts/dev/early_run_playtest/live_<voie>_<kit>/report.json`.
- Régression monstres : `artifacts/dev/20260912-151120-test-monsters-71b416e7/gut-strict-report.json` : **75 tests, 18 354 assertions, PASS**.
- Graphe et sauvegardes : `artifacts/dev/early_run_playtest/route_state.log` : **16 418 contrôles, 3 430 chemins complets, zéro échec**.
- Salles, carte complète, explorateur et comportements précoces après formatage : `artifacts/catabase_monsters/checks/early_run_routes_final_20260912/gut-strict-report.json` : **20 tests, 20 503 assertions, PASS**. Cette sélection reprend huit des 75 tests monstres ; les comptes ne sont pas disjoints.

Les imports et journaux moteur des validations finales sont sans erreur. Une exécution antérieure avait été bloquée par des aperçus WebP animés expérimentaux, sans référence dans le jeu : un `.gdignore` local dans leur dossier d'artefacts les exclut de l'import principal. Les essais incomplets ou en erreur ne sont pas comptés comme réussis. Les cinq nouveaux scripts passent le formateur avec vérification de structure ; les anciens catalogues n'ont pas été reformatés globalement.

## Suite recommandée pour le prochain playtest humain

Observer d'abord si la préparation de Fournaise et la différence entre garde protégé et archer au contact sont comprises sans explication orale. Mesurer ensuite l'avantage du tir et la pression au carrefour VII sur plusieurs builds, avec et sans équipement. Enfin seulement, étendre les combinaisons à VIII–XX. Ajouter des résistances ou davantage de contrôles immédiatement risquerait de masquer les problèmes d'accès aux cibles et de progression déjà observables.
