# Choisir les validations

La sélection locale est définie dans `tools/dev/test-suites.json`.
Les logs, contexte Git et résumés vont dans `artifacts/dev/<exécution>/`.
Un import interrompu, zéro test ou un rapport absent reste un échec.

| Modification | Commandes / contrôles |
|---|---|
| Lanceur, contexte, sélection des tests | `./dev.ps1 selftest` ; vérifier les résultats et la pagination de `context` |
| Codex de personnage / sort | `./dev.ps1 test smoke` : seulement deux suites UI, aucun parcours complet |
| Classes, cartes, deck et VFX Cartes | `./dev.ps1 test cards` ; parcours préparation → combat → bilan → reprise |
| Copies consommables | `./dev.ps1 test consumable-v2` ; inclus dans `cards`, `catabase` et `all`. `test_consumable_cards_integration.gd` utilise les douze scènes de combat réelles. `./tools/consumable_cards/verify_integration.ps1` capture le parcours intégré ; `capture.tscn` concerne seulement le prototype |
| Progression Prototype v1 | `./dev.ps1 test test/unit/test_consumable_cards_prototype_v1.gd` ; inclus dans les suites Cartes. Vérifier allocation au départ et dans le dossier, calculs élémentaires, quotas, anciens combats et ratio de PV à la reprise. Contrat : [prototype_v1.md](prototype_v1.md) |
| Probabilités et transactions des anciennes révisions Cartes | `./dev.ps1 test cards-audit` : simulations statistiques longues, également conservées dans `all` |
| Expédition, progression, inventaire | `./dev.ps1 test catabase` ; tester reprise, récompenses et sauvegardes antérieures |
| Monstres | `./dev.ps1 test monsters` ; comportement de combat et lecture des intentions |
| Terrain | `./dev.ps1 test terrain` ; contrats Studio et essai de la map réelle |
| Éditeurs Studio | `./dev.ps1 test studio` : ensemble exact partagé avec le job CI STUDIO-CONTRACTS |
| Haltes / audio | `./dev.ps1 test halts` ou `audio` ; contrôle runtime/écoute concernés |
| Moteur commun, déplacements ou suppressions de ressources | Import + `./dev.ps1 test all` + gates CI et scénarios impactés |
| Rendu HUD / inventaire | `./dev.ps1 capture hud` ou `inventory` ; inspection effective des images |
| Portées et survol tactique | `./dev.ps1 test tactical-readability` ; `./tools/tactical_readability/verify.ps1` capture la Battle réelle, le survol allié/ennemi, la portée des sorts et les ressources épuisées en 720p et 1080p |

`cards` fait partie de `catabase`. Les tests exacts échouent explicitement si
leur fichier a disparu du manifeste. `all` reste strict localement : ses échecs
ne sont pas cachés par la liste historique de la CI.

## Gates conservées

`.github/workflows/godot-validation.yml` conserve : import, contrats Studio,
suite globale avec comparaison exacte à `tools/gut_historical_allowlist.json`,
absence de mutation par GUT, portabilité des chemins audités, smokes Terrain,
Rencontres et Objets. La liste historique n’est pas une autorisation d’ajouter
un échec et ses entrées manquantes doivent aussi être examinées.

Les tests GUT ne remplacent pas une partie ou une validation visuelle.
Le parcours automatique V2 affaiblit volontairement les ennemis et rétablit les
PV entre rencontres pour vérifier les vingt transitions et les reprises. Il ne
prouve ni la difficulté, ni un taux de victoire. Les résultats du prototype
sont historiques. L'intégration dans la vraie run est documentée dans
l'[audit du 27 septembre](../audits/cards_integrated_run_2026-09-27.md) : scènes,
consommation, victoire, reprise et interfaces existantes. Ses fixtures de
transactions ne mesurent pas non plus l'équilibrage d'une partie normale.
`tests/expedition/README.md` décrit les scénarios d’expédition.
Les captures du lanceur proviennent de la galerie HUD ; elles ne certifient
pas tout le parcours public. Le workflow `ci.yml` est historique et manuel.

`doctor` ne valide pas l’import. Un problème d’environnement doit être résolu
sans neutraliser les erreurs du harnais. Les anciens rapports ne valident
jamais automatiquement une nouvelle modification.

État observé le 21 septembre 2026 : les contrôles d'outillage passent, mais la
validation globale n'est pas verte. Les timeouts, contrats historiques obsolètes
et erreurs de fermeture relevés sont consignés dans
[le compte rendu de nettoyage](../audits/project_cleanup_2026-09-21.md).
Le [lot suivant de retrait de contenu](../audits/content_retirement_2026-09-21.md)
détaille les contrats adaptés, l'extraction de destination et les nouveaux
résultats. `./dev.ps1 test retirement` couvre le retrait physique du trio et
de l'Archiviste, les aperçus Studio et les retours de Catabase. Le manifeste
reste la source du nombre exact de scripts ; les rapports datés sont historiques.

Le [retrait physique final](../audits/physical_cleanup_2026-09-21.md) consigne
les suppressions du trio et de l’Archiviste, les validations ciblées et les
échecs qui empêchent encore une validation globale.
