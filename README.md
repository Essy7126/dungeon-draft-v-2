# Catabase

[![Godot validation](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/godot-validation.yml/badge.svg)](https://github.com/essy7126/dungeon-draft-v-2/actions/workflows/godot-validation.yml)

Tactique roguelite au tour par tour sur grille, développé avec Godot 4.7,
GDScript et des ressources data-driven.

**Catabase** est le nom public et la seule aventure proposée. Le menu principal présente une entrée des Enfers peinte, animée par shader (caméra lente, brume et braseros), avec réduction des animations. La run historique à trois et le scénario d’essai sont mis de côté ; leurs ressources restent conservées pour les laboratoires et tests. Voir [le menu vivant](docs/design/catabase_main_menu_2026-09-10.md).

La priorité actuelle de travail est **Catabase d’Achille**. La [base de reprise du 5 septembre 2026](docs/ai/REPRISE_PROJET_2026-09-05.md) rassemble la direction artistique, les enseignements Dofus, les évolutions présentes dans le code et le prochain axe VFX. La présentation du trio ci-dessous décrit uniquement l’archive historique.

Le titre propose huit musiques locales, avec **Passage of Time** au premier lancement.
Le panneau **Musique** en bas à droite permet de choisir le morceau et son volume ;
ces préférences sont conservées entre les lancements. Les crédits sont accessibles
dans le jeu et dans [les attributions musicales](assets/audio/title/CREDITS.md).

La [Cour des Sources](docs/maps/greek_drawn_courtyard_v1.md) est une nouvelle map grecque dessinée, construite à partir de l’observation directe de Dofus et jouable avec les dalles et le combat communs. Ouvrir `tools/labs/greek_drawn_arena/GreekDrawnCourtyard.tscn` puis **F6** dans Godot.


La run historique, retirée du parcours public, utilise une équipe fixe : **Elfe**, **Mage** et **Guerrier**.
Chaque personnage commence avec 6 PA, 3 PM, quatre sorts et une progression par
discipline. Les PA et PM reviennent au début du tour ; un cast réussi accorde
une fois 1 XP à la discipline du sort, y compris pour un sort multi-cible.

La ressource de production `data/runs/first_run.tres` contient six salles. La
forêt peinte ouvre la run, les salles historiques 2 à 4 conservent leur ordre,
puis viennent la caldeira et la station orbitale finale. Les trois maps peintes
utilisent le moteur commun `GridData`/`Pathfinder` avec des layouts explicites ;
aucune collision n'est dérivée de leurs pixels.

## Sélection de personnage

Le menu ouvre désormais le [nouvel écran de sélection](docs/design/character_selection_2026-09-05.md) : aperçu du personnage, orientations, animations, statistiques et capacités réelles. Trois apparences d’Achille sont proposées : originale, peinte et Passe-rive ; elles lancent la même aventure Catabase en solo. Le refuge reste accessible depuis cet écran.

Pour le voir directement, ouvrir `ui/selection/CharacterSelectionScreen.tscn` et lancer **F6** dans Godot.

## Catabase : chemin et build recomposable

Dans **Catabase classique**, le départ se prépare dans sept fenêtres illustrées : arme, protection, deux techniques,
relique permanente, relique éphémère, puis récapitulatif. Les vingt objets possèdent
leur propre icône dessinée. À chaque montée de niveau des nouvelles constructions,
une annonce ouvre les caractéristiques, les apprentissages de sorts, puis le butin.
Les points de destin peuvent être conservés ; un objet obtenu peut être équipé depuis
la fenêtre de réception avant de revenir à la carte. La sauvegarde reprend à l'étape
de progression restante, sans répéter les gains.

La progression et le butin sont prioritaires sur l'entrée au carrefour. **Menu →
Caractéristiques** reste accessible après le combat : fiche détaillée (base, bonus,
total, résistances, équipement et effets), répartition des points et bouton pour
reprendre les décisions en attente. La consultation en combat reste en lecture seule.

En Classique, le parcours public suit **Nouvelle partie → sélection d’Achille → cinématique →
[Seuil des Ombres](docs/maps/underworld_threshold_2026-09-10.md) → run**. Dans cette
entrée jouable, on peut marcher entre les trois statues et lire leurs souvenirs ;
franchir la porte ouvre désormais la **préparation des six constructions** : arme,
protection, deux techniques libres, relique permanente et éphémère. Les six départs
sont personnalisables et évoluent par mutations pendant la run. Voir le
[lot jouable et ses règles](docs/design/catabase_first_six_2026-09-13.md).
La reprise rejoint directement la sauvegarde existante.

Le titre propose **Catabase classique** et une **variante Cartes**, avec deux
sauvegardes indépendantes. Une nouvelle partie Cartes utilise maintenant les
**quatre classes : Assassin, Gardien, Arpenteur et Thaumaturge**. L'apparence,
dont Passe-rive, reste indépendante. La préparation choisit cinq techniques
parmi sept cartes d'initiation de la classe, en deux copies chacune : dix cartes au deck,
quatre en main et deux gestes de secours hors pioche. Aucun équipement au départ.

Après les victoires de la variante Classes, le bilan arrive en premier : personnage,
niveau, XP gagnée, oboles et icônes du butin avec quantités et fiches au survol.
Sa fermeture déclenche ensuite l’annonce du niveau gagné, puis les caractéristiques,
maîtrises et spécialisation. Fermer l’annonce laisse un rappel sur la carte ; la
sauvegarde reprend à la décision restante sans répéter les gains ni le bilan fermé.
Les cartes sont des drops aléatoires, affichés avec les objets dans ce bilan et
ajoutés à la réserve : 0–2 sur un combat normal, 0–3 sur un élite, 0–4 sur le boss.
La **Résonance des échos** dépend de la profondeur, du danger et des combats
précédents sans carte ; elle améliore quantité et rareté, sans gain garanti.
Ses facteurs et les chances sont détaillés au survol dans le bilan. Le joueur
modifie ensuite son deck librement. Les cartes d'initiation ne tombent jamais et
ne gagnent pas de puissance avec les maîtrises. Les rares deviennent possibles
au palier 4, les épiques au palier 10 ; les haltes vendent six cartes différentes.

Inventaire, caractéristiques et sorts/deck disposent de fenêtres avec fermeture
par bouton ou Échap. L’inventaire présente Achille, ses six emplacements d’équipement,
le sac filtrable et la fiche d’objet (équiper, retirer, vendre, sertir). Les fenêtres
ouvertes en combat laissent l’arène visible et verrouillent les modifications.
Le reçu reste identique après vente, équipement et rechargement. **Mon deck**
ouvre les cartes, leurs coûts, portées et effets, y compris en consultation
pendant le combat. La liste défile indépendamment de la fiche sélectionnée.
La main affiche des cartes avec titre, illustration, PA, portée, valeur et effet.
Cadre de classe, bandeau de rareté et couleur de rôle distinguent les techniques.
Une fiche apparaît après un court survol (ou au focus clavier),
avec les effets particuliers mis en évidence. Elle laisse la barre de cartes
dégagée et ne capture pas les clics. Le deck reprend cette fiche en dehors de sa grille.
La collection
réunit deck, réserve et six emplacements d'équipement ; les objets ont leurs
icônes, détails, actions d'équipement, vente et sertissage. Les cartes étrangères
reçues pendant la run permettent l'hybridation, avec une maîtrise plafonnée à 2
contre 4 pour la classe principale. Le lot comprend 28 cartes d'initiation et 84 techniques à acquérir, 12
spécialisations, 24 modèles d'équipement en trois paliers et quatre runes.
À partir du palier 5, les rôles ennemis gagnent entraves, attraction, braises,
givre ou invocation annoncée selon leur spécialité. Les nouveaux contrôles ont
des recharges ; la stase nécessite une marque et protège ensuite la cible contre
les répétitions. [Règles et vérifications de cet écosystème](docs/ai/CARDS_ECOSYSTEM_2026-09-20.md).

Les parties de l'itération à trois propositions adoptent les drops à la reprise,
y compris une récompense encore en attente, sans toucher aux objets déjà acquis.
Les sauvegardes antérieures à cet écosystème gardent leur économie historique.
Voir les [règles de Résonance et de drop](docs/ai/CARD_DROPS_2026-09-20.md), les [règles jouables, budgets et extension
du système](docs/design/class_run_rules_v3.md) et la [validation de l'intégration](docs/ai/CLASS_RUN_IMPLEMENTATION_2026-09-19.md).
Un [contrôle de puissance sur 18 runs automatiques](docs/design/class_balance_readability_audit_2026-09-19.md)
documente l'avantage observé de la distance et les limites de cette mesure.
La route actuelle comporte vingt profondeurs, douze combats
et trois refuges. Le retrait de l'ancien prototype du 12 septembre est un état
historique, pas la description de cette nouvelle variante. Voir le
[contrat Cartes](docs/ai/CARDS_RUN_IMPLEMENTATION_NOTES.md) et
[l'itération après audit](docs/ai/CARDS_ITERATION_2026-09-16.md).

La main Cartes est intégrée à la barre de combat commune, avec cadres dessinés
bronze/émeraude et bascule Cartes/Objets. La collection et le butin reprennent
ce traitement. [Présentation, tests et captures](docs/ai/CARDS_VISUAL_ITERATION_2026-09-16.md).

Les cartes de classes, équipements, runes et reliques utilisent désormais une
[série de 112 illustrations peintes](assets/catabase/class_icons_painted_v1/README.md),
partagée entre préparation, combat, butin et inventaire. Les cases vides ont des
silhouettes neutres ; la sélection, l'état équipé et le palier restent indiqués
par l'interface. Le deck agrandit les illustrations, et l'inventaire sépare
personnage, sac et fiche d'objet. [Audit et vérifications](docs/ai/PAINTED_INTERFACE_AUDIT_2026-09-20.md).

Les combats peints intègrent les effets doux des quatre techniques de départ,
les pas, impacts ennemis, soins, boucliers et esquives, avec une harpe discrète.
Le sac, le grimoire, les récompenses et les interactions des haltes disposent
aussi de retours sonores courts aux aigus adoucis.
Le Seuil des Ombres et les combats peints ajoutent une caverne suspendue : souffle
grave, eau lointaine et longues respirations de volume, sur un bus d’ambiance
séparé. La boucle locale de 109 secondes entre progressivement ; elle respecte
la pause et la coupure des sons au Seuil. [Source et adaptation](assets/audio/catabase/ambience/CREDITS.md).
Musique : **Soft Mysterious Harp Loop**, **VWolfdog (Jordy Hake)**,
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/),
[source](https://opengameart.org/content/soft-mysterious-harp-loop) ; vitesse/hauteur,
aigus et niveau adaptés. [Crédits audio et licences](assets/audio/catabase/CREDITS.md).

Dix nouvelles arènes complètent les cinq historiques ; les haltes proposent des
zones de commerce, de récupération, de lore et de découverte de branches.

La carte sur parchemin s'ouvre aussi pendant le combat avec son icône à côté de
l'inventaire ou la touche **C**. Le kit se recompose entre les rencontres.
La [référence V3](docs/design/achilles/catabase_run_recomposable_v3.md), les
[doctrines et équipements](docs/design/achilles/catabase_build_doctrines_equipment.md),
la [pipeline des maps](docs/maps/catabase_expansion_v1.md) et les
[commandes de validation](tests/expedition/README.md) décrivent le contenu et ses limites.

L’[audit du parcours v4](docs/maps/catabase_route_audit_2026-09-11.md) relie les vingt
étapes, les embranchements, les quinze maps et les décors des haltes. Il distingue
les affectations actuelles des points de cohérence à arbitrer avant de construire
de nouveaux lieux ; c’est un instantané de conception daté.

L’[Explorateur de run](tools/run_explorer/README.md) affiche le parcours complet,
le décor de chaque destination et sa rencontre. Ouvrir
`tools/run_explorer/RunExplorer.tscn` avec **F6**, ou lancer
`./tools/run_explorer/explorer.ps1`. Les boutons permettent de jouer une destination
dans une session de laboratoire isolée ou d'examiner le rendu sans combat.
Les [dispositions par destination](docs/maps/catabase_route_layouts_2026-09-11.md)
différencient désormais 36 arènes de branches ; le bouton **Décor / dalles**
permet de comparer leurs sols tout en conservant les peintures actuelles.

Au [Seuil de Catabase](hub/seuil_crossroads/README.md), la première victoire
laisse place à l'exploration du décor : la barque, la porte ronde et le puits
mènent aux trois branches de l'étape II. Le bouton **Après le combat** de
l'explorateur permet d'essayer directement ces interactions.

L'[habillage peint Meshy](docs/design/achilles/catabase_meshy_ui_v1.md) complète les
sorts, équipements, marqueurs et menus. L'inventaire conserve ses actions visibles,
les kits de quatre à six sorts tiennent dans le HUD, et les retours visuels au clic
respectent l'option de réduction des animations.

Le bouton **Explorer les maîtrises** ouvre le [grimoire des sorts](docs/design/spell_codex_2026-09-05.md) du héros et du sort sélectionnés : recherche, filtre des choix prêts, arbre et fiche détaillée. Le même écran reste accessible depuis le HUD pendant la run.

## Lancer les tests

L'[atelier de sprites](tools/sprite_workshop/README.md) compare les clips avec
leurs références, permet de remplacer les dessins, régler les poses et exporter
une revue traçable. Ouvrir `tools/sprite_workshop/SpriteWorkshop.tscn` puis **F6**,
ou lancer `./tools/sprite_workshop/workshop.ps1 open`.

Le [dossier Spine et sa fiche de reprise locale](docs/spine/README.md) rassemble
les recherches, connecteurs MCP, références de mouvement et prochains essais.
Lire cette fiche pour reprendre le travail d'animation dans une autre tâche.

L'[atelier des haltes peintes](tools/halt_workshop/README.md) prépare des maps dans
une même direction artistique avec navigation, eau, feu et atmosphère paramétrés.
Son mode **Haltes peintes** est intégré au Studio avec plan spatial, calibration visuelle et essai de la copie de travail. Le sanctuaire émeraude et la forge sèche partagent les interactions de Catabase à l’étape VIII. Le sanctuaire est aussi jouable en visite isolée dans `hub/painted_halt/LivingHalt.tscn`
(**F6**) ou avec `./tools/halt_workshop/halt.ps1 open`.

Le [pilote Atelier du Bronze](docs/maps/bronze_workshop_pilot_2026-09-10.md) teste
la création de map depuis une maquette Blender métrique, avec proportions d’Achille,
peinture guidée et calques Krita. Ouvrir `tools/labs/bronze_workshop_pilot/BronzeWorkshopPilot.tscn`
puis **F6** pour visiter ce petit atelier.

Le [lanceur de développement](tools/dev/README.md) regroupe diagnostic, tests,
inspection des ressources, formatage et captures avec des rapports compacts :
`./dev.ps1 help` (PowerShell 7.2+). La version moteur de référence est Godot 4.7.1.

Les tests unitaires utilisent [GUT](https://github.com/bitwes/Gut)
(installé dans `addons/gut/`, tests dans `test/unit/`).

Dans l'éditeur : activer le plugin GUT puis utiliser le panneau **GUT**.

En ligne de commande (headless) :

```bash
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit -ginclude_subdirs -gprefix=test_ -gexit
```

La CI bloquante (`.github/workflows/godot-validation.yml`) s’exécute sur chaque
push et pull request. Elle vérifie l’import Godot, les contrats explicites des
éditeurs actuels, la suite GUT globale avec son allowlist historique, la
portabilité des chemins du code des éditeurs audités, l’absence de mutation du
worktree par la suite GUT globale et les smokes Terrain/Rencontres/Objets. Le
workflow historique `.github/workflows/ci.yml` reste uniquement lançable à la
demande.
