# Prototype deck — historique retiré, 12 septembre 2026

**Périmé : le joueur a rejeté ce mode et demandé son retrait.** Le code du deck,
sa main et ses tests spécifiques ont été supprimés. La source de reprise actuelle
est `docs/ai/challenges_without_deck_work.md`. Tout le texte ci-dessous décrit
l'expérience précédente, pas des tâches à reprendre ni le système actif.

Autorisation : mettre en place la proposition de deck/menaces/contrats et l'essayer.
Sans nouveaux personnages. Pas de délégation. Préserver les nombreux changements
artistiques et audio préexistants ; les fichiers gameplay de la passe précédente
sont également déjà modifiés. README et proposition relus.

Architecture retenue : état de deck indépendant dans ExpeditionSession ; sorts
résolus par SpellCaster et SpellModifier ; adaptateur possédé par Battle pour la
main, les intentions spéciales et objectifs. Nouvelles parties publiques activées,
anciennes sauvegardes et outils historiques sans deck conservés. Sauvegardes aux
frontières de combat comme le jeu existant, ordre de pioche déterministe.

Implémenté : 24 techniques + 4 fondamentaux, choix de deux familles, main de cinq,
conservation/défausse/épuisement, Ferveur, collection et édition entre combats,
récompenses transactionnelles, ennemis renforcés II–VI, zones annoncées, sceau,
contrats et Alerte facultative bornée au combat suivant. Aucun nouveau personnage.

Fichiers : core/expedition/catabase_deck_{state,catalog,modifier}.gd ;
battle/catabase_deck_{battle,marks}.gd ; ui/expedition/catabase_deck_editor.gd.
Intégrations dans Battle, PaintedBattle, Unit, ExpeditionSession/Flow,
GameManager et ExpeditionScreen. README et docs/design/catabase_deck_v1_2026-09-12.md
décrivent le lancement et les différences effectives avec la proposition.

Preuves : sélection stricte de 44 tests / 3 956 assertions PASS dans
artifacts/catabase_monsters/checks/deck_integration_20260912/gut-strict-report.json.
Trois parcours dans les scènes réelles : puits répétitif défaite V ; puits avec
politique de cartes défaite III ; Chasse–Garde/barque défaite III. Ce sont des
mesures de pression, pas une preuve d'équilibre ni de qualité d'un pilote humain.
Rapports sous artifacts/dev/early_run_playtest/live_*deck*/report.json.
Capture graphique des quatre étapes du deck sous artifacts/dev/deck_capture.
Main initialement coupée : marges corrigées ; caméra ensuite adaptée.

Implémentation terminée et recapture finale inspectée à 1280×720 : quatre étapes,
main lisible et combattants visibles, capture_final.log sans erreur et sortie 0.
Les libellés des défis sont français. Dernières corrections : conservation libérée
au renouvellement de main, types de sauvegarde rejetés proprement, sceau accessible,
Alerte appliquée sans sauter les autres ennemis, zones annoncées incluant les cases
occupées, dégâts magiques pour le feu et physiques pour la porte/barque.

Suite générale artifacts/dev/20260912-164057-test-all-98828525 : FAIL, délai de
900 secondes dépassé, bilan incomplet, erreurs de tests 3D/haltes/Studio. Sélection
finale artifacts/dev/deck_final/checks : 85/85 tests et 4 138 assertions réussis,
mais verdict strict FAIL pour erreurs à la fermeture moteur et à l'import normal.
Isolation des tests du deck : artifacts/dev/deck_probe/unit_final.log, 12/12,
104 assertions, sortie 0 sans erreur moteur. Ne pas annoncer une CI verte.
Le formateur a refusé le catalogue pour changement de structure, sans contournement.
Les deux JSON de démonstration Arena Studio régénérés par la suite générale étaient
propres dans le contexte Git initial ; leurs changements de test ont été annulés.

Suite souhaitée : retour humain sur une nouvelle partie. La pression est démontrée
par les parcours réels, pas l'équilibre des quinze paires de familles ni toute la run.
Aucun processus moteur de validation de cette tâche ne reste actif.

État Git à revérifier avant toute reprise : nombreux changements art/audio d'autres
tâches ; ne pas restaurer ni reformater globalement. Les valeurs de difficulté
restent des hypothèses et les premiers essais sont maintenant nettement punitifs.
