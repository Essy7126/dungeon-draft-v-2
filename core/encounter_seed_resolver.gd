@tool
class_name EncounterSeedResolver
extends RefCounted

## Source de verite partagee pour la seed transmise au planificateur.
const WAVE_SEED_STRIDE := 104_729


static func effective_seed(run_seed: int, wave_index: int) -> int:
	return run_seed + maxi(0, wave_index) * WAVE_SEED_STRIDE
