@tool
class_name TerrainVocabulary
extends RefCounted

## Glossaire unique du domaine Terrain. Le parcours nominal n'emploie que ces
## libelles ; les identifiants techniques restent disponibles pour le mode
## avance et pour les rapports.

const TAB_TITLE := "TERRAINS"
const TAB_SUBTITLE := "Construire la zone tactique d'une salle"

## Correspondance terme technique -> terme utilisateur. Elle sert aussi de
## table de verite au test de vocabulaire : aucune de ces cles ne doit
## apparaitre dans un libelle du parcours guide.
const USER_TERMS := {
	"spawn": "Point de départ",
	"spawns": "Points de départ",
	"foreground": "Premier plan",
	"occlusion": "Zones masquées",
	"runtime": "Résultat en jeu",
	"bundle": "Dossier de production",
	"background": "Illustration de fond",
	"painted": "Depuis une illustration",
	"modular": "Avec des tuiles",
	"hybrid": "Illustration avec tuiles spéciales",
}

## Definition courte de chaque mot du domaine, affichee dans l'aide et dans
## l'ecran d'accueil. Une seule definition par terme, partagee par tout le
## Studio.
const GLOSSARY := [
	["Salle", "Une étape d'une partie : sa rencontre, ses récompenses et son terrain."],
	["Terrain", "La zone tactique de la salle : la grille, les sols, les obstacles et les départs."],
	["Décor", "L'illustration de fond et le premier plan posés autour de la grille."],
	["Point de départ", "La case où un héros, un ennemi ou une invocation arrive au début du combat."],
	["Surface temporaire", "Un effet créé pendant le combat par un sort ; il n'est pas enregistré dans le terrain."],
	["Brouillon", "Une copie de travail enregistrée pour vous seul ; la partie n'est pas modifiée."],
	["Tester", "Lancer le vrai combat sur la version en cours, sans rien publier."],
	["Intégrer", "Rendre le terrain disponible dans une salle de la partie."],
]

## Les trois intentions de creation proposees a l'entree. L'ordre est celui des
## cartes affichees ; l'index correspond a ArenaDefinition.VisualMode.
const CREATION_CHOICES = [
	{
		"visual_mode": 0,
		"title": "Depuis une illustration",
		"display_title": "Depuis une illustration",
		"summary": "Importer un décor puis aligner la grille dessus.",
		"detail": "Le décor est une image peinte. Vous placerez la grille par-dessus en trois clics.",
		"needs_image": true,
		"confirm_label": "Créer et aligner l'illustration",
	},
	{
		"visual_mode": 1,
		"title": "Avec des tuiles",
		"display_title": "Avec des tuiles",
		"summary": "Choisir une taille et construire directement le terrain.",
		"detail": "Le Studio dessine le sol pour vous. C'est le choix le plus simple pour un premier terrain.",
		"needs_image": false,
		"confirm_label": "Créer et peindre",
	},
	{
		"visual_mode": 2,
		"title": "Illustration avec tuiles spéciales",
		"display_title": "Illustration avec tuiles spéciales",
		"summary": "Combiner un décor peint et des sols interactifs.",
		"detail": "Le décor reste au fond ; seules les cases spéciales (eau, glace, lave…) sont dessinées par-dessus.",
		"needs_image": true,
		"confirm_label": "Créer et aligner l'illustration",
	},
]

## Libelles utilisateur des trois apercus. Ils remplacent Logique / Art / Jeu.
const PREVIEW_LABELS := ["Structure", "Décor", "Résultat en jeu"]
const PREVIEW_TOOLTIPS := [
	"Voir la structure tactique : cases, sols, obstacles et départs.",
	"Voir le décor peint et ses couches.",
	"Voir le terrain assemblé comme dans la partie.",
]

## Orientation du camp des heros, en clair.
const CAMP_ORIENTATIONS := [
	"Héros en bas à gauche",
	"Héros en bas à droite",
	"Héros en haut à gauche",
	"Héros en haut à droite",
]


static func user_term(technical: String) -> String:
	return str(USER_TERMS.get(technical.to_lower(), technical))


static func creation_choice(index: int) -> Dictionary:
	var safe := clampi(index, 0, CREATION_CHOICES.size() - 1)
	return (CREATION_CHOICES[safe] as Dictionary).duplicate(true)


static func preview_label(index: int) -> String:
	return PREVIEW_LABELS[clampi(index, 0, PREVIEW_LABELS.size() - 1)]


static func glossary_markdown() -> String:
	var lines := PackedStringArray()
	for entry in GLOSSARY:
		lines.append("[b]%s[/b] — %s" % [entry[0], entry[1]])
	return "\n".join(lines)
