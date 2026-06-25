class_name TraitStigmata
extends Trait

var fervor_on_hit: float = 8.0
var max_hp_penalty: float = -10.0

func _trait_name() -> String:
	return "trait_stigmata"

func configure(params: Dictionary) -> void:
	fervor_on_hit = params.get("fervor_on_hit", fervor_on_hit)
	max_hp_penalty = params.get("max_hp_penalty", max_hp_penalty)

func _activate() -> void:
	if owner != null and max_hp_penalty != 0.0:
		owner.max_hp.add_modifier(max_hp_penalty, Stat.ModType.FLAT, source_id, -1)
		owner.current_hp = mini(owner.current_hp, owner.max_hp.get_int())
		owner.stats_changed.emit(owner)
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _deactivate() -> void:
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)

func _on_damage_dealt(target, _attacker, amount: int, _category, _element, _is_crit) -> void:
	if target != owner or owner == null or amount <= 0 or not owner.has_energy():
		return
	owner.generate_energy(fervor_on_hit, source_id)