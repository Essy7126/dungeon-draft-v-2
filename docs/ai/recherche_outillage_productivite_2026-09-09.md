# Outillage Godot et productivité — recherche du 9 septembre 2026

Objectif : réduire les tokens et le temps nécessaires à une tâche réussie, avec les mêmes exigences de validation.

Mise en œuvre ultérieure : voir `tools/dev/README.md` et `docs/ai/outillage_validation_2026-09-09.md` pour l'état installé et les vérifications exécutées.

Cette note repose sur une lecture du dépôt et de sources primaires. Les compatibilités annoncées par les éditeurs ne constituent pas une validation dans Dungeon Draft. Aucun plugin n'a été installé, activé ou testé pendant cette recherche. Aucun gain chiffré n'a été mesuré.

## Ce que le projet possède déjà

- `addons/godot_ai_workbench/` contient une passerelle locale, des commandes d'inspection, des diagnostics et des opérations runtime. Sa version locale déclarée est `0.2.0-dev`. Il n'est pas dans la liste des plugins activés de `project.godot`. La disponibilité du serveur compagnon et sa connexion restent à vérifier.
- Dungeon Draft Studio 2.0 est activé. Son point d'entrée utilise déjà `StudioProjectContext` et `StudioReferenceGraphService`. Il propose des outils d'édition de contenu : réutiliser ces services avant de créer un nouveau catalogue ou un nouvel éditeur.
- GUT `9.7.1` est installé et activé. `tools/ci/run_gut_strict.ps1` produit un rapport structuré et détecte notamment les erreurs moteur, les rapports manquants, les délais dépassés et l'absence de tests.
- Les sondes de monstres et les outils de captures existent. `EventBus` expose des événements d'action et de tour ; `CombatEventFact` offre une base structurée pour les observations de combat.
- `data/spell.gd` utilise déjà les Resources Godot pour les coûts, conditions, effets et références visuelles.
- `.editorconfig` existe, mais ne définit actuellement que l'encodage UTF-8.
- La CI principale déclare Godot `4.7`, tandis que le lanceur strict attend par défaut `4.7.1.stable.official.a13da4feb`. Cet écart est à harmoniser ou à documenter comme matrice de compatibilité ; il ne prouve pas, à lui seul, un échec de CI.

## Plugins et outils comparés

| Candidat | Fonction documentée et compatibilité annoncée | Recommandation pour ce projet |
| --- | --- | --- |
| [Godot AI Workbench](https://github.com/ZemDen/godot-ai-workbench) | Serveur MCP local et addon Godot, Windows 10+, Godot 4.x. Modes `minimal`, `lite`, `3d`, `full` et réponses runtime compactes. | Premier candidat à vérifier, puisque l'addon est présent. Tester un catalogue réduit, puis élargir si une capacité nécessaire manque. |
| [Godot MCP, bradypp](https://github.com/bradypp/godot-mcp) | Serveur Node.js : lancement du moteur, scènes, sortie de debug et opérations de ressources. Support Godot 3.5+/4.0+ annoncé. | Alternative si Workbench ne convient pas. Éviter de cumuler des passerelles couvrant les mêmes opérations. |
| [GDScript Formatter, GDQuest](https://github.com/GDQuest/GDScript-formatter) | Binaire Windows, addon Godot 4, formatage, contrôles de style, mode de vérification et configuration EditorConfig. | Candidat prioritaire pour automatiser les corrections mécaniques. Première évaluation sur quelques fichiers représentatifs. |
| [GDScript Toolkit](https://github.com/Scony/godot-gdscript-toolkit) | Outils Python `gdlint`, `gdformat`, analyseur syntaxique ; branche de paquets 4.x destinée à Godot 4. | Alternative au formateur GDQuest, notamment si ses règles de lint conviennent mieux. Choisir un seul formateur de référence. |
| [GUT](https://github.com/bitwes/Gut) | Tests GDScript ; intégration déjà présente localement. | Conserver et unifier son lancement. Le projet possède déjà une couche stricte de validation adaptée. |
| [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | Tests GDScript/C#, assertions, simulation de dépendances et tests de scènes. Matrice de compatibilité publiée par version. | À comparer seulement si GUT laisse un besoin concret non couvert. Une migration générale n'a pas de bénéfice démontré ici. |
| [just](https://just.systems/man/en/prerequisites.html) | Lanceur de recettes ; Windows pris en charge, avec un shell disponible. PowerShell peut être configuré explicitement. | Option pour partager des commandes locales et CI. Notre lanceur PowerShell peut suffire au départ. |
| [Dialogue Manager 4](https://github.com/nathanhoad/godot_dialogue_manager) | Éditeur et moteur de dialogues à embranchements, Godot 4.6+. | À envisager lorsque les dialogues, conditions et choix narratifs deviennent une charge importante. |
| [LimboAI](https://github.com/limbonaut/limboai) | Arbres de comportement et machines à états. La branche 1.8.x annonce Godot 4.6+ en GDExtension et 4.7 en module. | Prototype isolé seulement si l'édition visuelle des comportements devient nécessaire. L'IA tactique existante doit conserver ses règles de tour. |

### Points à vérifier avant adoption

Workbench présente un catalogue complet de 129 outils dans son README, mais permet de le réduire. L'intérêt pour nos tokens vient des opérations utiles disponibles et du volume effectivement envoyé au modèle. Il faut mesurer ces deux aspects. La version locale et celle du serveur doivent parler le même protocole. La mention générale « Godot 4.x » ne garantit pas le fonctionnement de chaque commande sur notre version exacte. [Source](https://github.com/ZemDen/godot-ai-workbench)

Le formateur GDQuest propose `--check` et `--verify-structure`. Sa documentation précise que la vérification de structure est imparfaite et ne garantit pas l'équivalence sémantique. Conserver la revue du diff et la validation Godot ; commencer sur les fichiers touchés, avec une version de l'outil fixée. [Source](https://github.com/GDQuest/GDScript-formatter)

Les sources consultées décrivent les capacités et, pour plusieurs projets, des matrices de compatibilité ou des distributions. La maintenance future, la qualité de toutes les versions et les gains sur notre jeu ne sont pas établis par cette recherche. Pour une adoption, sélectionner une version publiée précise, examiner ses changements et exécuter un essai représentatif.

## Manière de construire le projet recommandée

### 1. Renforcer les données et les outils de contenu existants

Faire passer l'ajout d'un monstre, sort ou objet par des définitions validées et des composants réutilisables. Une nouvelle mécanique justifie du code ; une variante de coût, de portée ou d'apparence peut rester une donnée. Les Resources Godot apportent typage, sérialisation et fichiers `.tres` adaptés au suivi Git. [Documentation Godot](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html)

Pour Dungeon Draft, le parcours proposé est : définir la ressource dans Studio, vérifier ses références, jouer une rencontre de test, puis inspecter le rapport et le rendu. Relier l'interface Studio et les commandes d'automatisation aux mêmes services pour éviter des règles divergentes.

### 2. Rendre les responsabilités du combat plus faciles à consulter

Lors des prochaines modifications, isoler progressivement les décisions tactiques, la résolution des effets, la progression et la présentation, avec des entrées et sorties explicites. L'organisation des scènes Godot encourage des dépendances maîtrisées. [Documentation Godot](https://docs.godotengine.org/en/4.7/tutorials/best_practices/scene_organization.html)

Appliquer cette évolution à un besoin concret, avec ses tests, plutôt que déplacer tout le dépôt. Le bénéfice recherché est qu'une modification de règle exige la lecture d'un ensemble limité de fichiers. Les contrats de données et les événements existants servent de points d'appui.

### 3. Livrer des fonctionnalités complètes de taille limitée

Une tâche doit avoir un résultat observable : par exemple un nouveau monstre, ses deux capacités, son intégration dans une rencontre et sa validation visuelle. Documenter les critères avant l'implémentation. Cette organisation permet de comparer les approches et réduit les reprises tardives d'intégration.

### 4. Unifier les opérations répétées

Proposer un point d'entrée local pour diagnostiquer l'environnement, exécuter une suite, jouer un scénario et produire des captures. Il délègue aux runners existants. Chaque opération conserve les logs complets, renvoie un résumé structuré et distingue réussite, échec, contrôle ignoré et exécution incomplète.

Les imports et écritures d'assets doivent être coordonnés avec les tests. Les processus graphiques concernés par nos runners sont exécutés en série. Les contrôles globaux exigés par la CI restent en place ; une sélection locale de tests n'en tient pas lieu.

### 5. Conserver des preuves reproductibles

Pour les scénarios de combat, enregistrer version du moteur, version du contenu, modifications locales pertinentes, état initial, état aléatoire nécessaire, actions et assertions. Un seed seul ne garantit pas la reproduction d'un bug. Toute préparation artificielle d'un scénario reste explicite.

Les résultats réutilisés doivent correspondre aux mêmes entrées et dépendances. En cas de doute sur leur fraîcheur, relancer la vérification. Les captures servent aussi à l'inspection humaine ; une différence de pixels ne suffit pas à établir une régression fonctionnelle.

## Ordre de mise en œuvre proposé

1. Définir la version moteur de référence et vérifier les chemins, imports et dépendances avec une commande de diagnostic.
2. Donner un point d'entrée commun aux tests et captures existants, avec un format de résultat compact qui conserve leurs verdicts stricts.
3. Vérifier Workbench sur une scène de test : inspection, diagnostic, capture, erreur et déconnexion ; commencer par un petit catalogue.
4. Évaluer un formateur sur quelques scripts, puis fixer sa version et les règles retenues dans EditorConfig et la CI.
5. Exposer les services utiles de Dungeon Draft Studio aux commandes automatisées, puis ajouter des scénarios reproductibles.
6. Décider séparément des plugins de contenu selon les besoins narratifs ou de conception d'IA.

## Mesurer l'intérêt réel

Comparer des tâches de correction locale, de mécanique de combat et d'interface. Garder d'abord le même modèle et le même effort de raisonnement. Relever tokens d'entrée, de sortie et de raisonnement lorsque disponibles, cache séparément, nombre d'appels, durée, validations et reprises. Les quotas d'un abonnement ne sont pas une mesure directe des tokens.

Retenir une optimisation si elle réduit la consommation totale par tâche validée sans augmenter les erreurs, les corrections supplémentaires ou les contrôles omis. Compter aussi le coût de création et de maintenance de l'outil. Les changements de modèle ou d'effort seront évalués dans une étape distincte.
