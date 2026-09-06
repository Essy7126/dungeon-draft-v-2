# Tir du Pélion — provenance et raccordement canonique

Documentation du 6 septembre 2026. Une génération neuve avec l’outil intégré `image_gen`, sans image DOFUS en entrée. Le PNG maître et l’original sont conservés.

- Asset : `asset/ui/recraft_hud_v1/icons/achilles_painted_v2/ability_achilles_pelion_shot.png`.
- Original : `C:/Users/paolo/.codex/generated_images/01a073ea-9e9b-7ff2-b6c2-4905ecf22531/exec-9700b658-3df5-4456-8a5f-698cf998fa5e.png`.
- SHA256 du PNG maître : `A839E2400D6DAB6A6A5E0E27CA716819EBF1A67DF16D35654DBF5063EF3B2256`.
- Dimensions : 1254 × 1254 ; sans texte, cadre ni badge.

Inspection initiale : arc recourbé bronze/or et flèche ivoire sur fond émeraude, distincts d’une lance ou d’un balayage. L’image a été inspectée à sa taille affichée. Limite observée : le padding demandé de 10 % n’est pas respecté partout, notamment à l’extrémité inférieure de l’arc ; la forme principale reste dans l’image. La validation de ressources ci-dessous ne remplace pas la revue visuelle du combat final.

## Raccordement et import

Dans `data/ui/achilles_hud_theme_refined.tres`, les identifiants canoniques sont explicitement liés aux assets v2 :

| Identifiant | Asset |
|---|---|
| `achilles_peleid_strike` | `ability_achilles_spear_thrust.png` |
| `achilles_fulminant_dash` | `ability_achilles_advance.png` |
| `achilles_pelion_shot` | `ability_achilles_pelion_shot.png` |
| `achilles_bronze_guard` | `ability_achilles_guard.png` |

Les anciens identifiants restent mappés pour compatibilité. Ce raccord ne modifie ni les sorts, ni leurs coûts, règles, VFX ou animations.

Import optimisé via un mini-projet isolé `work/run-integration-2026-09-06/pelion-import`, au même chemin `res://`, sous Godot headless 4.7.1 : aucun rendu GPU ni import global du jeu. Le PNG maître reste intact ; `process/size_limit=256`, `mipmaps/generate=true`. L’UID créé par l’éditeur déjà ouvert, `uid://dvtfl40x6n8r2`, a été conservé. Seuls les deux paramètres du sidecar Pelion et ses caches `.ctex` / `.md5` ont été remplacés par le résultat optimisé.

Cache : `.godot/imported/ability_achilles_pelion_shot.png-2dce882cdf548f88b8ad00e928499e7f.ctex`, 129 194 octets. Hash, UID, paramètres et taille du cache revérifiés lors de l’archivage de cette notice.

## Vérification du raccord

- `test_run_hud_canonical_bindings.gd` : 3/3 tests, 90 assertions, sortie 0 ; `artifacts/run_integration_20260906/test_logs/hud_canonical_bindings_pass.log`.
- `test_achilles_hud_icon_kit.gd` : 3/3 tests, 229 assertions, sortie 0 ; `artifacts/run_integration_20260906/test_logs/hud_legacy_icon_kit.log`.

Le premier test vérifie les entrées explicites du thème et l’identité des textures pour les loadouts résolus de Catabase et de l’Épreuve du Dialecticien, leurs copies runtime et les anciens alias ; un fallback vers `spell.icon` ne peut donc masquer un oubli. Une première invocation avait échoué sur les arguments PowerShell avant exécution ; la relance avec arguments cités a produit les résultats ci-dessus.

## Prompt exact

```text
Use case: stylized-concept
Asset type: a SINGLE square raster ability icon for a polished tactical fantasy game HUD, displayed at 64 pixels.
Primary request: the "Pelion Shot" ranged bow-and-arrow ability. ONE powerful ancient Greek recurved bow, made from warm bronze-tipped golden wood, with ONE large ivory-bright arrow drawn taut ready to release. Both curved limbs and the bowstring visibly form a clean readable bow silhouette. Arrow points diagonally toward the upper right. The arrowhead and broad bow limbs are large graphic focal shapes, no character or hands.
Style/medium: premium hand-painted stylized game art; confident brush-shaped planes, crisp edges and clean silhouette, tactile bronze metal and warm wood, generous luminous ivory highlights; original art, not photorealistic.
Scene/backdrop: full-bleed deep dark emerald-teal painted background with a medium emerald glow immediately behind the bow and arrow, subtle sweeping motion strokes along the arrow's straight trajectory. NO scenery.
Composition/framing: square, the centered bow-and-arrow fills roughly 75–80% of the canvas, important extremities within a 10% margin on every side. Recognizable immediately at a 64-pixel thumbnail: avoid thin spindly construction. The brightly lit subject must remain substantially lighter than the colored backdrop, with broad mid-value gold areas and ivory highlights. The bow is unmistakable, not a spear or sword.
Lighting/mood: confident heroic precision; warm ivory-bronze subject against cool emerald-teal, crisp silhouette and restrained magical arrow glint.
Constraints: NO text, letters, numbers, badges, frame, decorative border, slot shape, bevel around canvas, watermark, UI mockup, sprite sheet, multiple panels, face, whole person, landscape or tiny ornamentation. Just one bow with its single nocked arrow on the square painted background.
```
