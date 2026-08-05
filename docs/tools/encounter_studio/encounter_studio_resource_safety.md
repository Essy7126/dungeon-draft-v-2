# Sécurité des ressources

## Isolation

Ouvrir une run produit une copie explicite. Les ressources canoniques ne sont mutées ni par l’UI, ni par la preview, ni par la validation, ni par l’analyse. Les UnitData externes restent les mêmes références, tandis que les tableaux et dictionnaires de rencontres sont indépendants.

La session conserve un graphe source ↔ copie et un snapshot des EncounterDefinition sources. `source_is_untouched()` est couvert par les tests.

## Ressources partagées

Le graphe de références inspecte toutes les RunData détectées. Avant la première modification d’une rencontre ayant plusieurs usages, une boîte modale impose un choix explicite. **Dupliquer pour cet affrontement** crée une définition indépendante et un chemin `res://data/encounters/...` unique; supprimer la vague ne supprime jamais le fichier.

## Conflits

À l’ouverture, chaque fichier source reçoit un fingerprint `{exists, modified, md5}`. Si le disque change, la sauvegarde s’arrête avec `external_conflict` et liste les chemins. Le Studio n’effectue aucune fusion destructive.

## Transaction de sauvegarde

1. conflit et validation;
2. copie complète de récupération sous `user://dungeon_draft_studio/encounter_studio/recovery/`;
3. backup des fichiers existants concernés;
4. écriture des nouvelles EncounterDefinition;
5. rechargement et liaison externe des enfants;
6. écriture des RoomData, puis RunData;
7. rechargement `CACHE_MODE_IGNORE` de chaque fichier;
8. réouverture d’une copie de travail propre.

En cas d’échec, les backups déjà créés sont recopiés vers leurs chemins exacts. Seuls les chemins `res://` ou `user://`, extensions `.tres`/`.res`, sans `..`, sont acceptés. Aucun chemin absolu n’est sauvegardé.

La boîte de confirmation affiche tous les fichiers qui seront modifiés ou créés. Le cycle de sauvegarde de l’éditeur Godot n’écrit jamais implicitement une session Encounter Studio.

## Production

La mission n’a modifié aucune composition, quantité, borne de vague, multiplicateur, récompense, statistique, profil d’IA ou ressource de production. `res://tools/arena_map_editor/` reste présent et intact.

