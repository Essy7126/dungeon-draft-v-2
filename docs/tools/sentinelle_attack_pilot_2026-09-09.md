# Pilote Sentinelle — 9 septembre 2026

État : essai terminé, variantes rejetées pour la production après revue utilisateur.
Base Git : `6d99bfff`.

## Décision expérimentale

Comparer l’attaque E originale à A (retouches demandées) et B (trois nouvelles
poses clés). Remplacer uniquement les images 2, 4 et 5, conserver huit images
de 100 ms et le release à 400 ms. B2 est une expérience distincte qui tient les
poses d’anticipation et de retour sur deux images. Aucune modification des
ressources de production ni de la ruée d’Achille.

## Sources et limites observées

Trois appels à l’outil intégré imagegen ; prompts et sorties originaux conservés
dans `art/source/sprite_workshop/sentinelle_attack_pilot_2026-09-09/`.
Les deux premiers PNG sont RGB avec un damier dessiné. La troisième génération
corrige la lance trop longue de B et fournit un fond magenta pour le détourage
mécanique existant. A redessine davantage le corps que la retouche demandée.
La consommation en tokens n’est pas fournie par l’outil.

## Résultats vérifiés

- Trois PNG sources générés, six poses normalisées, trois variantes et l’original.
- Détourage par le helper existant ; une échelle constante par groupe, puis placement
  du pied avant sur le même repère. Les divisions du fichier généré ont été
  recalculées entre les silhouettes : la première pose de A débordait la colonne
  théorique. Aucun dessin coupé par une division régulière n’a été conservé.
- Export des quatre clips par SpriteClipService ; relecture exacte des pixels
  et durées. Les 23 autres animations sont conservées dans chaque profil temporaire.
- Contrôleur réel : aucun release à 399 ms, un release sur l’image 4 à 400 ms,
  retour idle à 800 ms, annulation avant impact et grand delta testés.
- Quatre estocs via EnemyTurnRunner/SpellCaster : chacun inflige 14 dégâts à
  Achille, dépense 4 PA et augmente l’utilisation du sort de un.
- Capture GPU 1280 × 720 pour chaque impact et résultat. Aperçu autonome HTML,
  GIF de 800 ms et planche comparative produits sous
  `artifacts/sprite_workshop/sentinelle_attack_pilot_2026-09-09/`.
- Les empreintes du profil, du SpriteFrames et de l’atlas E de production sont
  inchangées. Aucun asset de production ni ruée d’Achille n’a été remplacé.

Le scénario utilise la vraie salle du portique et la Sentinelle canonique dans
un roster temporaire déclaré. Le parcours actuel utilise des brutes évoluées
avec d’autres identifiants et sorts : ce pilote ne valide pas leurs kits.
Achille est placé légalement à l’est et soigné entre les quatre attaques.

**Le verdict technique global reste en échec.** Les 231 contrôles du scénario
réussissent, mais Godot signale à la fermeture 125 objets et 5 ressources retenus.
Le lanceur détecte ces messages et sort avec le code 1. Les ressources concernent
GridData, TerrainEffects, TerrainSurfaceRuntimeService, CellSurfaceState et
ElectricalTerrainRegionResolver. La grille du combat instrumentée est bien
libérée ; une projection terrain temporaire est suspectée. Le chemin
`ArenaVisualAssembler.expected_visual_signature()` crée une projection sans
libérer explicitement son service terrain ; cette piste n’a pas été isolée
par un test comparatif et aucun correctif du moteur commun n’a été appliqué.

Dernier rapport détaillé :
`artifacts/dev/20260909-152838-sentinelle-sprite-pilot-be4f3c72/report.json`.
Verdict strict : `summary.json` dans le même dossier ; détails dans
`pilot.stdout.log` et `pilot.stderr.log`.

Commandes exécutées :

```powershell
# NODE_PATH désigne les dépendances Node du runtime fourni par Codex.
node tools/sprite_workshop/experiments/prepare_sentinelle.cjs
./tools/sprite_workshop/experiments/test_sentinelle.ps1
./tools/sprite_workshop/experiments/test_sentinelle.ps1 -EngineVerbose
python tools/sprite_workshop/experiments/build_sentinelle_review.py artifacts/dev/20260909-152838-sentinelle-sprite-pilot-be4f3c72/report.json
```

Node/Python ont été appelés par leur chemin absolu dans le runtime local ; aucun
programme artistique supplémentaire n’a été installé. Les tests unitaires cités
dans le compte rendu précédent n’ont pas été réexécutés pour ce pilote isolé.

## Revue artistique et nouvelle décision

Le gain de lisibilité de la pointe ne suffit pas. Retour utilisateur : le bras
agit sans coordination convaincante du buste, de la tête et du corps entier ;
les directions sont mal construites. B2 évite deux retours prématurés de pose,
mais ne corrige pas cette mécanique. Toutes les variantes restent des essais.

**Ne pas poursuivre la finition ni décliner les quatre directions de ces poses.**
Le prochain essai doit commencer par une référence animée adaptée à la morphologie,
à l’arme et à la caméra ; construire ensuite quelques poses complètes simplifiées
et les faire évaluer en mouvement avant de produire les détails. Voir
[le catalogue de références](sprite_motion_references_2026-09-09.md).

Le nombre de générations (3) est connu ; aucune mesure comparable de coût en
tokens n’est disponible. Ce pilote ne démontre donc aucune économie chiffrée.
