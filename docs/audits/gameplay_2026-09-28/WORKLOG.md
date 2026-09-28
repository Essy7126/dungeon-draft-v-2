# Audit gameplay — reprise

Demande : auditer le gameplay profondément remanié, sans modifier les règles pendant le diagnostic. Référence initiale : `6e8d2605`, dépôt propre au départ ; comparaison avec `c6ab5a72` (études du 25 septembre).

Périmètre prioritaire : nouvelles parties Cartes consommables dans ExpeditionSession et Battle, préparation, 48 familles, quatre classes, progression, économie, rencontres réelles et lisibilité. Distinguer prototype, contrat historique et comportement public. Les anciennes sauvegardes et Classique restent hors du nouveau profil.

Premiers constats : mécanismes de build réellement ajoutés (ouverture, rétention, Ancre, Relais, sacrifice choisi, surfaces). L'adaptateur remplace les sorts/profils natifs des ennemis ; mesurer les conséquences sur les scènes réelles plutôt que reprendre les budgets des petites arènes.

Vérifications terminées : doctor réussi. Premier test sandboxé arrêté avant exécution (certificats/dossiers temporaires), puis relance autorisée réussie : 130 tests, 5 953 assertions, aucune erreur. Rapport `artifacts/dev/20260928-092313-test-consumable-v2-6ea5ffa0/gut-strict-report.json`.

Livrables : RAPPORT.md, CARTES_ET_BUILDS.md (48 familles, classes, équipement/reliques), observations.json, calculs.json ; outils dans tools/gameplay_audit_2026_09_28/. Douze scènes montées, 32 profils natifs énumérés, sept captures produites et inspectées sur l'exécution 093253 ; mesure complémentaire d'accès dans l'exécution 093851, réussie. Première version du harnais corrigée : initialiser les rencontres depuis les salles, pas depuis une ressource vide.

Résultats majeurs : aperçu des rencontres natif incohérent avec Battle Cartes ; bestiaire réduit par adaptation générique ; Obole achetée à 90 ne rapporte au maximum que 64 avant boss ; 108,10 normales attendues mais 6,31 d'une famille native précise ; rare native précise obtenue dans 32,22 % des runs ; accès aux leviers coûteux ; dernière amélioration uniquement pour le boss. Les mécanismes V2 et leur intégration sont bien présents. Ne pas réutiliser le diagnostic « mécanismes absents » des anciennes études.

Limites : pas de campagne complète à stats intactes ; ni taux de victoire ni validation globale/CI. Les captures déplacent le héros vers le mécanisme, les transitions de sonde déclarent les victoires. Les calculs sont analytiques, sans achats/troc/sacrifices dans les espérances de loot.

HEAD final revérifié : 6e8d2605de49d7ad53301db39395b12eaa5c13fe. Le dépôt de production reste inchangé ; ajouts uniquement dans les deux dossiers d'audit. Format GDScript, syntaxe JavaScript, calculs, liens locaux, espaces de fin et couverture des 48 lignes de familles vérifiés. Rapport prêt à reprendre sur une autre machine avec les observations archivées et les commandes de reproduction. Aucun correctif de gameplay appliqué ; audit terminé, implémentation des recommandations non engagée.
