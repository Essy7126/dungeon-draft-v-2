extends "extension_probe.gd"
## All epic casts in the real arena; inherited checks cover actual state expiration.


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/power/"
	showcase = [
		"a_reap",
		"g_bastion",
		"g_crash",
		"r_scatter",
		"r_bounty",
		"t_cataclysm",
		"t_hourglass",
		"a_stasis",
	]
	pair_distance = 2
	captured_frames = showcase.size() * 60
