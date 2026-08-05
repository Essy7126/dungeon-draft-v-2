# Audit avant modification — snapshots UI et feedback de combat

Date d'observation : 5 août 2026. Cet état « Before » a été relevé avant les modifications de la mission. La source de vérité est le dépôt local au HEAD `1aadd1bd1dec5d1cf108740c0f57e80047d22539`.

## Environnement et Git

- Racine : `C:/Users/paolo/Documents/dungeon-draft-v-2`
- Branche : `main`
- Godot : `4.7.1.stable.official.a13da4feb`, Forward Plus dans le projet
- Scène principale : UID `uid://bhxy4lh81uk3i`, résolu vers `res://ui/TitreEcran.tscn`
- Remote : `origin`, dépôt GitHub configuré
- Worktree : sale avant la mission. Le chantier Arena Studio, ses captures, le terrain dynamique et plusieurs fichiers de rendu étaient déjà modifiés ou non suivis. Aucun changement préexistant n'a été supprimé, stashed, réinitialisé ou écrasé.
- Conséquence : aucune branche, aucun commit et aucun push pour ne pas déplacer le travail local en cours.

## Parcours de production vérifié

Le chemin réel est : titre → StartHub → Archiviste/déclenchement de run → cinématique d'introduction → préparation de `first_run.tres` par `GameManager` → transition de salle → bataille peinte/déploiement → HUD persistant → inventaire/arbre/pause → après-combat/récompense → salle suivante → résultat de run.

L'inventaire détaillé et les blocages de fixtures sont générés par le registre dans `artifacts/ui_snapshots/1aadd1bd/inventory.md`. Il contient 23 couples écran/état : titre, hub (idle, Archiviste, dialogue, sélection de run, commerce), cinématique, transition, bataille/déploiement, cinq états de HUD/ciblage, inventaire, arbre, évolution, pause, après-combat, récompense, résultat, galerie de feedback et Arena Studio.

Arena Studio est une interface de production de l'éditeur, mais son chantier local recouvrait de nombreux fichiers préexistants. Il est inventorié et volontairement non capturé/modifié par cette mission. Les laboratoires et anciennes scènes simplement présentes sur disque n'ont pas été promus comme écrans de production.

## Architecture UI et rendu

- Le combat principal est un montage 2D isométrique (`Node2D`, `Camera2D`, Y-sort).
- Les personnages 3D sont rendus dans des `SubViewport`, puis intégrés par les vues d'unité 2D.
- Le HUD est en `CanvasLayer`/`Control` et reste indépendant de la perspective.
- Les `UnitView` sont regroupées et portent la correspondance vers leur `Unit` métier.
- Stratégie retenue après audit : texte en `Control` dans un `CanvasLayer` plein écran ; projection de l'ancre via la `UnitView`, puis fallback grille/caméra et centre du viewport. Cela garde une typographie nette et évite un `Label3D` affecté par la perspective.

## Pipeline de dégâts constaté

`DamageResolver.compute()` effectuait : validation du montant → esquive → résistance élémentaire → armure/résistance magique → multiplicateurs de statuts → critique → arrondi/plancher. `Unit._apply_damage_result()` effectuait ensuite l'absorption du bouclier puis la perte de PV.

Avant migration :

- `damage_dealt` transportait `DamageResult.amount`, soit le coup après mitigation et critique mais avant bouclier ; il ne représentait donc pas forcément la perte de PV.
- Il était émis après la mutation du bouclier, mais avant la soustraction de `current_hp`.
- `health_damage_taken` transportait déjà la perte réelle de PV et était émis après la mutation des PV.
- Un impact pouvait produire `shield_absorbed`, `damage_dealt`, `health_damage_taken`, `critical_hit` et les signaux locaux de jauge. Ces signaux n'avaient pas d'identifiant commun.
- Les abonnés actifs de `damage_dealt` étaient `battle/unit_view.gd` (flash 2D), `characters/character_iso_unit_view.gd` (réaction d'impact 3D projetée) et `battle/reporting/combat_report_tracker.gd` (statistiques sortantes).
- `CastContext.resolved` empêchait déjà une double résolution globale du cast, mais il n'existait pas d'idempotence par cible/impact.
- Les AOE résolvaient chaque cellule/cible séparément, sans `impact_id` ni `sequence_index` exposé.
- Les DoT empruntaient bien `Unit.take_damage()`, mais sans fait périodique typé.

## Pipeline de soins et bouclier constaté

- `Unit.heal()` plafonnait correctement les PV et émettait le soin réel dans `unit_healed`/`healing_applied`.
- Le montant théorique et l'overheal n'étaient pas exposés ensemble.
- `add_shield()` remplaçait un bouclier plus faible. `shield_gained` annonçait le montant demandé, pas toujours le delta effectivement gagné.
- Aucune mécanique d'immunité aux dégâts n'a été trouvée dans le chemin de production. Il ne faut donc pas inventer une règle métier : seule la capacité événementielle/visuelle peut être préparée.

## Feedback existant

`battle/floating_text_spawner.gd` constituait déjà un point central et utilisait un pool. Il écoutait les pertes de PV, soins, gains de bouclier et esquives, mais :

- son style était dispersé et codé en dur ;
- le gain de bouclier affichait le montant demandé ;
- il ne distinguait ni bouclier absorbé, critique structuré, DoT, immunité ou statuts ;
- il n'avait aucun identifiant de déduplication ;
- le rendu `Node2D` suivait l'espace monde plutôt qu'une couche écran stable.

## Défauts confirmés et historique

Confirmés : ambiguïté de `damage_dealt`, ordre pré-PV, absence d'overheal structuré, absence d'identifiants d'impact, styles non data-driven et projection monde fragile.

Déjà corrigés depuis l'audit historique du 2 août : la perte réelle de PV existait dans `health_damage_taken`, les DoT utilisaient le moteur central de dégâts, et un spawner central/poolé existait déjà. L'audit historique restait juste sur le fait que `damage_dealt` ne devait pas piloter l'affichage des PV.

## Risques et plan retenu

Risques : compatibilité des consommateurs legacy, double émission lors d'une double résolution, durée de vie des cibles, densité multi-impact à 720p, dépendances runtime de certaines scènes et pollution du chantier Arena Studio.

Plan : caractériser l'ordre → introduire un fait résolu unique → propager action/cast/impact/ordre → migrer les deux abonnés → conserver `damage_dealt` déprécié → remplacer le spawner sans casser les scènes → créer styles/réglages/galerie → créer runner/registre/manifeste → tests ciblés → captures réelles → handoff fallback.

## Hors périmètre respecté

Pas de changement des formules, valeurs de sorts, statistiques, progression, IA, salles, récompenses, inventaire métier, pathfinding, ligne de vue, cartes, scène principale, flux du hub, nombre de sorts, rigs ou animations de personnages.
