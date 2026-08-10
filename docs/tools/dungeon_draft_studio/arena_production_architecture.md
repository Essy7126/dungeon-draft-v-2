# Architecture de production Arena Studio 2.0

Statut : **WORKTREE_CANDIDATE** — patch local non committé. Base observée : `main` / `5b7458becbaae6d16c2989f84fb12b60f3b4eb9c`, le 2026-08-10.

La source éditée est `ArenaEditSession.working_arena`. La production suit une chaîne à autorité unique : validation pure, plan des fichiers, staging dans un dossier frère, contrôle des hashes et fingerprints, backup vérifié, publication atomique, rechargement puis inspection runtime. `ArenaProductionTransactionService` possède le commit du bundle ; `ArenaProductionAttachmentService` possède la mutation de la RunData. `ArenaIntegrationService` orchestre les deux et annule la production si l’intégration échoue.

Le bundle runtime contient `arena.tres`, le profil visuel si nécessaire, previews, rapports et `production_manifest.json`. Les sorties de diagnostic ne sont pas des dépendances runtime. Un bundle n’est réutilisé que si générateur, révision, source fingerprint, fingerprint produit, hashes, validation et construction runtime concordent.

Le tableau **Productions et récupérations** est en lecture seule par défaut. Toute archive, restauration ou suppression demeure une action explicite. Le dossier `res://data/arenas/produced/room_01_forest/` est une divergence gelée et n’est jamais une source du test direct.
