# Architecture — points d’entrée

Le projet conserve son organisation Godot existante. Les noms de versions dans
un dossier ne donnent pas son statut d’usage. Commencer par un domaine :
`./dev.ps1 context cards -Kind code`, puis lire seulement les dépendances utiles.

| Domaine | Entrée | Responsabilité |
|---|---|---|
| Application | `core/game_manager.gd` | État global de run, navigation et coordination des écrans |
| Expédition | `core/expedition/expedition_session.gd` | Session, récompenses, préparation et restauration |
| Route / sauvegarde | `core/expedition/expedition_route_state.gd`, `expedition_save_service.gd` | Étapes et persistance |
| Destination | `core/expedition/expedition_destination.gd` | Choix du lieu après progression/butin, sans écriture ni changement de scène |
| Cartes | `core/expedition/class_cards.gd`, `catabase_cards.gd`, `class_card_catalog.gd` | Règles actuelles, base commune et anciennes révisions |
| Combat | `battle/battle.gd`, `core/spell_caster.gd`, `units/unit.gd` | Cycle, résolution des sorts et état des unités |
| Grille / IA | `core/grid_data.gd`, `core/pathfinder.gd`, `core/enemy_ai.gd` | Terrain logique, chemin et décisions ennemies |
| HUD | `ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd` | Présentation du combat et main Cartes |
| Écrans de run | `ui/expedition/`, `ui/post_combat/`, `ui/run/` | Carte, bilan et fenêtres persistantes |
| Personnages | `ui/selection/character_selection_catalog.gd`, `core/run_content/` | Entrées publiques, profils et variantes |
| Régression | `test/fixtures/README.md` | Données de règles et dispositions logiques hors catalogue public |
| Contenu | `data/`, `assets/`, `asset/` | Ressources, médias et définitions |
| Édition | `addons/dungeon_draft_arena_studio/` | Documents, transactions, validation et aperçu |

## Frontières à respecter

- Les ressources `data/` définissent le contenu ; `core/` porte les règles et l’état.
  `GameManager` reste l’orchestrateur applicatif et peut ouvrir les écrans.
- Le choix entre route, carrefour, halte peinte et marchand appartient à
  `expedition_destination.gd`. Le manager délègue ce choix puis conserve la
  sauvegarde et l'exécution de la transition ; ses méthodes publiques restent stables.
- La présentation reste dans `battle/`, `ui/`, `characters/`, `hub/` et `vfx/`.
- Réutiliser les services du Studio ; les règles et contrats partagés ne doivent
  pas être recopiés dans les laboratoires.
- Le runtime charge encore quelques services dans le Studio (cadrage, manifestes,
  configuration d’essai). Préserver ces liens tant qu’une extraction partagée
  n’a pas été réalisée et validée.
- Réduire les gros contrôleurs par responsabilité au fil des changements, en
  conservant leurs API et tests pendant la transition. Pas de découpage arbitraire
  par nombre de lignes ni de déplacement global des ressources.

## Retrouver le contexte

`tools/dev/context-domains.json` est le registre court des entrées et alias.
La recherche classe ces entrées avant le reste, distingue code, tests, docs,
données et art, puis permet la pagination. Les archives, anciens audits et notes
de reprise sont accessibles avec `-IncludeArchive` ; ils ne sont pas des sources
automatiquement actuelles.

Les suites sont dans `tools/dev/test-suites.json`. Le lanceur et les contrats
Studio de la CI utilisent ce même manifeste. Voir [la validation](validation.md).

Les outils ne doivent pas écrire leurs sorties dans les sources : utiliser
`artifacts/` et conserver seulement les fixtures ou preuves choisies dans Git.
Les fichiers suivis déjà présents dans `artifacts/` ne sont pas tous supprimables.
