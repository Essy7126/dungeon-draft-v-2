class_name UISnapshotRegistry
extends RefCounted

const Scenario := preload("res://tools/ui_snapshots/ui_snapshot_scenario.gd")


static func production_scenarios() -> Array[UISnapshotScenario]:
	return [
		Scenario.new(&"title", &"default", "res://ui/TitreEcran.tscn", &"no_save", &"title"),
		Scenario.new(&"start_hub", &"idle", "res://hub/StartHub.tscn", &"hub_default", &"hub"),
		Scenario.new(&"start_hub", &"archivist_menu", "res://hub/StartHub.tscn", &"hub_archivist", &"hub_archivist"),
		Scenario.new(&"start_hub", &"archivist_dialogue", "res://hub/StartHub.tscn", &"hub_archivist", &"documented", &"production", "Le dialogue exige une intention d'interaction arrivée à destination ; fixture d'entrée non exposée."),
		Scenario.new(&"start_hub", &"run_room_selection", "res://hub/StartHub.tscn", &"hub_archivist", &"documented", &"production", "L'état est inventorié mais son API de test est privée au panneau."),
		Scenario.new(&"start_hub", &"trade", "res://hub/StartHub.tscn", &"hub_trade", &"documented", &"production", "Le contenu marchand dépend du catalogue runtime et ne possède pas encore de fixture publique."),
		Scenario.new(&"intro_cinematic", &"plan_05", "res://cinematics/intro/intro_cinematic.tscn", &"intro_t_42_5", &"intro"),
		Scenario.new(&"room_transition", &"default", "res://ui/Transitionsalle.tscn", &"first_run_room_01", &"documented", &"production", "L'écran lit un run actif et ne propose pas d'injection de snapshot sans muter GameManager."),
		Scenario.new(&"battle", &"deployment", "res://data/rooms/maps/painted_battle.tscn", &"first_run_room_01_seed_1337", &"battle"),
		Scenario.new(&"battle_hud", &"ally_turn", "res://ui/run/PersistentRunUI.tscn", &"first_run_room_01_seed_1337", &"documented", &"production", "Le tour actif nécessite l'avancement de la vraie TurnQueue ; aucun crochet de gel public."),
		Scenario.new(&"battle_hud", &"hero_selected", "res://ui/run/PersistentRunUI.tscn", &"first_run_room_01_seed_1337", &"documented", &"production", "La sélection dépend d'une UnitView de combat active."),
		Scenario.new(&"battle_hud", &"spell_selected", "res://ui/run/PersistentRunUI.tscn", &"first_run_room_01_seed_1337", &"documented", &"production", "L'état cible requiert le contrôleur de bataille et un sort disponible."),
		Scenario.new(&"battle_hud", &"valid_target", "res://data/rooms/maps/painted_battle.tscn", &"first_run_room_01_seed_1337", &"documented", &"production", "Le survol déterministe n'est pas injecté dans la grille de production."),
		Scenario.new(&"battle_hud", &"invalid_target", "res://data/rooms/maps/painted_battle.tscn", &"first_run_room_01_seed_1337", &"documented", &"production", "Le survol déterministe n'est pas injecté dans la grille de production."),
		Scenario.new(&"inventory", &"filled", "res://ui/inventory/InventoryScreen.tscn", &"starting_inventory", &"documented", &"production", "L'écran est possédé par PersistentRunUI et requiert les CharacterRunState du run."),
		Scenario.new(&"skill_tree", &"default", "res://ui/progression/screens/skill_tree_screen.tscn", &"elf_archer_rank_1", &"documented", &"production", "La liaison CharacterRunState est pilotée par PersistentRunUI."),
		Scenario.new(&"skill_evolution", &"choice", "res://ui/progression/evolution/SkillEvolutionOverlay.tscn", &"elf_rank_2", &"documented", &"production", "L'overlay attend une évolution mise en file par le service de progression."),
		Scenario.new(&"pause_menu", &"default", "res://ui/menus/dark_pause_menu.tscn", &"combat_mode", &"documented", &"production", "La pause globale modifierait SceneTree pendant une capture groupée."),
		Scenario.new(&"post_combat", &"decision", "res://ui/post_combat/PostCombatScreen.tscn", &"victory_room_01", &"documented", &"production", "Un CombatReport finalisé et l'état de récompense sont requis ; le runner historique reste la référence provisoire."),
		Scenario.new(&"post_combat", &"equipment_reward", "res://ui/post_combat/EquipmentRewardOverlay.tscn", &"reward_two_relics", &"documented", &"production", "Déjà couvert par tools/labs/equipment_reward ; consolidation différée pour ne pas dupliquer la fixture."),
		Scenario.new(&"run_result", &"victory", "res://ui/RunResultScreen.tscn", &"first_run_victory", &"documented", &"production", "L'écran dépend de GameManager.get_last_run_result()."),
		Scenario.new(&"combat_feedback", &"gallery", "res://tools/ui_snapshots/CombatFeedbackGallery.tscn", &"combat_feedback_gallery_v1", &"feedback_gallery"),
		Scenario.new(&"arena_studio", &"workspace", "res://addons/dungeon_draft_arena_studio/ui/studio_workspace.gd", &"arena_studio_current_worktree", &"documented", &"production", "Travail local Arena Studio en cours ; ses fichiers et captures sont préservés et exclus de cette mission."),
	]
