extends RefCounted
const PRESENTATION := {
	"exp_ct_masse": ["exp_heurt", 0],
	"exp_ct_pousse": ["exp_crochet", 0],
	"exp_ct_taille": ["exp_entaille", 0],
	"exp_ct_salve": ["exp_posture", 3],
	"exp_ct_lancer": ["exp_marque", 1],
	"exp_ct_retour": ["exp_fauchage", 2],
	"exp_ct_braise": ["exp_braise", 1],
	"exp_ct_flux": ["exp_marche", 2],
	"exp_ct_entaille": ["exp_entaille", 0],
	"exp_ct_recolte": ["exp_moisson", 0],
	"exp_ct_trait": ["exp_rupture", 1],
	"exp_ct_peage": ["exp_serment_brasier", 3],
	"exp_ct_sceau": ["exp_souffle", 3],
	"exp_ct_repercussion": ["exp_foudre", 2],
}


## All actions use the production SpellCaster and terrain services.
static func populate(c) -> void:
	var s: Spell = c._spell(
		"ct_masse",
		"Masse funéraire",
		4,
		1,
		1,
		1.6,
		"4 PA · 160 % Prouesse physique · retire 25 armure pour 2 activations après l'impact.",
	)
	s.applied_status = c._status("ct_fissure", "Armure fissurée", { "armure": -25.0 })
	s.applied_status.duration = 2
	s = c._spell(
		"ct_pousse",
		"Ébranler",
		2,
		1,
		1,
		0.45,
		"2 PA · 45 % Prouesse · repousse de 1 case. Prépare les collisions et le Clou.",
	)
	s.push_distance = 1
	s = c._spell(
		"ct_taille",
		"Taille du xiphos",
		3,
		1,
		1,
		1.15,
		"3 PA · 115 % Prouesse physique. Deux utilisations possibles par activation.",
	)
	s.once_per_activation = false
	s = c._spell(
		"ct_salve",
		"Garde de salve",
		2,
		0,
		0,
		0.0,
		"2 PA · réduit les 3 prochains impacts de 6 chacun jusqu'à votre prochaine activation. Les gros coups traversent cette garde.",
	)
	c._self_only(s)
	_mode(s, "salve")
	s = c._spell(
		"ct_lancer",
		"Lancer du disque",
		3,
		1,
		5,
		0.9,
		"3 PA · 90 % Prouesse physique. Le disque tombe sur la case ciblée ; récupérez-le avec Retour avant de relancer.",
	)
	s.can_target_free_cell = true
	_mode(s, "throw")
	s = c._spell(
		"ct_retour",
		"Retour de bronze",
		2,
		0,
		0,
		0.65,
		"2 PA · rappelle le disque. 65 % Prouesse à chaque ennemi du trajet dégagé vers Achille. Un mur bloque le retour.",
	)
	c._self_only(s)
	s.exclude_caster_from_area_effects = true
	s.exclude_allies_from_area_effects = true
	_mode(s, "return")
	s = c._spell(
		"ct_braise",
		"Braise captive",
		3,
		1,
		4,
		0.7,
		"3 PA · 70 % Prouesse magique Feu. Braise : 6 dégâts au début du tour de l'occupant, alliés inclus, pendant 2 tours.",
	)
	s.can_target_free_cell = true
	s.damage_type = Spell.DamageType.MAGICAL
	s.element = Spell.Element.FIRE
	s.terrain_effect = c.get_spell("exp_braise").terrain_effect.duplicate(true)
	s.terrain_effect.surface_id = &"ct_braise"
	s.terrain_effect.damage = 6
	s.terrain_effect.description = "6 dégâts Feu au début du tour ; 2 tours. Peut être déplacée par Flux."
	s = c._spell(
		"ct_flux",
		"Flux des cendres",
		2,
		1,
		4,
		0.0,
		"2 PA · ciblez votre braise : la pousse d'une case à l'opposé d'Achille (2 avec Mèche). Durée conservée. L'arrivée doit être sans surface.",
	)
	s.can_target_free_cell = true
	_mode(s, "flux")
	s = c._spell(
		"ct_entaille",
		"Entaille des morts",
		2,
		1,
		1,
		0.6,
		"2 PA · 60 % Prouesse physique, puis 4 dégâts physiques par activation pendant 2 activations. Rafraîchit sans cumuler ; agit aussi sur les ossements.",
	)
	s.applied_status = c._status("ct_plaie", "Fêlure sanglante", { })
	s.applied_status.duration = 2
	s.applied_status.damage_per_turn = 4
	s.applied_status.damage_type = Spell.DamageType.PHYSICAL
	s = c._spell(
		"ct_recolte",
		"Récolte des cicatrices",
		3,
		1,
		1,
		1.0,
		"3 PA · 100 % Prouesse physique ; +50 % sur une cible portant Fêlure sanglante. Aucun remboursement de PA.",
	)
	_mode(s, "harvest")
	s = c._spell(
		"ct_trait",
		"Trait du tribut",
		4,
		2,
		7,
		1.6,
		"4 PA · 160 % Prouesse physique à 2–7 cases. Le contact empêche le tir.",
	)
	s = c._spell(
		"ct_peage",
		"Péage offensif",
		1,
		0,
		0,
		0.0,
		"1 PA + 12 oboles · le prochain impact direct payé de cette activation gagne 50 % de ses dégâts de base. Une préparation à la fois, pas de copie des effets.",
	)
	c._self_only(s)
	_mode(s, "toll")
	s = c._spell(
		"ct_sceau",
		"Sceau protecteur",
		2,
		0,
		0,
		0.0,
		"2 PA · retire les pénalités de PA, PM et statistiques ; +10 résistance magique jusqu'au prochain tour. Recharge : 2 activations.",
	)
	c._self_only(s)
	s.cooldown_activations = 2
	_mode(s, "cleanse")
	c._card_ids["endurance"].append("exp_ct_sceau")
	c._node(
		"ct.sceau.learn",
		"endurance",
		"apprentissage",
		1,
		s.spell_name,
		s.description,
		[],
		1,
		String(s.spell_id),
	)
	s = c._spell(
		"ct_repercussion",
		"Répercussion",
		3,
		1,
		4,
		0.01,
		"3 PA · consomme jusqu'à 30 de votre réserve d'urne pour infliger 150 % du bronze consommé en ligne. Ne recharge pas l'urne.",
	)
	c._line(s)
	_mode(s, "bronze")
	c._card_ids["airain"].append("exp_ct_repercussion")
	c._node(
		"ct.repercussion.learn",
		"airain",
		"apprentissage",
		1,
		s.spell_name,
		s.description,
		[],
		1,
		String(s.spell_id),
	)
	# Two exclusive mutations per engine, followed by a costly culmination.
	for row in [
		["ct_masse", "briseur", "Rupture profonde", "Onde funéraire", 1.9, 1.0],
		["ct_salve", "airain", "Cinq écailles", "Trois plaques", 0.0, 0.0],
		["ct_retour", "chasseur", "Retour fatal", "Retour entravant", 1.1, 0.55],
		["ct_braise", "elements", "Braise durable", "Fournaise brève", 0.5, 0.9],
		["ct_entaille", "sang", "Plaie profonde", "Cicatrice d'airain", 0.4, 0.65],
		["ct_peage", "chasseur", "Avance coûteuse", "Petite monnaie", 0.0, 0.0],
	]:
		var root: String = "exp_" + str(row[0])
		var axis: String = str(row[1])
		if not c._card_ids[axis].has(root):
			c._card_ids[axis].append(root)
		c._node(
			"ct." + str(row[0]) + ".learn",
			axis,
			"apprentissage",
			1,
			c.get_spell(root).spell_name,
			c.get_spell(root).description,
			[],
			1,
			root,
		)
		for index in 2:
			var suffix := "_a" if index == 0 else "_b"
			var form: Spell = c._copy(root, str(row[0]) + suffix, row[2 + index], "")
			form.damage_scaling = c._scaling(float(row[4 + index])) if float(row[4 + index]) > 0 else null
			_configure_mutation(c, form, str(row[0]), index)
			var node_id := "ct." + str(row[0]) + suffix
			c._node(
				node_id,
				axis,
				"mutation",
				2,
				form.spell_name,
				form.description,
				["ct." + str(row[0]) + ".learn"],
				2,
				String(form.spell_id),
			)
			c.nodes.back()["exclusive_group"] = "ct_mutation_" + str(row[0])
			var final_form: Spell = c._copy(
				String(form.spell_id),
				str(row[0]) + suffix + "_final",
				form.spell_name + " — accomplie",
				form.description
				+ "\nAccomplissement : cette forme coûte 1 PA de moins (minimum 1).",
			)
			final_form.ap_cost = maxi(1, form.ap_cost - 1)
			if str(row[0]) == "ct_peage":
				final_form.description = form.description + "\nAccomplissement : le bonus gagne 20 points de pourcentage ; le prix reste identique."
				(final_form.modifiers[0] as CatabaseCombatModifier).amount += 0.2
			c._node(
				node_id + ".final",
				axis,
				"légende",
				4,
				final_form.spell_name,
				final_form.description,
				[node_id],
				8,
				String(final_form.spell_id),
			)


static func _mode(spell: Spell, mode: String) -> void:
	var modifier := CatabaseCombatModifier.new()
	modifier.mode = mode
	spell.modifiers.append(modifier)


static func _configure_mutation(c, s: Spell, root: String, variant: int) -> void:
	match root:
		"ct_masse":
			if variant == 0:
				s.applied_status.stat_modifiers = { "armure": -40.0 }
				s.description = "4 PA · 190 % Prouesse · -40 armure pendant 2 activations après l'impact."
			else:
				c._self_area(s)
				s.description = "4 PA · 100 % Prouesse à chaque ennemi adjacent ; fissure son armure de 25 pendant 2 activations."
		"ct_salve":
			(s.modifiers[0] as CatabaseCombatModifier).amount = 5 if variant == 0 else 8
			(s.modifiers[0] as CatabaseCombatModifier).charges = 5 if variant == 0 else 3
			s.description = "2 PA · %d impacts réduits de %d, jusqu'à votre prochaine activation." % [
				5 if variant == 0 else 3,
				5 if variant == 0 else 8,
			]
		"ct_retour":
			s.description = "2 PA · Retour du disque : %d %% Prouesse sur le trajet. Nécessite votre disque au sol." % [
				110 if variant == 0 else 55
			]
			if variant == 1:
				s.applied_status = c._status("ct_retour_lent", "Bronze aux chevilles", { })
				s.applied_status.mp_reduction = 2
				s.description += " -2 PM à la prochaine activation des ennemis touchés."
		"ct_braise":
			s.terrain_effect.damage = 5 if variant == 0 else 10
			s.terrain_effect.duration = 3 if variant == 0 else 1
			s.description = "3 PA · %d %% Prouesse magique ; braise de %d dégâts pendant %d tour(s). Flux conserve cette durée." % [
				50 if variant == 0 else 90,
				s.terrain_effect.damage,
				s.terrain_effect.duration,
			]
		"ct_entaille":
			s.applied_status.damage_per_turn = 8 if variant == 0 else 2
			if variant == 1:
				s.applied_status.stat_modifiers = { "armure": -20.0 }
			s.description = "2 PA · %d %% Prouesse ; %d dégâts par activation pendant 2 activations." % [
				40 if variant == 0 else 65,
				s.applied_status.damage_per_turn,
			]
			if variant == 1:
				s.description += " -20 armure pendant la fêlure."
		"ct_peage":
			(s.modifiers[0] as CatabaseCombatModifier).amount = 0.8 if variant == 0 else 0.3
			(s.modifiers[0] as CatabaseCombatModifier).price = 20 if variant == 0 else 6
			s.description = "1 PA + %d oboles · le prochain impact direct payé ce tour gagne %d %% de dégâts de base. Aucun effet secondaire copié." % [
				20 if variant == 0 else 6,
				80 if variant == 0 else 30,
			]
