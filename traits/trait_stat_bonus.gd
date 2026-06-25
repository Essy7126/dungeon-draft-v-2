class_name TraitStatBonus
extends Trait

var max_hp_flat: float = 0.0
var max_hp_pct: float = 0.0
var attack_flat: float = 0.0
var attack_pct: float = 0.0
var max_mp_flat: float = 0.0
var initiative_flat: float = 0.0
var armure_flat: float = 0.0
var resist_magique_flat: float = 0.0
var crit_chance_flat: float = 0.0

func _trait_name() -> String:
	return "trait_stat_bonus"

func configure(params: Dictionary) -> void:
	max_hp_flat = params.get("max_hp_flat", max_hp_flat)
	max_hp_pct = params.get("max_hp_pct", max_hp_pct)
	attack_flat = params.get("attack_flat", attack_flat)
	attack_pct = params.get("attack_pct", attack_pct)
	max_mp_flat = params.get("max_mp_flat", max_mp_flat)
	initiative_flat = params.get("initiative_flat", initiative_flat)
	armure_flat = params.get("armure_flat", armure_flat)
	resist_magique_flat = params.get("resist_magique_flat", resist_magique_flat)
	crit_chance_flat = params.get("crit_chance_flat", crit_chance_flat)

func _activate() -> void:
	if owner == null:
		return
	var before_hp: int = owner.max_hp.get_int()
	var before_mp: int = owner.max_mp.get_int()
	_add(owner.max_hp, max_hp_flat, max_hp_pct)
	_add(owner.attack_power, attack_flat, attack_pct)
	_add(owner.max_mp, max_mp_flat, 0.0)
	_add(owner.initiative, initiative_flat, 0.0)
	_add(owner.armure, armure_flat, 0.0)
	_add(owner.resist_magique, resist_magique_flat, 0.0)
	_add(owner.crit_chance, crit_chance_flat, 0.0)
	var after_hp: int = owner.max_hp.get_int()
	var after_mp: int = owner.max_mp.get_int()
	if after_hp > before_hp:
		owner.current_hp += after_hp - before_hp
		owner.hp_changed.emit(owner)
	if after_mp > before_mp:
		owner.current_mp += after_mp - before_mp
	owner.stats_changed.emit(owner)

func _add(stat: Stat, flat: float, pct: float) -> void:
	if stat == null:
		return
	if flat != 0.0:
		stat.add_modifier(flat, Stat.ModType.FLAT, source_id, -1)
	if pct != 0.0:
		stat.add_modifier(pct, Stat.ModType.PERCENT, source_id, -1)