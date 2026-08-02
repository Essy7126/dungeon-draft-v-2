# Racines de dépendances avant nettoyage

## Configuration exécutable

- `project.godot` : `run/main_scene = uid://bhxy4lh81uk3i` → `res://ui/TitreEcran.tscn`.
- Godot déclaré : `4.7`, Forward Plus.
- Autoloads : `DebugLogger`, `EventBus`, `CombatLogger`, `DebugOverlay`, `GameManager`, `AudioManager`, `VFXManager`.

## Parcours cible prouvé avant migration

- `res://ui/TitreEcran.tscn` → `res://ui/party/PartyPresentationScreen.tscn`.
- Équipe configurée : `elfe.tres`, `mage.tres`, `Guerrier.tres`.
- Run configurée : `fixed_trio_prototype_run.tres`.
- Salles à squelettes atteignables : `le_gue.tres`, `la_forge.tres`, `elite_brute.tres`, `terrain_2.tres`.
- Ennemis cibles : `skeleton_melee.tres`, `skeleton_ranged.tres`, `skeleton_chief.tres`.
- Progression : `CharacterRunState`, `DisciplineProgressState`, `SpellLoadoutState`, `CharacterProgressionService`, `SkillTreeResolver`, `SpellModifier`.

## Tests racines

- Tous les `res://test/unit/test_*.gd` configurés par `.gutconfig.json`.
- Scènes et observateurs sous `res://tests/room_transition/`.
- `addons/gut/` et `.github/workflows/ci.yml`.

## Méthode de résolution

- chemins littéraux `res://` ; UID ; identifiants `class_name` ; autoloads ; constantes de chemins ; fermeture transitive.
- Les chemins construits dynamiquement sans littéral restent `UNKNOWN` jusqu’à preuve contraire.
