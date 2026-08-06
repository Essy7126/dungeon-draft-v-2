# Automatisation Observatory V1.2

## Invariant de publication

Une release n’est activée que si elle provient du SHA exact de la branche
distante autorisée, d’un worktree détaché propre, et si export Godot,
provenance, tests Observatory, baseline GUT, validation Ajv, lint, typage,
Vitest, build et Playwright réussissent. En production, toute branche autre que
`main` est refusée. L’option `AllowPreviewBranch` existe uniquement pour la
validation temporaire sans tâches ni pare-feu.

## Algorithme

1. créer l’arborescence et acquérir `locks/update.lock` avec partage nul ;
2. exécuter `git fetch <remote> <branch> --prune` et résoudre le commit distant ;
3. retourner `no_change` lorsque ce SHA est déjà actif ;
4. créer un worktree détaché et vérifier `git status --porcelain` ;
5. importer Godot, exporter et certifier les trois champs de provenance ;
6. exécuter les contrôles Godot et frontend obligatoires ;
7. copier `dist`, calculer les SHA-256 et valider `release.json` ;
8. renommer le dossier temporaire en `releases/<sha>` ;
9. remplacer atomiquement `state/active.json`, puis exécuter `healthz` ;
10. en cas d’échec après activation, rétablir l’ancien pointeur ;
11. écrire statut, historique et logs, appliquer la rétention, nettoyer le
    worktree et libérer le verrou.

Les fichiers JSON sont remplacés avec `System.IO.File.Replace` et une sauvegarde
temporaire compatible Windows PowerShell 5.1. La release précédente et la
release active sont protégées pendant la rétention.

## Exploitation

`Get-ObservatoryStatus.ps1` indique SHA actif/détecté, dernier succès, dernier
échec et disponibilité HTTP. Les logs sont dans `logs/`; le dernier échec ne
retire jamais le site valide. `Rollback-Observatory.ps1 -ListOnly` liste les
releases dont structure, provenance et hashes sont encore valides.
