# Couverture des champs UI V1.1

- Statut : **CURRENT**
- Branche : `feature/observatory-truth-v1-1`, finalisation sur `feature/observatory-frontend-v1-1`.
- Commit de référence : schéma et types du commit snapshot V1.1 `b9e5a0161fc88cede9de9bd618298d1531d0b09a`.
- Date UTC : `2026-08-06T10:45:38Z`
- Validation : comparaison JSON Schema → TypeScript → composants, tests du snapshot réel et tests de pages.

`displayed` signifie visible directement ou dans un panneau repliable. `technical_only` signifie conservé dans les détails de provenance. `intentionally_hidden` est réservé aux champs sans valeur utilisateur immédiate ; aucun champ métier n’est supprimé du type TypeScript.

| Domaine | displayed | technical_only | intentionally_hidden |
|---|---|---|---|
| `meta` | `source_game_commit`, `source_branch`, `generated_at_utc`, `source_worktree_dirty_before_export`, `source_git_available`, `source_generated_from_clean_checkout` | `schema_version`, `generator_version`, `godot_version`, `project_name`, `contract_version`, `manifest_version` | aucun |
| `summary` | tous les compteurs, dont profils rédigés/sélectionnés/min/max | aucun | aucun |
| `contract.decisions` | `key`, `value`, `status`, `truth_status`, `source`, `rationale` | aucun | aucun |
| `runtime_facts` | `key`, `value`, `truth_status`, `evidence`, `notes` | `source_paths` | aucun |
| `character` | `id`, `name`, `description`, `role`, `presentation_summary`, `progression_summary`, `presentation_badge`, `max_hp`, `max_ap`, `max_mp`, `initiative`, `attack_power`, `force`, `armour`, `magic_resistance`, `dodge`, `critical_chance`, `critical_multiplier`, `resistances`, `basic_attack_enabled`, `active_spell_slots`, `spell_ids`, `discipline_ids` | `team`, chemins visuels et `source_path` | aucun |
| `spell` | identité, coûts, portées, cibles, zone, dégâts/soin/bouclier, `initial_cooldown`, `once_per_activation`, `line_from_caster`, `critical_chance`, `collision_damage`, `cluster_bonus_damage`, `ap_drain`, `teleport_behind_target`, `delayed_resolution`, invocation, statuts, `modifiers`, `serialization_warnings` | chemins icône/VFX/son/source, références de Resource et propriétaires | aucun |
| `item` | identité, rareté, tags, catégorie, emplacement, limite, compatibilité, modificateurs, effet/valeur d’usage, états équipable/consommable/valide, pools | profils FX/audio et chemins d’images/source | aucun |
| `run` | nom, seed, durées, salles, profils rédigés/sélectionnés/min/max et maxima PV/attaque/récompense | identité, source et erreurs de validation | aucun |
| `room` | nom, type de carte, dimensions, profils disponibles/min/max/sélectionnés, rencontres, spawns, récompense ultime et validation | chemins Resource, stratégie de résolution et identité dérivée | aucun |
| `wave` | nom, sélection, caractère obligatoire/optionnel, trois multiplicateurs, cibles runtime, totaux calculés, statuts et preuve | identité, source et erreurs | aucun |
| `encounter` | roster, totaux, rôles, factions, plafonds, budgets, capacités désactivées, formations, contraintes et validation | identité, chemins et preuve de calcul | aucun |
| `enemy` | identité, portée de présence, statistiques complètes, sorts, IA, faction/rôle, passifs, tags et validation | chemins visuels/source et stabilité d’identité | aucun |
| `enemy_spell` | mêmes champs métier que `spell`, contexte actif/désactivé/conditionnel par rencontre et tags | références ennemies, chemins et paramètres d’invocation détaillés | aucun |
| `ai_profile` | stratégie, rôles, seuils, distances et préférences | ID, source et ennemis référents | aucun |
| `contract_check` | cible, observé, santé, nature de preuve, entités affectées, preuve et message | aucun | aucun |
| `audit_result` | règle, libellé, sévérité, nature de preuve, statut, domaine, entités, message, preuve et recommandation | chemin source et ID technique | aucun |
