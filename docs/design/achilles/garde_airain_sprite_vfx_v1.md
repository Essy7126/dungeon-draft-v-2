# Garde d’airain — effet en sprites V1

Premier effet de sort dessiné branché sur l’Achille en sprites, dans le combat réel de la Cour des Sources. Le dessin vient d’ImageGen intégré ; le pipeline Node/Sharp ne fait que découper, recaler et assembler ses pixels et son alpha.

## Rendu

Une fine protection d’or bronze, un accent turquoise et un chevron clair apparaissent autour du personnage. L’intérieur est transparent pour garder le visage, l’équipement et les appuis lisibles. Le premier essai, trop proche d’un portail massif, reste conservé comme exploration ; la deuxième planche est la source utilisée.

| Phase | Dessins | Lecture |
|---|---|---|
| Apparition | 8 | 0,50 s, au gain réel de bouclier |
| Protection active | 1 | Pose fixe tant que les points de bouclier restent positifs |
| Impact absorbé | 4 | 0,25 s, puis retour à la protection active |
| Dissipation | 4 | 0,30 s, avec disparition douce de la fin |

Le maintien ne redémarre pas un effet périodique. Le même sprite reste attaché aux pieds du personnage et suit son déplacement, sa profondeur et son échelle de présentation. La mort et la destruction de la vue nettoient l’effet. Une nouvelle application remplace la précédente pour éviter l’empilement.

## Fichiers et réutilisation

- [Sources et prompts de génération](../../../art/source/vfx/achilles_guard_bronze_v1/).
- [Atlas transparents et manifeste](../../../vfx/assets/flipbooks/achilles_guard_bronze_v1/).
- [Pipeline reproductible](../../../tools/guard_sprite_pipeline/README.md).
- [Profil des phases](../../../vfx/profiles/achilles_guard_bronze_v1/guard_profile.tres).
- [Scène utilisée par le sort](../../../battle/vfx/achilles_guard_sprite_vfx.tscn).
- [Contrôleur de bouclier réutilisable](../../../vfx/runtime/vfx_shield_sprite_effect.gd).

Le profil réutilise la fondation `VFXProfile` et `FlipbookModule` existante. Pour un autre bouclier, on peut fournir de nouveaux atlas et dupliquer le profil/la scène, en conservant le contrôleur. Les durées et opacités se règlent dans les modules ; la taille se règle sur la scène. Les autres catégories de sorts demanderont leur propre raccord aux événements de gameplay.

Le sort conserve son coût de 2 PA, sa limite d’utilisation et ses 10 points de bouclier. L’effet observe le résultat : il n’accorde aucun point, ne calcule aucun dégât et ne modifie ni le rig ni les animations d’Achille.

## Essai

Relancer la Cour des Sources avec son [lanceur](../../../tools/labs/greek_drawn_arena/run_greek_courtyard.ps1), déployer Achille, puis lancer Garde d’airain sur lui-même. Le déplacement reste disponible après le sort et emporte la protection avec le personnage.

Les profils sont marqués `READY_FOR_HUMAN_REVIEW` : il s’agit d’une première proposition artistique jouable, réglable après appréciation du rendu.

## Vérification du 5 septembre 2026

La suite graphique ciblée passe : **70 tests, 1 310 assertions**, dont 9 tests du nouveau bouclier, plus les régressions du lecteur de flipbooks, du studio VFX, du sprite d’Achille et de l’arc de l’elfe. Les tests couvrent aussi pause/reprise, destruction, mort, dédoublonnage et retour de points pendant la dissipation. Les anciennes assertions de référence partagée pour les assets transitoires du studio ont été remplacées par la vérification de l’isolation prévue par le service de snapshots, sans changer ce service.

Le scénario sur la vraie Cour des Sources passe : sélection et lancement de Garde par les entrées GridView, 2 PA consommés, 10 points accordés, maintien fixe, puis déplacement légal d’une case. L’effet reste attaché à l’instance réelle du personnage : erreur d’ancrage et dérive des pieds mesurées à **0 px**. L’absorption 10 → 7 → 0 et la disparition sont vérifiées séparément par des appels contrôlés à `Unit.take_damage`, explicitement identifiés comme `lifecycle_probe` ; ce ne sont pas des actions jouées par l’IA ennemie.

Captures réelles : [apparition](../../../artifacts/guard_sprite_validation_v1/visual/guard_activation.png), [maintien](../../../artifacts/guard_sprite_validation_v1/visual/guard_hold.png), [marche](../../../artifacts/guard_sprite_validation_v1/visual/guard_hold_moving.png), [impact](../../../artifacts/guard_sprite_validation_v1/visual/guard_hit.png), [dissipation](../../../artifacts/guard_sprite_validation_v1/visual/guard_end.png). Le [rapport graphique](../../../artifacts/guard_sprite_validation_v1/visual/runtime_validation.json) précise les entrées utilisées et la portée de chaque contrôle. Les [résultats GUT](../../../artifacts/guard_sprite_validation_v1/gut_final/gut.junit.xml) et le [guide de reproduction](../../../tools/guard_sprite_validation/README.md) sont conservés.

Les vérifications fonctionnelles réussissent, mais les sorties Godot ne sont pas exemptes d’erreurs : les avertissements de ressources/RID non libérés à la fermeture restent présents, ainsi qu’une reprise asynchrone de `UnitView` après destruction dans la fermeture GUT. La suite indique également 14 orphelins, dont un contrôle du studio terrain. Ces messages sont conservés dans les journaux ; ce résultat ne vaut pas validation d’un arrêt propre de toute l’application. Le bouclier lui-même est supprimé après épuisement, mort et destruction de sa vue dans les contrôles dédiés.

Limite de l’outil comparatif : changer de variante de présentation d’Achille pendant une garde conserve l’échelle de l’aura choisie lors de sa création. Le déplacement, le zoom et le redimensionnement ordinaires héritent correctement de la vue.
La [passe sans captures](../../../artifacts/guard_sprite_validation_v1/timing/runtime_validation.json) passe également. Les transitions observées donnent 510,8 ms pour l’activation, 243,2 ms pour l’impact et 308,6 ms entre l’épuisement du bouclier et sa suppression. Les cibles sont 500 / 250 / 300 ms ; l’échantillonnage des changements de phase se fait entre les frames du moteur. Toutes les images de l’activation et de l’impact ont été observées. Le maintien reste à `elapsed = 0`, et la dérive d’ancrage reste nulle.

L’[aperçu animé capturé dans le jeu](../../../artifacts/guard_sprite_validation_v1/gameplay_clip/clip/garde_airain_gameplay.gif) montre les quatre phases et le déplacement. Il contient 79 captures du vrai viewport dans un cadre fixe, agrandies deux fois pour la lecture ; leurs timestamps définissent la durée du GIF. Les dégâts y restent le scénario contrôlé décrit plus haut. Cette capture GPU sert à montrer le rendu, pas à mesurer la cadence. Les images PNG, le manifeste et le rapport d’encodage sont conservés avec le GIF.