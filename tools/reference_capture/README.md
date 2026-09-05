# Inspection visuelle de Dofus

Ce script Windows capture uniquement la fenêtre Dofus ouverte avec `PrintWindow`. Il ne clique pas, ne modifie aucun réglage et ne lit ni la mémoire ni les fichiers du jeu.

Depuis la racine du projet :

```powershell
& .\tools\reference_capture\capture_dofus.ps1
```

Le PNG et son rapport JSON horodaté sont écrits dans `artifacts/reference_capture/`. Le script refuse plusieurs fenêtres Dofus ou une fenêtre minimisée. Une capture réussie doit être inspectée : une boîte de dialogue peut masquer le terrain, et certains moteurs peuvent renvoyer une image noire.

Cette méthode a été vérifiée le 5 septembre 2026 sur Dofus 3.6.10.11, fenêtre 2560 × 1600. Elle permet de comparer la composition visible, les formes et les couleurs ; elle ne révèle pas les technologies internes du client.

Les captures servent de références locales. Les assets grecs du jeu sont créés séparément.
