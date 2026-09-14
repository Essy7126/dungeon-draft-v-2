# Premier dialogue de Charon

Prototype demandé : accueil instantané au Seuil des Ombres (trois statues), avant création de la run. Portrait original peint, bulle en bas de l’écran, palette commune encre/bronze/ivoire/pétrole. Texte entier immédiat, sans défilement ni fermeture automatique. Poursuivre, Espace, Entrée ou Échap rendent la main à l’exploration. Les clics derrière la bulle ne déplacent pas Achille. Le décor reste animé.

Composant réutilisable : `ui/dialogue/portrait_dialogue.gd`. Déclenchement unique dans `_ready` du seuil ; la reprise de sauvegarde conserve son parcours direct. La réplique ne crée aucune règle de progression ni écriture de sauvegarde.

Portrait : `assets/catabase/dialogue/charon_v1/portrait.png`, généré avec l’outil imagegen intégré. Prompt conservé dans `art/source/catabase/charon_v1/prompt.txt`. Le shader de présentation masque les coins du portrait sans modifier l’original.

## Vérifications terminées

- Tests du seuil : **11 tests réussis**, zéro échec ni erreur moteur. `artifacts/dev/20260912-123007-charon-dialogue-tests-3e88d147/summary.json` et `gut.junit.xml`. Couvrent la prise de parole immédiate, le blocage des déplacements/interactions, la fermeture unique par touche, l’appui maintenu provenant de la scène précédente, les statues, la porte, la sauvegarde et la reprise.
- Rendu réel : **88 contrôles et 30 captures**, 1280×720, 1920×1080 et 1200×896 ; aucun texte coupé, encombrement inférieur à 42 % de la hauteur, fermeture par un événement clavier réel. `artifacts/dev/20260912-122329-threshold-capture-skip-painted_g-b93f5ef1/summary.json`. Portraits, texte et disposition inspectés visuellement. Le premier essai avait détecté une hauteur excessive au premier affichage ; le composant recalcule maintenant sa hauteur après la mise en page du texte.
- Parcours public : **39 contrôles réussis, 10 captures**, de Nouvelle partie à la sauvegarde après la porte, avec fermeture du dialogue par clic réel. `artifacts/dev/20260912-122542-threshold-flow-skip-painted_g-6935ba9d/summary.json`. Aperçu réel : `03-entry.png`.
- Import Godot réussi pour les captures et le parcours. Une tentative globale ultérieure (`20260912-122720-threshold-unit-skip-painted_g-6c8d8c0b`) a échoué sur `artifacts/spine_trial/veilleur_walk_E_v1/painted_walk_E.webp`, issu d’un autre essai en cours. Ce fichier est conservé ; les 11 tests finaux ont été exécutés directement par GUT, sur les ressources du dialogue déjà importées. Ce test ciblé ne prétend pas valider l’import global du dépôt.

Pour revoir le prototype : Nouvelle partie, ou lancement direct de `hub/catabase_threshold/CatabaseThreshold.tscn` dans Godot. Le composant et le portrait sont réutilisables pour les prochaines prises de parole.
