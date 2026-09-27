> **Historique : S21 rejeté par l’utilisateur le 26/09/2026.** La marche et le repos en combat réutilisent désormais les séquences des espaces libres. Voir [S22](../passe_rive_s22/README.md). Les preuves S21 ne valident pas S22.

# Passe-Rive S21 — repos neutre et marche

Reprise du 26 septembre 2026 après le retour « marche et idle incorrects ».
Choix utilisateur : posture neutre, armes rangées, mains libres entre les sorts.

## Défauts corrigés

- Les anciennes planches répétaient le même pied en avant au lieu d'un cycle à deux appuis.
- La garde redessinée à chaque image faisait varier la silhouette et les détails du costume.
- Le recadrage sur le pixel le plus bas d'une botte changeait le point d'ancrage pendant le pas.
- Les longs trajets accéléraient une marche sans disposer d'une animation de course.
- La cadence ne compensait pas l'échelle du personnage appliquée par la scène.

## Production et intégration

1. Poses extraites hors ligne dans Blender 5.1.2 du cycle original `CTRL_PR_WALK` : quatre poses neutres puis huit phases alternées. Les mains sont relâchées et vides. Le fichier maître reste inchangé ; empreinte et positions des pieds dans `guide_audit.json`.
2. Repeinture des guides par l'outil intégré `image_gen`, avec les sprites précédemment retenus comme référence de dessin. Le premier essai SE est rejeté car il remplaçait le contact opposé par une pose presque neutre. Consignes exactes et sélection dans `prompts.json`.
3. Cinq PNG RGBA : E, SE, S, NE, N ; W, SW, NW utilisent leurs miroirs. Douze cellules par planche ; au repos seule la première est utilisée, la marche utilise les huit cellules des deux dernières lignes.
4. Une seule échelle par vue pour le repos et la marche. Les régions sont alignées sur la racine projetée du guide Blender. Le générateur lit les pixels sans modifier les PNG. `build_s21_data.py --check` vérifie la reproductibilité des métadonnées.
5. Repos : dessin stable, respiration de 3,6 s limitée au haut du corps, amplitude maximale de 0,66 unité Godot avant agrandissement de scène ; bassin et bottes restent fixes. Marche : huit poses pilotées par la distance, cycle de 61 unités locales, échelle de scène compensée ; 0,72 s par case sur les trajets courts et longs. Le cycle conserve sa phase lors d'un virage.
6. Les sorts S18/S20 et leurs marqueurs de résolution restent actifs. Ils reviennent à la nouvelle posture neutre. Le rendu Classique conserve son système précédent.

## Essai reproductible

```powershell
./tools/class_card_vfx/play_passe_rive_s19.ps1 -Locomotion
./tools/class_card_vfx/play_passe_rive_s19.ps1 -Locomotion -Capture
./dev.ps1 test cards
```

Le bouton « Essayer marche → arrêt → sorts » parcourt les huit orientations au repos, les quatre axes de marche légaux de la grille sur une et trois cases, un trajet avec virage et trois sorts réels. L'arène prépare les ressources pour les essais et laisse l'IA en pause. Elle utilise le déplacement et la résolution de Battle. Le parcours de partie avec IA est contrôlé séparément.

## Limites précises

Les trois directions gauches sont des miroirs : l'asymétrie du carquois change donc de côté. La garde est animée par une respiration très légère du dessin stable, pas par une nouvelle séquence de poses. Les transitions d'équipement utilisent les premières et dernières poses des sorts existants ; une prise/rangement d'arme dédiée n'est pas encore dessinée. Cette reprise ne crée pas de course, de mort ou de réaction aux coups nouvelles.

Le contrôle visuel compare les appuis et les silhouettes au guide ; il ne garantit pas une absence absolue de glissement au pixel près entre huit poses discrètes. Les tests de logique ne constituent pas une validation artistique par l'utilisateur.

Références de construction du cycle : [Animation Mentor — Human Walk Cycle](https://www.animationmentor.com/blog/tutorial-animating-human-walk-cycle/) et [Toon Boom — Walk Analysis](https://learn.toonboom.com/modules/walk-cycle-animation/topic/walk-analysis1).

Résultats des essais et captures : [VALIDATION.md](VALIDATION.md).
