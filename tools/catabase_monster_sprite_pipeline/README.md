# Monstres de Catabase : vues fixes et animation locale

Le pipeline conserve les quatre concepts approuvés : Sentinelle d’airain, Rejeton de braise, Molosse du Styx et Lamie du Léthé. **Meshy produit uniquement leurs vues fixes indépendantes. Les animations et les spritesheets sont fabriquées localement.**

`generate_meshy.py`, ancienne commande de génération distante de spritesheets, est retirée : elle affiche les nouvelles commandes puis termine avec le code 2, sans charger Meshy, lire une clé ou envoyer une requête. Les identités et chemins des concepts sont dans `creature_specs.py`. `generate_views.py` les importe directement.

## 1. Obtenir et examiner les vues fixes

Depuis la racine du dépôt, avec Python, Pillow, NumPy et SciPy disponibles :

```powershell
python tools/catabase_monster_sprite_pipeline/generate_views.py
```

Cette commande est la seule étape distante du pipeline. Elle utilise les helpers du plugin Meshy, demande la clé de session sans l’afficher, génère les références manquantes et conserve les réponses dans `meshy_output/20260908_monster_views_v1/tasks.json`. Elle peut consommer des crédits. La clé n’est pas écrite dans les fichiers du pipeline.

Chaque turnaround contient quatre dessins indépendants dans une grille 2 × 2 :

| Position | Direction | Vue |
| --- | --- | --- |
| Haut gauche | E | Face, vers le bas et la droite |
| Haut droite | S | Face, vers le bas et la gauche |
| Bas gauche | N | Dos, vers le haut et la droite |
| Bas droite | W | Dos, vers le haut et la gauche |

Vérifier visuellement l’identité, la direction, l’anatomie, les membres, les accessoires complets et les marges magenta. La lance et le bouclier de la Sentinelle, ainsi que le bâton de la Lamie, doivent rester dans leurs mains anatomiques respectives. **Aucune texture n’est retournée horizontalement pour inventer une autre vue.** Le repositionnement des articulations du rig selon l’orientation ne constitue pas un retournement de texture.

Une référence téléchargée porte le statut `downloaded_pending_review`. Ce statut décrit son arrivée ; il ne constitue pas une validation anatomique. Les erreurs repérées sont conservées dans les métadonnées. Les corrections complètes rejetées restent dans `rejected_corrections.json`, et le registre actif revient à la dernière source utilisable.

Si une seule vue est incorrecte, demander une nouvelle vue fixe et l’inscrire dans `overrides.json` à côté du registre. La clé identifie exactement la famille et la direction, par exemple :

```json
{
  "sentinelle_airain_S": {
    "source_path": "chemin local de la vue carrée téléchargée",
    "sha256": "hash SHA-256 des octets originaux",
    "task_id": "identifiant de la génération Meshy",
    "status": "approved"
  }
}
```

Le statut `approved` est donné après examen visuel. Un remplacement encore `downloaded_pending_review` conserve un avertissement de revue. Une source rejetée ou un hash incohérent fait échouer la préparation. Le remplacement ne change que sa direction ; les autres vues lisent le turnaround original.

## 2. Détourer et aligner les vues

```powershell
python tools/catabase_monster_sprite_pipeline/prepare_views.py --inspect
python tools/catabase_monster_sprite_pipeline/prepare_views.py --prepare
```

`--inspect` calcule les mesures et écrit uniquement un rapport JSON sur la sortie standard. `--prepare` conserve les octets des originaux et produit, sous `art/source/characters/catabase_monsters/<famille>/` :

- `master.png` et `turnaround_source.png` : copies exactes des sources ;
- `override_source_<D>.png` : copie exacte d’un remplacement individuel éventuel ;
- `source_<D>.png` : vue détourée ;
- `base_frame_<D>.png` : vue sur un canevas RGBA de 512 × 384, ancre (256, 320) ;
- `alignment.json` : hashes, détourage, mesures, racines proposées et avertissements ;
- `fixed_views_contact.png` : planche pour la revue visuelle.

Le détourage réutilise l’implémentation magenta éprouvée du projet : décontamination des bords et suppression des seuls points déconnectés de trois pixels source ou moins. Un membre ou accessoire atteignant le bord de son quadrant bloque la préparation. Aucune partie du personnage n’est supprimée pour le faire rentrer.

Un seul facteur d’échelle est appliqué aux quatre vues de chaque famille. Les hauteurs cibles sont 280 pixels pour la Sentinelle, 230 pour le Rejeton, 185 pour le Molosse et 280 pour la Lamie. L’échelle est calculée depuis la hauteur médiane des silhouettes et limitée pour éviter tout découpage. La racine proposée utilise la position horizontale médiane du bas de la silhouette et le pixel opaque le plus bas : vérifier les pieds, la queue et les accessoires sur la planche.

Un remplacement carré est d’abord normalisé uniformément en 512 × 512. Un `capture_scale` explicite, accompagné de `capture_scale_reason`, peut compenser un cadrage initial plus rapproché. Il s’applique une seule fois à la référence complète, jamais séparément à chaque pose. Sentinelle S utilise 369/402 pour conserver la taille physique de sa famille.

Après une correction, reprendre uniquement la famille concernée :

```powershell
python tools/catabase_monster_sprite_pipeline/prepare_views.py --prepare --slug sentinelle_airain
```

## 3. Articuler localement et fabriquer les spritesheets

La version 2 utilise des pièces peintes réellement articulées. `humanoid_parts.py` définit le découpage, les pivots et les dessous reconstruits de la Sentinelle et du Rejeton ; `creature_parts.py` définit ceux du Molosse et de la Lamie. `articulated_animation.py` anime la hiérarchie des articulations, les appuis des pieds et les recettes propres à chaque personnage. `rig.json` est une référence historique de la version 1 et n'est plus lu.

Les bras, avant-bras, mains, cuisses, tibias et pieds tournent séparément. Les zones cachées au repos sont reconstruites avec la palette source, puis recouvertes par les pièces visibles. Les armes suivent leur main. La marche résout deux articulations par patte pour garder un contact au sol pendant l'appui ; les chevilles compensent l'inclinaison du tibia. Seule la queue souple de la Lamie emploie une déformation locale. Les textures des quatre directions sont indépendantes et ne sont jamais retournées.

Pour examiner une orientation sans toucher aux assets runtime :

```powershell
python tools/catabase_monster_sprite_pipeline/animate.py --slug sentinelle_airain --direction E --review-only
```

Les planches et boucles GIF sont dans `output/catabase_monsters_v2/review/<famille>/`. Ces GIF rapides servent à examiner les poses ; juger le rythme réel avec le GIF final de `preview.py` ou son lecteur HTML, qui suivent les profils du jeu. Examiner les mains, les armes, les appuis, les silhouettes et les chutes, puis corriger les découpes et recettes locales.

Après revue, reconstruire les quatre familles :

```powershell
python tools/catabase_monster_sprite_pipeline/animate.py --slug all
python tools/catabase_monster_sprite_pipeline/preview.py
```

`preview.py` écrit aussi `output/catabase_monsters_v2/review/animation_review.html` : lecture/pause, choix de la famille, de la direction, de l'action et de la taille, curseur de pose. Les références d'images sont locales et les données sont incluses dans la page. `--html-only` régénère uniquement cet aperçu.

Chaque famille possède 48 poses par direction, soit 192 poses ; les quatre familles totalisent 768 poses. La pose 0 conserve exactement la peinture de référence. Le rendu prémultiplie les couleurs pour éviter les franges sombres lors des rotations.

| Action | Indices | Poses | Boucle |
| --- | --- | ---: | --- |
| Repos (`idle`) | 0–7 | 8 | Oui |
| Marche (`walk`) | 8–19 | 12 | Oui |
| Attaque (`attack`) | 20–27 | 8 | Non |
| Sort (`cast`) | 28–35 | 8 | Non |
| Impact reçu (`hit`) | 36–39 | 4 | Non |
| Mort (`death`) | 40–47 | 8 | Non |

Les profils Godot règlent la durée effective par espèce ; l'export et les aperçus lisent ces mêmes valeurs. Le repos dure 2,4 s pour la Sentinelle, 1,25 s pour le Rejeton, 1,1 s pour le Molosse et 2,8 s pour la Lamie. Les attaques libèrent leur effet à l'image locale 4, après l'anticipation ; les projectiles ajoutent leur temps de trajet. La marche avance selon la distance parcourue et le repos conserve sa phase lors d'un changement de direction. Les GIF sont des outils de revue, les événements du jeu gardent autorité sur les dégâts.

## 4. Vérifier les fichiers et le rendu en jeu

```powershell
python tools/catabase_monster_sprite_pipeline/build.py --verify sentinelle_airain
python tools/catabase_monster_sprite_pipeline/build.py --verify rejeton_braise
python tools/catabase_monster_sprite_pipeline/build.py --verify molosse_styx
python tools/catabase_monster_sprite_pipeline/build.py --verify lamie_lethe
```

Cette vérification est locale et en lecture seule. Elle exige les quatre directions et contrôle les dimensions, les 48 régions, leurs hashes et l’intégrité des pixels relus. `--allow-partial` sert seulement au développement d’une orientation ; il ne valide pas une famille de production.

Les ressources finales se trouvent dans `assets/characters/catabase_monsters/<famille>/` : `atlas_<D>.png` compactés sans rotation, avec deux pixels de gouttière transparente, manifestes par direction, `sprite_frames.tres`, `portrait.tres`, `portrait.png` et `manifest.json`. Le portrait est un cadrage de la tête et du haut du corps de la pose E au repos ; vérifier son cadrage pour chaque créature.

Les marges des `AtlasTexture` restituent le canevas logique 512 × 384 et son ancre commune (256, 320), malgré le rangement compact. Chaque atlas est relu après écriture : ses régions doivent correspondre exactement aux pixels des poses, avec une erreur de reconstruction égale à zéro. Le manifeste conserve la vue source, les hashes du rendu et des sources, la hiérarchie des pièces et les recettes de poses. Ce contrôle détecte un fichier corrompu ou un découpage, mais ne remplace pas l’examen de l’anatomie et des animations.

Importer ensuite les assets dans Godot et exécuter les tests d’intégration de `test/unit/test_catabase_monsters_integration.gd`, puis le probe de combat `tools/catabase_monster_validation/combat_probe.tscn`, piloté par `tools/catabase_monster_validation/combat_probe.gd`. Vérifier notamment le déplacement réel, les attaques, les délais des projectiles, les états et la disparition des unités mortes. Les résultats doivent être consignés après exécution ; ce README n’affirme pas que des contrôles runtime non exécutés ont réussi.

## Fichiers conservés et artefacts locaux

Les images finales requises par le jeu, les sources explicitement conservées, les manifestes de provenance et les scripts forment le livrable. Les planches de revue, GIF, captures et journaux de travail restent dans `output/`, déjà ignoré par Git. Les caches `.godot/`, `__pycache__/` et `*.pyc` sont également ignorés. Les marqueurs `.gdignore` présents dans `output/` et `meshy_output/` empêchent Godot d’importer ces fichiers de travail.

`meshy_output/` dans son ensemble n’est pas ignoré par Git : ne pas ajouter en masse ses anciennes tentatives ou dépendances locales. Les générations rejetées sont des références d’audit, pas des sprites runtime. Ne jamais publier une clé de session avec les sources ou les rapports.
