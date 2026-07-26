# Tranche verticale de progression Mage de l'Elfe

## Règle d'XP

`GameManager` écoute l'annonce unique `EventBus.spell_cast(caster, spell, report)` et délègue l'attribution à `CharacterProgressionService`. Un cast accepté et résolu donne exactement `1 XP` à la discipline portée par `Spell.discipline_id`, même si son effet réel est faible ou nul. Cette règle volontairement simple pourra être réévaluée plus tard.

Un refus de coût, une cible invalide ou une annulation avant l'appel à `SpellCaster.cast()` n'émet pas `spell_cast` et ne donne donc rien. Une zone touchant plusieurs unités ou cellules reste un seul cast et rapporte un seul point. Le lanceur doit être l'instance exacte d'une `Unit` associée à un `CharacterRunState` ; les ennemis, sorts sans discipline et autres personnages ne peuvent pas créditer cet état.

Chaque gain apparaît dans le journal joueur sous la forme `+1 XP Mage`, avec l'identifiant de discipline, l'XP actuelle, le rang et le prochain seuil disponibles dans l'instantané de progression.

## Données et état vivant

Les règles restent dans des Resources génériques :

- `DisciplineRankData` définit un rang, son seuil d'XP totale et ses choix ;
- `SkillUpgradeData` définit un identifiant stable, sa présentation, la discipline, le rang, le sort ciblé et ses `SpellModifier` ;
- `DisciplineData.ranks` contient les rangs configurés.

`DisciplineProgressState` contient uniquement l'état vivant de la run : `discipline_id`, XP, rang, identifiants sélectionnés et rangs dont le choix est en attente. `CharacterRunState` possède un dictionnaire indépendant de ces états pour chaque personnage. Ni `Spell`, ni `DisciplineData`, ni les autres Resources partagées ne reçoivent d'état mutable.

## Seuil Mage rang 2

La discipline Mage de l'Elfe déclare :

- rang 1 : seuil total `0`, aucun choix ;
- rang 2 : seuil total `3`, exactement deux choix exclusifs.

Le troisième cast réussi de Boule de feu fait passer Mage au rang 2 et ajoute une seule entrée de rang `2` à la file. Les XP suivantes ne dupliquent pas cette entrée et aucun choix n'est attribué automatiquement.

## File de choix post-combat

Le combat ne consulte jamais la file et aucune interface ne l'interrompt. Après une victoire, `GameManager` applique l'ordre :

1. premier choix de progression en attente ;
2. autres choix éventuels ;
3. récompense de salle lorsqu'un pool existe ;
4. salle suivante ou `RunResultScreen` après la dernière salle.

`ProgressionChoiceScreen` reçoit un dictionnaire générique fourni par `GameManager`. Il affiche le personnage, la discipline, le rang, l'XP, le seuil et les deux cartes. Le joueur doit sélectionner une carte puis confirmer. La confirmation enregistre l'identifiant, retire le rang de la file et passe au choix suivant ou reprend le run.

## Application des évolutions

La chaîne est distincte des récompenses et des traits :

`SkillUpgradeData` → `CharacterRunState` → modificateurs de progression de `Unit` → `SpellCaster`.

`SpellCaster._gather_modifiers()` réunit les modificateurs du sort, des traits historiques et de la progression, filtre par identifiant stable de sort et évite les doublons. Les Resources `Spell` ne sont jamais modifiées pendant un cast.

### Cœur incandescent

`elf_mage_incandescent_core` cible `elf_fireball`. Son modifier écrit `+3` dans le bonus de dégâts de la cellule centrale du `CastContext`. Seule une unité exactement sur `ctx.cell` reçoit ce bonus ; les cellules périphériques conservent les dégâts normaux. Le dictionnaire est recréé pour chaque cast et ne fuit ni vers un autre sort, ni vers un autre lanceur.

### Braises persistantes

`elf_mage_persistent_embers` cible également `elf_fireball`. Après la résolution du terrain normal de Boule de feu, son modifier pose sur toutes les cellules affectées le terrain existant `res://data/terrain/feu.tres` avec une durée runtime forcée à un tour. La Resource de terrain n'est ni dupliquée ni mutée.

## Persistance

XP, rang, file et sélection vivent dans le `CharacterRunState` conservé par `GameManager` entre les salles. La même `Unit` garde sa collection explicite de modificateurs de progression ; `reset_combat_resources()` ne la touche pas. Une nouvelle run reconstruit les états et repart au rang 1, avec 0 XP et aucun choix.

## Compatibilité historique

Le draft historique ne crée toujours aucun `CharacterRunState` plafonné. Ses héros, huit sorts du Guerrier, énergies, Empreintes, traits, récompenses et `SpellModifier` par nom restent fonctionnels. Un sort sans `discipline_id` continue de se lancer normalement sans donner d'XP. Le flux historique conserve `RewardScreen`.

## Suite

Cette tranche reste la référence des deux choix Mage inchangés. Archer,
Assassin et Soigneur possèdent désormais eux aussi un rang 2 jouable; voir
`elf_rank_two_disciplines.md`.

Les rangs 3 à 5, l’arbre complet, le grimoire, le remplacement interactif,
l’équipement, l’énergie, la métaprogression et la sauvegarde disque restent
hors périmètre.
