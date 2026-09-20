extends RefCounted
## Deterministic loot rolls; no combat-speed or damage-taken incentive.
const Cards := preload("res://core/expedition/class_card_catalog.gd")


static func factors(depth: int, kind: String, drought: int) -> Dictionary:
	var exploration := mini(20, maxi(1, depth))
	var danger := 20 if kind == "elite" else 35 if kind == "boss" else 0
	var memory := mini(45, maxi(0, drought) * 15)
	var resonance := mini(100, 10 + exploration + danger + memory)
	var chances: Array[int] = [mini(85, 45 + resonance * 2 / 5), mini(65, 12 + resonance * 2 / 5)]
	if kind in ["elite", "boss"]:
		chances.append(mini(50, 10 + resonance / 4))
	if kind == "boss":
		chances.append(mini(40, 5 + resonance / 4))
	return {
		"resonance": resonance,
		"exploration": exploration,
		"danger": danger,
		"memory": memory,
		"drought": drought,
		"chances": chances,
	}


static func roll(seed_value: int, node: Dictionary, primary: String, drought: int) -> Dictionary:
	var details := factors(int(node.depth), str(node.kind), drought)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("card_drops_v2:%d:%s" % [seed_value, node.id])
	var families: Array[String] = []
	for chance in details.chances:
		if rng.randi_range(1, 100) > int(chance):
			continue
		var class_id := primary
		if rng.randf() >= .7:
			var others := Cards.CLASSES.keys()
			others.erase(primary)
			class_id = others[rng.randi_range(0, others.size() - 1)]
		var pool := Cards.reward_pool(class_id, int(node.depth))
		var weights: Array[float] = []
		var total := 0.0
		for family in pool:
			var tier := Cards.Ecology.tier(family)
			var members: int = pool.filter(
				func(id):
					return Cards.Ecology.tier(id) == tier,
			).size()
			var weight: float = (
				100.0 if tier == 1 else 10.0 + details.resonance * .3 if tier == 2 else 2.0
				+ details.resonance * .15
			) / members
			weights.append(weight)
			total += weight
		var pick := rng.randf() * total
		for index in pool.size():
			pick -= weights[index]
			if pick <= 0.0:
				families.append(pool[index])
				break
	return { "families": families, "factors": details }
