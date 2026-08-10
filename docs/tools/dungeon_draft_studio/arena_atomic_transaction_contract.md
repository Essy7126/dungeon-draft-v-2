# Contrat de transaction atomique Arena

Statut : **WORKTREE_CANDIDATE**.

Une transaction de production exécute : plan → staging → vérification → backup → commit → vérification finale. Aucune destination partielle n’est considérée valide. Les échecs avant commit retirent le staging ; les échecs après commit restaurent le backup, puis vérifient fichiers, hashes et rechargement.

L’intégration ajoute une seconde transaction : produire → préparer la salle → créer le recovery de salle et de RunData → sauvegarder → recharger → vérifier index, type de flow et fingerprints. Un échec de RunData provoque le rollback de la salle puis du bundle. UPDATE conserve les champs gameplay ; REPLACE les remplace explicitement.

Les changements de contexte multi-domaines suivent eux aussi prepare-all → stage-all → commit déterministe. Les domaines sont triés, jamais laissés à l’ordre d’un `Dictionary`. Un échec déclenche les callbacks rollback en ordre inverse et restaure les chemins sources capturés ; la sélection, l’état dirty et la transition en attente restent inchangés.
