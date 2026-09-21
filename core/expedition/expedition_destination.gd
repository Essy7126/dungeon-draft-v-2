extends RefCounted
## Décide du lieu affiché sans modifier la session ni changer de scène.
## GameManager conserve la sauvegarde et l'exécution de la transition.

const FLOW := preload("res://core/expedition/expedition_flow.gd")
const HALTS := preload("res://core/expedition/painted_halt_catalog.gd")
const CROSSROADS := preload("res://hub/seuil_crossroads/seuil_route_choices.gd")
const ROUTE_SCENE := "res://ui/expedition/ExpeditionScreen.tscn"
const HALT_SCENE := "res://hub/painted_halt/ExpeditionHalt.tscn"
const MERCHANT_SCENE := "res://hub/merchant_hall/MerchantHall.tscn"
const CROSSROADS_SCENE := "res://hub/seuil_crossroads/SeuilCrossroads.tscn"


static func is_merchant_hall_active(session: ExpeditionSession, run_active: bool) -> bool:
	if session == null or not run_active or session.route.phase != "reward":
		return false
	var node := session.route.get_current_node()
	if session.route.get_balance_revision() >= 1:
		return (
			str(node.get("halt_art_key", "")) == "etal_passeur" \
					and str(node.get("kind", "")) == "merchant"
			and int(node.get("depth", -1)) == 4
		)
	return (
		str(node.get("id", "")) == "d04_1" \
				and str(node.get("kind", "")) == "merchant"
		and int(node.get("depth", -1)) == 4
	)


static func painted_halt_manifest(session: ExpeditionSession, run_active: bool) -> String:
	if session == null or not run_active or session.route.phase != "reward":
		return ""
	if bool(session.route.get_current_node().get("preparation_only", false)):
		return ""
	if FLOW.required_step(session) != "hub":
		return ""
	return HALTS.manifest_for(session.route.get_current_node())


static func scene_for(session: ExpeditionSession, run_active: bool) -> String:
	# Les choix obligatoires de progression et butin précèdent les lieux.
	if session != null and FLOW.required_step(session) not in ["map", "hub"]:
		return ROUTE_SCENE
	if CROSSROADS.active(session):
		return CROSSROADS_SCENE
	if not painted_halt_manifest(session, run_active).is_empty():
		return HALT_SCENE
	return MERCHANT_SCENE if is_merchant_hall_active(session, run_active) else ROUTE_SCENE
