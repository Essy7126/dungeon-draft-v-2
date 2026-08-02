# Intégration du Guerrier comme troisième héros jouable

Verdict : **WARRIOR_FIRST_PLAYABLE_INTEGRATION_COMPLETE_WITH_WARNINGS**.

## Architecture

- Asset : `res://assets/characters/warrior/warrior_character_v01.glb`
- `WarriorVisual3D.tscn` et `warrior_visual_3d.gd` étendent l'architecture générique `CharacterVisual3D`
- `WarriorIsoUnitView.tscn` et `warrior_iso_unit_view.gd` étendent `CharacterIsoUnitView`
- Aucun code de `ElfIsoUnitView` n'a été dupliqué
- SubViewport 768 x 512, MSAA 4X, espace Linear, TAA et FXAA désactivés
- Échelle personnage 1,20 ; occupation verticale Idle mesurée à 70,31 %
- Pivot logique exact aux pieds, `WarriorIsoUnitView.position == Vector2.ZERO`
- Aucun z-index fixe ; le `UnitView` reste enfant direct de `YSortedWorld`
- Montures `RightHandMount`, `LeftHandMount` et `ImpactMount` via `BoneAttachment3D`; aucun marqueur visible ni socket osseux ajouté

Godot importe 24 os et les neuf animations attendues. Le mesh importé conserve 92 780 triangles et un skin valide.

## Contrat d'animation

| État | Animation Godot | Boucle | Déclenchement |
|---|---|---|---|
| Idle | `DD_Warrior_Idle` | oui | état par défaut |
| Walk | `DD_Warrior_Walk` | oui | déplacement dans quatre directions |
| Run | `DD_Warrior_Run` | oui | API visuelle disponible |
| Basic Attack | `DD_Warrior_Attack` | non | signal réel `attack_performed` |
| Spin Attack | `DD_Warrior_SpinAttack` | non | sorts associés |
| Heavy Attack | `DD_Warrior_HeavyAttack` | non | sorts associés |
| Parry | `DD_Warrior_Parry` | non | sorts associés |
| Hit | `DD_Warrior_Hit` | non | dégâts réels reçus |
| Death | `DD_Warrior_Death` | non | mort réelle et cellule libérée |

Les huit ressources de sorts du Guerrier conservent leurs calculs, coûts, Rage et effets. Le visuel choisit l'Action à partir du `resource_path` stable du sort. Les instants de libération sont calibrés sur les impacts Blender. Un appel générique optionnel `play_basic_attack()` a été ajouté à `UnitView`, et `Battle` transmet désormais le `Spell` déjà reçu à `prepare_spell_visual(cell, spell)`. Ces changements sont visuels uniquement et ne changent aucun calcul de gameplay.

## Équipe fixe

La voie principale `PartyPresentationScreen.tscn` présente désormais, dans cet ordre :

1. Elfe
2. Mage
3. Guerrier

La ressource du Gardien et ses scènes restent présentes et chargeables. Les statistiques, la Rage, les huit sorts et le sprite de secours de `Guerrier.tres` sont conservés ; seuls `unit_id = warrior`, `visual_scene`, `preview_visual_scene` et les métadonnées de présentation nécessaires ont été complétés.

## Validation salle 1

Scène : `res://tests/characters/warrior/WarriorSalle1GameplayIntegration.tscn`.

- Déploiement réel : Elfe / Mage / Guerrier
- Guerrier sélectionné et vivant en Idle
- Quatre directions : `DD_Warrior_Walk`, erreur finale de position 0, racine ISO locale stable
- Y-sort : validé derrière et devant une unité de référence sans z-index fixe
- Basic Attack : une occurrence visuelle, un seul événement de dégâts, racines stables après le bump existant
- Huit sorts : un signal de release et un signal `spell_cast` chacun ; aucune action pendante ou VFX résiduel
- Hit : déclenchée par dégâts réels puis retour à Idle
- Death : `death_animation_finished == true`, durée 2,962 s
- Ancienne cellule `[5,4]` libérée ; cellule logique après mort `[-1,-1]`
- `UnitView.global_position` : delta maximal 0
- `WarriorIsoUnitView.global_position` : delta maximal 0
- Visuel présent jusqu'à la fin de Death
- Elfe et Mage restent instanciables et fonctionnels
- Gardien toujours chargeable

`Coup d'épaule` produit deux événements de dégâts sur la cible de référence conformément à son gameplay existant (impact direct et collision). `Sol Corrompu` peut légitimement interrompre HeavyAttack par Hit parce que sa zone inflige aussi des dégâts au Guerrier.

## Tests automatisés

- Contrat Guerrier ciblé : 7/7 tests, 61 assertions, tous réussis.
- Trio fixe, présentation, cycle de vie, construction, HUD et arbre multi-personnage : 38/38 tests, 2 506 assertions, tous réussis.
- Suite unitaire complète : 367/372 tests réussis, 6 325/6 341 assertions.

Les cinq échecs restants sont préexistants et hors périmètre : un test de migration `venomous_blade`, trois tests de disciplines rang 2 de l'Elfe et un test de nettoyage de progression. Aucun de leurs fichiers ni des systèmes concernés n'a été modifié par cette intégration. GUT émet aussi un avertissement préexistant indiquant que `test_dark_pause_menu.gd` n'étend pas `GutTest` et l'ignore.

## Netteté, cadrage et performances

Audit de neuf animations : aucune coupure. Occupation verticale maximale observée : 94,53 % sur SpinAttack, avec marge résiduelle. Attack, HeavyAttack et Death utilisent un cadrage orthographique par Action afin de garder l'intégralité du mouvement visible.

Mesures de la dernière exécution graphique temps réel :

| Phase | FPS moyen | FPS minimum |
|---|---:|---:|
| Trio en Idle | 141,00 | 141 |
| Déplacement des trois visuels | 164,76 | 141 |
| Attaque du Guerrier | 165,00 | 165 |
| Plusieurs ennemis présents | 165,00 | 165 |
| Death | 163,94 | 161 |

- 3 SubViewports
- Environ 201 062 triangles visibles
- Mémoire statique relevée : 142 246 433 octets

## Preuves

- Rapport machine : `C:\Blender_AI_Test\Output\godot_warrior_first_playable_integration.json`
- Journal GUT ciblé : `C:\Blender_AI_Test\Output\gut_warrior_targeted_final.log`
- Journal GUT lié au trio : `C:\Blender_AI_Test\Output\gut_warrior_related_final.log`
- Journal GUT complet : `C:\Blender_AI_Test\Output\gut_full_suite_after_warrior.log`
- Audit d'import : `C:\Blender_AI_Test\Output\warrior_godot_import_audit.json`
- Audit de cadrage : `C:\Blender_AI_Test\Output\warrior_iso_render_audit.json`
- 13 captures : `res://tests/characters/warrior/screenshots/`
- Vidéo temps réel : `res://tests/characters/warrior/warrior_first_playable_review.mp4`
- Vidéo : 31,83 s, 955 images, 1200 x 896, 30 FPS, H.264, yuv420p, sans audio
- SHA-256 vidéo : `974BCE00B521E1FD4AC9887EC2A4A6D396E6ED3F750B1807CB2BE81ED03BCB53`

L'essai natif `--write-movie` avec le renderer headless factice de Godot 4.7.1 a planté avant la première image. La capture finale a été refaite avec le renderer D3D12 normal, puis encodée avec le FFmpeg local déjà isolé. Cet incident n'affecte ni le projet, ni le test temps réel final.

## Avertissements conservés

- Les huit sorts n'ont actuellement pas de `vfx_scene` dédiée. Le gameplay et le nettoyage ont été validés avec une couche VFX vide.
- Death conserve la chute verticale de Hips d'environ 0,638 m. La dérive horizontale originale d'environ 0,693 m a été retirée dans l'Action de production ; un débordement visuel du corps couché vers une case adjacente reste possible.
- Le modèle n'embarque pas d'arme. Les montures de main sont prêtes, mais aucun accessoire artistique n'a été créé.
