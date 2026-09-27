# Réaudit — refonte Cartes dans Catabase

Les corrections ultérieures et leurs nouvelles preuves sont suivies dans
[le compte rendu de corrections](cards_corrections_2026-09-27.md). Les constats
ci-dessous décrivent l'état observé avant ces corrections.

Audit du 27 septembre 2026, HEAD `c6ab5a72c1789e4cc285300c9bbae9c78524fa05` avec modifications locales. Le cœur du mode Cartes est raccordé à l'aventure existante, mais **l'intégration complète ne peut pas être déclarée terminée : quatre défauts restent confirmés**. Les scénarios de référence et les tests de reprise ne couvrent pas toutes les fonctionnalités réellement montées dans les scènes publiques.

Aucune règle de production modifiée pendant ce réaudit. Les sondages utilisent un répertoire utilisateur isolé, sans conversion ni modification des sauvegardes personnelles. Les modifications concurrentes de sprites, VFX, Studio et haltes sont conservées.

## 1. P1 — Les cinq mécanismes de salle de la refonte sont absents du parcours public

**Preuve.** La traversée de la graine 33, en choisissant la première destination disponible à chaque embranchement, monte douze vraies scènes `RegisteredTerrainBattle.tscn`. Aucune ne possède de `room_rules`. Les combats 4, 5, 6, 8, 9 et 11 annoncent pourtant respectivement `forge`, `hourglass`, `garden`, `convoy`, `reservoir`, `garden` dans le catalogue de la refonte.

**Cause.** `core/game_manager.gd:2552` réserve `_uses_card_ecosystem()` à la révision 3. La fabrique `core/expedition/expedition_run_factory.gd:195` place les mécanismes derrière ce même booléen. Le nouveau profil est en révision 4. Son adaptateur `battle/consumable_cards_runtime.gd` n'installe aucun mécanisme équivalent sur les décors existants. La lecture de cette branche confirme que le problème ne se limite pas à la graine sondée.

**Effet joueur.** Pas de presse à déplacer, de croix à retarder, d'anneau, de porteurs à intercepter ni de charges à stocker/décharger. Six des douze épreuves perdent leur règle de salle. Les tests du prototype passent parce qu'ils exécutent `consumable_cards_battle.gd`, qui possède ses propres commandes et son propre état de salle.

**Correction attendue.** Installer ces règles dans les scènes actuelles et leur sauvegarde, avec des interactions visibles dans le HUD existant. Ne pas simplement élargir le booléen historique : il active aussi l'ancien rééquilibrage des monstres. Ne pas réintroduire une aventure parallèle. Vérifier chaque mécanisme après une action puis après reprise.

La première hypothèse de cet audit portait sur une perte d'état des mécanismes au rechargement. Le sondage précise le constat : ils ne sont actuellement pas montés. La reprise de ces mécanismes reste une exigence à traiter lors de leur raccordement, pas un bug actif reproduit ici.

## 2. P2 — La protection de formation du combat 7 n'a aucun porteur

**Preuve.** Au combat 7 / profondeur 10 du trajet sondé, la définition demande `break_guard_formation` avec `guard, brute`. Les unités montées sont « Exécuteur d'airain » et « Brute vétérane », toutes deux classées `brute` ; leur variante est vide. Aucune protection de formation ne peut donc se déclencher.

**Cause.** `battle/consumable_cards_runtime.gd:24` remplace le roster prévu par une inférence fondée sur les noms et les portées. Le mot recherché pour attribuer `guard` n'est présent dans aucun de ces deux noms. `core/expedition/consumable_enemy_rules.gd:49` n'active la variante que pour un `guard`.

**Correction attendue.** Raccorder explicitement les rôles logiques de chaque rencontre aux unités existantes et valider les prérequis des variantes. Conserver les apparences ne dispense pas de garantir le soutien, la parade ou la formation prévus. Ajouter cette assertion au test des douze scènes, actuellement limité au démarrage, au nombre d'ennemis et au checkpoint.

## 3. P2 — La garde absorbe la pression

**Contrat.** `docs/design/cartes_refonte_v2_2026-09-26/REGLES.md:125` prévoit une perte de PV après le tour 9, sans garde, résistance ni anti-létal.

**Cause.** `battle/consumable_cards_runtime.gd:97` passe par `Effects.hit(..., "pressure", true)`. Le dernier argument ignore les résistances ; il ne contourne pas l'absorption de bouclier dans `units/unit.gd:1704`. L'exclusion de l'anti-létal existe, mais ne suffit pas.

**Reproduction et conséquence.** Le sondage place 18 points de garde sur le héros, puis appelle le début de ronde qui applique la pression due après le tour 9. La perte attendue vaut `arrondi(110 × 0,025) = 3 PV`. Résultat réel : **PV 110 → 110, garde 18 → 15** ; résultat attendu : **PV 110 → 107, garde 18 → 18**. Cette absorption avantage la garde face à la limite temporelle et fausse le budget de survie. La limite dure de 24 tours demeure ; il ne s'agit pas d'une survie infinie.

**Correction attendue.** Une perte de PV dédiée à la pression, avec événements et issue du combat cohérents, sans absorption de garde. Tester avec garde, résistances et Édit actifs, ainsi que sur une pression létale.

## 4. P2 — Pâris ne change pas de phase sur les dégâts périodiques

**Reproduction.** Dans la vraie dernière scène, le boss possède 724 PV maximum. Placé à 369 PV, il subit une brûlure de 29 PV au début de son activation : il tombe à **340/724**, sous le seuil de **362**, mais sa phase reste **1**. Le comportement suivant est encore `prepare_line`.

**Cause.** `battle/consumable_cards_runtime.gd:141` actualise la phase uniquement après une action du héros. Le début d'activation (`:66`) applique bien brûlure/saignement, sans actualiser la phase avant la décision ennemie. Les dégâts périodiques ne constituent pas une action du héros dans ce branchement.

**Correction attendue.** Actualiser les transitions après chaque résolution susceptible de modifier les PV, avant le choix du prochain comportement. Conserver une intention déjà préparée conformément aux règles ; ne pas soigner, changer d'UID ou verser un deuxième butin.

## Point fermé pendant l'audit : reconnaissance des nouveaux sorts par les VFX

Le passage propre de 13 h 14 constatait **0/50** sorts reconnus par `ClassCardVFXRouter.handles()` : le catalogue ignorait les identifiants `cc2_*`. Un travail concurrent a ajouté la branche `_current_card()` dans `vfx/class_cards/class_card_vfx_catalog.gd` à 13 h 16. Le dernier sondage constate **50/50 reconnus**, soit les 48 familles en forme de base et les deux secours. Ce point est donc retiré des défauts ouverts ; il n'a pas été corrigé par ce réaudit.

La reconnaissance du routeur ne démontre pas que chaque effet approuvé est rejoué à l'identique ni que tous les nouveaux effets sont visuellement finalisés. Les gestes et le routeur continuent d'évoluer dans le travail concurrent ; leur contrôle visuel exhaustif n'est pas revendiqué ici.

## Mesures complémentaires : le budget total de PV ne suffit pas

Les chiffres suivants comparent la construction du catalogue de référence au roster réellement monté. Somme d'ATK = addition des valeurs d'attaque de base, **pas** des dégâts par tour mesurés : portée, placement, armure, protection et cadence changent aussi.

| Combat | Roster prévu → réel | Somme ATK prévue → réelle | Écart |
|---|---|---:|---:|
| 1 | Brute → Archer | 11 → 9 | −18,2 % |
| 6 | Officiant/Molosse/Brute → Brute/Archer/Molosse | 68 → 75 | +10,3 % |
| 7 | Porte-égide/Brute → Brute/Brute | 67 → 70 | +4,5 % |
| 9 | Lamie/Molosse/Porte-égide → Brute/Brute/Archer | 125 → 140 | +12,0 % |
| 10 | Porte-égide/Archer/Lamie/Officiant → Brute/Archer/Porte-égide/Archer | 183 → 210 | +14,8 % |
| 12 | Pâris/Lamie/Molosse → Pâris/Brute/Brute | 203 → 231 | +13,8 % |

Le combat final conserve 1 344 PV cumulés, mais le boss passe de 840 PV de référence à 724 PV réels : les deux brutes récupèrent davantage du budget. Ces écarts ne prouvent pas à eux seuls un mauvais équilibrage ; ils montrent que les calculs du prototype ne valident pas le trajet public. Les mécanismes de salle absents retirent aussi des sources de dégâts et des moyens de contrôle.

## Vérifications et limites

Harnais reproductible : `./tools/consumable_cards/audit_live_integration.ps1`. Il respecte le verrou moteur, isole APPDATA et distingue exécution terminée et intégration complète. Un verdict `NEEDS_CHANGES` signifie sondages exécutés et écarts confirmés ; `INCOMPLETE` signale une preuve incomplète. Le lanceur retourne un code non nul dans les deux cas. Les scènes sont réelles ; les transitions entre victoires sont des fixtures de transaction, et les PV/états des micro-scénarios sont imposés. Ce n'est ni une partie gagnée ni une campagne de balance.

Preuves finales :

- **Sondages** : `artifacts/dev/20260927-131648-cards-live-reaudit-4c8d82d7/observations.json` et `summary.json`. Douze scènes montées, exécution complète, zéro erreur moteur ; quatre défauts ouverts, VFX 50/50 reconnus. Le moteur termine avec code 0 ; le lanceur signale les écarts avec `NEEDS_CHANGES`.
- **Suite Cartes fraîche** : `artifacts/dev/20260927-131503-test-cards-30af5308/summary.json`, **PASS, 192 tests / 15 010 assertions**, aucune erreur. Exécution GUT de 316,645 secondes. Ce résultat décrit le passage effectué, pas les modifications visuelles concurrentes postérieures à son chargement.
- **Sources** : empreintes des huit fichiers centraux dans `artifacts/dev/cards-reaudit-source-hashes-20260927.json`. Contrôle final : empreintes inchangées ; HEAD inchangé. Les évolutions du routeur visuel sont distinguées ci-dessus.
- **Vérification Git** : `git diff --check` PASS ; aucune règle de production modifiée par l'audit. Calculs détaillés dans `artifacts/dev/cards-reaudit-budgets-20260927.json`.

Le passage intermédiaire propre `artifacts/dev/20260927-131410-cards-live-reaudit-997a1578/` conserve la preuve du défaut VFX avant l'évolution concurrente. Le résultat final le remplace pour l'état de ce raccordement.

La première tentative de sondage (`131101…747c4ef6`) et l'import de la première suite Cartes (`131207…1db6e233`) ont rencontré le nouvel atlas `sprites_s24/kick_high.png` encore non importé. Le premier n'est pas une preuve propre ; le second a exécuté **zéro test**. L'import a ensuite produit la ressource. La tentative `131315…8a965899` n'a exécuté aucun test à cause du verrou occupé. Ces tentatives ne sont pas comptées comme des succès.

Le précédent résultat de 190 tests / 14 625 assertions reste une preuve historique. Le test des douze scènes (`test_consumable_cards_integration.gd:138`) ne vérifie ni les variantes attendues ni les mécanismes de salle ni la sélection des VFX. Le test de commandes de salle (`test_consumable_cards_mechanics.gd:209`) utilise le moteur isolé. Cette différence explique pourquoi les tests peuvent rester verts avec les présents écarts.

Les contrôles globaux et leurs 166 échecs historiques sont décrits dans l'audit précédent ; ils ne sont pas réexécutés pour cet audit sans changement de code de production. Aucun résultat global vert n'est revendiqué. Les quatre classes jouées jusqu'au boss, l'équilibrage sur plusieurs chemins et les essais visuels exhaustifs des nouveaux sorts restent hors de la preuve acquise.

## Ordre recommandé des corrections

1. Raccorder les mécanismes à la run existante et garantir leurs reprises ; valider les rôles indispensables aux variantes.
2. Corriger pression et transitions de phase dans Battle, avec tests du chemin réel.
3. Contrôler visuellement les nouveaux raccordements VFX et les sorts révisés.
4. Rejouer les parcours des quatre classes et les embranchements ; mesurer ensuite l'économie et la difficulté avec le contenu réellement activé.
