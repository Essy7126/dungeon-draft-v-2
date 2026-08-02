class_name CharacterMovementTiming
extends RefCounted

# Source de verite unique pour le mouvement logique et sa presentation 3D.
const MOVE_SEGMENT_DURATION := 0.24
const WALK_CYCLE_DURATION := 0.84
const RUN_CYCLE_DURATION := 0.65


static func duration_for_segments(segment_count: int) -> float:
	return maxf(float(segment_count), 1.0) * MOVE_SEGMENT_DURATION


static func playback_speed_for_loop(source_duration: float, running: bool = false) -> float:
	if source_duration <= 0.0:
		return 1.0
	var target_cycle := RUN_CYCLE_DURATION if running else WALK_CYCLE_DURATION
	return source_duration / target_cycle
