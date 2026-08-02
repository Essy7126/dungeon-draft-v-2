# Résultats des validations

Environnement : Godot `4.7.stable.official.5b4e0cb0f`, exécutable `C:\tmp\godot-4.7-stable\Godot_v4.7-stable_win64_console.exe`, Windows/PowerShell.

## Caractérisation avant nettoyage

- GUT complet : 48 scripts, 420 tests, 412 succès, 8 échecs, 6 730 assertions réussies sur 6 752.
- Les échecs observés concernaient notamment le modifier Elfe « Lame venimeuse » et des scénarios de hub/pause déjà présents. Le temps et la ligne de commande complète n'ont pas été persistés dans un artefact durable; cette limite est conservée explicitement plutôt que de reconstruire une commande prétendument exacte.

## Validation finale GUT

Commande exacte :

```powershell
& 'C:\tmp\godot-4.7-stable\Godot_v4.7-stable_win64_console.exe' --headless --log-file 'C:\Users\paolo\Documents\dungeon-draft-v-2\docs\audits\project_cleanup\gut_current.log' --path 'C:\Users\paolo\Documents\dungeon-draft-v-2' -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gprefix=test_ -gexit
```

- Statut : succès, code de sortie 0.
- Durée GUT : 22,318 s; durée murale observée : 26,7 s.
- Scripts : 39.
- Tests : 335.
- Succès : 335.
- Échecs : 0.
- Assertions : 29 097.
- Nouveaux échecs : 0.
- Deux messages `ERROR` sont volontairement produits par des tests négatifs de validation d'identifiants (doublon Elfe et identifiant non assigné); ils sont attendus et le runner termine avec le code 0.

La suite couvre les statistiques, `DamageResolver`, les PA/PM, les casts, la progression, les transitions, les trois personnages, les salles conservées et les contrats techniques ajoutés dans `res://test/unit/test_combat_contracts.gd`.

## Import Godot final

Commande exacte :

```powershell
& 'C:\tmp\godot-4.7-stable\Godot_v4.7-stable_win64_console.exe' --headless --editor --quit --path 'C:\Users\paolo\Documents\dungeon-draft-v-2'
```

- Statut : succès, code de sortie 0.
- Durée murale : 6,9 s.
- Ressource manquante ou erreur de parsing : aucune.

## Démarrage de la scène principale

Commande exacte :

```powershell
& 'C:\tmp\godot-4.7-stable\Godot_v4.7-stable_win64_console.exe' --headless --path 'C:\Users\paolo\Documents\dungeon-draft-v-2' --quit-after 5
```

- Statut : succès, code de sortie 0.
- Durée murale : 1,8 s.
- Le menu principal se charge.
- Avertissement à l'arrêt forcé : deux instances ObjectDB et une ressource encore en usage. Aucun crash ni échec de chargement.

## Références et format du diff

Commandes exactes :

```powershell
node .codex_validate_refs.mjs
git -c safe.directory=C:/Users/paolo/Documents/dungeon-draft-v-2 diff --check
```

- Scanner de références : `MISSING 0`. Cinq chemins volontairement absents utilisés par des tests négatifs `FileAccess` sont explicitement ignorés.
- `git diff --check` : succès, code de sortie 0, aucune sortie.
