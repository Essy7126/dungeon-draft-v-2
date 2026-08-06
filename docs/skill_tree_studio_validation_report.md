# Rapport de validation — Studio des personnages et compétences durci

Date : 6 août 2026
Cible : Godot `4.7.stable.official`, GDScript, GUT `9.7.1`
Base auditée : `94fcdc700cf576a15ee4134d9f3dee680626827a`, branche `main`
Verdict : **PARTIAL**

Le Studio lui-même est fonctionnel, transactionnel et couvert par ses tests ciblés. Le dépôt complet ne peut toutefois pas recevoir un verdict GO : des contrats historiques restent rouges à cause d’un UID invalide dans `Guerrier.tres`, deux tests de progression reflètent une modification concurrente de `eagle_eye.tres`, les variantes de zoom d’éditeur demandées n’étaient pas injectables dans le runner autonome, et les exécutions Godot signalent encore des allocations libérées tardivement.

## Périmètre et conservation du worktree

- Aucun `checkout`, `reset`, `stash`, `clean`, commit, push ou changement de branche n’a été exécuté.
- Les valeurs de production sous `data/units`, `data/characters` et `data/spells` n’ont pas été modifiées par cette mission.
- Le worktree contenait et a continué de recevoir des changements Arena, runtime, salles et progression indépendants. Ils ont été laissés en place.
- `addons/dungeon_draft_arena_studio/plugin.cfg` était déjà modifié par un autre travail. Sa version n’a pas été augmentée : les gates globaux ne sont pas tous verts.
- La modification présente de `data/characters/elf/upgrades/eagle_eye.tres` et la nouvelle Resource `elf_archer_eagle_eye.tres` sont extérieures à cette mission. Elles expliquent les deux divergences de progression finales.

## Inventaire d’autorité

| Domaine | Autorité constatée | Usage dans le Studio |
|---|---|---|
| Sélection et validité d’un chemin | `SkillTreeResolver` | Validation et simulation sans logique parallèle |
| État de progression | `DisciplineProgressState`, `CharacterRunState` | Lecture seulement dans le preview ; aucune écriture de run |
| Exécution des sorts | `SpellCaster`, `Unit`, `GridData`, `Pathfinder`, `TerrainEffects` | Sandbox runtime réel |
| Données éditées | `UnitData`, `DisciplineData`, `DisciplineRankData`, `SkillTreeNodeData`, `Spell`, `SpellModifier` | Working copy isolée |
| Identité et partage | `SkillTreeReferenceIndex` | Index des chemins, IDs, références entrantes, partages et orphelins |
| Propriétés éditables | `SkillTreePropertyRegistry` | Contrat centralisé de type, éditeur et politique de copie |
| Persistance | `SkillTreeSaveTransactionService` | Plan, conflits, staging, manifest, application, reload et rollback |

Le catalogue de production observé contient trois personnages jouables, douze disciplines, douze sorts racines et 216 améliorations. Le profil historique reste explicite dans `production_2026_08_05.tres`; les règles `0/2/4/8/4`, les seuils `0/5/12/21/30` et les seize configurations ne sont plus traités comme une loi universelle pour les nouveaux contenus.

## Baseline avant durcissement

| Gate | Résultat baseline | Observation |
|---|---:|---|
| Import éditeur | code `0` | Alertes UID d’assets ennemis, doublon historique `ItemDefinition`, fuites à la fermeture |
| Test Studio isolé | aucun test exécuté | Erreur d’indentation dans le test historique, corrigée dans le périmètre test |
| Contrat complet | `0/5`, `4488/4493` assertions | Les cinq cas échouaient uniquement sur l’UID invalide de `Guerrier.tres:6` |
| Surfaces Studio partagées | `16/21`, `1080/1085` assertions | UID Guerrier et références historiques des salles du trio fixe |

Les logs de référence sont conservés sous `artifacts/skill_tree_studio/baseline/`.

## Réalisation par phase

### Historique local, isolation et brouillons

- Chaque document possède un `UndoRedo` local, borné à 256 opérations et libéré à la fermeture.
- Ouvrir ou changer de personnage réinitialise l’historique ; aucune opération n’atteint l’historique global de l’éditeur.
- L’état sale dépend d’une empreinte de la working copy. Annuler après sauvegarde redevient sale ; refaire exactement l’état sauvegardé peut le nettoyer.
- Les opérations multi-Resources sont atomiques : duplication, renommage référentiel, création de branche et suppression transitive.
- Les brouillons versionnés sont écrits sous `user://dungeon_draft_studio/skill_tree/drafts/` avec métadonnées. Au redémarrage, l’utilisateur choisit Restaurer, Comparer ou Abandonner ; aucune restauration silencieuse.

### Chemins, copie et sauvegarde transactionnelle

- Les chemins sont réservés avant création et classés `FREE`, `RESERVED_IN_SESSION`, `EXISTS_ON_DISK`, `CACHE_ONLY`, `RECOGNIZED`, `UNSAFE` ou `TYPE_CONFLICT`.
- La détection combine `FileAccess`, `ResourceLoader.exists`, cache ResourceLoader, réservations de session et type de script global.
- La copie préserve l’identité partagée quand elle est intentionnelle. « Rendre unique » ne casse que le partage sélectionné.
- Le plan de sauvegarde typé expose créations, mises à jour, détachements, orphelins, changements de propriétés et conflits externes.
- La transaction crée une récupération et un manifest avant toute écriture, produit une copie de travail et un staging, applique dans l’ordre, recharge sans cache et compare une empreinte profonde.
- Une erreur de manifest, d’écriture ou de reload déclenche le rollback de tous les fichiers déjà touchés. Le document reste sale et le brouillon n’est effacé qu’après succès complet.
- Les conflits externes sont calculés avec un reload profond hors cache ; un fichier supprimé en working copy est explicitement exclu du plan d’écriture et signalé comme détachement/orphelin.

### Références et cycle de vie

- L’index recense Resources, chemins, IDs projet, références entrantes, relations de partage et objets inatteignables.
- Une collision d’ID est vérifiée au niveau du projet, pas seulement du personnage ouvert.
- Détacher, adopter, archiver et supprimer définitivement sont quatre opérations distinctes.
- Archiver ou supprimer crée d’abord une copie récupérable. Une Resource avec références entrantes est refusée.
- La suppression définitive exige la saisie exacte d’un identifiant fort.

### Couverture de propriétés et UX

- L’audit automatisé de toutes les propriétés `PROPERTY_USAGE_STORAGE` des classes de production ne trouve aucune propriété sans contrat d’éditeur.
- Booléens, nombres, chaînes, enums, couleurs, vecteurs, Resources, tableaux typés, dictionnaires de cooldown d’invocation et liste ordonnée de modificateurs permanents sont éditables.
- Le graphe propose layout déterministe par couches, grille, alignement, distribution, copie multiple, relations internes conservées, légende et exclusions orange pointillées.
- `Escape` annule explicitement le geste de connexion actif. Les positions épinglées sont persistées dans l’état UI, pas dans les Resources de gameplay.
- Le catalogue garde les personnages sans discipline. La recherche globale ouvre le bon personnage, la bonne discipline et le bon nœud.
- Les champs en cours d’édition sont commit avant sauvegarde, validation, preview ou changement de document.

### Analyse et preview runtime

- L’énumération des chemins est bornée et retourne durée, limite, nombre visité, résultat exact ou tronqué et raison de troncature.
- La validité d’un nœud est calculée séparément de l’énumération exhaustive des feuilles.
- L’analyse détecte dominance stricte, nœuds incomparables et capstone uniquement numérique comme avertissement.
- Le preview exécute neuf scénarios : défenses 0/25/50/100, allié, cible affaiblie, backstab, cibles multiples et case libre.
- Chaque scénario compare sort de base et chemin sélectionné, puis affiche delta, faits runtime et trace des modificateurs.
- Le sandbox utilise les vraies classes runtime et désactive toute progression : aucune écriture de run ou attribution d’XP.

## Audit des types de modificateurs

| Famille de production | Projection statique | Sandbox `SpellCaster` | Trace explicite |
|---|---:|---:|---:|
| `SpellModRangeBonus` | portée | oui | oui |
| `SpellModAdditionalPush`, `SpellModExactPushDistance` | — | oui | oui |
| `SpellModCollisionDamage` | — | oui | oui |
| `SpellModApplyStatus`, `SpellModNextTurnMovement` | — | oui | oui |
| `SpellModHealBonus`, `SpellModAdditionalShield` | — | oui | oui |
| `SpellModTerrainOnAffectedCells` | — | oui | oui |
| `SpellModAlignedSecondaryTarget` | — | oui | oui |
| `SpellModBackstabDamageBonus`, `SpellModCentralCellDamageBonus`, `SpellModDamageBonusAtMinRange` | — | oui | oui |
| `SpellModSkillTreeEffect`, tous ses `EffectType` | portée/case libre si applicable | oui | oui |

Le test parcourt tous les modificateurs présents sur les disciplines de production de l’Elfe et exige `sandbox=true`, `unsupported=false`. Un test séparé compare de manière déterministe les dégâts de base et modifiés produits par le vrai runtime. Limite connue : la parité numérique exacte n’est pas encore assertée individuellement pour chaque sous-type et chaque scénario déclencheur.

## Résultats finaux reproductibles

| Suite | Résultat | Assertions | Log |
|---|---:|---:|---|
| Import éditeur | code `0` | — | `artifacts/skill_tree_studio/final_import.log` |
| Studio historique isolé | `10/10` | `82/82` | `final_01_studio_isolated.log` |
| Durcissement Studio | `40/40` | `439/439` | `final_02_hardening.log` |
| Resolver, effets et progression | `77/79` | `869/871` | `final_03_runtime_progression.log` |
| Contrat complet | `0/5` | `4488/4493` | `final_04_complete_contract.log` |
| Surfaces Studio partagées | `18/21` | `1080/1083` | `final_05_shared_studio.log` |
| Encounter partagé | `15/15` | `166/166` | `final_06_encounter_shared.log` |
| Matrice visuelle | `51/51` | zéro débordement mesuré | `capture_matrix_rendered_04.log` |
| `git diff --check` | propre après correction | — | contrôle terminal final |

Les 50 tests propres au Studio totalisent 521 assertions vertes. Les échecs globaux restants sont :

1. Cinq échecs inchangés du contrat complet, tous dus à l’UID invalide `uid://0flkpto1jkby` dans `data/units/alliés/Guerrier.tres:6`.
2. Trois échecs de surfaces partagées ayant exactement la même cause.
3. Deux échecs de progression : `eagle_eye.tres` contient désormais deux modificateurs alors que les contrats historiques en attendent un. Ce fichier de production était modifié hors mission.
4. L’import signale aussi des UID d’assets ennemis et le script dupliqué `output/validation-feedback-candidate/data/items/item_definition.gd`; ils sont hors périmètre.

## Validation visuelle

Le runner `SkillTreeStudioCaptureRunner.tscn` a produit les 17 états requis à 1280×720, 1920×1080 et 2560×1440 : ouverture, recherche catalogue, graphe complet, inspecteur général/effets/relations, erreurs, analyse, preview, plan, collision, orphelins, modes guidé/avancé, focus clavier, suppression et brouillon récupérable.

- 51 PNG ont été rendus avec OpenGL Compatibility sur une NVIDIA GeForce RTX 4070 Laptop GPU.
- `capture_metrics.json` rapporte `bad=0`, échelle réelle `1.0`, actions principales visibles et largeur de graphe utile dans chaque capture.
- Les dialogues plan/collision/orphelins sont bornés à 680 px de haut ; leurs actions restent accessibles à 1280×720.
- Le thème réellement exercé est le thème sombre hérité du projet/éditeur.

Artefacts : `artifacts/skill_tree_studio/screenshots/`.

## Risques et écarts restants

- Corriger l’UID du Guerrier et décider si les contrats historiques doivent accepter le second modificateur d’Œil d’aigle nécessite une modification des données de production, explicitement interdite dans cette mission.
- Les échelles d’éditeur 125 % et 150 % ainsi qu’un thème clair n’ont pas été capturés : le runner autonome ne permettait pas d’injecter fidèlement ces réglages. Les trois résolutions et l’échelle réelle sont, elles, validées.
- Les analyses longues exposent leurs limites et durées, mais ne possèdent pas encore de bouton d’annulation coopérative dans l’interface.
- Godot signale encore des `ObjectDB`/RID/resources en usage à la fermeture des runners headless et visuels. Aucun test fonctionnel n’échoue pour cette raison, mais un passage de profilage de cycle de vie reste conseillé.
- La couverture preview garantit qu’aucun type de production n’est déclaré silencieusement non supporté, sans encore fournir une assertion de parité numérique exhaustive pour chaque sous-type.
- Tant que ces points et les gates historiques ne sont pas résolus, ne pas augmenter la version du plugin.

## Commande de reprise

```powershell
& "C:\tmp\godot-4.7-stable\Godot_v4.7-stable_win64_console.exe" `
  --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= `
  -gtest=res://test/unit/test_skill_tree_studio_hardening.gd -gexit
```

## Conclusion

**PARTIAL** — le Studio durci est utilisable et ses gates dédiés sont verts, mais un GO de dépôt ou de publication serait prématuré avant correction des données historiques, alignement des contrats de progression, validation DPI/thème complémentaire et réduction des fuites signalées à la fermeture.
