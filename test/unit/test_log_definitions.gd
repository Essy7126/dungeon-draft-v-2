extends GutTest

const LogDefinitions = preload("res://debug/log_definitions.gd")
const CombatLoggerScript = preload("res://core/combat_logger.gd")
const UnitScript = preload("res://units/unit.gd")
const SpellCasterScript = preload("res://core/spell_caster.gd")
const TerrainEffectsScript = preload("res://core/terrain_effects.gd")
const EnemyAIScript = preload("res://core/enemy_ai.gd")
const BossPersephoneScript = preload("res://core/ai/boss_persephone.gd")


func test_logger_preserve_son_api_publique() -> void:
	assert_eq(DebugLogger.LogLevel, LogDefinitions.LogLevel)
	assert_eq(DebugLogger.LogCategory, LogDefinitions.LogCategory)


func test_raccourcis_utilisent_les_definitions_canoniques() -> void:
	assert_eq(CombatLoggerScript.CAT_COMBAT, LogDefinitions.LogCategory.COMBAT)
	assert_eq(CombatLoggerScript.CAT_STATS, LogDefinitions.LogCategory.STATS)
	assert_eq(UnitScript.CAT_COMBAT, LogDefinitions.LogCategory.COMBAT)
	assert_eq(UnitScript.CAT_STATS, LogDefinitions.LogCategory.STATS)
	assert_eq(SpellCasterScript.CAT_SPELL, LogDefinitions.LogCategory.SPELL)
	assert_eq(TerrainEffectsScript.CAT, LogDefinitions.LogCategory.TERRAIN)
	assert_eq(EnemyAIScript.CAT, LogDefinitions.LogCategory.AI)
	assert_eq(BossPersephoneScript.CAT, LogDefinitions.LogCategory.AI)
