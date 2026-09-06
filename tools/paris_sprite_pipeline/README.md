# Paris : deux angles maîtres, quatre orientations de jeu

La production utilise **cinq feuilles RGBA natives et 72 dessins sources**. Les variantes dont l’équipement divergeait ont été écartées. Chaque forme conserve deux angles maîtres : `E`, de face en trois quarts, et `N`, de dos en trois quarts. Le moteur réutilise les mêmes textures pour `S` et `W` avec un miroir horizontal ; aucun dessin retourné n’est fabriqué ou enregistré par ce pipeline.

| Source | Dessins | Disposition |
| --- | ---: | --- |
| `source_spectral_E.png` | 16 | 4 × 4 |
| `source_spectral_N.png` | 16 | 4 × 4 |
| `source_infernal_E.png` | 16 | 4 × 4 |
| `source_infernal_N.png` | 16 | 4 × 4 |
| `source_transform_ALL.png` | 8 | 4 × 2 ; ligne E puis ligne N |

Les sources sont dans `art/source/characters/paris/sprites_v1`. Pour les feuilles de corps, les indices sont : repos `0`, déplacement `1–4`, attaque `5–8`, incantation `9–11`, réaction `12–13`, mort `14–15`. La transformation emploie `0–3` pour E/S et `4–7` pour N/W.

Les trois ressources `frames_spectral.tres`, `frames_infernal.tres` et `frames_transform.tres` exposent **52 clips** : 6 familles × 4 orientations × 2 formes, puis 4 clips de transformation. Les clips S utilisent exactement les références de textures E, les clips W celles de N. Les 52 clips ne correspondent donc pas à 52 séries de dessins indépendantes. Les portraits des deux formes utilisent leur angle E.

`alignment.json` contient une échelle fixe par feuille, 16 ancres de sol pour chaque corps et 8 ancres pour la métamorphose. Les fenêtres de découpe peuvent être précisées manuellement. Chaque pixel source dont l’alpha est supérieur à zéro, même égal à 1, doit appartenir à exactement une fenêtre. Le pipeline refuse les sources opaques, les coordonnées invalides, les omissions et duplications de pixels, les ancres non finies, les sorties coupées et les références de poses invalides.

Les substitutions de poses gardent le nombre de frames : `spectral_E:attack`, `infernal_N:cast`, `transform_ALL:transform_E` ou `transform_ALL:transform_N`. Une substitution d’un angle maître s’applique aussi à son orientation miroir. Les aperçus et ressources utilisent les mêmes choix de poses.

Le découpage retire uniquement des marges transparentes. Les pixels RGBA du dessin sont conservés avant l’échelle fixe ; la copie dans l’atlas est vérifiée après réouverture du PNG. Les tests à échelle 1 exigent une identité RGBA complète, y compris les pixels d’alpha 1. Il n’y a ni détourage par couleur, ni déformation du corps, ni miroir hors moteur.

```powershell
node tools/paris_sprite_pipeline/build.cjs --inspect
node tools/paris_sprite_pipeline/build.cjs
node --test tools/paris_sprite_pipeline/build.test.cjs
```

`--allow-partial` permet une revue de production avec des sources manquantes et écrit `complete: false` ; ce résultat n’est pas un personnage livrable. Le manifest expose le nombre réel de dessins, les angles maîtres, les orientations miroir, la couverture des pixels, les ancres, les échelles et les SHA des sources et régions. Les cinq feuilles valides sont nécessaires pour `complete: true`.

Les GIF de revue montrent les deux angles maîtres uniquement. Leurs cadences d’attaque, d’incantation et de mort suivent le profil de simulation : 0,68 s, 0,76 s et 0,64 s. La métamorphose dure 0,90 s. Le fondu de mort de 0,16 s et le déplacement fondé sur la distance sont pilotés par le runtime et doivent être contrôlés dans les captures de combat. Les GIF d’atelier ne sont pas des preuves de gameplay.

Details du mode optionnel sans perte : [segmentation des silhouettes](segmentation.md).
