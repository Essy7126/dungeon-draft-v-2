# Fiche de travail — laboratoire cartes consommables

Complément du 25 septembre : l'audit approfondi et la fiche de reprise actuels sont dans `research_2026-09-25/`. Le README parent pointe vers ce dossier. Il ajoute 21 références utilisées, trois chapitres, seize cas de calcul et cinq tests (treize avec le laboratoire parent). `early_supply` reste historique et non monotone ; le stress de 70 % n'est pas une restriction de classe. Les résultats du 24 ci-dessous sont conservés.

Base inspectée : 6a500c545f04d3e4c53a99d3643d0c4d844e303f, 2026-09-24.

Demande : approfondir recherches, cartes, mathématiques des drops, logique de run et économie ; livrer un dossier reprenable sur un autre ordinateur. Pas d'implémentation du gameplay.

Contraintes utilisateur : quinze cartes initiales ; exemplaires à usage unique ; préparation avec plafond envisagé de trente ; sacs droppés par les mobs ; normales faibles abondantes et taux croissants ; rangs supérieurs rares ; établir la base sans prospection, maîtrise, reliques ou bonus de performance.

Correction importante : les effectifs réels sont 1, 2 ou 3, 3, 3, 4, 3, 2, 4, 3, 4, 3, 3 (boss compris). Les 43 monstres avant boss du document précédent étaient une hypothèse, pas la route réelle.

Travail : sources commentées, simulateur Node sans dépendances, paramètres JSON, tests mathématiques, cartes CSV, rapport et protocole de reprise. Les sorties brutes restent dans artifacts/dev ; les conclusions et commandes restent dans ce dossier.

État et validations finaux : voir README.md et REPORT.md. Les trois propositions antérieures présentes en fichiers non suivis au début sont conservées ; ne pas les prendre pour des règles implémentées.

Terminé : six sources commentées ; vingt lignes de cartes ; 36 cas × 20 000 parcours ; calcul exact de contrôle ; huit tests réussis avec Node v24.19.0 et isolation désactivée. RESULTs portables dans RESULTS.csv, détails régénérables dans artifacts/dev/card-economy-lab. Aucun changement du moteur, aucun commit ni push effectué. Prochaine étape : mesurer la consommation réelle et la compatibilité des cartes avant d'implémenter ou de retenir un équilibrage.
