@tool
class_name ArenaHeroStartCapacityService
extends RefCounted

## Résout la capacité de départ depuis l'autorité de run et le même résolveur
## que le runtime. Aucun effectif fixe n'est maintenu dans l'interface.


static func resolve(run_data: RunData) -> Dictionary:
	if run_data == null:
		return {
			"known": false,
			"minimum": 0,
			"message": "Sélectionnez une run pour vérifier la capacité de départ des héros.",
			"heroes": [],
		}
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run_data, true)
	if resolution == null or not resolution.is_valid():
		return {
			"known": false,
			"minimum": 0,
			"message": "L’effectif de la run sélectionnée ne peut pas être résolu.",
			"heroes": [],
			"errors": resolution.errors.duplicate() if resolution != null else [],
		}
	return {
		"known": true,
		"minimum": resolution.heroes.size(),
		"message": "%d case(s) de départ héros minimum pour cette run." % resolution.heroes.size(),
		"heroes": resolution.heroes.duplicate(),
		"used_legacy_fallback": resolution.used_legacy_fallback,
	}
