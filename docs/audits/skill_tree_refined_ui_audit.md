# Audit fonctionnel et validation — arbre de compétences REFINED V2

Date de référence : 2026-08-01

Branche : `main`

HEAD de départ après synchronisation : `79c4aebf3ff10fbab8b40bed45ea242dd41ea963`

## Périmètre réellement présent

Le système de progression possède une source de vérité unique et exploitable. Les règles, XP, rangs, choix, prérequis, exclusions et modificateurs sont portés par les ressources et par les classes de progression existantes. L’écran `SkillTreeScreen` est consultatif pendant le combat ; les choix effectifs sont résolus par le flux de progression existant après combat.

Personnages et données disponibles :

| Personnage | Disciplines réelles | Profondeur réelle |
|---|---|---|
| Elf | Archer, Assassin, Mage, Soigneur | Archer : rangs 1–5, 18 choix ; trois autres branches : rangs 1–2, 2 choix chacune |
| Mage | Pyromancie, Cryomancie, Foudromancie, Géomancie | rang 1 uniquement, aucun choix |
| Guardian | aucune | progression non définie |
| Warrior | aucune | progression non définie |
| Druid | aucune | progression non définie |
| Assassin | aucune | progression non définie |
| Necromancer | aucune | progression non définie |
| Hoplite | aucune | progression non définie |

Seuils réels de l’Archer : 0, 3, 7, 12 et 18 XP. Les autres branches Elf ont un seuil de rang 2 à 3 XP. Les disciplines du Mage ne déclarent qu’un rang racine à 0 XP. Aucun arbre fictif ne doit être créé pour les six autres personnages.

## Fichiers et responsabilités

- `ui/progression/screens/skill_tree_screen.gd/.tscn` : ouverture, fermeture, onglets, sélection de branche, détail, responsive et restauration du focus.
- `ui/progression/components/skill_tree_graph_view.gd/.tscn` : création des nodes, placement, connexions, scroll et navigation spatiale.
- `ui/progression/components/skill_tree_node_view.gd/.tscn` : rendu d’un node et des cinq états visuels actuels.
- `ui/progression/components/skill_tree_node_detail_panel.gd/.tscn` : détail consultatif du node sélectionné.
- `ui/progression/components/skill_tree_discipline_tab.gd/.tscn` : navigation actuelle des disciplines.
- `ui/progression/skill_tree_visual_state.gd` : projection des règles en états `SELECTED`, `AVAILABLE`, `LOCKED_BY_XP`, `LOCKED_BY_BRANCH` et `FUTURE`.
- `characters/progression/skill_tree_resolver.gd` : validation et décision d’éligibilité ; reste la source de vérité des prérequis et exclusions.
- `data/characters/skill_tree_node_data.gd`, `skill_upgrade_data.gd`, `discipline_data.gd`, `discipline_rank_data.gd` : modèle de données.
- `characters/progression/discipline_progress_state.gd`, `character_run_state.gd` : XP, rangs, choix en attente, choix acquis et synchronisation des modificateurs.
- `data/characters/**/disciplines/*.tres` et `data/characters/elf/upgrades/*.tres` : contenu réel de progression.
- `ui/run/persistent_run_ui.gd/.tscn` : ouverture depuis le HUD, neutralisation/restauration des contrôles et compatibilité avec la pause.
- `ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd` : signal du bouton `Compétences` du UtilityDock.
- `ui/progression/lab/skill_tree_graybox_lab.gd/.tscn` : preview existante.
- `ui/progression/skin/*`, `ui/progression/theme/skill_tree_graybox_theme.tres` et `asset/ui/dungeon_draft/arbre_compétences/*` : skin et assets.

## Modèle de données et règles observées

- `DisciplineData` contient l’identité, la couleur de présentation et les rangs.
- `DisciplineRankData` contient le rang, le seuil total d’XP et les choix.
- `SkillTreeNodeData` étend `SkillUpgradeData` avec les vrais prérequis et exclusions.
- `DisciplineProgressState` conserve XP, rang, choix acquis et rangs en attente.
- `SkillTreeResolver` valide les arbres, refuse les choix hors rang, sans prérequis ou exclus, et empêche de résoudre un rang avant les précédents.
- `CharacterRunState.select_upgrade()` reste le seul point d’application d’un choix et de ses modificateurs au personnage.
- L’écran de combat ne mute actuellement aucune donnée : il est volontairement consultatif.

## Limites et problèmes de lisibilité

- Le header ne montre que le nom en texte : aucun portrait, emblème HUD, accent personnage ou résumé global.
- Les branches sont des onglets horizontaux. Elles n’affichent ni XP, ni seuil suivant, ni jauge, ni état MAX, ni chemin déjà choisi.
- La hiérarchie globale est plate : titre, rangs et branches entrent en concurrence avant le chemin de progression.
- Le panneau de détail affiche description, sort, prérequis, état et raison, mais ne hiérarchise pas clairement l’action disponible et n’expose pas les incompatibilités comme une section dédiée.
- Les états sont distincts par pictogramme et teinte, mais la sélection d’inspection n’est pas persistante visuellement après la perte du focus.
- Aucun libellé court directement sur le node ne distingue explicitement `ACQUIS`, `DISPONIBLE`, `VERROUILLÉ` et `EXCLU`.
- Le rang maximum est seulement résumé dans le footer ; il n’est pas visible dans la navigation de branche.

## Limites responsive et navigation

- À 720p, la somme du graphe minimal, du panneau de détail et des marges dépend fortement du scroll horizontal ; la navigation de branches reste une rangée horizontale supplémentaire.
- Le panneau de détail ne peut pas être replié.
- Le graphe est scrollable via `ScrollContainer`, mais ne propose ni drag-pan, ni commandes de recentrage, ni indication de navigation.
- Le zoom n’est pas nécessaire avec les données actuelles et n’est pas implémenté.
- La navigation clavier/manette existe entre onglets, nodes et bouton fermer, mais l’organisation horizontale des disciplines ne correspond pas aux quatre zones demandées.

## Éléments temporaires ou hardcodés

- `SkillTreeGraphView` contient un layout spécial codé pour les identifiants Archer `elf_archer_eagle_eye` et `elf_archer_repel_arrow`, ainsi que leurs titres de bandes.
- La map visuelle détaillée ne couvre que les 19 présentations de l’Archer Elfe.
- Les fallbacks d’icônes construisent systématiquement un identifiant `elf_<discipline>`, ce qui ne généralise pas correctement l’identité du Mage.
- Les badges de navigation utilisent eux aussi le préfixe `elf_`.
- Le bouton `Skills` du HUD est désactivé lorsque le thème n’a pas de discipline par défaut ; six personnages ne peuvent donc pas encore atteindre un état propre `Progression non définie`.
- Le `SkillTreeStatusButton` superposé et le bouton `Compétences` du UtilityDock constituent deux accès visuels simultanés pendant le combat.
- La preview ne simule que l’Archer Elfe et huit scénarios proches ; elle ne couvre pas les personnages sans arbre ni le Mage.

## Décisions de refonte compatibles avec les règles

- Conserver intégralement les ressources, le resolver, les états de progression et le caractère consultatif en combat.
- Réorganiser l’unique écran existant en `CharacterHeader`, `BranchNavigation`, `SkillTreeCanvas` et `NodeDetailPanel`.
- Piloter l’identité à partir des mêmes `CharacterHUDThemeData` que le HUD REFINED.
- Présenter les six personnages sans disciplines avec un état vide explicite, sans node ni branche inventée.
- Remplacer les préfixes visuels codés par une résolution discipline/personnage avec fallback neutre.
- Conserver les connexions issues uniquement de `prerequisite_node_ids` et les exclusions issues uniquement du resolver.
- Garder l’acquisition dans le flux existant ; le panneau de combat expliquera l’état sans créer un second mécanisme de sélection.

## Validation finale de la passe V2

- L’unique `SkillTreeScreen` conserve les quatre zones validées : `CharacterHeader`, `BranchNavigation`, `SkillTreeCanvas` et `NodeDetailPanel`.
- La révélation est fondée sur `DisciplineProgressState.rank` et sur le rang requis porté par les vraies ressources, avec une profondeur configurable de 1. Les rangs au-delà de la frontière sont remplacés par des `RankGate` génériques et leurs nodes réels ne sont pas instanciés.
- Le prochain rang peut être inspecté, mais son nom, son effet, son tooltip mécanique et son détail sont masqués conformément aux options de la ressource `skill_tree_refined_config.tres`.
- Le panneau de détail utilise un contenu générique pour le rang verrouillé. Il n’appelle pas de mutation et conserve le message consultatif du flux après combat.
- Le layout spécial Archer ne change aucune règle : il organise uniquement les vrais identifiants issus des ressources. Le layout générique reste utilisé pour les autres disciplines.
- Les 17 scénarios de preview utilisent exclusivement des `CharacterRunState` et des disciplines réelles : aucun node ou rang fictif n’est injecté dans le runtime.
- Les huit personnages restent couverts. Elf et Mage affichent leurs seules disciplines réelles ; Guardian, Warrior, Druid, Assassin, Necromancer et Hoplite affichent l’état vide `Progression non définie` sans `RankGate` fictif.
- Les validations ciblées arbre, intégration et multi-personnages totalisent 24 tests et 1 433 assertions sans échec avant la suite élargie.
