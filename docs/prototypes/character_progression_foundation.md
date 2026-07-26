# Fondation de progression des personnages

## Identifiants stables

`UnitData.unit_id` et `Spell.spell_id` sont désormais les clés durables du runtime. Les anciennes ressources restent compatibles grâce à un fallback déterministe utilisant leur `resource_path`, jamais leur nom affiché. `Spell.discipline_id` reste un `StringName` ouvert afin que de futurs personnages puissent déclarer leurs propres disciplines.

## Données et états

`DisciplineData` porte uniquement l'identité et la présentation d'une discipline : identifiant, libellé, description, icône et couleur. Les disciplines disponibles sont associées à chaque `UnitData`.

`SpellLoadoutState` conserve séparément les sorts connus et les quatre emplacements actifs par défaut. Il refuse les identifiants dupliqués, n'équipe que des sorts connus et renvoie des copies défensives de ses listes.

`CharacterRunState` relie une `Unit`, son identifiant, ses disciplines et son loadout. Chaque héros reçoit sa propre instance. Le signal de changement du loadout appelle explicitement `sync_loadout_to_unit()`, de sorte que `Unit.spells` reste la vue active consommée par le combat et le HUD.

`GameManager.character_states` conserve ces états par `character_id` pour les runs préconfigurés. La liste historique `heroes` reste inchangée, et le draft historique ne crée pas de loadout plafonné afin de ne tronquer aucun ancien héros.

## Contenu initial de l'Elfe

L'Elfe déclare quatre disciplines data-driven et un sort actif par discipline :

1. Archer — `elf_precise_shot` — Tir précis
2. Assassin — `elf_sneak_strike` — Frappe sournoise
3. Mage — `elf_fireball` — Boule de feu
4. Soigneur — `elf_sylvan_heal` — Soin sylvestre

La Boule de feu de l'Elfe est une ressource distincte, car la ressource historique est également utilisée par le Mage. Elle réutilise les mêmes VFX, audio, terrain et effets sans modifier le contenu historique.

## Évolutions construites sur la fondation

La progression d’XP, les rangs et les choix post-combat sont désormais posés
au-dessus de cette architecture sans changer le contrat du loadout. La tranche
Mage initiale est décrite dans `elf_mage_progression_slice.md`; le rang 2 des
quatre disciplines est décrit dans `elf_rank_two_disciplines.md`.

Les rangs 3+, le remplacement interactif, le grimoire, les équipements et les
énergies propres à ces personnages restent hors périmètre.
