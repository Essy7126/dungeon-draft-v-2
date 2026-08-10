# Ownership des champs RoomData / ArenaDefinition

Statut : **WORKTREE_CANDIDATE**.

`RoomIntegrationFieldPolicy` classe chaque propriété stockée. Les champs Arena possèdent grille, calibration, cellules, murs, spawns, objectifs et profil visuel. Les champs Room gameplay possèdent rencontre, vagues, ennemis, récompenses, flow et progression. Les champs d’identité et de liaison ont une politique explicite. Le gate exige `UNKNOWN = 0`.

UPDATE fusionne l’Arena working copy dans la RoomData cible tout en reprenant le gameplay depuis la version disque la plus récente. REPLACE substitue toute la salle et affiche les données abandonnées. Lorsqu’une salle est partagée, l’intégration crée une copie spécifique à la run avant mutation.

Les snapshots Arena, gameplay et Room complète sont distincts. Chaque test de sauvegarde et rollback compare les fingerprints pertinents afin qu’une modification d’art ou de grille ne puisse effacer rencontre, vagues ou récompenses.
