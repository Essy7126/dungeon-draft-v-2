# Guide utilisateur — maps visuelles 1.3.1

## Deux commandes différentes

**Construction dynamique** édite immédiatement la map ouverte dans le Studio. **Importer du Lab** récupère une map construite dans la scène autonome. Le menu Lab contient séparément **Ouvrir le Lab autonome**.

## Créer et peindre une map modulaire

1. Ouvrir Dungeon Draft Studio → Arènes → Nouvelle.
2. Choisir **Modulaire**, nom, identifiant et dimensions.
3. Ouvrir **Construction dynamique** (icône en rail, libellé complet dans l'inspecteur).
4. Choisir Pierre, Eau, Glace, Lave ou VOID dans Terrain. La ligne indique nom, `terrain_id`, praticabilité, type logique et raccourci.
5. Peindre ; le preview semi-transparent montre le pinceau. Un trait forme une seule action Undo.
6. Choisir Mur normal/feu/glace, spawns, objectif ou décoration si nécessaire.

La texture change immédiatement. VOID laisse un trou. Les murs ne remplacent pas le sol.

## Art et Jeu

Choisir la vue **Art** pour vérifier sol, murs, décorations et foreground. Choisir **Jeu** pour ajouter unités, Y-sort, occlusion et caméra runtime. Masquer la grille ne masque jamais les dalles.

## Convertir une map peinte

Ouvrir la forêt puis Construction dynamique. Choisir **HYBRID — terrains spéciaux** pour laisser la pierre au décor, ou **HYBRID — TOUTES LES DALLES TACTIQUES** pour afficher une vraie dalle `stone.png` sur chaque cellule normale. Le background reste intact dans les deux cas. Le panneau **SOL HYBRIDE** permet de changer ce choix ensuite ; Undo revient au contrat précédent. Sauvegarder sous une nouvelle arène si le résultat doit être conservé.

Lors de **Importer le décor**, choisir également **TOUTES LES DALLES TACTIQUES — pierre incluse** si le sol tactique complet doit rester au-dessus de l'illustration. Une map auparavant MODULAR présélectionne ce choix.

## Lab autonome et transfert

1. Menu Lab → Ouvrir le Lab autonome.
2. Nouvelle, dimensions, terrains, murs, spawns et objectif.
3. Sauver puis Envoyer au Studio.
4. Revenir au Studio ; **Importer du Lab (1)** ouvre le résumé et la miniature.
5. Choisir Ouvrir comme working copy ou Importer comme nouvelle arène.

## Produire

Cliquer Produire, parcourir Identité → Validation → Aperçu → Production, puis Produire maintenant. Le bouton reste bloqué si une dalle/texture/un mur attendu manque. Le résultat SALLE PRÊTE affiche les comptes attendus/rendus, les previews valides et le rechargement de la ressource.
