# Workflow PAINTED, MODULAR et HYBRID

## PAINTED

Le background peint représente le sol. Aucun sol modulaire de base n'est promis. Murs, décorations et foreground restent disponibles. Le clic Construction dynamique affiche un dialogue avant toute édition invisible :

- **HYBRID — terrains spéciaux** : conserve le fond, crée le profil si nécessaire, choisit NON_BASE_TERRAINS/base stone et enregistre une seule action Undo ;
- **HYBRID — TOUTES LES DALLES TACTIQUES** : conserve également le fond, mais affiche immédiatement `normal` et `stone` avec le vrai asset `stone.png` sur chaque cellule définie ;
- **Créer une copie MODULAIRE** : conserve topologie, spawns et obstacles dans la working copy mais passe au sol entièrement modulaire ;
- **Modifier uniquement la logique** : reste PAINTED et affiche en permanence que les dalles ne seront pas rendues ;
- **Annuler** : ne change rien.

Aucune option ne sauvegarde automatiquement ou n'écrase la ressource source.

## MODULAR

Une nouvelle map MODULAR reçoit un profil et des cellules stone. Construction dynamique s'ouvre directement. Chaque cellule définie non VOID est rendue ; les murs sont superposés au sol. VOID retire sa dalle.

## HYBRID

Le background reste visible. NONE n'ajoute aucun sol ; NON_BASE_TERRAINS rend uniquement les overlays différents du terrain de base ; ALL_DEFINED rend toutes les dalles définies. Le panneau **SOL HYBRIDE** permet de passer explicitement entre ces politiques sur la working copy.

Le défaut historique reste NON_BASE_TERRAINS pour les anciennes ressources. Lorsqu'un décor est ajouté à une map MODULAR, le dialogue d'import propose par défaut **TOUTES LES DALLES TACTIQUES** afin de conserver le sol qui était visible avant le passage en HYBRID. Le choix reste affiché et modifiable avant confirmation.

Undo/Redo restaure simultanément mode, profil, `terrain_id` et rendu du canvas.
