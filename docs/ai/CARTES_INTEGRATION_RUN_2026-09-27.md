# Cartes — intégration dans la run Catabase existante

Demande du 27 septembre : retirer le parcours public parallèle et appliquer la refonte au mode Cartes actuel. HEAD de départ : c6ab5a72c1789e4cc285300c9bbae9c78524fa05. Le dépôt contient des travaux concurrents (personnages, VFX, sélection et haltes) à préserver.

## Décisions
- Garder Titre → sélection du personnage → introduction → seuil → ExpeditionSession → Battle et les haltes existantes.
- Le profil des nouvelles cartes est une règle de cette session, pas une troisième variante ni une autre sauvegarde.
- Conserver les anciennes sauvegardes lisibles sans les convertir implicitement.
- Brancher consommation, statistiques, progression, préparation, équipement et décisions de cartes dans les écrans existants.
- Vérifier le vrai parcours et la reprise ; les tests du prototype isolé ne constituent pas une preuve d'intégration.

## État
Session, départ, économie, progression, atelier, main et Battle raccordés. Entrée publique Cartes V2 et propriétaire `GameManager.consumable_run` retirés. Sauvegarde dans le fichier Cartes existant, avec restauration explicite des anciens profils. Les arènes du prototype restent uniquement des fixtures.

Fichiers centraux : `consumable_cards_integration.gd` (session), `battle/consumable_cards_runtime.gd` (Battle), `consumable_expedition_checkpoint.gd` et `consumable_native_status_checkpoint.gd` (reprise), atelier intégré, sélection et main existante. Les douze rencontres gardent leurs cartes et unités visuelles. L'adaptateur applique leurs budgets et les sept rôles numériques de la refonte.

Preuve ciblée acquise : `20260927-113726-test-cards-19e2a418` PASS, 185 tests / 14 428 assertions. Scène Battle réelle : copie consommée, reprise sans redéploiement, main/PA/PM/bouclier/positions/statuts natifs/intention ennemie et compteur terrain conservés ; deuxième tour jouable. Les échecs intermédiaires et tentatives bloquées par un verrou ne sont pas comptés comme réussites.

Preuve visuelle : `20260927-114544-cards-integrated-visual-020607ce` PASS, entrée publique puis huit captures à chaque résolution 1280×720 et 1600×900. Sélection, départ, vraie Battle et fenêtres existantes inspectés. La page de bilan était mal nommée dans le harnais ; elle a été corrigée et exige une nouvelle capture.

Suite globale `20260927-114638-test-all-2790eefa` terminée : 3 177 tests, 264 159 assertions, exactement les 166 mêmes identités d'échec que `20260926-155430…b864d248`, même crash de fermeture -1073741819. Aucune nouvelle identité d'échec ; CI toujours rouge (allowlist de huit, non modifiée). Comparaison dans `artifacts/dev/cards-global-comparison-20260927.json`.

Capture finale corrigée `20260927-121111-cards-integrated-visual-63d11492` PASS : entrée publique et seize images, zéro diagnostic moteur. Bilan inspecté aux deux résolutions. Smokes partagés `20260927-121325-cards-shared-smokes-9d8ffcd7` : Rencontre fonctionnel mais fuites à la fermeture ; Objets échoue encore ; Terrain headless sans viewport, GL produit les images mais fuit. Pas de gate CI déclarée verte.

La reprise `cards` de 12 h 10 a exécuté 181 tests, mais le nouveau script d'intégration manquait à cause d'un `Vector2i` non inférable dans le test. Type explicité. Une tentative de 12 h 14 n'a exécuté aucun test (verrou des captures). Le passage de 12 h 16 a révélé le refus des coordonnées d'ennemis morts après conversion JSON, ainsi qu'une mauvaise sélection de carte dans le test du coup final. Corrigés : neuf tests d'intégration / 430 assertions PASS à 12 h 22, puis **suite Cartes complète PASS : 190 tests / 14 625 assertions** dans `20260927-122354-test-cards-ed72ec45`, sans erreur moteur. Le diagnostic Rencontre verbose est fonctionnel et n'a pas reproduit les fuites du premier passage.

Modifications postérieures au démarrage global, couvertes par la suite Cartes finale : victoire sauvegardée avant animation, ratio de PV non arrondi conservé entre changements d'équipement et rechargements, libellé des piles consommées, fermeture du commerce à la halte de préparation finale, contrôle d'activation ennemie consommée, coordonnées JSON des unités mortes. Tests ajoutés pour ces cas et pour les douze scènes de combat.

## Résultat et limites
Intégration terminée. [Audit final](../audits/cards_integrated_run_2026-09-27.md) : preuves, défauts corrigés et contrôles globaux rouges. `git diff --check` passe ; 12 270 fichiers audités sans référence manquante. HEAD toujours `c6ab5a72c1789e4cc285300c9bbae9c78524fa05`, aucun commit effectué. Les travaux concurrents et sauvegardes personnelles sont préservés. La balance complète sur les vraies cartes reste à mesurer ; les fixtures de transitions ne la prouvent pas.
