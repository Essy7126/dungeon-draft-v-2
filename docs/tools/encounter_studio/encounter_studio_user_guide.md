# Guide pratique — Studio de rencontres

1. Dans Godot, ouvrez **Projet > Paramètres du projet > Extensions** et activez **Dungeon Draft Studio**. Ouvrez ensuite l’écran principal **Dungeon Draft Studio**, puis l’onglet **RENCONTRES**.
2. Cliquez **Ouvrir une run** et choisissez une `RunData`. La première run est ouverte automatiquement par défaut.
3. Choisissez une salle à gauche. Son mode (`Vagues data-driven`, rencontre historique ou liste historique) est affiché.
4. Choisissez un affrontement dans la timeline. La barre horizontale donne accès aux vagues suivantes.
5. Dans **Composition**, recherchez une UnitData ennemie, double-cliquez pour l’ajouter, puis utilisez `−`, `+` ou **Retirer**. Modifiez les PV/attaque/récompense de la vague et les plafonds/budgets de la rencontre avec les contrôles dédiés.
6. Un bandeau orange signale une rencontre partagée. À la première modification, choisissez de modifier tous les usages ou l’action recommandée **Dupliquer pour cet affrontement**.
7. Saisissez une **Seed de run** puis cliquez **Générer un placement**. La map réelle, les zones, exclusions strictes, unités numérotées et distances à la zone alliée apparaissent.
8. Dans **Analyse**, lancez 10, 100 ou 1 000 seeds. **Annuler** interrompt une analyse longue. Une seed problématique peut être saisie dans la barre pour la revoir.
9. Lisez le panneau inférieur : rouge = erreur bloquante, orange = avertissement, bleu = information. Double-cliquez une ligne proposant une correction automatique.
10. Cliquez **▶ Tester**. Le Studio crée une copie temporaire, lance la vraie scène de bataille avec le vrai `GameManager`, puis nettoie le contexte de test.
11. Cliquez **Sauvegarder**. Vérifiez la liste exacte des fichiers; une récupération `user://` est créée avant toute écriture. Les enfants sont écrits avant les parents et tous les fichiers sont rechargés pour vérification.
12. Pour abandonner les changements non sauvegardés, rouvrez la run. Après un échec d’écriture, cliquez **Restaurer la dernière récupération** sous l’arbre des salles; vérifiez la session restaurée, puis sauvegardez pour confirmer.

Conseil : utilisez **Progression** pour comparer objectivement deux affrontements. Le Studio ne prétend pas prédire la victoire ni le temps de combat.
