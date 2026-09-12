extends RefCounted
## Authored levels are baked into the assets; all cues stay below combat attacks.
const CUES := {
	&"select": ["res://assets/audio/catabase/feedback/select.wav"],
	&"open": ["res://assets/audio/catabase/feedback/open.wav"],
	&"close": ["res://assets/audio/catabase/feedback/close.wav"],
	&"confirm": ["res://assets/audio/catabase/feedback/confirm.wav"],
	&"error": ["res://assets/audio/catabase/feedback/error.wav"],
	&"equip": ["res://assets/audio/catabase/feedback/equip.wav"],
	&"reward": ["res://assets/audio/catabase/feedback/reward.wav"],
	&"turn": ["res://assets/audio/catabase/feedback/turn.wav"],
	&"heal": ["res://assets/audio/catabase/feedback/heal.wav"],
	&"block": ["res://assets/audio/catabase/feedback/block.wav"],
	&"dodge": ["res://assets/audio/catabase/feedback/dodge.wav"],
	&"hit": ["res://assets/audio/catabase/feedback/hit.wav"],
	&"magic_hit": ["res://assets/audio/catabase/feedback/magic_hit.wav"],
	&"fall": ["res://assets/audio/catabase/feedback/fall.wav"],
	&"step": [
		"res://assets/audio/catabase/feedback/step_1.wav",
		"res://assets/audio/catabase/feedback/step_2.wav",
		"res://assets/audio/catabase/feedback/step_3.wav",
	],
}
