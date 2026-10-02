# Installation LAN après fusion

Cette procédure ne doit être exécutée qu’après fusion de la PR V1.2 dans
`origin/main`. Elle n’installe aucun runner GitHub Actions.

Depuis le dépôt principal propre :

```powershell
git fetch origin main --prune
$v12Commit = git log -1 --format=%H -- tools/observatory/live/Install-ObservatoryLan.ps1
git merge-base --is-ancestor $v12Commit origin/main
if ($LASTEXITCODE -ne 0) { throw 'Observatory V1.2 n’est pas encore dans origin/main.' }

powershell.exe `
  -NoProfile `
  -ExecutionPolicy Bypass `
  -File .\tools\observatory\live\Install-ObservatoryLan.ps1 `
  -RepositoryRoot 'C:\Users\paolo\Documents\dungeon-draft-v-2' `
  -GodotPath 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' `
  -Port 8080 `
  -PollMinutes 5 `
  -ConfigureFirewall
```

Sans terminal administrateur, l’installation continue et affiche
`FIREWALL_CONFIGURATION_PENDING` avec la commande exacte à exécuter en
administrateur. Elle ne tente aucune élévation silencieuse.

Vérification :

```powershell
.\tools\observatory\live\Get-ObservatoryStatus.ps1
Invoke-RestMethod http://127.0.0.1:8080/__observatory/healthz
```

Rollback et désinstallation :

```powershell
.\tools\observatory\live\Rollback-Observatory.ps1 -ListOnly
.\tools\observatory\live\Rollback-Observatory.ps1
.\tools\observatory\live\Uninstall-ObservatoryLan.ps1 -RemoveFirewall
```

Les releases restent conservées. Ajouter `-RemoveData` uniquement si leur
suppression explicite est souhaitée.
