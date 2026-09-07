extends GutTest

const Session := preload("res://hub/sanctuary_prototype/sanctuary_session.gd")


func test_achat_met_a_jour_solde_stock_et_inventaire_ensemble() -> void:
	var session := Session.new()
	assert_eq(session.get_drachmes(), 120)
	assert_eq(session.get_shop_items().size(), 3)
	assert_eq(session.get_blessings().size(), 3)
	var result := session.buy_item(&"nectar_des_sources", 2)
	assert_true(result.ok)
	assert_eq(result.total_price, 50)
	assert_eq(session.get_drachmes(), 70)
	assert_eq(session.get_inventory(), {&"nectar_des_sources": 2})
	assert_eq(session.get_snapshot().stocks[&"nectar_des_sources"], 0)


func test_achats_successifs_cumulent_la_quantite_sans_double_debit() -> void:
	var session := Session.new()
	assert_true(session.buy_item(&"nectar_des_sources").ok)
	assert_true(session.buy_item(&"nectar_des_sources").ok)
	assert_eq(session.get_drachmes(), 70)
	assert_eq(session.get_inventory()[&"nectar_des_sources"], 2)
	assert_eq(session.get_snapshot().stocks[&"nectar_des_sources"], 0)


func test_solde_insuffisant_ne_change_aucune_donnee() -> void:
	var session := Session.new()
	assert_true(session.buy_item(&"sceau_de_bronze").ok)
	var before := session.get_snapshot()
	var result := session.buy_item(&"fil_d_ariane")
	assert_false(result.ok)
	assert_eq(result.error, &"insufficient_funds")
	assert_eq(session.get_snapshot(), before)


func test_stock_epuise_refuse_un_nouvel_achat_sans_mutation() -> void:
	var session := Session.new()
	assert_true(session.buy_item(&"nectar_des_sources", 2).ok)
	var before := session.get_snapshot()
	var result := session.buy_item(&"nectar_des_sources")
	assert_false(result.ok)
	assert_eq(result.error, &"insufficient_stock")
	assert_eq(session.get_snapshot(), before)


func test_quantite_indisponible_ne_realise_pas_un_achat_partiel() -> void:
	var session := Session.new()
	var before := session.get_snapshot()
	for quantity: int in [3, 9223372036854775807]:
		var result := session.buy_item(&"nectar_des_sources", quantity)
		assert_false(result.ok)
		assert_eq(result.error, &"insufficient_stock")
		assert_eq(session.get_snapshot(), before)


func test_article_inconnu_et_quantites_invalides_ne_changent_rien() -> void:
	var session := Session.new()
	var before := session.get_snapshot()
	for item_id: StringName in [&"", &"article_inconnu"]:
		var result := session.buy_item(item_id)
		assert_false(result.ok)
		assert_eq(result.error, &"unknown_item")
		assert_eq(session.get_snapshot(), before)
	for quantity: int in [0, -1, -100]:
		var result := session.buy_item(&"nectar_des_sources", quantity)
		assert_false(result.ok)
		assert_eq(result.error, &"invalid_quantity")
		assert_eq(session.get_snapshot(), before)


func test_une_seule_benediction_et_aucun_double_choix() -> void:
	var session := Session.new()
	assert_true(session.get_selected_blessing().is_empty())
	assert_true(session.choose_blessing(&"athena").ok)
	var selected := session.get_selected_blessing()
	assert_eq(selected.id, &"athena")
	assert_false(String(selected.effect).is_empty())
	var before := session.get_snapshot()
	for blessing_id: StringName in [&"athena", &"hermes", &"hestia"]:
		var result := session.choose_blessing(blessing_id)
		assert_false(result.ok)
		assert_eq(result.error, &"blessing_already_chosen")
		assert_eq(session.get_snapshot(), before)


func test_benediction_inconnue_ne_consomme_pas_le_choix() -> void:
	var session := Session.new()
	var before := session.get_snapshot()
	for blessing_id: StringName in [&"", &"dieu_inconnu"]:
		var result := session.choose_blessing(blessing_id)
		assert_false(result.ok)
		assert_eq(result.error, &"unknown_blessing")
		assert_eq(session.get_snapshot(), before)
	assert_true(session.choose_blessing(&"hestia").ok)


func test_vues_retournees_et_sessions_sont_independantes() -> void:
	var session := Session.new()
	var second_session := Session.new()
	var initial := second_session.get_snapshot()
	assert_true(session.buy_item(&"nectar_des_sources").ok)
	assert_true(session.choose_blessing(&"hermes").ok)
	var before := session.get_snapshot()
	var inventory := session.get_inventory()
	inventory[&"nectar_des_sources"] = 999
	var snapshot := session.get_snapshot()
	snapshot.stocks[&"nectar_des_sources"] = 999
	var shop := session.get_shop_items()
	shop[0].price = -500
	shop[0].stock = 999
	var blessings := session.get_blessings()
	blessings[0].name = "Modifié"
	var chosen := session.get_selected_blessing()
	chosen.id = &"hestia"
	assert_eq(session.get_snapshot(), before)
	assert_eq(session.get_shop_items()[0].price, 25)
	assert_ne(session.get_blessings()[0].name, "Modifié")
	assert_eq(second_session.get_snapshot(), initial)


func test_reset_restaure_stock_solde_inventaire_et_choix() -> void:
	var session := Session.new()
	var initial := session.get_snapshot()
	assert_true(session.buy_item(&"nectar_des_sources", 2).ok)
	assert_true(session.buy_item(&"fil_d_ariane").ok)
	assert_true(session.choose_blessing(&"athena").ok)
	assert_ne(session.get_snapshot(), initial)
	session.reset()
	assert_eq(session.get_snapshot(), initial)
	assert_true(session.get_selected_blessing().is_empty())
	assert_true(session.choose_blessing(&"hermes").ok)
	assert_true(session.buy_item(&"sceau_de_bronze").ok)
