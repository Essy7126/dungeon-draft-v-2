# Passe-rive AutoSprite

66 planches originales transparentes de 1280 × 1280 (5 × 5 images de 256).
Le générateur conserve leurs octets et produit les ressources Godot, le portrait,
les SHA-256, les cycles, les pivots et les échelles par clip.

```powershell
python tools/passe_rive_autosprite/build.py
./tools/passe_rive_autosprite/validate.ps1
./tools/passe_rive_autosprite/validate.ps1 -Integration
./tools/passe_rive_autosprite/capture.ps1 -Scenario entry
./tools/passe_rive_autosprite/capture.ps1 -Scenario combo -Direction E -TimingOnly
./tools/passe_rive_autosprite/capture.ps1 -Scenario shot -Direction N
./tools/passe_rive_autosprite/capture.ps1 -Scenario combo -Kit wrath -Direction S
./tools/passe_rive_autosprite/capture.ps1 -Scenario hit_death -Direction W
```

Python requiert Pillow. Par défaut, rebuild depuis les originaux déjà empaquetés ;
`--source <dossier>` permet leur première importation depuis les exports fournis.
Godot et sa version sont résolus via les outils du dépôt. Exécuter la validation
avant les captures après toute modification de ressources pour terminer l'import.

La validation exige un import complet, au moins neuf tests et aucune erreur
moteur inattendue. Les captures lancent la sélection publique ou la vraie scène
de combat, avec des données utilisateur isolées. Les rapports sont dans
`artifacts/dev/`, les images sous `artifacts/dev/passe_rive_autosprite/`.
Le dossier APPDATA de chaque capture est consigné dans son `summary.json`.

Les directions des scénarios combat sont celles de la grille : `S` produit
notamment un geste visuel SW. Seuls les sauts W/SW existent dans les sources ;
les autres orientations utilisent leur esquive native. Arc, dash, garde,
réactions et mort ont chacun leur séquence.

Voir [la fiche d'intégration](../../docs/ai/passe_rive_autosprite_integration.md)
pour les réglages d'ancrage, les preuves et les limites de la suite élargie.
