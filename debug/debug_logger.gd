# DebugLogger.gd
# À ajouter dans Project > Project Settings > Autoload

extends Node

enum LogLevel {
	TRACE = 0,
	DEBUG = 1,
	INFO  = 2,
	WARN  = 3,
	ERROR = 4
}

enum LogCategory {
	COMBAT,
	AI,
	STATS,
	SPELL,
	TERRAIN,
	TURN,
	PATHFINDING,
	SYSTEM
}

const CATEGORY_LABELS := {
	LogCategory.COMBAT:      "[COMBAT]",
	LogCategory.AI:          "[AI]",
	LogCategory.STATS:       "[STATS]",
	LogCategory.SPELL:       "[SPELL]",
	LogCategory.TERRAIN:     "[TERRAIN]",
	LogCategory.TURN:        "[TURN]",
	LogCategory.PATHFINDING: "[PATH]",
	LogCategory.SYSTEM:      "[SYS]",
}

const LEVEL_LABELS := {
	LogLevel.TRACE: "TRACE",
	LogLevel.DEBUG: "DBG",
	LogLevel.INFO:  "INFO",
	LogLevel.WARN:  "WARN",
	LogLevel.ERROR: "ERR",
}

const LEVEL_COLORS := {
	LogLevel.TRACE: Color(0.6, 0.6, 0.6),
	LogLevel.DEBUG: Color(0.8, 0.8, 1.0),
	LogLevel.INFO:  Color(1.0, 1.0, 1.0),
	LogLevel.WARN:  Color(1.0, 0.85, 0.2),
	LogLevel.ERROR: Color(1.0, 0.3, 0.3),
}

# Config
var min_level: LogLevel = LogLevel.TRACE
var enabled_categories: Dictionary = {}  # LogCategory -> bool
var max_entries: int = 200

# State
var entries: Array[Dictionary] = []
var turn_number: int = 0

signal log_added(entry: Dictionary)

func _ready() -> void:
	# Toutes les catégories activées par défaut
	for cat in LogCategory.values():
		enabled_categories[cat] = true

func _log(level: LogLevel, category: LogCategory, message: String, context: Dictionary = {}) -> void:
	if level < min_level:
		return
	if not enabled_categories.get(category, true):
		return

	var entry := {
		"level":    level,
		"category": category,
		"message":  message,
		"context":  context,
		"turn":     turn_number,
		"time":     Time.get_ticks_msec(),
	}

	entries.append(entry)
	if entries.size() > max_entries:
		entries.pop_front()

	_print_to_console(entry)
	log_added.emit(entry)

# Raccourcis
func trace(cat: LogCategory, msg: String, ctx: Dictionary = {}) -> void:
	_log(LogLevel.TRACE, cat, msg, ctx)

func debug(cat: LogCategory, msg: String, ctx: Dictionary = {}) -> void:
	_log(LogLevel.DEBUG, cat, msg, ctx)

func info(cat: LogCategory, msg: String, ctx: Dictionary = {}) -> void:
	_log(LogLevel.INFO, cat, msg, ctx)

func warn(cat: LogCategory, msg: String, ctx: Dictionary = {}) -> void:
	_log(LogLevel.WARN, cat, msg, ctx)

func error(cat: LogCategory, msg: String, ctx: Dictionary = {}) -> void:
	_log(LogLevel.ERROR, cat, msg, ctx)

func set_turn(t: int) -> void:
	turn_number = t

func clear() -> void:
	entries.clear()

func get_filtered(level_min: LogLevel, categories: Array) -> Array:
	return entries.filter(func(e):
		return e.level >= level_min and (categories.is_empty() or e.category in categories)
	)

func _print_to_console(entry: Dictionary) -> void:
	var prefix := "[T%02d][%s]%s " % [
		entry.turn,
		LEVEL_LABELS[entry.level],
		CATEGORY_LABELS[entry.category]]
	var full: String = prefix + entry.message
	if not entry.context.is_empty():
		full += " | " + str(entry.context)

	match entry.level:
		LogLevel.WARN:  push_warning(full)
		LogLevel.ERROR: push_error(full)
		_:              print(full)
