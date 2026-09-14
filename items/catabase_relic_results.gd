extends RefCounted


## Executed by RelicRuntimeService: same inventory, activation and event contracts.
static func apply(
	effect: ItemReactiveEffectData,
	hero: Unit,
	context: Dictionary,
	inventory: RunInventory,
	instance: ItemInstance,
) -> bool:
	if hero == null or not hero.is_alive:
		return false
	match effect.result_id:
		&"ct_passive":
			hero.set_meta("ct_relic_%d" % int(effect.value), true)
			return true
		&"ct_bronze":
			var source: Unit = context.get("damage_source")
			if (
				source == null or source.team == hero.team
				or not context.get("guard_absorbed", false)
			):
				return false
			var before := int(hero.get_meta("ct_bronze", 0))
			var guarded := 0
			for absorption: Dictionary in context.get("source_absorption", []):
				if &"guard" in absorption.get("tags", []):
					guarded += int(absorption.get("amount_absorbed", 0))
			hero.set_meta("ct_bronze", mini(40, before + floori(guarded * 0.5)))
			return int(hero.get_meta("ct_bronze")) > before
		&"ct_supply":
			if hero.current_ap < 1 or inventory.get_instance(instance.instance_id) == null:
				return false
			var changed := false
			match int(effect.value):
				1:
					var before := hero.current_hp
					hero.heal(24, hero, { "action_id": &"relic:ct_onguent" })
					changed = hero.current_hp > before
				2:
					hero.grant_current_activation_mp_bonus(2)
					changed = true
				3:
					changed = hero.add_sourced_shield(
						&"ct_supply",
						24,
						hero,
						{ "tags": [&"guard"], "expires_after_activations": 1 },
					) != null
				4:
					changed = CatabaseCombatModifier.cleanse(hero)
			if not changed:
				return false
			hero.current_ap -= 1
			EventBus.ap_changed.emit(hero, hero.current_ap, hero.max_ap.get_int())
			hero.stats_changed.emit(hero)
			return bool(inventory.remove_quantity(instance.instance_id, 1).get("success", false))
	return false
