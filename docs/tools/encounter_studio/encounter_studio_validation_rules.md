# Règles de validation

La validation retourne des `StudioValidationMessage` typés avec sévérité, code stable, titre, explication, chemin, salle, vague, cellule et correction éventuelle.

## Erreurs bloquant la sauvegarde

- Run absente ou sans salle; RoomData ou RoomWaveData nulle.
- Grille runtime impossible à construire ou `RoomGridLayout` invalide.
- Zone de déploiement alliée vide ou sans case praticable.
- Rencontre moderne absente, roster vide, tableaux non parallèles, UnitData nulle/dupliquée ou quantité non positive.
- Nom de vague vide; multiplicateurs de PV/attaque non positifs; récompense négative.
- `living_enemy_cap` inférieur au roster initial.
- Aucune formation ou formation non reconnue par `EncounterDefinition.FORMATION_IDS`.
- Case interdite dupliquée ou hors grille.
- Placement impossible pour la seed de test demandée.
- Conflit de fingerprint avec un fichier modifié sur disque.

## Avertissements

- Zone ennemie préférée vide.
- Rôle sans politique spécialisée : le fallback générique réel reste autorisé.
- `room_index` différent de la position réelle.
- Budget d’invocation sans capacité active correspondante.
- Capacité d’invocation active avec budget nul.
- Rencontre utilisée par plusieurs vagues/salles.
- `allowed_spawn_groups` présent mais non consommé par le runtime.

## Informations

- Mode moderne ou historique de chaque salle.
- Placement sorti de la zone ennemie préférée, ce qui est autorisé.

## Corrections automatiques V1

- ajuster le plafond vivant au roster initial;
- utiliser l’index réel de salle;
- dédupliquer les cases interdites.

Une correction passe par Undo/Redo et ne sauvegarde jamais automatiquement. Les avertissements ne bloquent pas la sauvegarde; les erreurs la bloquent.

