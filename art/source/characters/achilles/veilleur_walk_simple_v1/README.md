# Veilleur — marche simple, essai en quatre vues

12 septembre 2026. Reprise directe demandée depuis la planche des premières
générations jointe par l'utilisateur. **Une génération ImageGen intégrée** pour
les quatre vues. Le générateur a dessiné sept poses par vue au lieu des huit
demandées ; les 28 poses réelles sont conservées, sans interpolation ni rig.

- Cycle : 7 dessins à 10 images/seconde, soit 700 ms.
- Vues : E/S de face, N/W de dos, dessinées sur la même planche.
- Fond en damier peint retiré par détourage logiciel déjà autorisé. Couleurs
  originales conservées dans les silhouettes ; position calée à la ceinture.
- Taille uniforme des dessins, aucune déformation de jambes ou de bottes.
- Vitesse de déplacement initiale : environ 75 pixels/seconde à l'échelle jeu.
  C'est un réglage d'essai ; les contacts peints ne sont pas déclarés parfaits.
- Arrêt : maintien de la deuxième pose. Virages instantanés, pas de nouvel idle.

## Tester dans Godot

```powershell
./tools/veilleur_walk/iso.ps1 open -Simple
```

Ou ouvrir `tools/veilleur_walk/WalkSimpleReview.tscn`, puis F6.
Cliquer les cases, utiliser les flèches ou « Tour des 4 vues ». Espace pour
mettre en pause. Le menu de vitesse permet de comparer normal, ralenti et ×2.

La scène réutilise la carte forêt, sa grille, les obstacles et le déplacement
du laboratoire existant. L'ancien essai à 48 images reste accessible séparément.

## Sources

- [Référence utilisateur](user_reference.png).
- [Planche générée brute](sheet.png) et [prompt exact](prompt.txt).
- [28 poses détourées](../../../../../artifacts/spine_trial/veilleur_walk_simple_v1/all_poses.jpg).
- Ressources Godot : `assets/characters/Achilles/veilleur_walk_simple_v1/`.
- Export : `tools/veilleur_walk/build_simple.py` ; seules découpe, transparence,
  translation et mise en atlas sont calculées.

Contrôle natif : `iso.ps1 verify -Simple`, rapport dans
`artifacts/spine_trial/veilleur_walk_simple_v1/godot_report.json`.
Import et 93 contrôles natifs réussis ; quatre captures GPU inspectées.
Rapport daté : `artifacts/dev/20260912-162544-veilleur-simple-6b7e1786/summary.json`.
Retour utilisateur : le reste est correct ; défauts localisés au passage des pieds.
Préserver ce résultat et cibler la séquence / les dessins des jambes, sans refaire
le personnage ni densifier automatiquement le cycle. Correction pas encore faite.
