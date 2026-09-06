# Production sprite du Dialecticien

Les dessins viennent de l'outil intégré **imagegen**. Le pipeline ne dessine aucun personnage : il découpe les vraies sources RGBA, applique une échelle commune à chaque planche et place les poses selon les racines au sol explicitement revues dans `alignment.json`.

```powershell
node tools/philosopher_sprite_pipeline/build.cjs --inspect
node tools/philosopher_sprite_pipeline/build.cjs
node --test tools/philosopher_sprite_pipeline/build.test.cjs tools/philosopher_sprite_pipeline/build_effects.test.cjs
```

`sharp` doit être disponible via Node ou `SHARP_PATH`. Le chemin du runtime Codex sert uniquement de secours sur la machine de production.

Les huit sources se trouvent dans `art/source/characters/philosopher_mage/sprites_v1/`, avec leurs prompts exacts. Les sorties sont dans `assets/characters/philosopher_mage/sprites_v1/`. Chaque atlas contient 16 cellules de 512 × 384 ; racine au sol (256,320). Les huit familles sont repos, marche, attaque, soin, contrôle, protection, coup reçu et défaite, dans les quatre directions N/E/S/W.

La marche possède sept poses. Les sorts, réactions et chutes possèdent quatre poses. Le repos est fixe. Les durées du SpriteFrames correspondent aux durées du profil runtime ; la marche en jeu est liée à la distance parcourue, et le runtime pilote les marqueurs de libération.

Les quatre dessins dont la prise du bâton est incohérente restent archivés, mais sont exclus des références jouées : le geste correct précédent est maintenu. Les raisons exactes sont dans `alignment.json`. Sur la pose rejetée N/14, le corps et le bâton sont deux composantes : leur regroupement est explicitement limité à cette seule cellule, pour préserver les pixels de la source dans l'atlas.

Le pipeline refuse une source sans alpha, des composantes ambiguës, des racines manquantes, une coupe à la frontière de sortie et toute suppression de pixel de source d'alpha supérieur à 32. Il conserve la bordure translucide voisine des composantes, puis copie les lignes RGBA sans seconde composition. Chaque région d'atlas est comparée octet pour octet avec sa pose préparée. `manifest.json` conserve les SHA, les placements et les mesures de transparence.

Le portrait est un **SpriteFrames** contenant `idle_E`, enveloppant une région d'AtlasTexture : il respecte le champ `UnitData.preview_sprite_frames`. Les GIF et les feuilles sur fond gris servent à la revue artistique ; les captures du harness prouvent séparément le rendu et les timings en jeu.

Le [pipeline des effets](README_effects.md) produit six animations et les cinq icônes de sorts.
