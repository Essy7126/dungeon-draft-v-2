# Montée de niveau — annonce et choix séparés

## Recherche et décision

Les captures Dofus fournies par le joueur mettent en avant un niveau, un portrait,
des gains illustrés et des accès séparés aux sorts et caractéristiques.
Le changelog historique Dofus 2.11 précise qu'un gain simultané de plusieurs
niveaux affiche une seule annonce au niveau final :
https://dofus.jeuxonline.info/actualite/39796/modifications-apportees-mise-jour-211
Il distingue aussi les interfaces d'attribution de caractéristiques et de sorts.
Cette source date de 2013 : elle ne prouve ni le comportement actuel de Dofus 3,
ni une appréciation unanime des joueurs. Les captures servent de référence visuelle.

Adaptation : matière brune, portrait 3D existant à échelle contenue, halo vectoriel
discret, niveau dominant, gains colorés et trois destinations explicites.
Pas d'éditeur de deck ou de classe inclus dans la notification.

## Contrat implémenté

- Le reçu de butin reste prioritaire ; sa fermeture enregistrée ouvre l'annonce.
- Le stade persistant `advancement` est conservé, sans migration des sauvegardes.
- La présentation lit les courbes du profil pour les gains automatiques et budgets.
  Elle ne distribue aucune récompense : gains PV/Puissance **de base**, points gagnés
  et points encore disponibles sont distingués.
- Répartition, deck et classe sont des fenêtres distinctes, avec retour à l'annonce.
- Continuer et fermer conservent les points. La spécialisation obligatoire reste
  bloquante et possède un accès clairement indiqué. Inspection seule ne valide rien.
- Aucun changement d'équilibrage, de distribution de loot ou de courbe XP.

## Fichiers et vérifications

Présentation : `ui/expedition/consumable_level_up_view.gd` ; synthèse en lecture
seule : `consumable_level_summary.gd` ; navigation : `expedition_screen.gd`.

Le scénario natif `tools/consumable_cards/level_up_capture.gd` contrôle : butin avant
annonce, retours depuis répartition/deck/classe, reprise, spécialisation obligatoire,
plusieurs niveaux regroupés et limites d'écran. Il est intégré au vérificateur
dossier pour 1280×720 et 1600×900. Les tests unitaires vérifient les budgets,
l'absence de mutation, la conservation des points et le blocage de spécialisation.

Première passe native : 60 captures, huit scénarios/résolutions réussis,
`artifacts/dev/20261001-043612-player-dossier-d3bdf014/report.json`.
Inspection visuelle effectuée sur l'annonce de niveau 2 en 720p et celle de
spécialisation en 900p. Les libellés ont ensuite été affinés pour supprimer les
gains nuls et remplacer les pluriels techniques « point(s) ».

Validation finale des interfaces : 60 captures et huit scénarios/résolutions
réussis, sans erreur moteur, dans
`artifacts/dev/20261001-044020-player-dossier-fc9b1ca4/report.json`.
Inspection visuelle supplémentaire : annonce regroupant les niveaux 1 → 8 en 720p.
La suite `consumable-v2` passe : 224 tests, 20 996 assertions,
`artifacts/dev/20261001-044004-test-consumable-v2-1e966816/gut-strict-report.json`.
Le contrôle ciblé complémentaire relit explicitement le fichier de sauvegarde :
5 tests, 25 assertions réussis,
`artifacts/dev/20261001-044459-test-test_unit_test_consumable_cards_level_summary.gd-32fadad9/gut-strict-report.json`.
Le contrôle de format des quatre nouveaux scripts et `git diff --check` passent.

Limites : fixtures déterministes d'interface, pas une nouvelle mesure d'équilibrage.
Les variantes historiques de progression restent inchangées. L'échec préexistant
du test d'inventaire classique (`test_run_interface_access`, constaté lors du
chantier Deck précédent) n'est pas corrigé par cette refonte Cartes.
