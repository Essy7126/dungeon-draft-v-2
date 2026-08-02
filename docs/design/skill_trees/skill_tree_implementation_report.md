# Rapport d’implémentation des douze arbres

## Résultat

Le trio fixe possède 12 arbres chargés, 19 nœuds par arbre et 228 nœuds au total : 12 racines R1 et 216 choix R2–R5. Les seuils sont 0, 3, 7, 12 et 18 XP. Chaque sort réussi crédite uniquement sa discipline. Les choix utilisent `CharacterRunState`, `DisciplineProgressState`, `SkillTreeResolver` et `SpellModifier`, puis persistent par snapshot pendant la run.

## Matrice de conformité finale

| Personnage | Arbre | Sort | 19 nœuds | Effets fonctionnels | UI fonctionnelle | Tests verts | Hypothèses V1 restantes |
|---|---|---|---:|---|---|---|---|
| Elfe | Archer | Tir précis | Oui | Oui | Oui | Oui | Rafraîchissement des statuts selon le contrat global. |
| Elfe | Assassin | Frappe sournoise | Oui | Oui | Oui | Oui | Cumul/rafraîchissement des statuts ; seuil « passe à » résolu sans double bonus. |
| Elfe | Mage | Boule de feu de l’Elfe | Oui | Oui | Oui | Oui | Valeurs de racine non normalisées ; terrain identique non rafraîchi. |
| Elfe | Soigneur | Soin sylvestre | Oui | Oui | Oui | Oui | Bouclier par remplacement ; Floraison arrondie à l’inférieur. |
| Mage | Pyromancie | Boule de feu | Oui | Oui | Oui | Oui | Valeurs de racine non normalisées. |
| Mage | Cryomancie | Mur de glace | Oui | Oui | Oui | Oui | Forme et durée de base reprises du dépôt. |
| Mage | Foudromancie | Tempête orageuse | Oui | Oui, arc secondaire inclus | Oui | Oui | Cible de l’arc choisie dans un ordre cardinal déterministe. |
| Mage | Géomancie | Onde sismique | Oui | Oui | Oui | Oui | Aucune hypothèse chiffrée supplémentaire. |
| Guerrier | Brutalité | Frappe lourde | Oui | Oui | Oui | Oui | Seuil d’exécution résolu par remplacement. |
| Guerrier | Assaut | Charge | Oui | Oui | Oui | Oui | Trajet de Charge conservateur et sans franchissement. |
| Guerrier | Furie | Tourbillon | Oui | Oui | Oui | Oui | Zone élargie sur les axes cardinaux. |
| Guerrier | Rempart | Garde | Oui | Oui | Oui | Oui | Boucliers par remplacement ; ordre d’attaque à une charge. |

## Extension générique ajoutée

`SpellModSkillTreeEffect` porte les paramètres sérialisés communs aux onze arbres reconstruits : dégâts directs ou conditionnels, soin, portée, zone cardinale, terrain, statut périodique, ralentissement, régénération, vulnérabilité à charges, réduction de dégâts sortants, poussée, collision, bouclier, mobilité du prochain tour, purification, soin adjacent, ordre d’attaque, déplacement de Charge et ciblage de case libre.

Le pipeline de `SpellCaster` possède désormais deux passages génériques supplémentaires : finalisation de la zone avant les autres effets, puis finalisation des agrégats de statuts et de dégâts conditionnels. Aucun effet n’est codé dans `Battle`, `SkillTreeScreen` ou un script de personnage.

## Interface

- Quatre onglets réels par héros, liés par `discipline_id` au sort de base.
- Révélation progressive, deux branches, rangs R1–R5, lignes et détail de nœud.
- États courts : `ACQUIS`, `DISPONIBLE`, `XP REQUISE`, `VERROUILLÉ`, `EXCLU`.
- Icônes de racine issues des sorts et glyphes sémantiques issus des modificateurs.
- Souris, scroll, drag-pan, clavier et manette conservés.
- Profils testés : 1280×720, 1920×1080, 2560×1440.

## Captures

Les captures reproductibles se trouvent dans `res://artifacts/skill_trees/captures/` : douze vues d’arbres, cinq états demandés et trois résolutions. Elles sont générées par `res://tools/capture_skill_trees.tscn`.

## Inventaire de la passe

### Sources créées

- Extension générique : `core/spell_mods/spell_mod_skill_tree_effect.gd` et son sidecar UID.
- Disciplines Guerrier : `data/characters/warrior/disciplines/assault.tres`, `fury.tres`, `bulwark.tres`.
- Sorts Guerrier : `data/spells/Guerrier/frappe_lourde.tres`, `charge.tres`, `tourbillon.tres`, `garde.tres`.
- Statut générique : `data/status/charged_outgoing_damage_data.gd` et son sidecar UID.
- Tests : `test_skill_tree_complete_contract.gd`, `test_skill_tree_generic_effects.gd`, `test_skill_tree_screen_complete_ui.gd` et leurs sidecars UID.
- Outillage : `tools/generate_preview_skill_trees.gd`, `tools/generate_preview_skill_trees.tscn`, `tools/capture_skill_trees.gd`, `tools/capture_skill_trees.tscn` et les sidecars UID des scripts.
- Documentation : `skill_tree_balance_assumptions_v1.md`, `skill_tree_id_migration.md`, présent rapport.
- Captures ignorées par Git : les 12 fichiers `tree_<personnage>_<discipline>.png`, `state_fully_locked.png`, `state_partially_progressed.png`, `state_excluded_branch.png`, `state_rank_5.png`, `state_capstone_detail.png` et les trois fichiers `resolution_<largeur>x<hauteur>.png`, avec leurs imports Godot.

### Sources modifiées

- Progression : `characters/progression/character_run_state.gd`, `discipline_progress_state.gd`.
- Pipeline générique : `core/cast_context.gd`, `core/grid_data.gd`, `core/spell_caster.gd`, `core/spell_modifier.gd`, `units/unit.gd`.
- Arbres complets : `data/characters/elf/disciplines/assassin.tres`, `mage.tres`, `healer.tres`; `data/characters/mage/disciplines/fire.tres`, `ice.tres`, `lightning.tres`, `earth.tres`; `data/characters/warrior/disciplines/breaker.tres`.
- Sorts et héros : les quatre sorts Mage, `data/units/alliés/mage.tres`, `data/units/alliés/Guerrier.tres`, `characters/warrior/warrior_visual_3d.gd`.
- Statuts et présentation : `data/status/status_data.gd`, `charged_damage_vulnerability_data.gd`, les thèmes HUD Mage/Guerrier, le catalogue d’icônes, les trois scripts d’interface d’arbre.
- Tests existants migrés : fondation de progression, tests Archer/Elfe, tests Mage, cycle de progression, cycle du trio et intégration Guerrier.
- Nettoyage de vocabulaire legacy : la description de `data/units/ennemie/run_hurleur_gobelin.tres` ne mentionne plus la Ferveur.

### Sources supprimées

- Arbres partiels Elfe : les six fichiers `assassin_rank_[1-2].tres`, `mage_rank_[1-2].tres`, `healer_rank_[1-2].tres`; les modifiers et upgrades `abundant_sap`, `backstab`, `incandescent_core`, `persistent_embers`, `protective_bark`, `venomous_blade`; `data/status/elf_venomous_blade_poison.tres`.
- Kit legacy Guerrier : `breaker_rank_[1-2].tres`; `executioner.tres` et ses rangs 1–3; `ravager.tres` et ses rangs 1–2; les modifiers et upgrades `crippling_execution`, `cruel_mark`, `distant_mark`, `driving_shove`, `earthen_stomp`, `final_sentence`, `violent_stomp`; les sorts `bourrade.tres`, `execution_de_guerre.tres`, `marque_de_guerre.tres`, `pietinement.tres`.
- Héros retiré : `data/units/alliés/Gardien.tres`, après vérification de l’absence de dépendance active.

Au niveau des nœuds, 209 nœuds de onze arbres ont été reconstruits depuis la preview et les 19 nœuds Archer existants ont été conservés après validation, soit 228 nœuds actifs. Les migrations exactes d’identifiants sont listées dans `skill_tree_id_migration.md`.

## Validation

- Import Godot 4.7 headless final : code de sortie 0, sans erreur de parse ni UID invalide.
- Suite ciblée finale : 34/34 tests et 4 743 assertions pour le contrat structurel, les configurations, le resolver, les effets et l’interface.
- GUT complet au 2026-08-02 : 390/391 et 35 442/35 444 assertions. L’unique échec est préexistant et hors périmètre dans `test_dark_pause_menu.gd` (deux textures de focus du menu pause sont nulles). Les 390 autres tests passent ; aucune correction du menu pause n’a été incluse dans cette passe arbres.
- Audit grep : aucune occurrence d’énergie, Ferveur, Éveil, Empreinte ou coup signature dans les ressources actives des douze arbres et des douze sorts. Les seuls chemins legacy restants sont des assertions de non-existence dans les tests.
- `git diff --check` : aucune erreur.
- Aucun stage, commit ou push n’a été effectué.

## Verdict

`SKILL_TREES_IMPLEMENTED_WITH_ASSUMPTIONS`
