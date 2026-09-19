# Intégration des classes — 19 septembre 2026

Demande : rendre jouables les propositions de l'audit, avec création lisible, cartes indépendantes de l'ancien arbre, progression et butin. Les modifications présentes avant cette tâche sont conservées.

Décisions : nouvelle révision Cartes ; anciennes sauvegardes conservées. Quatre classes, cinq familles de départ choisies parmi quinze, deux exemplaires par famille. Maîtrises et améliorations par exemplaire. Pas d'équipement de départ. Le butin rejoint la réserve, jamais automatiquement le deck. Interfaces dédiées et retour au Seuil physique pour les trois chemins.

Références : création BG3 (https://baldursgate3.game/news/community-update-21-forging-your-legacy_77), séparer identité et compétences et rendre la correction possible ; compte rendu illustré de l'interface Dofus 2.46 (https://dofus.jeuxonline.info/actualite/54181/beta-246-astrub-interfaces-tour-proprietaire), montrer ensemble XP, monnaie et objets reçus. Ces références guident la hiérarchie, pas les illustrations.

État : intégré dans les nouvelles parties Cartes. Règles détaillées : [classes révision 3](../design/class_run_rules_v3.md).

## Fichiers et décisions

- Cinq modules `core/expedition/class_*.gd` : 4 classes, 12 spécialisations, 60 techniques indépendantes de l'ancien arbre, 72 équipements (24 modèles × 3 paliers), 4 runes.
- `ui/selection/cards_character_setup.gd`, `cards_choice_page.gd` : création progressive avec personnage central et effets explicites ; `ui/expedition/catabase_cards_departure.gd` présente les 15 techniques natives, une décision à la fois.
- `ui/expedition/class_workshop.gd` : deck, réserve, butin acquis, six emplacements, équipement, revente, sertissage, maîtrises et spécialisation. Lecture seule en combat.
- `asset/ui/class_cards/` : 88 pictogrammes SVG originaux, source reproductible dans `tools/build_system_lab/draw_class_icons.py`.
- Services communs réutilisés : lancement de sort/statuts, équipement, calcul de statistiques et inventaire. Ajout d'une attribution facultative du lanceur pour les statuts ajoutés par un modificateur. Pas de second moteur de combat.
- Les nouveaux passifs se réinitialisent entre les combats. Les ressources de sort restent stables par copie/rang pour ne pas casser la sélection du HUD. Les rangs, le budget et les identifiants de rune invalides sont refusés à la restauration.
- L'ancienne création Classique et les anciennes sauvegardes Cartes sont conservées. Le nouveau catalogue s'applique à une nouvelle partie Cartes.

## Preuves de validation

| Vérification | Résultat | Preuve |
|---|---|---|
| Nouvelle suite, import isolé et analyse stricte | **PASS : 12 tests, 1 356 assertions**, aucune erreur moteur/import | `artifacts/dev/20260919-143724-test-test_unit_test_catabase_class_run.gd-5c5c8915/summary.json` |
| Catalogue et résolution | Les 60 techniques se lancent dans le moteur commun ; dégâts, garde, mouvement, PA, attribution des statuts, passif une fois par activation, amélioration d'une seule copie | Même suite |
| Progression et persistance | 4 classes × 20 profondeurs, sauvegarde/reprise à chaque récompense ; reçus de butin, six emplacements, rune appliquée une seule fois | Même suite ; victoires injectées, pas une simulation de performance tactique |
| Suite ciblée commune, 8 fichiers | 72/72 tests et 2 056 assertions réussies ; **verdict strict FAIL** à cause de ressources conservées à l'arrêt et de l'import sans mode récupération | `artifacts/dev/class-final-shared/gut-strict-report.json`, `gut.stdout.log` |
| Diagnostic des ressources | Les tests existants `test_spell_modifier`, `test_terrain_status_timing` et `test_enemy_turn_banner_gate` réussissent leurs assertions mais conservent leurs fixtures à l'arrêt ; le test de déduplication est propre | `artifacts/dev/class-debug/test_*.console.log` concernés |
| Suite Catabase générale | **FAIL : 487 tests**, mêmes 15 tests en échec et mêmes diagnostics principaux que le rapport antérieur à l'intégration | Comparaison `artifacts/dev/20260919-110049-test-catabase-f47397ec/summary.json` / `artifacts/dev/20260919-141213-test-catabase-95f93d0d/summary.json` |
| Interfaces réelles, dernière passe | **PASS : 144 contrôles, 24 captures**, 1280×720 et 1920×1080. Sélection publique transmettant la classe, cinq choix de cartes, véritable lancement depuis le HUD avec dépense de PA/défausse, tour ennemi/joueur, niveau, caractéristiques, maîtrises, butin et équipement. Destination après butin : Seuil physique, trois sorties disponibles. Aucun diagnostic d'erreur dans le journal. | `artifacts/dev/class-ui/report.json`, `artifacts/dev/class-ui/engine4.log` |

Inspection visuelle effectuée sur les captures de création, préparation des cartes, niveau, caractéristiques, collection, butin, maîtrises, équipement et combat. Les panneaux longs défilent ; les actions principales du parcours restent accessibles en pied de fenêtre à 720p. Les captures finales du lancement d'une carte et de la répartition des caractéristiques ont également été relues après les ajustements de libellés.

Les quinze échecs historiques concernent six tests de catalogues graphiques, deux de sélection historique, trois du seuil, deux de contenu/formations et deux d'interface de reliques. Ils ne sont ni masqués ni ajoutés à une liste d'exceptions. La suite globale n'est donc pas déclarée verte.

## Limites assumées du lot

- Les spécialisations ont des conditions réellement exécutées, mais pas de sous-couches divinité/culte supplémentaires. Les améliorations modifient portée, ligne de vue, obstacles ou durée de garde ; elles ne constituent pas 60 sorts additionnels indépendants.
- Le catalogue d'équipement partage 24 modèles et une progression chiffrée en trois paliers. L'ajout de mécaniques d'objet plus singulières reste une extension de contenu.
- Les quatre parcours complets testent l'économie des transactions et la reprise. Ils ne mesurent pas les taux de victoire des builds ; l'équilibrage tactique sur toutes les combinaisons reste à poursuivre par parties jouées.
- Des essais intermédiaires ont échoué puis ont été corrigés : déclaration redondante repérée à l'import et deux nouvelles fixtures de test qui contournaient les règles de main/XP. Le résultat retenu est la nouvelle exécution stricte indiquée dans le tableau, pas ces tentatives.
