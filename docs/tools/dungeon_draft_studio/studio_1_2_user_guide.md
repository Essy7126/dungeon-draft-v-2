# Guide utilisateur Dungeon Draft Studio 1.2

1. Dans Godot, ouvrez le main screen **Dungeon Draft Studio**.
2. Cliquez **Détacher** (`Ctrl+Shift+D`) pour travailler dans la fenêtre native.
3. Appuyez sur `Tab` ou cliquez **Focus** pour agrandir la carte ; répétez pour restaurer les panneaux.
4. Cliquez **DYN**, puis **Nouvelle** pour créer une carte dynamique et choisissez ses dimensions.
5. Peignez pierre/eau/glace/lave/VOID avec `1` à `5`.
6. Choisissez un mur normal/feu/glace et placez-le avec `Ctrl+clic` ; le même mur est retiré, un autre le remplace.
7. Placez les spawns héros/ennemis et vérifiez le chemin/LOS.
8. En Lab autonome, cliquez **Envoyer au Studio**. De retour au Studio, le statut annonce le transfert ; cliquez **Lab** pour ouvrir la working copy vérifiée.
9. Choisissez **Logique** dans la barre globale pour contrôler grille et topologie.
10. Choisissez **Art** pour examiner les assets sans debug.
11. Choisissez **Jeu** pour voir le renderer runtime, le trio, la rencontre, les murs et l’occlusion.
12. Cliquez **Tester** pour lancer la copie de travail dans la vraie scène de combat ; les sources ne sont pas sauvegardées.
13. Cliquez **Produire**, vérifiez les cinq onglets et la liste des fichiers, puis **Produire maintenant**. Corrigez toute erreur ou conflit affiché. Attendez **SALLE PRÊTE**.
14. **Sauver** enregistre le document canonique ; la production marque également son résultat rechargé comme état sauvé.
15. Cliquez **Réintégrer**, fermez la fenêtre ou utilisez `Ctrl+Shift+D` pour revenir dans Godot.

Pour un ancien schéma, choisissez explicitement migration de la working copy ou lecture seule. Ne copiez jamais les PNG du kit art dans la logique gameplay : `arena_definition.tres` reste l’autorité.
