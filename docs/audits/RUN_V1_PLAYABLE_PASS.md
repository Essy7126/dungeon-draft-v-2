# RUN V1 PLAYABLE — Elfe / Mage / Guerrier

Verdict final : **RUN_V1_PLAYABLE_PASS_COMPLETE_WITH_WARNINGS**.

La première run conserve exactement le trio Elfe, Mage et Guerrier. Le Guerrier fonctionne désormais uniquement avec PV, PA, PM, états, terrain, poussées, collisions et progression. Aucun modèle 3D, GLB, matériau ou fichier Blender n'a été modifié. Aucun commit ni push n'a été effectué.

## 1. Sécurité Git et état initial

- Branche : `main`
- HEAD initial et final : `bd88b7a4515d965b32bc305759f799aadf0c9cb4`
- La copie locale était déjà modifiée avant cette passe. Les changements existants, notamment l'intégration 3D du Guerrier, `battle/battle.gd`, `battle/unit_view.gd`, `PartyPresentationScreen.tscn`, le thème du Guerrier et plusieurs tests du trio, ont été conservés.
- Les ressources historiques du Guerrier (`rage.tres`, `chassis_guerrier.tres`, `trait_chassis_guerrier.gd`) sont toujours présentes.
- `.claude/settings.local.json` n'a pas été modifié ni supprimé.
- `git diff --check` final : aucune erreur.
- État final : worktree volontairement non propre, sans commit et sans push. Le diff suivi combiné de la copie locale compte 29 fichiers, 292 insertions et 129 suppressions ; les ressources et preuves nouvelles restent non suivies.

Suite initiale relevée avant la passe : 367/372 tests et 6 325/6 341 assertions, avec cinq échecs Elfe déjà présents.

## 2. Audit du trio verrouillé

| Personnage | PA / PM | Énergie active | Châssis énergétique | Sorts actifs | Disciplines | HUD de production |
|---|---:|---|---|---:|---:|---|
| Elfe | 6 / 3 | non | non | 4 | 4 | PA/PM, aucun contrôle énergie visible |
| Mage | 6 / 3 | non | non | 4 | 4 | PA/PM, aucun contrôle énergie visible |
| Guerrier | 6 / 3 | non | non | 8 | 3 | PA/PM, aucun contrôle énergie visible |

La voie de présentation conserve l'ordre `elf`, `mage`, `warrior`. Le Gardien reste chargeable séparément et n'est pas ajouté à la première run. La run fixe contient quatre salles. Les tests de présentation, construction, cycle de vie et progression valident la transition des données entre salles ; la scène de revue déploie le trio dans la vraie salle 1.

## 3. Retrait de Rage / Ferveur / Éveil / Garde

Dans `Guerrier.tres`, les références actives `energy_type` et `chassis_trait` ont été retirées. Les huit sorts ont désormais :

- `fervor_cost = 0` ;
- `energy_generated = 0` ;
- `imprint_fervor_cost = 0` ;
- `charge_verb = ""`.

Résultat runtime :

- `Warrior.has_energy() == false` ;
- aucun trait Châssis Guerrier instancié ;
- aucune génération d'énergie par attaque, poussée ou collision ;
- aucune barre ou étiquette d'énergie ;
- aucun bouton Éveil ou Garde/Réaction ;
- aucun signal de ces deux actions connecté dans le HUD Refined de production.

Les systèmes génériques et ressources legacy n'ont pas été supprimés afin de préserver les contenus historiques.

## 4. Coûts PA finaux

| Discipline | ID stable | Sort | Coût |
|---|---|---|---:|
| Briseur | `warrior_shove` | Bourrade | 1 PA |
| Briseur | `warrior_hook` | Crochet | 2 PA |
| Briseur | `warrior_shoulder_charge` | Coup d'épaule | 3 PA |
| Briseur | `warrior_shockwave` | Onde de choc | 4 PA |
| Bourreau | `warrior_war_mark` | Marque de guerre | 2 PA |
| Bourreau | `warrior_execution` | Exécution de guerre | 4 PA |
| Saccageur | `warrior_stomp` | Piétinement | 2 PA |
| Saccageur | `warrior_corrupted_ground` | Sol corrompu | 4 PA |

Les trois combinaisons de référence tiennent dans le budget réel de 6 PA : Crochet + Coup d'épaule + Bourrade, Marque + Exécution, Piétinement + Sol corrompu. Les dégâts, zones, poussées, attraction, collisions, Marque et terrains existants ont été conservés.

## 5. Arbre de compétences du Guerrier

Les données se trouvent sous `res://data/characters/warrior/` et utilisent `CharacterRunState` et `CharacterProgressionService` existants.

| Discipline | ID | Rang 2 — 3 XP | Rang 3 — 7 XP |
|---|---|---|---|
| Briseur | `warrior_breaker` | Bourrade motrice / Crochet allongé | Charge écrasante / Onde résonnante |
| Bourreau | `warrior_executioner` | Marque distante / Marque cruelle | Sentence finale / Exécution invalidante |
| Saccageur | `warrior_ravager` | Piétinement violent / Piétinement tellurique | Corruption distante / Sol hostile |

Total : 3 disciplines, 3 accès de rang 1 et **12 choix réels** aux rangs 2 et 3. Chaque paire d'un même rang est mutuellement exclusive. Les douze améliorations reposent sur des `SpellModifier` data-driven existants : portée, poussée, dégâts de collision ou centraux et effets de déplacement au tour suivant.

Validation réelle : trois casts Briseur donnent exactement 3 XP, l'arbre s'ouvre, `warrior_breaker_driving_shove` est acquis, puis Bourrade pousse effectivement la cible de deux cases au lieu d'une.

## 6. Profil d'animations

Le mapping de production utilise d'abord `spell_id`, avec le `resource_path` uniquement comme repli de compatibilité. `spell_name` n'est pas utilisé comme identifiant.

| Spell ID | Action | Vitesse | Impact normalisé | Impact visuel après calibration | Durée finale |
|---|---|---:|---:|---:|---:|
| `warrior_shove` | `DD_Warrior_Attack` | 7,15 | 0,7191 | 0,597 s | 0,830 s |
| `warrior_hook` | `DD_Warrior_Parry` | 1,00 | 0,5879 | 0,333 s | 0,567 s |
| `warrior_shoulder_charge` | `DD_Warrior_SpinAttack` | 5,75 | 0,2294 | 0,226 s | 0,986 s |
| `warrior_shockwave` | `DD_Warrior_SpinAttack` | 5,75 | 0,2294 | 0,226 s | 0,986 s |
| `warrior_war_mark` | `DD_Warrior_Attack` | 7,15 | 0,7191 | 0,597 s | 0,830 s |
| `warrior_execution` | `DD_Warrior_HeavyAttack` | 3,90 | 0,3511 | 0,393 s | 1,120 s |
| `warrior_stomp` | `DD_Warrior_SpinAttack` | 5,75 | 0,2294 | 0,226 s | 0,986 s |
| `warrior_corrupted_ground` | `DD_Warrior_HeavyAttack` | 3,90 | 0,3511 | 0,393 s | 1,120 s |

Le Basic Attack reste `DD_Warrior_Attack`. Quatre profils offensifs distincts sont réellement utilisés : Attack, Parry, SpinAttack et HeavyAttack. Exécution est plus lourde que Marque, et Onde de choc se distingue de Bourrade.

### Durées avant / après

| Action | Avant | Après | Cible respectée |
|---|---:|---:|---|
| Attack | 5,933 s | 0,830 s | oui |
| SpinAttack | 5,667 s | 0,986 s | oui |
| HeavyAttack | 4,367 s | 1,120 s | oui |
| Parry | 0,567 s | 0,567 s | oui |
| Hit | 1,233 s | 0,484 s | oui |
| Death | 2,967 s | 1,447 s théorique ; 1,464 s mesurée | oui |

Durée moyenne des huit gestes de sorts : environ **4,771 s avant** et **0,928 s après**, soit une réduction d'environ 80,6 %. Les temps d'impact observés en salle 1 sont compris entre 0,254 s et 0,651 s selon l'Action et les frais de résolution.

Chaque sort validé émet exactement un `cast_release_reached` et un événement `spell_cast`. Les dégâts ne sont jamais produits par l'animation. Coup d'épaule conserve légitimement ses deux événements de dégâts de gameplay (impact puis collision). Sol corrompu peut légitimement interrompre HeavyAttack par Hit, car sa zone touche aussi le lanceur.

Hit revient à Idle. Death reste prioritaire, dure 1,464 s, libère l'ancienne cellule, laisse la cellule logique à `(-1, -1)`, garde `UnitView` et la racine ISO immobiles et conserve le visuel jusqu'à `death_animation_finished`.

## 7. HUD compact RUN V1

La ressource `res://data/ui/combat_hud_layout_run_v1_compact.tres` remplace la grande configuration Clean dans `PersistentRunUI`.

| Mesure à 1080p | Avant | Après |
|---|---:|---:|
| Hauteur | 220 px | 108 px |
| Part verticale | 20,37 % | 10,00 % |
| Portrait | 114 px | 80 px |
| Barre PV | 230 × 30 px | 180 × 18 px |
| Slot | 100 px | 70 px |
| Icône | 80 px | 54 px |
| Section personnage | 350 px | 290 px |
| Fin de tour | 195 × 58 px | 138 × 42 px |
| Opacité plaque | 0,90 | 0,78 |

La hauteur a diminué de 50,9 %. Les huit sorts tiennent sur une seule rangée sans défilement et sans recouvrir le personnage ou la fin de tour. Les boutons Inventaire et Carte, indisponibles, ne créent plus une seconde bande dans le mode compact ; Compétences reste accessible et son raccourci K fonctionne.

Les slots 1 à 8 ont maintenant de vrais raccourcis clavier `1` à `8`, en plus de leurs libellés. Les noms longs sont coupés avec ellipse. Le cas synthétique `12 PA`, l'état indisponible, la taille de police minimale et la carte d'infobulle ont été testés à 720p.

## 8. Responsive

| Résolution | Taille calculée du HUD | Part verticale | Huit slots / chevauchement |
|---|---:|---:|---|
| 1280 × 720 | 1000 × 86,4 px | 12,00 % | validé / aucun |
| 1600 × 900 | 1041,7 × 90 px | 10,00 % | validé / aucun |
| 1920 × 1080 | 1250 × 108 px | 10,00 % | validé / aucun |
| 2560 × 1440 | 1375 × 118,8 px | 8,25 % | validé / aucun |

Les quatre résolutions sont couvertes par le test contractuel. Les captures 720p, 1080p et 1440p confirment visuellement que les coûts restent lisibles, que Fin de tour reste utilisable et que la scène demeure majoritairement visible. Les HUD à quatre sorts de l'Elfe et du Mage restent pris en charge par les tests multi-personnages.

## 9. Validation gameplay et performances

La revue automatisée de la vraie salle 1 valide :

- trio `elf`, `mage`, `warrior` et changement de personnage/tour ;
- Guerrier sélectionné avec 6 PA, 3 PM, huit sorts et aucune énergie ;
- cinq casts réels dans la revue vidéo et les huit sorts dans la scène d'intégration complète ;
- quatre gestes offensifs distincts ;
- coûts et états actif/inactif mis à jour ;
- déplacement d'une case avec erreur finale 0 et racine ISO stable ;
- arbre ouvert, XP gagné, choix acquis et effet réel appliqué ;
- couche VFX vide après résolution ;
- Hit et Death validés ;
- Guerrier restauré vivant en Idle pour l'état final.

Mesure principale à 1920 × 1080 : **157,39 FPS moyens**, **111 FPS minimum**, 251 échantillons.

| Phase d'intégration 3D | FPS moyen | FPS minimum |
|---|---:|---:|
| Trio Idle | 136,00 | 136 |
| Trois visuels en mouvement | 153,87 | 136 |
| Attaque Guerrier | 165,00 | 165 |
| Plusieurs ennemis | 165,00 | 165 |
| Death | 161,62 | 160 |

## 10. Tests finaux

| Lot | Résultat | Assertions |
|---|---:|---:|
| Contrat RUN V1 | 7/7 | 290 |
| Guerrier + progression + HUD + trio | 140/140 | 4 180 |
| Suite complète | 374/379 | 6 632/6 648 |

Les cinq échecs de la suite complète sont identiques à l'état initial et hors périmètre :

1. migration `venomous_blade` dans `test_elf_archer_skill_tree.gd` ;
2. deux tests de poison Lame venimeuse dans `test_elf_rank_two_disciplines.gd` ;
3. choix croisés de rang 2 dans `test_elf_rank_two_disciplines.gd` ;
4. nettoyage des modificateurs rang 2 dans `test_progression_lifecycle.gd`.

GUT signale aussi à la fermeture des instances et ressources encore référencées. Ces diagnostics de l'outil existaient avant la passe et apparaissent après les résumés de tests.

Journaux :

- `C:\Blender_AI_Test\Output\run_v1_gut_contract.log`
- `C:\Blender_AI_Test\Output\run_v1_gut_targeted.log`
- `C:\Blender_AI_Test\Output\run_v1_gut_full.log`
- `C:\Blender_AI_Test\Output\run_v1_playable_runtime.json`
- `C:\Blender_AI_Test\Output\godot_warrior_first_playable_integration.json`

## 11. Captures et vidéo

Répertoire : `res://artifacts/run_v1_playable_pass/`.

Captures requises présentes :

- `hud_before_1080p.png`
- `hud_compact_720p.png`
- `hud_compact_1080p.png`
- `hud_compact_1440p.png`
- `warrior_breaker_animation.png`
- `warrior_execution_animation.png`
- `warrior_ravager_animation.png`
- `warrior_skill_tree.png`
- `warrior_no_energy_ui.png`
- `trio_run_playable.png`

Vidéo : `run_v1_playable_review.mp4`.

- 293 images ;
- 9,77 s ;
- 30 FPS ;
- 1200 × 896, viewport natif du projet en Movie Maker ;
- H.264 High, 4:2:0, sans piste audio ;
- taille : 1 863 865 octets ;
- SHA-256 : `1949884E2F6E5A50C28019EFDED7AC10C789C88E2DF70B25994C9917D9EB8388`.

Le fichier AVI Movie Maker intermédiaire est conservé à côté du MP4. L'option de fenêtre 1920 × 1080 ne remplace pas le viewport interne 1200 × 896 utilisé par Godot pour `--write-movie`; le ratio natif a été conservé afin de ne pas déformer l'image.

## 12. Fichiers créés ou modifiés par la passe

### Données de production

- `data/unit_data.gd`
- `core/game_manager.gd`
- `data/units/alliés/Guerrier.tres`
- les huit ressources sous `data/spells/Guerrier/`
- `data/ui/warrior_hud_theme_refined.tres`
- `data/ui/combat_hud_layout_run_v1_compact.tres`
- 9 ressources de discipline/rang, 12 upgrades et 12 modifiers sous `data/characters/warrior/`

### Animation et interface

- `characters/warrior/warrior_visual_3d.gd`
- `characters/warrior/warrior_iso_unit_view.gd`
- `ui/run/PersistentRunUI.tscn`
- `ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd`
- `ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn`
- `battle/battle.gd` : option générique d'affichage des panneaux auxiliaires uniquement
- `data/rooms/maps/battle_salle1_iso.tscn` : panneaux auxiliaires et overlay debug masqués dans la première salle

### Tests et preuves

- `test/unit/test_run_v1_playable_pass.gd`
- mise à jour des contrats Guerrier, progression, HUD, trio et présentation dans `test/unit/`
- `tests/characters/warrior/RunV1PlayableReview.tscn`
- `tests/characters/warrior/run_v1_playable_review.gd`
- `artifacts/run_v1_playable_pass/`
- `docs/audits/RUN_V1_PLAYABLE_PASS.md`

Les fichiers 3D et plusieurs fichiers d'intégration Guerrier non suivis étaient déjà présents au début de la mission ; ils ont été préservés. Aucun fichier GLB ou texture source n'a été modifié.

## 13. Dettes et avertissements non bloquants

1. Les huit sorts du Guerrier n'ont pas de `vfx_scene` dédiée. Le feedback générique, la résolution et le nettoyage ont été validés ; aucun VFX résiduel n'est présent.
2. Cinq tests Elfe préexistants restent rouges et doivent être traités dans une passe distincte.
3. GUT 9.7.1 émet des diagnostics de ressources/instances à la fermeture, y compris après un lot ciblé 140/140 vert.
4. La vidéo Movie Maker utilise le viewport natif 1200 × 896, tandis que les preuves statiques responsive sont bien en 1280 × 720, 1920 × 1080 et 2560 × 1440.

Ces avertissements n'empêchent pas la première run Elfe / Mage / Guerrier d'être jouable avec le nouveau contrat PA/PM et le HUD compact.
