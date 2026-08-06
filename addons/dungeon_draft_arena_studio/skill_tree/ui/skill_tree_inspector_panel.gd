@tool
class_name SkillTreeInspectorPanel
extends VBoxContainer

signal property_change_requested(target, property_name: StringName, value, action_name: String)
signal subject_requested(subject)
signal add_modifier_requested(node: SkillUpgradeData)
signal remove_modifier_requested(node: SkillUpgradeData, modifier: SpellModifier)
signal exclusion_change_requested(first: SkillTreeNodeData, second: SkillTreeNodeData, enabled: bool)
signal existing_modifier_requested(node: SkillUpgradeData, modifier: SpellModifier)
signal duplicate_modifier_requested(node: SkillUpgradeData, modifier: SpellModifier)
signal unique_modifier_requested(node: SkillUpgradeData, modifier: SpellModifier)
signal move_modifier_requested(node: SkillUpgradeData, modifier: SpellModifier, offset: int)
signal inspect_in_godot_requested(resource: Resource)

const TAB_NAMES := ["Général", "Sort", "Effets", "Relations", "Apparence", "Avancé"]

var title_label: Label
var help_label: Label
var tabs: TabContainer
var _boxes := {}
var _unit: UnitData
var _discipline: DisciplineData
var _spell: Spell
var _subject: Resource
var _messages: Array[SkillTreeValidationMessage] = []
var _guided := true


func _ready() -> void:
	custom_minimum_size.x = 390
	add_theme_constant_override("separation", 6)
	title_label = Label.new()
	title_label.text = "3 · PROPRIÉTÉS"
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	add_child(title_label)
	help_label = Label.new()
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
	add_child(help_label)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_build_tabs()


func set_context(
		unit: UnitData,
		discipline: DisciplineData,
		spell: Spell,
		subject: Resource,
		messages: Array[SkillTreeValidationMessage],
		guided: bool
	) -> void:
	_unit = unit
	_discipline = discipline
	_spell = spell
	_subject = subject
	_messages = messages
	_guided = guided
	_refresh()


func commit_pending_edits() -> void:
	# Les éditeurs déclenchent leur transaction sur focus_exited/popup_closed.
	# Libérer le focus inclut donc la valeur visible avant une commande globale.
	var viewport := get_viewport()
	if viewport == null:
		return
	var focused := viewport.gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	for picker_value in find_children("*", "ColorPickerButton", true, false):
		var picker := picker_value as ColorPickerButton
		if picker != null and picker.get_popup() != null \
				and picker.get_popup().visible:
			picker.get_popup().hide()


func _build_tabs() -> void:
	for tab_name in TAB_NAMES:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 9)
		scroll.add_child(box)
		_boxes[tab_name] = box


func _refresh() -> void:
	if tabs == null:
		return
	for box_value in _boxes.values():
		var box := box_value as VBoxContainer
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	help_label.visible = _guided
	_add_subject_messages()
	if _subject is UnitData:
		_build_unit(_subject as UnitData)
	elif _subject is DisciplineData:
		_build_discipline(_subject as DisciplineData)
	elif _subject is DisciplineRankData:
		_build_rank(_subject as DisciplineRankData)
	elif _subject is SkillUpgradeData:
		_build_node(_subject as SkillUpgradeData)
	elif _subject is Spell:
		_build_spell(_subject as Spell)
	elif _subject is SpellModifier:
		_build_modifier(_subject as SpellModifier)
	else:
		title_label.text = "3 · PROPRIÉTÉS"
		help_label.text = "Cliquez sur un personnage, une discipline, un rang ou une amélioration."
		_add_info(_box("Général"), "Aucun élément sélectionné.")
	_update_tab_visibility()


func _build_unit(unit: UnitData) -> void:
	title_label.text = "PERSONNAGE · %s" % unit.unit_name.to_upper()
	help_label.text = "Ces valeurs deviennent les caractéristiques de base lors de la prochaine création du personnage. Une partie déjà commencée ne change pas."
	var general := _box("Général")
	_add_line(general, unit, &"unit_name", "Nom affiché", "Nom visible par le joueur.", "Exemple : Guerrier")
	_add_multiline(general, unit, &"description", "Description", "Résumé du personnage et de son style de jeu.")
	_add_section(general, "CARACTÉRISTIQUES DE BASE")
	_add_integer(general, unit, &"max_hp", "PV maximum", "Quantité de dégâts supportée avant la mort.", 1, 99999)
	_add_integer(general, unit, &"initiative", "Initiative", "Détermine l’ordre de jeu.", 0, 9999)
	_add_integer(general, unit, &"max_ap", "PA maximum", "Points disponibles pour lancer des actions à chaque tour.", 0, 99)
	_add_integer(general, unit, &"max_mp", "PM maximum", "Nombre de cases de déplacement disponibles.", 0, 99)
	_add_integer(general, unit, &"attack_power", "Puissance d’attaque", "Valeur de base utilisable par les calculs de dégâts.", 0, 9999)
	_add_float(general, unit, &"force", "Force de déplacement", "Résistance et puissance pour les poussées et attractions.", 0.0, 9999.0, 0.5)
	_add_section(general, "DÉFENSE")
	_add_float(general, unit, &"armure", "Armure", "Réduit les dégâts physiques avec un rendement décroissant.", 0.0, 1000.0, 1.0)
	_add_float(general, unit, &"resist_magique", "Résistance magique", "Réduit les dégâts magiques.", 0.0, 1000.0, 1.0)
	_add_percent(general, unit, &"esquive", "Esquive", "Probabilité d’annuler complètement une attaque.")
	_add_percent(general, unit, &"crit_chance", "Chance critique", "Chance critique propre au personnage.")
	_add_float(general, unit, &"crit_multi", "Multiplicateur critique", "Exemple : 1,5 signifie 150 % des dégâts.", 1.0, 10.0, 0.05)
	var advanced := _box("Avancé")
	_add_stable_id(advanced, unit, &"unit_id", "Identifiant stable du personnage")
	_add_integer(advanced, unit, &"active_spell_slots", "Emplacements de sorts actifs", "Nombre de sorts équipables simultanément.", 1, 12)
	_add_resource(_box("Apparence"), unit, &"preview_visual_scene", "Scène de présentation", "PackedScene")


func _build_discipline(discipline: DisciplineData) -> void:
	title_label.text = "DISCIPLINE · %s" % discipline.display_name.to_upper()
	help_label.text = "Une discipline est un chemin de progression associé à un sort de base. Les rangs se débloquent grâce à l’XP cumulée."
	var general := _box("Général")
	_add_line(general, discipline, &"display_name", "Nom affiché", "Nom visible dans le jeu.", "Exemple : Pyromancie")
	_add_multiline(general, discipline, &"description", "Description", "Explique le style et la promesse de cette discipline.")
	_add_stable_id(general, discipline, &"discipline_id", "Identifiant stable")
	_add_color(general, discipline, &"presentation_color", "Couleur de présentation", "Couleur utilisée pour reconnaître cette discipline.")
	_add_resource(_box("Apparence"), discipline, &"icon", "Icône", "Texture2D")
	var ranks := discipline.ranks.filter(func(value): return value != null)
	_add_section(general, "PROGRESSION")
	_add_info(general, "%d rang(s). Cliquez sur un badge de rang dans le graphe pour modifier son seuil d’XP." % ranks.size())
	var sort_box := _box("Sort")
	if _spell != null:
		_add_info(sort_box, "Sort associé : %s" % _spell.spell_name)
		_add_action_button(sort_box, "Modifier le sort de base", func(): subject_requested.emit(_spell))
	else:
		_add_error_box(sort_box, "Aucun sort du personnage n’utilise cette discipline.")
		_add_base_spell_selector(sort_box, discipline)
	_add_storage_info(_box("Avancé"), discipline)


func _build_rank(rank_data: DisciplineRankData) -> void:
	title_label.text = "RANG %d" % rank_data.rank
	help_label.text = "Le seuil correspond à l’XP totale accumulée, pas au prix individuel d’une amélioration."
	var general := _box("Général")
	_add_integer(general, rank_data, &"required_total_xp", "Seuil total d’XP", "XP cumulée nécessaire pour atteindre ce rang.", 0, 999999)
	var previous := _previous_rank(rank_data.rank)
	var delta := rank_data.required_total_xp - previous.required_total_xp \
		if previous != null else rank_data.required_total_xp
	_add_readonly(general, "XP depuis le rang précédent", str(delta), "Différence calculée automatiquement.")
	_add_readonly(general, "Nombre de choix", str(rank_data.choices.size()), "Nombre d’améliorations proposées à ce rang.")
	_add_info(general, "Le jeu accorde actuellement 1 XP à la discipline après chaque lancement réussi de son sort.")
	_add_storage_info(_box("Avancé"), rank_data)


func _build_node(node: SkillUpgradeData) -> void:
	title_label.text = "AMÉLIORATION · %s" % node.display_name.to_upper()
	help_label.text = "Une amélioration est un choix définitif pendant la run. Son identifiant reste stable même si son nom affiché change."
	var general := _box("Général")
	_add_line(general, node, &"display_name", "Nom affiché", "Nom compris par le joueur.", "Exemple : Flèches brûlantes")
	_add_multiline(general, node, &"description", "Description", "Décrivez précisément le résultat obtenu.")
	_add_stable_id(general, node, &"upgrade_id", "Identifiant stable")
	_add_node_rank_selector(general, node)
	var spell_box := _box("Sort")
	_add_spell_selector(spell_box, node)
	if _spell != null:
		_add_action_button(spell_box, "Ouvrir le sort de base", func(): subject_requested.emit(_spell))
	var effects := _box("Effets")
	_add_info(effects, SkillTreeEffectSummaryService.summarize_node(node))
	for modifier in node.spell_modifiers:
		if modifier == null:
			_add_error_box(effects, "Entrée d’effet vide.")
			continue
		var row := HBoxContainer.new()
		effects.add_child(row)
		var open := Button.new()
		open.text = modifier.modifier_name if not modifier.modifier_name.is_empty() else "Effet spécialisé"
		open.tooltip_text = SkillTreeEffectSummaryService.summarize_modifier(modifier)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open.pressed.connect(func(): subject_requested.emit(modifier))
		row.add_child(open)
		var up := Button.new()
		up.text = "↑"
		up.tooltip_text = "Place cet effet avant le précédent."
		up.pressed.connect(func(): move_modifier_requested.emit(node, modifier, -1))
		row.add_child(up)
		var down := Button.new()
		down.text = "↓"
		down.tooltip_text = "Place cet effet après le suivant."
		down.pressed.connect(func(): move_modifier_requested.emit(node, modifier, 1))
		row.add_child(down)
		var duplicate := Button.new()
		duplicate.text = "Copier"
		duplicate.tooltip_text = "Crée une copie indépendante de cet effet."
		duplicate.pressed.connect(func(): duplicate_modifier_requested.emit(node, modifier))
		row.add_child(duplicate)
		var unique := Button.new()
		unique.text = "Unique"
		unique.tooltip_text = "Remplace cet effet par une Resource indépendante avant modification."
		unique.pressed.connect(func(): unique_modifier_requested.emit(node, modifier))
		row.add_child(unique)
		var remove := Button.new()
		remove.text = "Retirer"
		remove.tooltip_text = "Retire cet effet du nœud après confirmation dans l’historique."
		remove.pressed.connect(func(): remove_modifier_requested.emit(node, modifier))
		row.add_child(remove)
	_add_action_button(effects, "+ Ajouter un effet", func(): add_modifier_requested.emit(node))
	var existing_field := _field(
		effects, "Partager un effet existant",
		"Choisissez une Resource SpellModifier. Elle restera partagée après sauvegarde, mais sera modifiée sur une copie de travail isolée."
	)
	if Engine.is_editor_hint():
		var existing_picker := EditorResourcePicker.new()
		existing_picker.base_type = "SpellModifier"
		existing_picker.resource_changed.connect(func(resource: Resource):
			if resource is SpellModifier:
				existing_modifier_requested.emit(node, resource)
		)
		existing_field.add_child(existing_picker)
	else:
		var unavailable := Label.new()
		unavailable.text = "Sélecteur disponible dans l’éditeur Godot."
		existing_field.add_child(unavailable)
	var relations := _box("Relations")
	_add_relation_list(relations, node)
	var appearance := _box("Apparence")
	_add_resource(appearance, node, &"icon", "Icône compacte", "Texture2D")
	_add_resource(appearance, node, &"card_texture", "Illustration de carte", "Texture2D")
	_add_storage_info(_box("Avancé"), node)


func _build_spell(spell: Spell) -> void:
	title_label.text = "SORT · %s" % spell.spell_name.to_upper()
	help_label.text = "Le sort de base est la racine de la discipline. Les améliorations appliquent leurs modificateurs à son identifiant stable."
	var general := _box("Général")
	_add_line(general, spell, &"spell_name", "Nom du sort", "Nom visible pendant le combat.")
	_add_multiline(general, spell, &"description", "Description", "Explique ce que fait le sort sans vocabulaire technique.")
	_add_stable_id(general, spell, &"spell_id", "Identifiant stable du sort")
	_add_stable_id(general, spell, &"discipline_id", "Discipline associée")
	var sort_box := _box("Sort")
	_add_integer(sort_box, spell, &"ap_cost", "Coût en PA", "Points d’action consommés lors d’un lancement réussi.", 0, 99)
	_add_integer(sort_box, spell, &"minimum_range", "Portée minimale", "Distance minimale autorisée.", 0, 99)
	_add_integer(sort_box, spell, &"spell_range", "Portée maximale", "Distance maximale autorisée.", 0, 99)
	_add_bool(sort_box, spell, &"needs_line_of_sight", "Ligne de vue nécessaire", "Empêche de cibler à travers les obstacles.")
	_add_integer(sort_box, spell, &"cooldown_activations", "Temps de recharge", "Nombre d’activations avant de pouvoir relancer le sort.", 0, 99)
	_add_integer(sort_box, spell, &"max_uses_per_combat", "Utilisations maximales", "Zéro signifie aucune limite par combat.", 0, 999)
	_add_bool(sort_box, spell, &"once_per_activation", "Une fois par activation", "Empêche plusieurs utilisations pendant le même tour du personnage.")
	_add_section(sort_box, "CIBLES")
	_add_bool(sort_box, spell, &"can_target_enemy", "Cibler les ennemis", "Autorise une unité ennemie.")
	_add_bool(sort_box, spell, &"can_target_ally", "Cibler les alliés", "Autorise une unité alliée.")
	_add_bool(sort_box, spell, &"can_target_self", "Se cibler soi-même", "Autorise le lanceur comme cible.")
	_add_bool(sort_box, spell, &"can_target_free_cell", "Cibler une case libre", "Autorise une cellule sans unité.")
	var effects := _box("Effets")
	_add_integer(effects, spell, &"damage", "Dégâts de base", "Dégâts avant les améliorations et modificateurs.", 0, 99999)
	_add_integer(effects, spell, &"heal", "Soin de base", "PV rendus avant les améliorations.", 0, 99999)
	_add_enum(effects, spell, &"damage_type", "Type de dégâts", "Détermine la défense utilisée.", ["Physiques", "Magiques"])
	_add_enum(effects, spell, &"element", "Élément", "Élément utilisé par les résistances.", ["Aucun", "Feu", "Glace", "Foudre", "Ombre", "Sacré", "Terre"])
	_add_percent(effects, spell, &"crit_chance", "Chance critique du sort", "S’ajoute à la chance critique du personnage.")
	_add_integer(effects, spell, &"push_distance", "Distance de poussée", "Nombre de cases de déplacement forcé.", 0, 99)
	_add_integer(effects, spell, &"pull_distance", "Distance d’attraction", "Nombre de cases vers le lanceur.", 0, 99)
	_add_integer(effects, spell, &"shield_grant", "Bouclier accordé", "Points de bouclier donnés directement.", 0, 99999)
	var appearance := _box("Apparence")
	_add_resource(appearance, spell, &"icon", "Icône", "Texture2D")
	_add_resource(appearance, spell, &"vfx_scene", "Effet visuel", "PackedScene")
	_add_resource(appearance, spell, &"sound_cast", "Son de lancement", "AudioStream")
	var advanced := _box("Avancé")
	_add_section(advanced, "PRÉSENTATION ET TIMING")
	_add_enum(advanced, spell, &"vfx_placement", "Placement du VFX", "Départ du lanceur vers la cible, ou directement sur la case ciblée.", ["Lanceur vers cible", "Case ciblée"])
	_add_enum(advanced, spell, &"visual_action", "Animation visuelle", "Action jouée par la représentation du personnage.", ["Par défaut", "Principale", "Puissante"])
	_add_float(advanced, spell, &"impact_delay_seconds", "Délai d’impact", "Secondes entre l’animation et la résolution.", 0.0, 10.0, 0.01)
	_add_integer(advanced, spell, &"initial_cooldown", "Recharge initiale", "Nombre d’activations avant la première disponibilité.", 0, 99)
	_add_section(advanced, "ZONE")
	_add_integer(advanced, spell, &"aoe_size", "Taille de zone", "Taille utilisée avec la forme de zone.", 1, 99)
	_add_enum(advanced, spell, &"aoe_shape", "Forme de zone", "Disposition des cases affectées.", ["Cible unique", "Croix", "Carré", "Ligne"])
	_add_bool(advanced, spell, &"line_from_caster", "Ligne depuis le lanceur", "Oriente la zone en ligne à partir du lanceur.")
	_add_section(advanced, "TERRAIN ET STATUT")
	_add_resource(advanced, spell, &"terrain_effect", "Effet de terrain", "TerrainEffectData")
	_add_resource(advanced, spell, &"applied_status", "Statut appliqué", "StatusData")
	_add_bool(advanced, spell, &"status_source_scoped", "Statut lié à la source", "Distingue les statuts selon leur lanceur.")
	_add_bool(advanced, spell, &"replaces_same_source_status", "Remplacer le même statut", "Remplace l’instance précédente appliquée par la même source.")
	_add_section(advanced, "DÉPLACEMENT ET MÉCANIQUES")
	_add_integer(advanced, spell, &"collision_damage", "Dégâts de collision", "Dégâts lorsqu’une poussée rencontre un obstacle.", 0, 99999)
	_add_bool(advanced, spell, &"push_all_adjacent", "Pousser toutes les unités adjacentes", "Applique la poussée autour du point d’impact.")
	_add_bool(advanced, spell, &"push_affected_units", "Pousser les unités de la zone", "Applique la poussée à chaque unité affectée.")
	_add_integer(advanced, spell, &"cluster_bonus_damage", "Bonus de regroupement", "Dégâts supplémentaires selon le nombre d’ennemis regroupés.", 0, 99999)
	_add_integer(advanced, spell, &"ap_drain", "Drain de PA", "PA retirés au prochain tour de la cible.", 0, 99)
	_add_bool(advanced, spell, &"teleport_behind_target", "Téléportation dans le dos", "Place le lanceur derrière sa cible.")
	_add_integer(advanced, spell, &"bonus_damage_if_marked", "Bonus sur cible marquée", "Dégâts ajoutés si le statut demandé est présent.", 0, 99999)
	_add_stable_id(advanced, spell, &"bonus_damage_status_id", "Identifiant du statut requis")
	_add_bool(advanced, spell, &"bonus_requires_linked_status_source", "Marque liée au lanceur", "Exige que la marque provienne de la source attendue.")
	_add_bool(advanced, spell, &"forces_taunt", "Forcer la provocation", "Contraint la cible à agir selon la règle de provocation.")
	_add_integer(advanced, spell, &"taunt_duration", "Durée de provocation", "Nombre de tours concernés.", 0, 99)
	_add_line(advanced, spell, &"heal_bonus_effect_name", "Nom du bonus de soin", "Libellé technique du bonus conditionnel.")
	_add_float(advanced, spell, &"heal_bonus_multiplier", "Multiplicateur de soin", "Exemple : 1,5 signifie 150 %.", 0.0, 100.0, 0.05)
	_add_section(advanced, "RÉSOLUTION DIFFÉRÉE")
	_add_enum(advanced, spell, &"delayed_resolution", "Mode différé", "Résout le sort immédiatement, plus tard avec frappe/poussée, ou par invocation.", ["Aucun", "Frappe et poussée", "Invocation"])
	_add_bool(advanced, spell, &"consumes_activation_on_resolution", "Consommer l’activation à la résolution", "Consomme l’activation lorsque l’effet différé se déclenche.")
	_add_line(advanced, spell, &"telegraph_label", "Texte d’annonce", "Texte affiché pour prévenir le joueur.")
	_add_color(advanced, spell, &"telegraph_color", "Couleur d’annonce", "Couleur du télégraphe de l’effet différé.")
	_add_section(advanced, "INVOCATION")
	_add_resource(advanced, spell, &"summon_unit_data", "Unité invoquée", "UnitData")
	_add_stable_id(advanced, spell, &"summon_type", "Type stable d’invocation")
	_add_integer(advanced, spell, &"summon_starting_hp", "PV de départ de l’invocation", "Zéro utilise la valeur par défaut de l’unité.", 0, 99999)
	_add_integer(advanced, spell, &"summon_max_living_team", "Maximum vivant dans l’équipe", "Limite d’invocations simultanées.", 0, 999)
	_add_integer(advanced, spell, &"condition_hp_at_or_below", "Condition de PV", "-1 désactive la condition ; sinon le sort exige des PV inférieurs ou égaux.", -1, 99999)
	_add_stable_id(advanced, spell, &"requires_absent_unit_id", "Unité devant être absente")
	_add_integer_dictionary(
		advanced, spell, &"summon_initial_cooldowns",
		"Recharges initiales des invocations",
		"Associe chaque identifiant de sort invoqué à sa recharge initiale."
	)
	_add_ordered_modifier_list(
		advanced, spell, &"modifiers", "Modificateurs permanents",
		"Liste ordonnée des SpellModifier toujours actifs sur ce sort."
	)
	_add_storage_info(advanced, spell)


func _build_modifier(modifier: SpellModifier) -> void:
	title_label.text = "EFFET · %s" % modifier.modifier_name.to_upper()
	help_label.text = "Un modificateur transforme le sort ciblé sans changer son fichier de code. Le résumé ci-dessous décrit le résultat attendu."
	var general := _box("Général")
	_add_line(general, modifier, &"modifier_name", "Nom de l’effet", "Nom utilisé dans l’éditeur et les rapports.")
	_add_stable_id(general, modifier, &"target_spell_id", "Identifiant du sort ciblé")
	_add_line(general, modifier, &"target_spell_name", "Ancien filtre par nom", "Compatibilité historique : laissez vide lorsque l’identifiant stable est renseigné.")
	_add_info(_box("Effets"), SkillTreeEffectSummaryService.summarize_modifier(modifier))
	if modifier is SpellModSkillTreeEffect:
		_build_skill_tree_effect(modifier as SpellModSkillTreeEffect)
	else:
		_add_info(general, "Ce modificateur spécialisé conserve son fonctionnement runtime existant.")
		_build_generic_advanced(modifier)
	_add_storage_info(_box("Avancé"), modifier)


func _build_skill_tree_effect(effect: SpellModSkillTreeEffect) -> void:
	var effects := _box("Effets")
	var effect_labels: Array[String] = []
	for index in range(SpellModSkillTreeEffect.EffectType.size()):
		effect_labels.append(SkillTreeEffectSummaryService.effect_type_label(index))
	_add_enum(effects, effect, &"effect_type", "Type d’effet", "Choisit la transformation appliquée au sort.", effect_labels)
	_add_enum(effects, effect, &"target_scope", "Cible de l’effet", "Précise qui reçoit cette transformation.", ["Ennemi principal", "Allié principal", "Ennemis affectés", "Alliés affectés", "Lanceur"])
	_add_integer(effects, effect, &"amount", "Quantité principale", "Valeur principale : dégâts, soin, cases, bouclier ou PM.", -99999, 99999)
	if not _guided or effect.effect_type in [
		SpellModSkillTreeEffect.EffectType.STATUS_DOT,
		SpellModSkillTreeEffect.EffectType.STATUS_VULNERABILITY,
	]:
		_add_integer(effects, effect, &"secondary_amount", "Quantité secondaire", "Valeur complémentaire utilisée par certains effets.", -99999, 99999)
	if not _guided or effect.effect_type in [
		SpellModSkillTreeEffect.EffectType.STATUS_DOT,
		SpellModSkillTreeEffect.EffectType.STATUS_SLOW,
		SpellModSkillTreeEffect.EffectType.STATUS_REGEN,
		SpellModSkillTreeEffect.EffectType.STATUS_OUTGOING_DAMAGE,
	]:
		_add_integer(effects, effect, &"duration", "Durée", "Nombre de tours pendant lesquels le statut reste actif.", 0, 99)
		_add_line(effects, effect, &"status_name", "Nom du statut", "Nom visible du statut appliqué.")
		_add_stable_id(effects, effect, &"status_group", "Groupe stable du statut")
	if not _guided or effect.effect_type in [
		SpellModSkillTreeEffect.EffectType.DAMAGE_LOW_HP,
		SpellModSkillTreeEffect.EffectType.DAMAGE_BACKSTAB_OR_LOW_HP,
		SpellModSkillTreeEffect.EffectType.HEAL_LOW_HP,
	]:
		_add_percent(effects, effect, &"threshold_ratio", "Seuil de PV", "Exemple : 0,30 signifie moins de 30 % des PV.")
	if not _guided or effect.effect_type == SpellModSkillTreeEffect.EffectType.ADJACENT_HEAL_RATIO:
		_add_percent(effects, effect, &"ratio", "Part du soin", "Proportion partagée avec les alliés adjacents.", 2.0)
	var advanced := _box("Avancé")
	_add_integer(advanced, effect, &"charges", "Charges", "Nombre de déclenchements possibles.", 1, 99)
	_add_stable_id(advanced, effect, &"effect_group", "Groupe d’effet")
	_add_enum(advanced, effect, &"status_mode", "Mode du statut", "BASE crée la valeur, DELTA l’ajoute et OVERRIDE la remplace.", ["BASE", "DELTA", "OVERRIDE"])
	_add_enum(advanced, effect, &"status_damage_type", "Type de dégâts du statut", "Défense utilisée par les dégâts périodiques.", ["Physiques", "Magiques"])
	_add_enum(advanced, effect, &"status_element", "Élément du statut", "Élément utilisé par les résistances.", ["Aucun", "Feu", "Glace", "Foudre", "Ombre", "Sacré", "Terre"])
	_add_enum(advanced, effect, &"status_timing", "Moment d’application", "Moment où l’effet périodique est résolu.", ["Début du tour", "Fin du tour"])
	_add_bool(advanced, effect, &"require_backstab", "Exiger une attaque dans le dos", "Condition supplémentaire de déclenchement.")
	_add_bool(advanced, effect, &"require_ally_target", "Exiger une cible alliée", "Condition supplémentaire de déclenchement.")


func _build_generic_advanced(resource: Resource) -> void:
	var advanced := _box("Avancé")
	for property in resource.get_property_list():
		var name := StringName(property.get("name", &""))
		var usage := int(property.get("usage", 0))
		if name in [&"script", &"resource_name", &"resource_path", &"resource_local_to_scene", &"modifier_name"] \
				or usage & PROPERTY_USAGE_EDITOR == 0:
			continue
		var value: Variant = resource.get(name)
		match typeof(value):
			TYPE_BOOL:
				_add_bool(advanced, resource, name, str(name).capitalize(), "Paramètre avancé du modificateur.")
			TYPE_INT:
				_add_integer(advanced, resource, name, str(name).capitalize(), "Paramètre avancé du modificateur.", -999999, 999999)
			TYPE_FLOAT:
				_add_float(advanced, resource, name, str(name).capitalize(), "Paramètre avancé du modificateur.", -999999.0, 999999.0, 0.01)
			TYPE_STRING, TYPE_STRING_NAME:
				_add_line(advanced, resource, name, str(name).capitalize(), "Paramètre avancé du modificateur.")


func _add_relation_list(parent: VBoxContainer, node: SkillUpgradeData) -> void:
	if not node is SkillTreeNodeData:
		_add_info(parent, "Ce type historique ne contient pas de relations visuelles.")
		return
	var tree_node := node as SkillTreeNodeData
	_add_section(parent, "PRÉREQUIS — TOUS OBLIGATOIRES")
	_add_info(parent, "Reliez un nœud d’un rang inférieur vers celui-ci. Plusieurs liaisons signifient ET, jamais OU.")
	if tree_node.prerequisite_node_ids.is_empty():
		_add_readonly(parent, "Prérequis", "Aucun", "Les nœuds du rang 2 sont reliés implicitement au sort de base.")
	else:
		for prerequisite_id in tree_node.prerequisite_node_ids:
			_add_readonly(parent, "Requiert", _node_display_name(prerequisite_id), str(prerequisite_id))
	_add_section(parent, "EXCLUSIONS")
	_add_info(parent, "Une exclusion empêche deux choix d’être acquis dans la même progression.")
	if tree_node.excluded_node_ids.is_empty():
		_add_readonly(parent, "Exclusions", "Aucune", "Ce nœud ne bloque aucun autre choix.")
	else:
		for excluded_id in tree_node.excluded_node_ids:
			_add_readonly(parent, "Exclut", _node_display_name(excluded_id), str(excluded_id))
	_add_info(parent, "Cochez les choix incompatibles. Le Studio applique automatiquement la relation dans les deux sens.")
	if _discipline != null:
		for rank_data in _discipline.ranks:
			if rank_data == null:
				continue
			for candidate in rank_data.choices:
				if not candidate is SkillTreeNodeData or candidate == tree_node:
					continue
				var check := CheckBox.new()
				check.text = "Exclure « %s » (rang %d)" % [candidate.display_name, candidate.rank]
				check.button_pressed = tree_node.excluded_node_ids.has(candidate.upgrade_id)
				check.tooltip_text = "Empêche ces deux améliorations d’être acquises ensemble."
				check.toggled.connect(func(enabled: bool):
					exclusion_change_requested.emit(tree_node, candidate, enabled)
				)
				parent.add_child(check)


func _add_subject_messages() -> void:
	var subject_id := _subject_id()
	var relevant := _messages.filter(func(message: SkillTreeValidationMessage) -> bool:
		return message.subject_id == subject_id \
			or (_subject is DisciplineData and message.subject_id == _discipline.discipline_id)
	)
	if relevant.is_empty():
		return
	var box := _box("Général")
	for message in relevant:
		var panel := PanelContainer.new()
		var label := Label.new()
		label.text = "%s · %s\n%s%s" % [
			message.severity_label(), message.title, message.explanation,
			"\nCorrection : " + message.suggestion if not message.suggestion.is_empty() else "",
		]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.48, 0.42) if message.is_error() else Color(1.0, 0.72, 0.3)
		)
		panel.add_child(label)
		box.add_child(panel)


func _add_line(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String, example := ""
	) -> void:
	var field := _field(parent, label_text, description, example)
	var edit := LineEdit.new()
	edit.text = str(target.get(property_name))
	edit.tooltip_text = description
	field.add_child(edit)
	_add_inline_messages(field, property_name)
	var original := edit.text
	var commit := func():
		if edit.text == original:
			return
		var value: Variant = StringName(edit.text) if target.get(property_name) is StringName else edit.text
		property_change_requested.emit(target, property_name, value, "Modifier %s" % label_text)
		original = edit.text
	edit.text_submitted.connect(func(_text): commit.call())
	edit.focus_exited.connect(commit)


func _add_multiline(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String
	) -> void:
	var field := _field(parent, label_text, description)
	var edit := TextEdit.new()
	edit.text = str(target.get(property_name))
	edit.custom_minimum_size.y = 82
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.tooltip_text = description
	field.add_child(edit)
	_add_inline_messages(field, property_name)
	var original := edit.text
	edit.focus_exited.connect(func():
		if edit.text != original:
			property_change_requested.emit(target, property_name, edit.text, "Modifier %s" % label_text)
			original = edit.text
	)


func _add_integer(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String, minimum: int, maximum: int
	) -> void:
	_add_number(parent, target, property_name, label_text, description, minimum, maximum, 1.0, true)


func _add_float(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String, minimum: float, maximum: float,
		step: float
	) -> void:
	_add_number(parent, target, property_name, label_text, description, minimum, maximum, step, false)


func _add_percent(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String, maximum := 1.0
	) -> void:
	_add_float(parent, target, property_name, label_text, description, 0.0, maximum, 0.01)


func _add_number(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String, minimum: float, maximum: float,
		step: float, integer: bool
	) -> void:
	var field := _field(parent, label_text, description)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = minimum < 0.0
	spin.value = float(target.get(property_name))
	spin.tooltip_text = description
	field.add_child(spin)
	_add_inline_messages(field, property_name)
	var original := spin.value
	var commit := func():
		if is_equal_approx(spin.value, original):
			return
		property_change_requested.emit(
			target, property_name, int(spin.value) if integer else spin.value,
			"Modifier %s" % label_text
		)
		original = spin.value
	spin.get_line_edit().text_submitted.connect(func(_text): commit.call())
	spin.get_line_edit().focus_exited.connect(commit)


func _add_bool(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String
	) -> void:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = bool(target.get(property_name))
	check.tooltip_text = description
	parent.add_child(check)
	var explanation := Label.new()
	explanation.text = description
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_color_override("font_color", Color(0.66, 0.71, 0.78))
	explanation.visible = _guided
	parent.add_child(explanation)
	check.toggled.connect(func(value: bool):
		property_change_requested.emit(target, property_name, value, "Modifier %s" % label_text)
	)
	_add_inline_messages(parent, property_name)


func _add_enum(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String, values: Array[String]
	) -> void:
	var field := _field(parent, label_text, description)
	var option := OptionButton.new()
	for value in values:
		option.add_item(value)
	option.select(clampi(int(target.get(property_name)), 0, maxi(0, values.size() - 1)))
	option.tooltip_text = description
	field.add_child(option)
	_add_inline_messages(field, property_name)
	option.item_selected.connect(func(index: int):
		property_change_requested.emit(target, property_name, index, "Modifier %s" % label_text)
	)


func _add_color(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String
	) -> void:
	var field := _field(parent, label_text, description)
	var picker := ColorPickerButton.new()
	picker.color = target.get(property_name) as Color
	picker.tooltip_text = description
	field.add_child(picker)
	_add_inline_messages(field, property_name)
	var original := picker.color
	picker.popup_closed.connect(func():
		if picker.color != original:
			property_change_requested.emit(
				target, property_name, picker.color, "Modifier %s" % label_text
			)
			original = picker.color
	)


func _add_resource(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, base_type: String
	) -> void:
	var field := _field(parent, label_text, "Choisissez une Resource %s depuis le projet." % base_type)
	if not Engine.is_editor_hint():
		var current := target.get(property_name) as Resource
		var fallback := Label.new()
		fallback.text = current.resource_path if current != null and not current.resource_path.is_empty() else "Aucune ressource"
		fallback.tooltip_text = "Sélecteur disponible dans l’éditeur Godot."
		field.add_child(fallback)
		_add_inline_messages(field, property_name)
		return
	var picker := EditorResourcePicker.new()
	picker.base_type = base_type
	picker.edited_resource = target.get(property_name) as Resource
	picker.tooltip_text = "Glissez une Resource compatible ou utilisez le menu de sélection."
	field.add_child(picker)
	_add_inline_messages(field, property_name)
	picker.resource_changed.connect(func(resource: Resource):
		property_change_requested.emit(target, property_name, resource, "Modifier %s" % label_text)
	)


func _add_integer_dictionary(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String
	) -> void:
	var box := _field(parent, label_text, description)
	var values := target.get(property_name) as Dictionary
	var keys := values.keys()
	keys.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	for key_value in keys:
		var original_key := str(key_value)
		var row := HBoxContainer.new()
		box.add_child(row)
		var key_edit := LineEdit.new()
		key_edit.text = original_key
		key_edit.placeholder_text = "Identifiant du sort"
		key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(key_edit)
		var amount := SpinBox.new()
		amount.min_value = 0
		amount.max_value = 999
		amount.value = int(values[key_value])
		amount.custom_minimum_size.x = 92
		row.add_child(amount)
		var remove := Button.new()
		remove.text = "Retirer"
		row.add_child(remove)
		key_edit.focus_exited.connect(func():
			var next_key := key_edit.text.strip_edges()
			if not next_key.is_empty() and next_key != original_key:
				var changed := (target.get(property_name) as Dictionary).duplicate(true)
				var old_value: Variant = changed.get(original_key, int(amount.value))
				changed.erase(original_key)
				changed[next_key] = old_value
				property_change_requested.emit(target, property_name, changed, "Renommer une recharge d’invocation")
		)
		amount.value_changed.connect(func(next_value: float):
			var changed := (target.get(property_name) as Dictionary).duplicate(true)
			changed[key_edit.text.strip_edges()] = int(next_value)
			property_change_requested.emit(target, property_name, changed, "Modifier une recharge d’invocation")
		)
		remove.pressed.connect(func():
			var changed := (target.get(property_name) as Dictionary).duplicate(true)
			changed.erase(original_key)
			changed.erase(key_edit.text.strip_edges())
			property_change_requested.emit(target, property_name, changed, "Retirer une recharge d’invocation")
		)
	var add := Button.new()
	add.text = "+ Ajouter une recharge"
	add.pressed.connect(func():
		var changed := (target.get(property_name) as Dictionary).duplicate(true)
		var suffix := 1
		var key := "nouveau_sort"
		while changed.has(key):
			suffix += 1
			key = "nouveau_sort_%d" % suffix
		changed[key] = 0
		property_change_requested.emit(target, property_name, changed, "Ajouter une recharge d’invocation")
	)
	box.add_child(add)


func _add_ordered_modifier_list(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, description: String
	) -> void:
	var box := _field(parent, label_text, description)
	var modifiers := target.get(property_name) as Array
	for index in range(modifiers.size()):
		var modifier := modifiers[index] as SpellModifier
		if modifier == null:
			continue
		var row := HBoxContainer.new()
		box.add_child(row)
		var open := Button.new()
		open.text = modifier.modifier_name
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open.pressed.connect(func(): subject_requested.emit(modifier))
		row.add_child(open)
		for spec in [["↑", -1], ["↓", 1]]:
			var move := Button.new()
			move.text = str(spec[0])
			move.disabled = index + int(spec[1]) < 0 or index + int(spec[1]) >= modifiers.size()
			move.pressed.connect(func():
				var changed := (target.get(property_name) as Array).duplicate()
				var next_index := index + int(spec[1])
				var value: Variant = changed[index]
				changed.remove_at(index)
				changed.insert(next_index, value)
				property_change_requested.emit(target, property_name, changed, "Réordonner les modificateurs permanents")
			)
			row.add_child(move)
		var duplicate := Button.new()
		duplicate.text = "Copier"
		duplicate.pressed.connect(func():
			var changed := (target.get(property_name) as Array).duplicate()
			changed.insert(index + 1, modifier.duplicate(true))
			property_change_requested.emit(target, property_name, changed, "Dupliquer un modificateur permanent")
		)
		row.add_child(duplicate)
		var unique := Button.new()
		unique.text = "Unique"
		unique.pressed.connect(func():
			var changed := (target.get(property_name) as Array).duplicate()
			changed[index] = modifier.duplicate(true)
			property_change_requested.emit(target, property_name, changed, "Rendre unique un modificateur permanent")
		)
		row.add_child(unique)
		var remove := Button.new()
		remove.text = "Retirer"
		remove.pressed.connect(func():
			var changed := (target.get(property_name) as Array).duplicate()
			changed.remove_at(index)
			property_change_requested.emit(target, property_name, changed, "Retirer un modificateur permanent")
		)
		row.add_child(remove)
	var add_new := Button.new()
	add_new.text = "+ Créer un effet"
	add_new.pressed.connect(func():
		var changed := (target.get(property_name) as Array).duplicate()
		changed.append(SpellModSkillTreeEffect.new())
		property_change_requested.emit(target, property_name, changed, "Ajouter un modificateur permanent")
	)
	box.add_child(add_new)
	if Engine.is_editor_hint():
		var picker := EditorResourcePicker.new()
		picker.base_type = "SpellModifier"
		picker.resource_changed.connect(func(resource: Resource):
			if resource is SpellModifier:
				var changed := (target.get(property_name) as Array).duplicate()
				changed.append(resource)
				property_change_requested.emit(target, property_name, changed, "Partager un modificateur permanent")
		)
		box.add_child(picker)


func _add_spell_selector(parent: VBoxContainer, node: SkillUpgradeData) -> void:
	var field := _field(parent, "Sort ciblé", "Sort transformé par les effets de cette amélioration.")
	var option := OptionButton.new()
	var selected := 0
	for index in range(_unit.spells.size() if _unit != null else 0):
		var spell := _unit.spells[index]
		if spell == null:
			continue
		option.add_item(spell.spell_name)
		option.set_item_metadata(option.item_count - 1, spell.get_effective_spell_id())
		if spell.get_effective_spell_id() == node.target_spell_id:
			selected = option.item_count - 1
	option.select(selected)
	field.add_child(option)
	option.item_selected.connect(func(index: int):
		property_change_requested.emit(
			node, &"target_spell_id", StringName(option.get_item_metadata(index)),
			"Changer le sort ciblé"
		)
	)


func _add_node_rank_selector(parent: VBoxContainer, node: SkillUpgradeData) -> void:
	var field := _field(
		parent, "Rang", "Déplace l’amélioration dans un autre rang sans changer son identifiant."
	)
	var option := OptionButton.new()
	if _discipline != null:
		var ranks := _discipline.ranks.duplicate()
		ranks.sort_custom(func(a, b): return a != null and (b == null or a.rank < b.rank))
		for rank_data in ranks:
			if rank_data == null or rank_data.rank <= 1:
				continue
			option.add_item("Rang %d — %d XP" % [rank_data.rank, rank_data.required_total_xp])
			option.set_item_metadata(option.item_count - 1, rank_data.rank)
			if rank_data.rank == node.rank:
				option.select(option.item_count - 1)
	option.item_selected.connect(func(index: int):
		property_change_requested.emit(
			node, &"rank", int(option.get_item_metadata(index)),
			"Déplacer %s" % node.display_name
		)
	)
	field.add_child(option)


func _add_base_spell_selector(
		parent: VBoxContainer,
		discipline: DisciplineData
	) -> void:
	if _unit == null or _unit.spells.is_empty():
		return
	var field := _field(
		parent,
		"Associer un sort existant",
		"Le sort choisi deviendra la racine de cette discipline. Son fonctionnement reste inchangé."
	)
	var option := OptionButton.new()
	option.add_item("Choisir un sort…")
	option.set_item_metadata(0, null)
	for spell in _unit.spells:
		if spell == null:
			continue
		option.add_item(spell.spell_name)
		option.set_item_metadata(option.item_count - 1, spell)
		if spell.discipline_id == discipline.discipline_id:
			option.select(option.item_count - 1)
	field.add_child(option)
	option.item_selected.connect(func(index: int):
		var selected_spell := option.get_item_metadata(index) as Spell
		if selected_spell != null:
			property_change_requested.emit(
				selected_spell,
				&"discipline_id",
				discipline.discipline_id,
				"Associer %s à %s" % [selected_spell.spell_name, discipline.display_name]
			)
	)


func _add_stable_id(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String
	) -> void:
	_add_line(
		parent, target, property_name, label_text,
		"Identifiant technique utilisé par les sauvegardes et les références. Ne le changez pas simplement pour renommer l’élément.",
		"Utilisez des lettres minuscules, chiffres et tirets bas."
	)


func _add_readonly(
		parent: VBoxContainer, label_text: String, value: String, description: String
	) -> void:
	var field := _field(parent, label_text, description)
	var edit := LineEdit.new()
	edit.text = value
	edit.editable = false
	field.add_child(edit)


func _add_storage_info(parent: VBoxContainer, resource: Resource) -> void:
	_add_section(parent, "STOCKAGE")
	var format := "Sous-resource embarquée" if resource.is_built_in() else "Resource externe"
	_add_readonly(parent, "Format", format, "Le Skill Studio conserve ce format lors de la sauvegarde.")
	_add_readonly(parent, "Chemin", resource.resource_path if not resource.resource_path.is_empty() else "Nouveau fichier non sauvegardé", "Emplacement réel de la Resource.")
	_add_action_button(
		parent, "Ouvrir dans l’Inspecteur Godot",
		func(): inspect_in_godot_requested.emit(resource)
	)


func _field(
		parent: VBoxContainer, label_text: String, description: String, example := ""
	) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	parent.add_child(box)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	box.add_child(label)
	if _guided:
		var explanation := Label.new()
		explanation.text = description + ("\n" + example if not example.is_empty() else "")
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		explanation.add_theme_color_override("font_color", Color(0.66, 0.71, 0.78))
		box.add_child(explanation)
	return box


func _add_inline_messages(parent: VBoxContainer, property_name: StringName) -> void:
	var subject_id := _subject_id()
	for message in _messages:
		if message.property_name != property_name or message.subject_id != subject_id:
			continue
		var label := Label.new()
		label.text = "%s : %s%s" % [
			message.severity_label(), message.explanation,
			" Correction : " + message.suggestion if not message.suggestion.is_empty() else "",
		]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.46, 0.42) if message.is_error() else Color(1.0, 0.72, 0.3)
		)
		parent.add_child(label)


func _add_section(parent: VBoxContainer, text: String) -> void:
	var separator := HSeparator.new()
	parent.add_child(separator)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	parent.add_child(label)


func _add_info(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
	parent.add_child(label)


func _add_error_box(parent: VBoxContainer, text: String) -> void:
	var panel := PanelContainer.new()
	var label := Label.new()
	label.text = "⚠ " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42))
	panel.add_child(label)
	parent.add_child(panel)


func _add_action_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _box(name: String) -> VBoxContainer:
	return _boxes[name] as VBoxContainer


func _subject_id() -> StringName:
	if _subject is UnitData:
		return (_subject as UnitData).get_effective_unit_id()
	if _subject is DisciplineData:
		return (_subject as DisciplineData).discipline_id
	if _subject is SkillUpgradeData:
		return (_subject as SkillUpgradeData).upgrade_id
	return _discipline.discipline_id if _discipline != null else &""


func _previous_rank(rank_number: int) -> DisciplineRankData:
	if _discipline == null:
		return null
	var previous: DisciplineRankData = null
	for rank_data in _discipline.ranks:
		if rank_data != null and rank_data.rank < rank_number \
				and (previous == null or rank_data.rank > previous.rank):
			previous = rank_data
	return previous


func _node_display_name(node_id: StringName) -> String:
	if _discipline != null:
		for rank_data in _discipline.ranks:
			if rank_data == null:
				continue
			for node in rank_data.choices:
				if node != null and node.upgrade_id == node_id:
					return node.display_name
	return str(node_id)


func _update_tab_visibility() -> void:
	for index in range(tabs.get_tab_count()):
		var tab_name := tabs.get_tab_title(index)
		var box := _box(tab_name)
		tabs.set_tab_hidden(index, box.get_child_count() == 0 or (_guided and tab_name == "Avancé"))
