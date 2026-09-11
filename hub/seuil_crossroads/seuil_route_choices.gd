extends RefCounted
const DESTINATIONS := {
	"boat": "Les traces du Léthé",
	"gate": "Le portique des oboles",
	"well": "La sente des oliviers",
}


static func active(session: ExpeditionSession) -> bool:
	if not (
		session != null and session.route.current_node_id == "d01_0"
		and session.route.phase in ["reward", "map"]
	):
		return false
	var found := { }
	var edges: Array = session.route.get_current_node().edges
	for node in session.route.nodes:
		if str(node.id) in edges and str(node.title) in DESTINATIONS.values():
			found[str(node.title)] = true
	return found.size() == DESTINATIONS.size()


static func can_depart(session: ExpeditionSession) -> bool:
	return (
		active(session) and session.route.phase == "map"
		and session.character.champion_progression.unspent_attribute_points == 0
	)


static func destination(session: ExpeditionSession, landmark: String) -> Dictionary:
	if not active(session) or not DESTINATIONS.has(landmark):
		return { }
	var edges: Array = session.route.get_current_node().edges
	for node in session.route.nodes:
		if str(node.title) == DESTINATIONS[landmark] and str(node.id) in edges:
			return node
	return { }
