# Run Content Isolation Migration

Date : 2026-08-06  
Branche : `main`  
HEAD migré : `bf2d6f7a8b6dabf2c8b74c5743852475f7c84e0a`

## Résultat

Les deux runs officielles portent maintenant une autorité de contenu explicite :

- `res://data/runs/first_run.tres` →
  `res://data/runs/profiles/main_content_profile.tres` ;
- `res://data/runs/fixed_trio_prototype_run.tres` →
  `res://data/runs/profiles/test_content_profile.tres`.

Chaque profil contient, dans l’ordre Elfe, Mage, Guerrier, un `RunHeroProfile`
qui partage le `UnitData` de base et référence un
`CharacterProgressionProfile` propre à la run.

Les profils principaux sous `data/runs/progression/main/` référencent les
Resources de production historiques. Les profils test sous
`data/runs/progression/test/` embarquent leurs propres copies de tout le graphe
mutable : 12 sorts, 12 disciplines, 60 rangs, 216 nœuds, 263 modificateurs et
les Resources mutables atteignables de statut/terrain. Les valeurs, IDs, ordres,
prérequis et exclusions n’ont pas été rééquilibrés.

## Transaction exécutée

`RunContentMigrationService.migrate_official_runs()` applique l’ordre suivant :

1. charge et valide les trois `UnitData` historiques ;
2. construit les profils principaux en mémoire ;
3. clone les progressions test par inventaire, allocation, mapping et remappage ;
4. sauvegarde les six profils dans un staging unique sous `user://` ;
5. recharge et compare chaque fingerprint sémantique ;
6. sauvegarde et recharge les deux profils de contenu staged ;
7. audite le staging et exige `progression_shared_count == 0` ;
8. copie toutes les cibles existantes vers un backup unique sous `user://` ;
9. reconstruit des Resources fraîches pour garantir l’absence de chemin
   `user://` dans la production ;
10. sauvegarde les six enfants sous `res://`, puis les deux parents ;
11. modifie et sauvegarde les deux `RunData` en dernier ;
12. recharge les runs, exécute l’audit final et écrit le manifeste.

En cas d’erreur après les backups, seules les nouvelles cibles de la tentative
sont supprimées et les fichiers existants sont recopiés depuis le backup. Les
Resources historiques de progression ne sont jamais sauvegardées par le
cloneur.

Le runner reproductible est
`res://tools/migrate_run_content_isolation.gd`. Deux passages successifs ont
retourné `ok: true`, les mêmes fingerprints et zéro conflit ; le second passage
n’a créé aucune nouvelle cible.

## Fingerprints de migration

| Héros | Main staged/production | Test staged/production | Resources par graphe |
|---|---|---|---:|
| Elfe | `6c118ef0534c6d3fb902e829cc0758e4122d589c363cd0dbca845e35aa12a5a1` | identique | 191 |
| Mage | `74d907d9bf101fa76de41a45070406c7493f13d5dc1ea010e4afe51df49343a7` | identique | 194 |
| Guerrier | `b29560e886e961e43c599430a14c0163ec0910aa3dccb593bd62815c2c21f6a6` | identique | 187 |

L’égalité sémantique initiale est intentionnelle : le contenu test démarre avec
le même équilibrage. L’isolation physique est prouvée séparément par l’absence
d’identité/path mutable commun et par les tests de mutation réciproque.

Le manifeste déterministe complet se trouve dans
`res://data/runs/profiles/run_content_isolation_manifest.json`.

## Créer une copie spécifique à une run

Le chemin métier minimal pour un futur Studio est :

```gdscript
var source := RunContentCatalogService.progression_profile_for(run_data, &"elf")
var result := RunContentCatalogService.create_run_specific_copy(
	base_unit_data,
	source,
	"res://data/runs/progression/my_run/elf_progression_profile.tres",
	&"my_run",
)
if not result.is_valid():
	push_error(result.errors)
	return
var saved := RunProgressionCloneService.save_reload_and_compare(
	result,
	"res://data/runs/progression/my_run/elf_progression_profile.tres",
)
```

Après `saved.ok`, créer un `RunHeroProfile`, l’ajouter à un
`RunContentProfile`, sauvegarder le parent, puis seulement assigner ce parent à
`RunData.content_profile`. Un Studio ne doit jamais assigner directement un
sort ou une discipline provenant d’une autre run sans repasser par le cloneur
et l’audit.

## Compatibilité legacy

Les `RunData` sans profil restent chargeables. `RunHeroResolver` utilise alors
le trio historique avec un avertissement explicite. Les deux runs officielles
sont migrées et leurs tests imposent `used_legacy_fallback == false`.

`start_preconfigured_run(run_data, hero_sources)` et
`start_direct_encounter_test(run_data, hero_sources)` restent prioritaires :
une injection explicite ne consulte pas le profil de la run.
