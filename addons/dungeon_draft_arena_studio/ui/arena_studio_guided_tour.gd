@tool
class_name ArenaStudioGuidedTour
extends AcceptDialog

## Visite volontairement sans prérequis Godot, Git ou Resource.

const PAGES := [
	{
		"title": "Bienvenue dans Arena Studio",
		"target": &"welcome",
		"body": "Cette visite construit une salle jouable sans ouvrir de fichier technique. Arena Studio garde une copie de travail : rien n’est écrit dans le jeu avant une confirmation explicite.",
	},
	{
		"title": "Une run",
		"target": &"run",
		"body": "Une run est la suite ordonnée des salles traversées pendant une partie. La run Principale joue une rencontre par salle. La run de Test peut enchaîner plusieurs vagues dans une même salle.",
	},
	{
		"title": "Une salle",
		"target": &"room",
		"body": "Une salle est le conteneur gameplay placé dans la run. Elle possède une identité, une rencontre ou des vagues, des récompenses, une scène et une arène. Son numéro correspond à sa position dans la run.",
	},
	{
		"title": "Une arène",
		"target": &"arena",
		"body": "L’arène est la partie tactique et visuelle de la salle : grille, dalles, murs, obstacles, points d’apparition, décor, premier plan et occlusion. Mettre à jour une arène ne doit pas effacer le gameplay de sa salle.",
	},
	{
		"title": "La copie de travail",
		"target": &"working_copy",
		"body": "Le Studio édite une copie isolée de l’arène. Annuler, rétablir, Tester et valider utilisent cette copie ; la ressource canonique ne change qu’après votre confirmation explicite dans l’assistant de production.",
	},
	{
		"title": "PAINTED, MODULAR et HYBRID",
		"target": &"visual_modes",
		"body": "PAINTED utilise un décor peint. MODULAR construit le sol et les volumes depuis les données. HYBRID combine un fond peint et des dalles tactiques selon une politique explicite. Background reste derrière le jeu ; foreground et occlusion restent devant lorsque le profil le demande.",
	},
	{
		"title": "La grille tactique",
		"target": &"grid",
		"body": "La grille découpe l’image en cellules jouables. Recentrer et Adapter à l’image règlent la vue. Calibration en 3 clics aligne la grille sur un décor existant sans déplacer le décor lui-même.",
	},
	{
		"title": "Créer les dalles",
		"target": &"tiles",
		"body": "Dans Construction dynamique, choisissez Terrain puis peignez pierre, eau, glace, lave ou vide. Toutes les dalles tactiques affiche aussi les cellules normales avec la vraie texture pierre. Chaque trait peut être annulé.",
	},
	{
		"title": "Murs, obstacles et spawns",
		"target": &"walls_spawns",
		"body": "Mur place un obstacle qui bloque selon sa configuration. Spawn place le départ des héros, des ennemis ou un objectif. Préparer automatiquement peut créer une bordure et des spawns de départ, puis la validation indique ce qui manque.",
	},
	{
		"title": "Exporter la référence artistique",
		"target": &"art_export",
		"body": "Exporter le kit artistique produit des images de référence, une grille et des masques. Vous pouvez les transmettre à un artiste sans lui demander de modifier les données du jeu.",
	},
	{
		"title": "Réimporter le décor",
		"target": &"art_import",
		"body": "Importer le décor relit l’image attendue par le kit et vérifie sa taille et sa géométrie. Le décor reste derrière les dalles tactiques ; le premier plan et l’occlusion restent au-dessus lorsque la scène l’exige.",
	},
	{
		"title": "Logique, Art et Jeu",
		"target": &"views",
		"body": "Logique montre la structure tactique. Art montre le décor et les couches visuelles. Jeu assemble la salle comme le runtime, avec dalles, murs et personnages. Vérifiez toujours les trois vues.",
	},
	{
		"title": "Aperçu rapide ou exact",
		"target": &"quick_exact",
		"body": "Rapide privilégie l’itération et signale clairement ses fixtures. Exact utilise la RunData active, les vrais héros, la rencontre et l’assembleur runtime. Le badge indique toujours la fidélité obtenue ; aucun fallback n’est silencieux.",
	},
	{
		"title": "Valider",
		"target": &"validate",
		"body": "Valider contrôle la grille, les chemins, les spawns et l’assemblage. Une erreur bloque la production. Un avertissement explique un point à vérifier sans modifier automatiquement votre salle.",
	},
	{
		"title": "Tester",
		"target": &"test",
		"body": "Tester lance la copie de travail dans la vraie scène de combat. La salle canonique n’est pas modifiée. Revenez au Studio pour corriger, annuler ou rétablir vos changements.",
	},
	{
		"title": "Choisir la destination",
		"target": &"destination",
		"body": "Dans Destination de la salle, choisissez Principale ou Test, l’action et la salle. Mettre à jour l’arène est recommandé : rencontre, vagues et récompenses sont conservées. Remplacer toute la salle est un mode avancé.",
	},
	{
		"title": "Conflit de bundle",
		"target": &"bundle_conflict",
		"body": "Un bundle existant est inspecté avant toute écriture : complet, incomplet, référencé, legacy, étranger ou modifié. Un bundle incomplet non référencé peut être archivé puis reconstruit après confirmation. Un bundle référencé bloque cette action.",
	},
	{
		"title": "Mettre à jour ou remplacer",
		"target": &"update_replace",
		"body": "Mettre à jour l’arène conserve l’identité de la salle, sa rencontre, ses vagues et ses récompenses. Remplacer toute la salle remplace aussi ces champs et demande une confirmation avancée. L’assistant affiche toujours ce qui sera conservé.",
	},
	{
		"title": "Intégrer à la run",
		"target": &"integrate",
		"body": "Lisez le résultat, la portée, les chemins et les fichiers affectés, puis cliquez Intégrer à la run. Le Studio produit, sauvegarde avec recovery, recharge, vérifie l’index exact et sélectionne immédiatement la salle intégrée.",
	},
	{
		"title": "Rollback et récupérations",
		"target": &"rollback",
		"body": "Production et intégration forment une transaction. Si un stage, un hash, une sauvegarde ou un rechargement échoue, le Studio restaure la run et le bundle précédents. Productions et récupérations permet d’ouvrir les rapports et de restaurer explicitement une archive.",
	},
	{
		"title": "Réintégrer la fenêtre",
		"target": &"reintegrate",
		"body": "Le workspace peut être détaché pour gagner de la place. Le bouton Réintégrer la fenêtre ou le raccourci configuré remet exactement la même instance dans l’éditeur : copie de travail, sélection, zoom et historique sont conservés.",
	},
	{
		"title": "Exercice sandbox",
		"target": &"sandbox",
		"body": "L’exercice guidé travaille uniquement sous user://dungeon_draft_studio/tests : petite arène, terrains, murs, spawns, validation, kit artistique, décor fixture, bundle incomplet, archive/reconstruction, RunData fixture, intégration puis rollback. Aucune run officielle n’est modifiée.",
	},
]

var _page := 0
var _title_label: Label
var _body_label: Label
var _counter_label: Label
var _previous_button: Button
var _next_button: Button


func _ready() -> void:
	title = "Visite guidée — créer et intégrer une salle"
	min_size = Vector2i(680, 410)
	get_ok_button().hide()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 23)
	_title_label.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	root.add_child(_title_label)
	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(620, 225)
	_body_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_body_label)
	var footer := HBoxContainer.new()
	root.add_child(footer)
	_counter_label = Label.new()
	_counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_counter_label)
	_previous_button = Button.new()
	_previous_button.text = "← Précédent"
	_previous_button.pressed.connect(func():
		_page = maxi(0, _page - 1)
		_refresh()
	)
	footer.add_child(_previous_button)
	var restart := Button.new()
	restart.text = "Recommencer"
	restart.pressed.connect(func():
		_page = 0
		_refresh()
	)
	footer.add_child(restart)
	_next_button = Button.new()
	_next_button.pressed.connect(_next)
	footer.add_child(_next_button)
	_refresh()


func start(start_target: StringName = &"") -> void:
	_page = 0
	if start_target != &"":
		for index in range(PAGES.size()):
			if StringName(PAGES[index].get("target", &"")) == start_target:
				_page = index
				break
	_refresh()
	popup_centered()


func current_target() -> StringName:
	return StringName(PAGES[_page].get("target", &""))


func _next() -> void:
	if _page >= PAGES.size() - 1:
		hide()
		return
	_page += 1
	_refresh()


func _refresh() -> void:
	if _title_label == null:
		return
	var page := PAGES[_page] as Dictionary
	_title_label.text = str(page.get("title", ""))
	_body_label.text = str(page.get("body", ""))
	_counter_label.text = "Étape %d sur %d" % [_page + 1, PAGES.size()]
	_previous_button.disabled = _page == 0
	_next_button.text = "Terminer" if _page == PAGES.size() - 1 else "Suivant →"
