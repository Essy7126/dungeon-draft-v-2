# Cartes V2 — intégration

Demande : « Ok on mets ça en place ». Contrat : `docs/design/cartes_refonte_v2_2026-09-26/`.
Base vérifiée : `c6ab5a72c1789e4cc285300c9bbae9c78524fa05`, 26 septembre 2026.
Les modifications locales des autres travaux de sélection, sprites, audio et VFX sont conservées.

## Décisions et état

- Profil explicite `catabase_cards_consumable_v2`, sauvegarde indépendante et contenu `2.0.0-design.1`.
- Runtime jouable : 48 familles, 4 classes / 8 spécialisations, progression, économie, 12 combats / 20 profondeurs, 5 mécanismes et Pâris en deux phases.
- Chaque commande résout sur un état détaché, valide, écrit atomiquement puis publie. Reprise entre acteurs et sur choix en attente ; reçus exact-once.
- Grille, Pathfinder, SpellCaster, Unit, DamageResolver, EnemyAI, TerrainEffects et services Studio réutilisés. Hooks communs activés explicitement pour V2.
- Sept ArenaDefinition et 26 objets publiés via ArenaSerializer et ItemTransactionalSaveService ; ItemCatalog dédié, copie/fingerprint/undo compatibles.
- Menu : option explicite Cartes V2. Classique et Cartes historique conservent leurs fichiers. Pas de bascule par défaut avant réception humaine.
- UI dédiée : départ, préparation paginée, ouverture, suivi, progression, équipement, marchand, parcours, combat, prévision et bilan. Apparences existantes, pas encore toute la mise en scène du combat historique.
- Chronique de découvertes / 20 derniers bilans, sans transfert de puissance. Santé proportionnelle conservée sans accumulation d'arrondis lors des changements d'équipement.

## Fichiers

- `core/expedition/consumable_*` : catalogue, profil, état, math, sorts/modificateur, effets, tours, terrain, économie, rencontres, combat, commandes, checkpoints et contenu.
- `data/cards/consumable_v2/` : manifeste et ressources Studio.
- `ui/expedition/consumable_cards_*`, `ConsumableCardsScreen.tscn` : présentation.
- `core/game_manager.gd`, `ui/titre_ecran.gd`, branche initiale de `ui/selection/character_selection_screen.gd` : entrée / reprise.
- Moteur commun : opt-in dans `catabase_cards`, `cast_context`, `spell_caster`, `spell_modifier`, `damage_resolver`, `unit` ; géométrie commune des salles dans `card_tactical_room_rules`.
- Studio Objets : sous-type V2 dans copie, validation, fingerprint et restauration d'historique.
- `test/unit/test_consumable_cards_*.gd`, suite `consumable-v2` incluse dans cards/catabase/all.
- `tools/consumable_cards/` : publication et captures reproductibles.
- Guide : `docs/current/cards_v2.md`.

## Preuves exécutées

- Doctor : Godot 4.7.1 et GUT 9.7.1. Ce contrôle seul ne valide pas l'import.
- Première exécution `artifacts/dev/20260926-154402-test-consumable-v2-774df276` : **38 tests, 1389 assertions, succès**. Historique, remplacée par les exécutions d’audit ci-dessous.
- `artifacts/consumable_cards_v2/content_publication.json` : 7 maps, 26 objets, aucune erreur de publication. Les 26 fuites ObjectDB de la première publication ont disparu après libération explicite des UndoRedo, vérifiée lors de l’audit.
- Captures moteur `artifacts/consumable_cards_v2/01_departure.png` à `07_market.png`, plus variantes `_720` : compression de libellés, barres PV et cadrage corrigés ; nouvelles captures inspectées pendant l’audit.
- Audit CI de contenu : 7 tests Python réussis ; audit des références sérialisées, 12202 fichiers, zéro ressource externe manquante (`resources.json`). Ce résultat ne couvre pas tous les chemins construits.
- Suite globale `artifacts/dev/20260926-155430-test-all-b864d248` : 3144 tests, 262552 assertions, 166 tests en échec et plantage à la fermeture (-1073741819). Aucun échec V2. Comparaison au rapport de 14:38 : 169 → 166 échecs, aucune nouvelle identité, trois anciens échecs Studio résolus. Cela ne valide pas la gate globale : l'allowlist en attend huit, et la fermeture a planté. Détails : `artifacts/consumable_cards_v2/global_comparison.json` et `allowlist.log`.

Le parcours automatique des vingt profondeurs utilise des ennemis affaiblis et des soins de fixture. Il prouve les transitions et les reprises, **pas l'équilibrage ni un taux de victoire**. Le premier combat a aussi un scénario conservant ses PV normaux.

## Suite de cette tâche

Audit demandé ensuite : [rapport d’intégration](../audits/cards_v2_integration_2026-09-26.md).

- Quatre défauts corrigés : classification de l’absorption, remise à zéro entre combats,
  identité unique des runs et coûts/portées affichés en combat.
- Trois fixtures corrigées ; aucune règle assouplie pour faire passer leurs tests.
- `20260926-222704-test-consumable-v2-26b70495` : **49 tests / 2624 assertions, PASS**.
- `20260926-223039-test-cards-259adf66` : **166 tests / 14092 assertions, PASS**,
  dont 50 tests V2. Inclut un test supplémentaire du départ/remplacement et de
  conservation des fichiers des autres profils, et la parité des objets publiés.
- Publication rejouée : 7 maps / 26 objets, zéro erreur et plus de fuite UndoRedo
  signalée. Captures réalisées aux deux résolutions ; départ, préparation, combat,
  prévision, dossier et marchand inspectés.
- Nouvel audit des ressources : 12210 fichiers, zéro référence sérialisée manquante.
- Smoke Rencontre réussi. Smoke Terrain headless sans image ; reprise graphique
  avec cinq captures et sortie 0, mais fuites/erreurs de ressources à la fermeture.
  Smoke Objets historique en échec sur une fixture warrior et une
  sélection sans métadonnées. Analyse générique du Studio non adaptée aux objets V2.
- Contrats Studio `20260926-223513-test-studio-758187c7` : **494/522 tests réussis**,
  28 en échec, tous déjà présents dans le dernier rapport global. Pas de timeout
  ni crash ; erreurs moteur et fuites maintiennent le verdict FAIL.
- Départ/reprise via GameManager dans un APPDATA isolé : **PASS**, état conservé,
  phase ennemie poursuivie et deux fichiers historiques inchangés.
- Empreintes : **65 fichiers V2 inchangés** après tests Cartes/Studio ; cela ne
  certifie pas l’absence de mutation dans tout l’arbre partagé. Diff vérifié.
- Rapport d’audit complété ; HEAD revérifiée et inchangée à la fin des contrôles.
- Réception humaine et calibration restent nécessaires ; aucune validation humaine inventée.

- Portabilité : aucun chemin local dans les nouveaux fichiers V2 ; la gate du dépôt relève 17 chemins de provenance VFX déjà présents dans un fichier non modifié par cette tâche. Versions Studio 2.0.0 conservées, diff suivi sans erreur d’espacement.
- Formateur 0.25.0 : contrôle structurel tenté sur les seuls nouveaux scripts, refus de transformation sur des expressions complexes. Aucun contournement du garde-fou ; le formatage intégral n’est pas déclaré validé.

