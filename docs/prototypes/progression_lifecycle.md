# Cycle de vie de la progression

Ce document décrit uniquement le cycle de vie du système de progression. Il
n'ajoute aucune règle, discipline ou évolution.

## Propriétaire du service et connexion EventBus

`GameManager`, autoload unique pendant l'exécution du projet, possède une seule
instance de `CharacterProgressionService`. Le service est sans état et ne se
connecte pas lui-même au bus. `GameManager` possède aussi l'unique callback
logique qui lui délègue les casts :

`EventBus.spell_cast` → `GameManager._on_successful_spell_cast()` →
`CharacterProgressionService.grant_cast_xp()`.

La connexion est créée par `_connect_progression_service()` dans `_ready()`.
L'appel est idempotent grâce à `Signal.is_connected()`. Elle n'est donc recréée
ni au démarrage d'une run, ni lors d'un changement de salle, ni au retour au
titre. `_disconnect_progression_service()` est appelée par `_exit_tree()` et
retire explicitement le callback. Le cycle de vie du signal est ainsi celui de
`GameManager`, pas celui d'une salle ou d'une run.

Le service recherche le `CharacterRunState` dont la `unit` est exactement
l'instance du lanceur. Une ancienne `Unit`, un ennemi ou un autre personnage ne
peut donc pas créditer l'état courant.

## Cycle de vie d'une run

`GameManager.cleanup_run_state()` est le point de nettoyage commun. Il est
appelé :

- avant un nouveau run préconfiguré, après validation de ses entrées ;
- avant la reconstruction du draft historique ;
- au lancement et à l'annulation d'un nouveau draft ;
- au retour au titre ;
- sur toute erreur rencontrée après le début d'une construction de run.

Le nettoyage ferme l'écran de progression actif, annule la continuation
post-combat, retire le `RunData` en attente et les rewards proposés, remet les
index et indicateurs de run à leur valeur neutre, vide les héros et
`character_states`, puis libère les tableaux de salles et rewards. Le résultat
terminal et le nom du run précédent sont également effacés. Ils restent
disponibles sur `RunResultScreen` jusqu'au retour au titre, mais ne peuvent pas
être réutilisés par une nouvelle run.

Avant de retirer un `CharacterRunState`, `dispose()` :

1. déconnecte `SpellLoadoutState.changed`, ce qui casse le cycle de références
   entre le loadout et son propriétaire `RefCounted` ;
2. détache les modifiers de progression de la `Unit` ;
3. retire les références runtime au personnage, au loadout et aux états de
   discipline.

Les traits historiques sont ensuite désactivés par `Unit.clear_traits()`. Les
Resources statiques chargées depuis les `.tres` ne sont ni supprimées ni
modifiées.

Chaque nouveau `DisciplineProgressState.initialize()` remet explicitement XP à
`0`, rang à `1`, sélections et choix en attente à vide. La nouvelle `Unit`
commence aussi avec une collection vide de modifiers de progression.

## File post-combat et écran

`_awaiting_post_battle_progression` représente l'unique continuation
post-combat différée. `cleanup_run_state()` et `_finish_run()` la neutralisent.
`_room_outcome_resolved` refuse un deuxième résultat de la même bataille ; il
n'est réarmé que lorsque la salle suivante démarre. Deux signaux de victoire
identiques ne peuvent donc ni empiler deux écrans, ni faire avancer deux fois le
run.

`GameManager` ne garde qu'un `WeakRef` vers `ProgressionChoiceScreen`.
`register_progression_screen()` refuse une deuxième instance tant que la
première est valide. L'écran se désenregistre à sa fermeture et dans
`_exit_tree()`. Un nettoyage actif le marque fermé, efface son choix, désactive
la confirmation et le place en `queue_free()`. Un callback tardif voit l'état
fermé et ne peut rien appliquer.

La confirmation possède aussi une garde `_confirmation_in_flight`. Le bouton
est désactivé avant l'appel au contrôleur. Un refus réarme l'écran ; une
acceptation affiche un nouveau dictionnaire défensivement dupliqué ou ferme
l'écran. Deux confirmations rapides ne peuvent donc pas sélectionner deux
évolutions.

## Cycle de vie des modifiers

La chaîne reste :

`CharacterRunState` → `Unit` → `SpellCaster`.

Une sélection recalcule toute la collection active et remplace celle de la
`Unit`. `Unit.set_progression_spell_modifiers()` filtre deux fois la même
instance, et `SpellCaster._gather_modifiers()` conserve son propre filtre lors
de l'assemblage avec les modifiers de sort et de traits. Un nouvel appel de
synchronisation, un changement de salle ou `reset_combat_resources()` ne peut
donc pas ajouter un doublon.

Le nettoyage appelle `Unit.clear_progression_spell_modifiers()`. Une nouvelle
run sans évolution ne reçoit aucun modifier précédent. Deux personnages
possèdent deux tableaux runtime indépendants, même quand ils lisent les mêmes
Resources statiques `SkillUpgradeData` et `SpellModifier`.

## Baseline Godot 4.6.3

Les trois mesures utilisent le même exécutable et la même commande GUT. Les
commits historiques ont été ouverts dans des worktrees détachés afin de
préserver les chemins Unicode.

| État | Scripts | Tests | Assertions | Sortie |
| --- | ---: | ---: | ---: | ---: |
| parent `aeaa9e3b0174a2c55dc5384a4850bfdf9f78f32f` | 15 | 106/106 | 668 | 0 |
| départ `f174c998fbbd9e732e8f0ac3f62927e1683deddb` | 16 | 133/133 | 841 | 0 |
| stabilisation locale | 17 | 151/151 | 1002 | 0 |
| rang 2 des quatre disciplines | 19 | 190/190 | 1393 | 0 |

À la fermeture GUT, les trois mesures donnent exactement :

- `2 RID` de type DummyTexture ;
- `WARNING: ObjectDB instances leaked at exit` ;
- `29 resources still in use at exit` ;
- l'erreur interne GUT `AccessibilityServer` non déclaré ;
- l'erreur interne GUT d'un retour `null` pour `StringName` dans
  `stub_params.gd` ;
- l'avertissement de compatibilité GUT 9.7.1 / Godot 4.6.3.

L'import headless du parent, du commit de départ et de la stabilisation sort
avec le code `0` et le seul avertissement ObjectDB. Il ne signale ni RID ni
compte de Resources.

Un démarrage court de la scène principale (`--quit-after 5`) sort également
avec le code `0` dans les trois états. Chacun signale le même avertissement
ObjectDB et exactement `1 resource still in use at exit`.

Classification :

- les deux erreurs de parsing sont internes à GUT et préexistent au système ;
- l'avertissement de compatibilité appartient à GUT ;
- les deux RID DummyTexture sont identiques dès le parent et relèvent du rendu
  dummy ou du harnais de test, sans preuve d'une régression projet ;
- ObjectDB et les 29 Resources sont une baseline persistante commune, qui peut
  inclure les autoloads volontaires et le harnais GUT. Leur type exact reste
  indéterminé, mais leur nombre ne croît ni avec la progression ni avec cinq
  cycles de run.

L'addon GUT n'a donc pas été modifié.

## Validation et limites

Les 19 tests de `test_progression_lifecycle.gd` exécutent notamment trois
démarrages successifs,
un ancien lanceur, les transitions de salle, les resets de combat, la
libération d'une ancienne `Unit` par `WeakRef`, les nettoyages pendant un choix,
les doubles confirmations, deux personnages indépendants et cinq cycles de
stress. Ils vérifient aussi que le retour au titre détache chacun des six
modifiers ajoutés aux rangs 2 Archer, Assassin et Soigneur. Le premier cast de
chaque run fraîche donne exactement `1 XP`, avec rang `1` et zéro modifier.

La validation automatique couvre le flux réel `EventBus` et le stress
headless. Elle ne remplace pas une longue session interactive avec changement
manuel de toutes les scènes. Les avertissements historiques restent présents,
mais aucune croissance cumulative attribuable à la progression n'a été
observée.
