# Run Content Isolation Contract

Date d'audit initial : 2026-08-06  
Depot observe : `C:\Users\paolo\Documents\dungeon-draft-v-2`  
Branche : `main`  
HEAD initial : `bf2d6f7a8b6dabf2c8b74c5743852475f7c84e0a`  
`origin/main` : `bf2d6f7a8b6dabf2c8b74c5743852475f7c84e0a`  
Godot : `4.7.stable.official.5b4e0cb0f`  
GUT : `9.7.1`

## Contrat de verite initial

**OBSERVE** — Le depot etait propre avant toute ecriture : aucun fichier suivi
modifie, staged, non suivi ou en conflit, et aucun diff initial. La run
principale est `res://data/runs/first_run.tres`; la run de test est
`res://data/runs/fixed_trio_prototype_run.tres`.

**OBSERVE** — Le gate officiel `test_run_flow_isolation.gd` passe 22/22 avec
224 assertions. Les `RoomData` et les modes `SINGLE_ENCOUNTER` /
`WAVE_CHAIN` sont distincts. Ce gate ne couvre pas l'autorite du contenu
heroique.

**OBSERVE** — Avant cette migration, `RunData` ne reference aucun contenu de
heros. `GameManager.start_run()` appelle `start_preconfigured_run()` avec
`PRODUCTION_HERO_DATA_PATHS`. La cinematique charge egalement ses trois chemins
exportes puis appelle `start_preconfigured_run()`. Le hub choisit une `RunData`,
mais `LanternboundArchivistData.hero_sources` reste une liste globale partagee.

**OBSERVE** — Les trois `UnitData` historiques portent a la fois la base du
personnage et sa progression : `active_spell_slots`, `spells` et
`disciplines`. Ces derniers atteignent `Spell`, `DisciplineData`,
`DisciplineRankData`, `SkillUpgradeData`, `SkillTreeNodeData`, `SpellModifier`,
ainsi que des `StatusData` et `TerrainEffectData` mutables.

**OBSERVE** — `Unit.from_data()` et `CharacterRunState.initialize()` consomment
le `UnitData` recu. `SkillTreeResolver` et `CharacterProgressionService`
resolvent ensuite les IDs stables contenus dans ce graphe. Les relations de
prerequis et d'exclusion sont stockees par ID, pas par pointeur de ressource.

**OBSERVE** — `SkillTreeEditSession.open(UnitData)` cree deja une vue de travail
par `SkillTreeCopyService`. `SkillTreeSnapshotService.storage_fingerprint()` et
les services de sauvegarde/rechargement fournissent les primitives historiques
de comparaison et de transaction.

**HISTORIQUE** — Le probe controle precedent, sur le meme HEAD, a demontre que
les deux runs recevaient les memes 12 fingerprints de disciplines et que la
fixture test n'atteignait pas le runtime sans injection manuelle. Il reste une
baseline, pas une preuve post-migration.

**DIVERGENCE** — `docs/ai/CURRENT_STATE.md` se declare non courant et reference
encore le HEAD `94fcdc7`, alors que le checkout audite est `bf2d6f7`. Il ne doit
etre actualise qu'apres les gates finaux.

**INCONNU** — Le comportement de la suite globale et des Studios apres migration
reste non verifie au stade de ce contrat. Il sera consigne dans
`RUN_CONTENT_ISOLATION_VALIDATION.md` apres execution reelle.

## Autorite et chemin runtime retenus

**DECISION VALIDEE** — Une seule architecture fait autorite :

```text
RunData
  -> RunContentProfile
      -> RunHeroProfile
          -> base_unit_data (partage intentionnel)
          -> CharacterProgressionProfile (propre a la run)
```

`RunData.content_profile` devient l'autorite du chemin normal :

```text
Hub -> RunData -> GameManager.start_run()
    -> RunHeroResolver -> copies UnitData runtime
    -> GameManager._prepare_preconfigured_run()
```

La cinematique transmet la `RunData` selectionnee et n'impose plus de trio
global aux runs migrees. `hero_sources` reste seulement une donnee legacy.

## Partage autorise et isolation obligatoire

**DECISION VALIDEE** — La whitelist de partage est explicite : `UnitData` de
base, `Texture2D`, `SpriteFrames`, `PackedScene`, `AudioStream`, `Font`,
`Material`, `Mesh`, `Shader` et `Script`. Ces objets portent la base ou des
assets visuels/immutables et peuvent etre partages intentionnellement.

**DECISION VALIDEE** — Sont propres a chaque progression :
`CharacterProgressionProfile`, `Spell`, `DisciplineData`,
`DisciplineRankData`, `SkillUpgradeData`/`SkillTreeNodeData`, `SpellModifier`
et toute autre `Resource` mutable atteignable, notamment `StatusData` et
`TerrainEffectData`. Toute ressource partagee hors whitelist est une erreur.

La progression principale peut referencer les fichiers historiques. La
progression test est un graphe clone, sauvegarde sous
`res://data/runs/progression/test/`, dont aucune ressource mutable interdite
n'est commune au graphe principal.

## APIs explicites preservees

**DECISION VALIDEE** — `start_preconfigured_run(run_data, hero_sources)` et
`start_direct_encounter_test(run_data, hero_sources)` restent des chemins
d'injection prioritaires pour les tests, fixtures et outils. Seul
`start_run(run_data)` resout automatiquement le contenu depuis `RunData`.

Une `RunData` legacy sans profil conserve temporairement le trio historique et
emet un avertissement de migration. Les deux runs officielles ne doivent jamais
emprunter ce fallback.

## Invariants

- ordre runtime stable : Elfe (`elf`), Mage (`mage`), Guerrier (`warrior`);
- exactement trois profils officiels, sans doublon et avec IDs compatibles avec
  `base_unit_data.get_effective_unit_id()`;
- memes statistiques, equipe, apparence, scenes et presentation qu'avant;
- memes IDs, ordre des sorts, disciplines, rangs et choix;
- memes prerequis, exclusions, cibles de sorts et comportement runtime;
- aucune mutation d'une ressource canonique pendant la resolution;
- copie runtime non sauvegardee du `UnitData`, avec remplacement limite a
  `spells`, `disciplines` et `active_spell_slots`;
- aucun chemin Windows absolu serialise;
- aucune reference de progression interdite partagee entre les profils
  officiels.

## Strategie de clonage et migration

**DECISION VALIDEE** — `RunProgressionCloneService` utilise plusieurs passes :
inventaire deterministe, creation des clones sans relations, mapping source vers
clone, remappage recursif des proprietes de stockage, validation de whitelist,
sauvegarde, rechargement et comparaison de fingerprint. `duplicate(true)` seul
n'est pas considere comme une preuve d'isolation.

**DECISION VALIDEE** — La migration construit d'abord les six
`CharacterProgressionProfile`, puis les deux `RunContentProfile`, et modifie en
dernier les deux `RunData`. Elle valide une copie sous `user://` avant les
ecritures `res://`, sauvegarde enfants avant parents, recharge chaque niveau et
restaure les backups si une etape echoue.

Chemins cibles :

- `res://data/runs/progression/main/*_progression_profile.tres`;
- `res://data/runs/progression/test/*_progression_profile.tres`;
- `res://data/runs/profiles/main_content_profile.tres`;
- `res://data/runs/profiles/test_content_profile.tres`.

**RECOMMANDATION** — Les futurs Studios doivent demander les documents via
`RunContentCatalogService` et ne jamais reconstruire une autorite concurrente a
partir de recherches globales de `UnitData`.

## Fichiers inspectes avant implementation

Inspection directe ou recherche structurelle : `data/runs/run_data.gd`, les
deux runs officielles et leurs ressources de salles,
`hub/lanternbound_archivist_data.gd`, `hub/data/lanternbound_archivist.tres`,
`hub/start_hub_controller.gd`, `cinematics/intro/intro_cinematic.gd`,
`core/game_manager.gd`, `data/unit_data.gd`, `units/unit.gd`, les classes de
sort/discipline/rang/noeud/modificateur/statut/terrain, les services de
progression runtime, les services Skill Tree de copie/catalogue/snapshot/
sauvegarde/session, et les tests de run, trio, hub, cinematic, progression et
Skill Tree inventories dans `test/unit/`.
