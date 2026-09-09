# Monstres de Catabase — gameplay et progression v2

Les quatre concepts approuvés deviennent des `UnitData` indépendants. Leurs sprites peints sont portés par `characters/enemies/catabase_monsters/`. Leurs deux techniques utilisent les événements d'attaque et de sort du visuel. En mêlée, les dégâts surviennent à la pose d'impact ; les projectiles ajoutent leur temps de trajet. Les portraits sont chargés à la demande depuis `assets/characters/catabase_monsters/<famille>/portrait.tres`.

## Statistiques de base

| Adversaire | PV | PA / PM | Initiative | Prouesse | Défense | Rôle |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| Sentinelle d'airain | 78 | 4 / 2 | 6 | 14 | 35 armure ; première poussée réduite de 1 par activation | Tenir les goulets, repousser |
| Rejeton de braise | 42 | 4 / 3 | 10 | 10 | Feu +35 %, glace −20 % | Tireur fragile, attaque annoncée |
| Molosse du Styx | 50 | 4 / 5 | 13 | 11 | Aucune réduction passive | Approcher vite, saigner |
| Lamie du Léthé | 54 | 4 / 3 | 8 | 8 | 20 résistance magique ; ombre +20 %, feu −15 % | Contrôler l'approche à distance |

L'armure suit la mitigation existante `armure / (armure + 100)` : 35 armure représente environ 26 % de réduction physique, pas 35 %. Aucun ennemi ne possède d'esquive aléatoire ni de sort faisant sauter un tour.

## Techniques

Chaque technique coûte 4 PA et ne peut être utilisée qu'une fois par activation. Une unité ne cumule donc pas plusieurs attaques dans son activation. Les techniques spéciales sont bloquées à la première activation et reviennent toutes les trois activations. Les descriptions indiquent les dégâts de base ; le montant effectif est calculé depuis la prouesse runtime.

| Adversaire | Technique primaire | Technique spéciale |
| --- | --- | --- |
| Sentinelle | **Estoc d'airain** : 14 physique, portée 1 | **Heurt du rempart** : 18 physique, portée 1, pousse de 1 |
| Rejeton | **Éclat de braise** : 10 feu, portée 2–5, ligne de vue | **Fournaise annoncée** : prépare 14 feu et 4 feu sur deux activations, portée 2–6 ; résolution à l'activation suivante, qui est consommée |
| Molosse | **Morsure du Styx** : 11 physique, portée 1 | **Déchirure funèbre** : 16 physique, portée 1, 3 physique sur deux activations |
| Lamie | **Trait de l'oubli** : 8 ombre, portée 2–6 | **Reflux du Léthé** : 10 ombre, portée 2–5, −1 PM pendant une activation |

Les dégâts périodiques sont fixes et respectent les défenses. Les dégâts directs suivent la prouesse : coefficient 1 pour les primaires, puis 18/14, 1,4, 16/11 et 1,25 pour les spéciales. La courbe de prouesse propre à la descente augmente donc réellement les attaques, indépendamment de la courbe de PV.

La Fournaise suit la cible, mais exige encore portée et ligne de vue lors de sa résolution. Rompre cette ligne ou sortir des 2–6 cases annule dégâts et brûlure. Le lanceur ne récupère pas son activation consommée. La correction ciblée de `SpellCaster.resolve_pending_activation()` applique un statut différé uniquement après un impact valide sur une cible encore vivante ; les anciens projectiles sans statut conservent leur comportement.

## IA et placement

Les profils réutilisent les décisions génériques existantes : mêlée pour Sentinelle/Molosse ; distance avec repli pour Rejeton/Lamie. Les cibles, coûts et délais sont revérifiés par `SpellCaster`. Toutes les techniques étant offensives, elles entrent dans la sélection générique de l'IA ; aucune technique de soutien ne reste inutilisable faute de logique dédiée.

La distance minimale de placement vaut `max(5, PM + 3)`, augmentée jusqu'à `portée maximale + 1` pour un tireur. Cela donne 5 cases pour la Sentinelle, 8 pour le Molosse, 7 pour le Rejeton et la Lamie. La distance maximale ajoute 6 cases. Le planificateur conserve ces minimums et les cellules interdites par le décor ; le maximum est une préférence de placement. Les intentions armure/mêlée/vitalité/signature privilégient les lignes, mobilité les flancs, distance/contrôle les groupes séparés. Les cartes fournissent la géométrie réelle : l'indice du catalogue de cartes ne représente pas leur difficulté.

## Intégration dans la descente

`CatabaseMonsterEncounterCatalog.configure_encounter()` est appelé seulement par `ExpeditionRunFactory.make_room()`, avant la copie et la croissance des statistiques. Les ressources de salles sources et les autres runs ne sont pas modifiées.

Le tutoriel à la profondeur 1, l'épreuve du champion de bronze à la profondeur 7, Pâris à la profondeur 20 et les rencontres explicitement marquées `boss` gardent leurs compositions, statistiques et restrictions originales, y compris dans les salles provisoires créées avant le choix d'un nœud. Les autres combats normaux/élites utilisent l'intention tactique enregistrée du nœud, sans adapter la composition à la construction du joueur :

| Intention du nœud (`reward`) | Deux premiers adversaires |
| --- | --- |
| Armure, mêlée | Sentinelle + Rejeton |
| Distance, élémentaire | Rejeton + Molosse |
| Mobilité | Molosse + Lamie ; avant profondeur 5 : Molosse + Rejeton |
| Contrôle, soin, découverte | Lamie + Sentinelle ; avant profondeur 5 : Sentinelle + Rejeton |
| Vitalité | Sentinelle + Molosse |
| Signature | Sentinelle + Lamie |

Les premiers groupes et les reprises après halte aux profondeurs 5, 9, 13 et 17 comportent deux adversaires. À partir de la profondeur 10, les autres combats combinent trois rôles distincts : Molosse si le duo n'en possède pas, sinon Rejeton si absent, sinon Sentinelle. Aucun groupe ne double une Lamie ou une Sentinelle ; les groupes à trois ne doublent aucun rôle. Le plafond vivant correspond exactement au groupe ; aucun budget d'invocation ne subsiste. Le format reste une seule vague par nœud.

### Courbe fixe de PV et de dégâts

`ExpeditionRunFactory` applique les coefficients ci-dessous aux seules copies runtime des quatre monstres. Les élites ajoutent **15 % de PV et 12 % de prouesse**, sans action, PM, résistance ou adversaire supplémentaires. Les techniques, délais et dégâts périodiques restent ceux des ressources de base. Le coefficient provient uniquement de la profondeur et du type de nœud : ni PV actuels, ni équipement, ni talents, ni niveau réel du héros n'entrent dans le calcul.

| Profondeur | PV × | Prouesse × | Groupe | Rythme |
| --- | ---: | ---: | ---: | --- |
| 2 | 0,45 | 0,70 | 2 | Découverte de la garde et du tireur |
| 3 | 0,55 | 0,85 | 2 | Poursuite ou première élite facultative |
| 5 | 0,68 | 0,95 | 2 | Reprise après le camp ; découverte du contrôle |
| 6 | 0,82 | 1,10 | 2 | Pression avant l'épreuve du bronze |
| 9 | 1,05 | 1,35 | 2 | Reprise après l'autel |
| 10 | 1,30 | 1,60 | 3 | Première combinaison de trois rôles |
| 11 | 1,50 | 1,85 | 3 | Point haut avant le bivouac ; bibliothèque facultative |
| 13 | 1,65 | 2,05 | 2 | Reprise sur les terrasses |
| 14 | 1,95 | 2,45 | 3 | Lignes de tir et garde du pont |
| 15 | 2,15 | 2,80 | 3, élite | Épreuve des obélisques |
| 16 | 2,30 | 3,00 | 3, élite facultative | Renoncer à la halte pour le défi |
| 17 | 2,45 | 3,20 | 2 | Reprise dans le jardin |
| 18 | 2,90 | 3,80 | 3 | Dernier effort avant le feu de Pâris |

Les haltes ne donnent pas de combat ni d'XP artificiels. La progression individuelle reste croissante ; la baisse du nombre de corps aux reprises réduit les PV et les actions du groupe. Les rencontres protégées conservent leur ancienne formule `(1 + max(0, profondeur − 5) × 0,07)`, avec ×1,20 pour le champion élite. Aucun identifiant de ressource, de sort, de nœud ou de récompense ne change. Une sauvegarde de frontière reconstruit la rencontre depuis son nœud enregistré avec les nouvelles valeurs ; aucune migration de format n'est nécessaire.

### Groupes et PV concrets par salle

S = Sentinelle, R = Rejeton, M = Molosse, L = Lamie. Les nombres sont les PV runtime arrondis, élite comprise lorsqu'indiquée.

| Étape / salle | Groupe et PV |
| --- | --- |
| 2 — Portique des lances / Éclaireurs | S35 + R19 / R19 + M23 |
| 3 — Guetteurs / Tribut élite | M28 + R23 / S49 + R27 |
| 5 — Gué des serments / Roseaux | L37 + S53 / R29 + M34 |
| 6 — Atrium / Gardiens du foyer | S64 + M41 / R34 + M41 |
| 9 — Cloître / Pas sans retour | L57 + S82 / M53 + L57 |
| 10 — Arches / Chaînes élite | R55 + M65 + S101 / L81 + S117 + M75 |
| 11 — Fosse / Bibliothèque si combat | S117 + M75 + R63 / L81 + S117 + M75 |
| 13 — Orage / Rempart | R69 + M83 / S129 + R69 |
| 14 — Longs traits / Fers croisés élite | R82 + M98 + S152 / S175 + R94 + M112 |
| 15 — Obélisques élite | S193 + L134 + M124 |
| 16 — Défi sans repos si combat élite | S206 + L143 + M132 |
| 17 — Dalles fendues / Garde du jardin | M123 + L132 / S191 + R103 |
| 18 — Derniers noms / Lances noires élite | L157 + S226 + M145 / S260 + R140 + M167 |

### Budget du kit de départ

La référence est Achille sans points d'attributs investis, objets ou talents : Frappe du Péléide = 55 % de prouesse pour 3 PA ; Garde d'airain = 5 % des PV maximum + 25 % de prouesse pour 2 PA. Cette combinaison laisse 1 PA pour la Percée. Le calcul conservateur omet les victoires facultatives des profondeurs 11 et 16. Les dégâts de Frappe passent par le vrai `DamageResolver`, donc incluent les 35 d'armure de la Sentinelle.

| Exemple | Achille PV / prouesse | Frappe / garde | Frappes nécessaires par cible | Volley primaire brut / après garde |
| --- | --- | --- | --- | --- |
| 2, Portique | 135 / 22 | 12 / 12 | S : 4 ; R : 2 | 17 / 5 |
| 10, Chaînes élite | 350 / 57 | 31 / 32 | L : 3 ; S : 6 ; M : 3 | 59 / 27 |
| 18, Lances noires élite, sans XP facultative | 635 / 106 | 58 / 58 | S : 7 ; R : 3 ; M : 3 | 148 / 90 |

Ces budgets sont une hypothèse d'équilibrage vérifiée sur les données, pas une simulation de victoire. Ils comptent les actions offensives, pas la durée totale d'une salle : approche, couverture, choix de cible, attaques à distance et contrôles modifient l'exposition. Le test impose 2–7 Frappes par adversaire, un volley primaire complet au plus égal à 24 % des PV de référence, et au plus 15 % après la garde disponible dès le départ. Les spéciales ajoutent leur pression ponctuelle après leur première activation ; Fournaise demeure annoncée et annulable. Les améliorations choisies par le joueur créent un avantage durable au lieu d'être compensées par les ennemis.

## Vérification

Le flux de production artistique est documenté dans [le README du pipeline](../../tools/catabase_monster_sprite_pipeline/README.md) : vues fixes indépendantes par Meshy, revue des sources et remplacements anatomiques, préparation, articulation locale puis assemblage. La commande distante historique de spritesheets est retirée. Les textures ne sont jamais mises en miroir pour remplacer une direction manquante.

La version 2 anime 48 poses par direction avec des pièces peintes articulées, des appuis de pieds résolus par deux articulations et des gestes propres à chaque espèce. Les occlusions sont reconstruites localement depuis la palette source ; les armes restent solidaires des mains. Les quatre peintures fixes indépendantes de Meshy conservent leur identité graphique. Le détail et les commandes figurent dans le README du pipeline.

Les tests d'intégration se trouvent dans `test/unit/test_catabase_monsters_integration.gd`. Le probe de combat est `tools/catabase_monster_validation/combat_probe.tscn`, piloté par `tools/catabase_monster_validation/combat_probe.gd`. Leur preuve visuelle et runtime est distincte des vérifications de progression ci-dessous.

La suite `test/unit/test_catabase_monster_progression.gd` utilise les vrais nœuds de route, la factory, les grilles, le planificateur de formation et le calcul de mitigation. Elle vérifie toutes les branches des seeds **2401, 42 et 777**, les limites de placement et de groupes, les courbes de PV/attaque, les reprises, le kit canonique sans XP facultative, les rencontres protégées, l'immuabilité des 15 salles et des quatre unités/sorts sources, et la reconstruction des nœuds sérialisés. Les ressources sources restent référencées durant la suite, ce qui empêche un rechargement de masquer une mutation en mémoire.

Commandes exécutées le 8 septembre 2026, depuis la racine du dépôt, avec Godot **4.7.1.stable.official.a13da4feb** et GUT **9.7.1** :

```powershell
./tools/catabase_monster_validation/run_checks.ps1 -GodotPath 'C:/Users/p.montebello/AppData/Local/Temp/dungeon-draft-godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe' -TestPath 'res://test/unit/test_catabase_monster_progression.gd' -ExpectedTestCount 8 -SuiteId progression_v2_verified
./tools/catabase_monster_validation/run_checks.ps1 -GodotPath 'C:/Users/p.montebello/AppData/Local/Temp/dungeon-draft-godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe' -TestPath 'res://test/unit/test_catabase_monster_progression.gd' -ExpectedTestCount 8 -SuiteId progression_v2_final -ImportEvidenceDirectory 'artifacts/catabase_monsters/checks/progression_v2_verified'
```

Résultat final : **Strict PASS, 8 tests / 1 877 assertions, aucune erreur**, 36,42 s pour la suite avec sources conservées en mémoire. L'import frais de la première commande et le processus GUT sortent tous deux à 0 ; la seconde commande réutilise cette preuve après un changement limité au fixture de test. Rapports : `artifacts/catabase_monsters/checks/progression_v2_verified/` et `progression_v2_final/` (artefacts locaux ignorés). Aucune victoire de run complète ou animation nouvelle n'est revendiquée par cette suite de progression.
