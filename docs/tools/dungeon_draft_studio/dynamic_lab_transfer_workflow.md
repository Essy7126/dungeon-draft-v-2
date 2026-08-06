# Dynamic Arena Lab → Dungeon Draft Studio

Le mode intégré **Construction dynamique** édite directement la working copy et l'historique de l'onglet Arènes. Il ne nécessite aucun transfert.

Le **Lab autonome** reste une scène de sandbox : `res://tools/labs/dynamic_arena/DynamicArenaLab.tscn`. Il utilise ArenaDefinition, les registries terrain/mur, le render plan, le renderer et les snapshots partagés. Son sol demeure visible sous les murs.

## Envoyer au Studio

Le bouton crée atomiquement sous `user://dungeon_draft_studio/lab_transfers/` :

- `arena.tres` ;
- `manifest.json` version 2 ;
- `validation.json` ;
- `thumbnail.png`.

Le manifeste contient transfer/schema/fingerprint, taille, mode, thème, total et comptes par terrain, murs, spawns, objectifs, fingerprint du profil et verdict de validation. Le chargement revérifie les fingerprints Arena et profil.

## Importer du Lab

La barre globale affiche **Importer du Lab (N)** ; **Ouvrir le Lab autonome** est une entrée distincte du menu Lab. Le dialogue de transfert montre miniature, nom, taille, mode, terrains, murs, spawns, validation et empreinte. Ses actions sont : working copy, nouvelle arène, supprimer, annuler.

L'import ouvre toujours une working copy ; il n'écrit jamais directement dans une map de production. Après ouverture, le Studio reconstruit le plan et la preview et annonce les comptes importés.
