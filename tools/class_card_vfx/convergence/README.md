# Convergence — planche J

Production autorisée le 28 septembre 2026 pour **`cc2_t08`**, normale et
améliorée, dans la run Cartes consommable actuelle.
[Intention validée](../../../docs/design/vfx_avant_production_lot3_2026-09-27/j_convergence.png).

Quatre pétales facettés indigo, violets et lilas se contractent pendant
8 poses / 0,267 s autour d'un cœur ivoire. Au cast confirmé, les traits courts
relient les positions de départ et d'arrivée des ennemis réellement attirés.
Quatre lames s'ouvrent selon les axes de la grille ; les contacts ivoire avec
un mince bord chaud apparaissent deux poses plus tard, sur les seuls dégâts
ou absorptions de garde confirmés. Tout se dissipe avant 0,734 s, sans état
ni terrain persistant. Un cast sans préparation joue seulement la résolution.

## Raccord au combat

- Le rayon d'attraction Manhattan 2 et la croix de dégâts de cinq cases restent
  les deux géométries des règles existantes. La version améliorée augmente la
  portée de ciblage à cinq ; elle conserve l'aire et les dégâts de la carte.
- Les positions sont prélevées après l'attraction, avant les morts. Une cible
  tuée reçoit ainsi son contact sur la case où elle a réellement été frappée.
- Un déplacement empêché par une occupation ou un mur ne crée pas de traînée.
  Le lecteur ne déplace jamais les vues des personnages. Le déplacement forcé
  ennemi actuel est instantané ; les traits soulignent ce déplacement.
- Les lames sont projetées avec les axes réels de la grille, sans angle
  isométrique gravé dans l'image. Leur dessin s'arrête aux murs ; cela ne
  modifie pas la géométrie de dégâts du moteur. Les alliés ne reçoivent aucun
  éclat de contact. Une case vide peut porter une lame de la zone, aucun impact.
- Les préparations refusées, périmées ou interrompues sont supprimées. Un
  rapport déjà présenté ne rejoue pas l'effet. Fermeture et reprise n'ajoutent
  aucun maintien. Le routeur Cartes garde son contrôle de périmètre existant.

Le compagnon `vfx/class_cards/convergence/facts.gd` ne fait que lire la
résolution et enrichir son rapport. `consumable_card_spells.gd` l'attache à
`t08`. Les coûts, dégâts, règles d'attraction et états ne sont pas modifiés.

## Sources et reproduction

Source : `art/source/vfx/convergence/convergence.blend`. Quatre scènes,
34 poses RGBA à 30 images/s : nœud 8, lame 12, contact 8, traînée 6.
Les facettes et arêtes sont des géométries originales à matériaux cel émissifs,
sans bloom. Palette : #29283f, #403165, #7657b5, #9867d4, #c8a6eb,
#e1c8ff, #fff0cc, #ffcd88.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python tools/class_card_vfx/convergence/build.py -- --render
python tools/class_card_vfx/convergence/pack.py
blender --background --factory-startup --python tools/class_card_vfx/convergence/verify_source.py
python tools/class_card_vfx/convergence/verify_pixels.py
./tools/class_card_vfx/convergence/workshop_isolated.ps1
./dev.ps1 test test/unit/test_consumable_cards_convergence_vfx.gd
./dev.ps1 test cards
./tools/class_card_vfx/convergence/run.ps1 -Capture
node tools/class_card_vfx/convergence/encode.cjs
./tools/class_card_vfx/convergence/run.ps1
```

`pack.py` assemble les atlas sans retouche. Le rerendu du `.blend` vérifie
les pixels des 34 poses. Le service Sprite Clip du Studio est réutilisé
inchangé dans un projet d'export isolé ; quatre documents d'édition sont
conservés dans `art/source/sprite_workshop/convergence_*.json`.

La revue utilise la troisième salle réelle de la run. Trois ennemis sont
placés à distance deux et les PV rétablis à leur maximum naturel. L'IA est
suspendue. Les deux clips montrent la version normale en détail, puis la
version améliorée à la caméra normale. Chaque clip repart d'une salle fraîche,
car un ennemi fragile peut être tué par les dégâts réels. Une commande publique
supplémentaire sur l'ennemi le plus robuste vérifie consommation, sauvegarde
sur disque et reprise des PV et positions.
Le bilan final et les deux victoires préalables sont des fixtures explicites,
pas une partie jouée ni une mesure d'équilibrage. Les captures gardent les
pixels natifs du viewport ; le GIF applique seulement sa quantification.

Les résultats effectifs restent dans `artifacts/dev/class_card_vfx/convergence/`
et les journaux du lanceur. Le suivi de production est dans
[la fiche du 28 septembre](../../../docs/ai/CONVERGENCE_PRODUCTION_2026-09-28.md).

Validation du 28 septembre : **317 tests Cartes / 21 298 assertions**, import
complet, 34 poses reproduites à l'identique, 4 exports Studio, **253 contrôles
de revue et 90 images**. La capture et le runtime ont conservé leurs empreintes.
[Rapport d'intégration](../../../artifacts/dev/class_card_vfx/convergence/integration_report.json).

![Convergence — détail puis caméra normale](../../../artifacts/dev/class_card_vfx/convergence/combat/convergence.gif)
