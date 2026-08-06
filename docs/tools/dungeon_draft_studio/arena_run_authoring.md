# Arena Studio 2.0 — authoring d’une run

Statut : **WORKTREE_CANDIDATE**  
Date : 2026-08-06

Le navigateur Arena est dérivé de `StudioProjectContext.active_run.rooms`. La liste historique Forêt/Volcan/Espace ne sert plus que de compatibilité pour créer ou calibrer un document legacy.

## Opérations

`ArenaRunAuthoringService` supporte insertion, remplacement, mise à jour, duplication, déplacement, retrait de référence, copie spécifique à une run, Undo/Redo, brouillon, sauvegarde et rechargement.

- Retirer ne supprime jamais un fichier.
- Une salle embarquée sans chemin doit recevoir une destination avant sauvegarde.
- La sauvegarde écrit d’abord une sauvegarde de récupération et un staging, écrit la `RunData`, recharge puis compare la séquence exacte des chemins.
- Le plan expose indices modifiés, avant/après et garantit `removed_files = []`.

## Production et rattachement

L’assistant Produire propose une RunData découverte, l’action `NONE`, `APPEND`, `INSERT_BEFORE`, `INSERT_AFTER`, `REPLACE` ou `UPDATE`, et l’index demandé. `ArenaProductionAttachmentService` recalcule l’index effectif, recharge l’arène produite et la run canonique, applique l’opération dans une session distincte, sauvegarde transactionnellement puis vérifie le chemin à l’index exact.

Une run cible déjà sale bloque le bouton Produire. En cas d’échec de rattachement, la RunData reste inchangée ; l’arène produite est signalée comme ressource disponible, sans prétendre que le rattachement a réussi.

