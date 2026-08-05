@tool
class_name RoomRewardProjectionService
extends RefCounted

const PROGRESS_SEED_SALT := 4_865_291
const ROLL_SEED_SALT := 7_914_673


static func ultimate_chance(
		room: RoomData,
		run_seed: int,
		room_index: int,
		cleared_wave_count: int
	) -> int:
	if room == null:
		return 0
	var chance := room.get_ultimate_reward_base_chance()
	var gain_range := room.get_ultimate_reward_gain_range()
	var rng := make_room_rng(run_seed, room_index, PROGRESS_SEED_SALT)
	for _wave_index in maxi(0, cleared_wave_count - 1):
		chance += rng.randi_range(gain_range.x, gain_range.y)
	return clampi(chance, 0, 100)


static func ultimate_won(
		room: RoomData,
		run_seed: int,
		room_index: int,
		cleared_wave_count: int,
		required_wave_count: int
	) -> bool:
	if room == null or required_wave_count <= 0 \
			or cleared_wave_count < required_wave_count:
		return false
	var rng := make_room_rng(run_seed, room_index, ROLL_SEED_SALT)
	return rng.randi_range(1, 100) <= ultimate_chance(
		room, run_seed, room_index, cleared_wave_count
	)


static func cumulative_reward_multiplier(room: RoomData, cleared_wave_count: int) -> float:
	if room == null:
		return 0.0
	var total := 0.0
	for wave_index in clampi(cleared_wave_count, 0, room.get_wave_count()):
		total += room.get_reward_multiplier_for_wave(wave_index)
	return total


static func make_room_rng(
		run_seed: int,
		room_index: int,
		seed_salt: int
	) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + (room_index + 1) * 1_000_003 + seed_salt
	return rng
