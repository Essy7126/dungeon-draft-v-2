# Guide utilisateur — VFX Flipbook Foundation Lab

Le laboratoire montre la fondation technique des flipbooks VFX de Dungeon Draft. Les atlas actuels sont entièrement synthétiques : ils servent à tester le runtime, pas à représenter une direction artistique approuvée.

## Lancer le laboratoire

1. Ouvrir le dossier du projet dans l'Explorateur Windows.
2. Double-cliquer sur `LANCER_LAB_VFX_FLIPBOOK.cmd`.
3. Au premier lancement, le script cherche automatiquement Godot 4.7. S'il ne le trouve pas, sélectionner manuellement l'exécutable Godot 4.7 dans la boîte de dialogue.
4. Le chemin validé est mémorisé hors du dépôt dans `%LOCALAPPDATA%\DungeonDraft\godot_path.txt`.

Pour ouvrir directement la scène dans l'éditeur, double-cliquer sur `OUVRIR_LAB_VFX_FLIPBOOK_DANS_GODOT.cmd`.

## Contrôles

- `Play`, `Pause`, `Resume`, `Replay` et `Clear` pilotent le cycle de vie réel du VFX.
- `Scrub` recrée une instance propre et l'amène au temps absolu choisi.
- `0.25x`, `0.5x`, `1.0x` changent la vitesse.
- `LOW`, `MEDIUM`, `HIGH` sélectionnent la qualité et testent les fallbacks.
- `MIX`, `ADD`, `PREMULTIPLIED` changent le mode de fusion.
- `Light/Dark` change le fond de contrôle.
- `1 instance`, `4 instances`, `10 instances` testent la charge et le nettoyage.

## Logs et diagnostic

Les logs sont écrits dans `%LOCALAPPDATA%\DungeonDraft\logs`. Le chemin exact est affiché dans la console à chaque lancement.

En cas d'échec, la fenêtre ouverte par le `.cmd` reste visible. Copier :

- le message d'erreur ;
- le chemin du log ;
- le mode utilisé (`Run`, `Edit` ou `Smoke`) ;
- la version de Godot ;
- une capture d'écran si le défaut est visuel.

Le smoke automatisé peut être lancé manuellement depuis la racine du projet avec :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\launchers\launch_vfx_flipbook_lab.ps1 -Mode Smoke
```

Un chemin Godot explicite peut être fourni avec `-GodotPath` lors de l'appel direct du script PowerShell (cet argument n'est pas destiné aux fichiers `.cmd`). Les variables `GODOT4_BIN` puis `GODOT_BIN` sont également reconnues. Les arguments ajoutés après un fichier `.cmd` sont transmis à Godot.

## Limites

- Aucun asset EmberGen de production n'est inclus.
- Les couleurs, silhouettes et atlases sont des fixtures techniques.
- Le laboratoire ne modifie aucune donnée de gameplay, aucun sort et aucune arène.
- Une validation visuelle technique ne vaut pas approbation artistique.
