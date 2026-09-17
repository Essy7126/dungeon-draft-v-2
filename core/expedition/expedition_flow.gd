extends RefCounted
## Derive the next player decision from saved gameplay state, without a second save schema.


static func required_step(session: ExpeditionSession) -> String:
	if session == null:
		return "map"
	if session.needs_preparation:
		return "departure"
	if session.route.get_balance_revision() >= 1 and session.route.phase == "reward" and int(session.route.get_current_node().get("depth", 0)) == 20:
		return "rewards"
	if not session.advancement_step.is_empty():
		return session.advancement_step
	if session.is_editable() and session.character.champion_progression.unspent_attribute_points > 0:
		return "progression"
	if session.route.phase != "reward":
		return "map"
	var node := session.route.get_current_node()
	if (
		session.cards == null and int(node.get("depth", 0)) == ExpeditionBuildState.CAPACITY_DEPTH
		and session.build.depth_eight_choice.is_empty()
	):
		return "capacity"
	if ExpeditionRouteCatalog.is_halt(str(node.get("kind", ""))):
		return "hub"
	return "rewards"
