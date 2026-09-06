# Observatory LAN runtime

Ces scripts publient en lecture seule le dernier commit validé de
`origin/main`. Ils ne lisent jamais le worktree courant pour construire le
site : chaque candidate est exportée et testée dans un worktree détaché propre.

## Scripts

- `Install-ObservatoryLan.ps1` vérifie la toolchain, écrit la configuration,
  lance une première publication et, après fusion seulement, peut créer les
  deux tâches Windows et la règle pare-feu privée optionnelle.
- `Update-ObservatoryLive.ps1` prend un verrou exclusif, résout le SHA distant,
  génère et valide une release temporaire, puis remplace atomiquement
  `state/active.json`. Un échec conserve la release active.
- `Start-ObservatoryLan.ps1` lance le serveur Node sans dépendance externe et
  enregistre son PID.
- `Get-ObservatoryStatus.ps1` expose le statut local sans secret.
- `Rollback-Observatory.ps1` active une release antérieure déjà validée sans
  reconstruire le dépôt.
- `Uninstall-ObservatoryLan.ps1` retire uniquement les objets nommés ; les
  données sont conservées sauf avec `-RemoveData`.
- `Test-ObservatoryRelease.ps1` vérifie structure, provenance et SHA-256.

## Arborescence de déploiement

```text
config/live-config.json
runtime/*
releases/<sha>/{dist,release.json}
state/{active,status,history}.json
logs/update-*.log
locks/update.lock
worktrees/update-*
```

Le serveur écoute `0.0.0.0:8080` par défaut, mais aucune règle Internet et
aucune redirection de routeur ne sont créées. La règle optionnelle est limitée
au profil `Private` et à `LocalSubnet`.

## Tests

```powershell
node --test .\tools\observatory\live\tests\observatory-lan-server.test.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\tools\observatory\live\tests\Test-LiveAutomation.ps1
```

Les fixtures utilisent uniquement des dépôts et dossiers temporaires, puis les
suppriment. L’installation permanente n’est jamais exercée avant la fusion.
