@tool
class_name SpellIdPathService
extends RefCounted

## Traduit le nom français d'un sort en identifiant technique, puis en chemin de
## fichier. Deux emplacements sont légitimes et permanents :
## - le dossier du personnage, convention déjà appliquée par add_discipline() ;
## - le dossier partagé du projet, convention déjà appliquée par mur_de_glace.tres.
## L'emplacement range le fichier, il ne rend jamais le sort exclusif à un
## personnage : un Spell reste une Resource autonome et référençable.

const CHARACTER_SPELL_DIRECTORY := "res://data/characters/%s/spells"
const SHARED_SPELL_DIRECTORY := "res://data/spells"
const ACCENT_REPLACEMENTS := {
	"à": "a", "â": "a", "ä": "a", "á": "a", "ã": "a",
	"ç": "c", "é": "e", "è": "e", "ê": "e", "ë": "e",
	"î": "i", "ï": "i", "í": "i", "ô": "o", "ö": "o", "ó": "o",
	"ù": "u", "û": "u", "ü": "u", "ú": "u", "ÿ": "y", "œ": "oe",
	"’": "_", "'": "_", "-": "_", " ": "_",
}


## `heroes` est le catalogue du projet (SkillTreeCatalogService.discover_units()).
## `current_path` exclut le personnage ouvert du test de collision, exactement
## comme _project_id_collision() le fait déjà dans le Studio : sa copie de
## travail est comparée à part. `reserved_ids` couvre les identifiants créés
## pendant la session, que le disque ne connaît pas encore — sans lui, deux
## créations successives portant le même nom produiraient le même identifiant.
func suggest_spell_id(
		display_name: String,
		heroes: Array[Dictionary],
		current_path := "",
		reserved_ids: Array = []
	) -> StringName:
	var base := normalize_spell_id(display_name)
	if base.is_empty():
		base = "nouveau_sort"
	var candidate := StringName(base)
	var suffix := 2
	while _spell_id_taken(candidate, heroes, current_path, reserved_ids):
		candidate = StringName("%s_%d" % [base, suffix])
		suffix += 1
	return candidate


func normalize_spell_id(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	for source in ACCENT_REPLACEMENTS:
		normalized = normalized.replace(source, ACCENT_REPLACEMENTS[source])
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_"
	var result := ""
	var previous_underscore := false
	for character in normalized:
		var safe := character if allowed.contains(character) else "_"
		if safe == "_":
			if previous_underscore:
				continue
			previous_underscore = true
		else:
			previous_underscore = false
		result += safe
	return result.trim_prefix("_").trim_suffix("_")


## Même convention que celle écrite en dur dans add_discipline() pour le sort de
## base d'une nouvelle discipline.
func character_draft_path(unit: UnitData, spell_id: StringName) -> String:
	var unit_slug := normalize_spell_id(str(unit.get_effective_unit_id())) \
		if unit != null else ""
	if unit_slug.is_empty():
		unit_slug = "personnage"
	return (CHARACTER_SPELL_DIRECTORY % unit_slug).path_join("%s.tres" % spell_id)


## Emplacement des sorts réutilisables par tout le projet, déjà occupé par
## mur_de_glace.tres.
func shared_draft_path(spell_id: StringName) -> String:
	return SHARED_SPELL_DIRECTORY.path_join("%s.tres" % spell_id)


func _spell_id_taken(
		value: StringName,
		heroes: Array[Dictionary],
		current_path: String,
		reserved_ids: Array
	) -> bool:
	for reserved in reserved_ids:
		if StringName(reserved) == value:
			return true
	if heroes.is_empty():
		return false
	return SkillTreeReferenceIndex.project_id_exists(
		heroes, "spell", value, current_path
	)
