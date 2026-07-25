extends RefCounted

enum LogLevel {
	TRACE = 0,
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
}

enum LogCategory {
	COMBAT,
	AI,
	STATS,
	SPELL,
	TERRAIN,
	TURN,
	PATHFINDING,
	SYSTEM,
}
