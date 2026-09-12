# Retrait du deck — état du 12 septembre 2026

Demande : le joueur rejette le deck, veut ses sorts habituels et conserve seulement
les défis influençant le combat suivant. Relique permanente/éphémère = direction
à réfléchir, pas une autorisation d'implémenter un nouveau système maintenant.
Pas de délégation. Changements art/audio des autres tâches préservés.

Fait : suppression des modules deck, tests et outils de capture associés ; retour
des sorts, arbres, récompenses et caméra habituels. Unit et PaintedBattle ont
retrouvé leur contenu antérieur au prototype ; aucun bonus de stats de ce mode.
État de défis indépendant (core/expedition/catabase_challenge_state.gd), adaptateur
Battle et repère du sceau séparés. Le public active les défis ; les outils anciens
peuvent garder start_expedition(seed) sans eux. Une sauvegarde contenant « deck »
migre vers le kit normal et conserve seulement ses conséquences à venir.

Règles : refuser ne pénalise jamais la durée. Réussite = bouclier Achille 10 % PV
au combat suivant ; échec = bouclier premier ennemi 10 %. Durée deux activations,
pas d'accumulation. Ancienne alerte 2 reprise une fois avec 20 %. Défis : victoire
en cinq/six tours, deux déplacements ennemis, sceau à éteindre avant fin T4/2 PA.

Preuves : 7 tests / 61 assertions PASS strict dans
artifacts/dev/20260912-180434-test-test_unit_test_catabase_challenges.gd-4a0114fe.
Le premier essai avait identifié le type float des entiers JSON ; corrigé et
retesté avec lecture d'un véritable fichier de sauvegarde. Capture graphique
inspectée dans artifacts/dev/challenge_capture : quatre sorts, Garde lancée,
PA 6→4, bouclier 10, sorts inchangés ; sortie 0 sans erreur moteur.

Terminé : régressions ciblées parcours/récompenses/sauvegardes dans
artifacts/dev/challenge_regression : PASS strict, 40 tests et 3 866 assertions,
aucune erreur. Les nouveaux journaux/JUnit utilisent l'import recovery validé de
cette passe. Aucun processus de validation de cette tâche encore actif.
Diff vérifié : seuls les hooks de défis subsistent dans Battle ; les ajouts audio
concurrents d'ExpeditionScreen sont préservés. Pas de référence active au deck,
hormis la migration de l'ancienne clé de sauvegarde. Prochaine étape : réflexion
avec le joueur sur une identité de combat et des reliques, sans présumer de règles.
