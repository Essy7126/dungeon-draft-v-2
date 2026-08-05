# Pipeline « Produire la salle »

L’assistant présente cinq étapes : Identité, Validation, Aperçu, Production et Résultat. L’écriture n’est autorisée qu’après confirmation explicite et si la validation ne contient aucune erreur.

## Plan sans écriture

`ArenaProductionService.plan()` annonce les fichiers créés, mis à jour et en conflit. Un fichier existant n’est modifiable que s’il appartient à un manifeste `dungeon_draft_studio_1_2` et si son SHA-256 correspond encore au manifeste. Tout fichier manuel ou modifié hors Studio bloque la production.

## Écriture et vérification

La production : crée une récupération des fichiers mis à jour sous `user://`, clone le document, choisit la battle_scene, sauvegarde/recharge le profil enfant, sauvegarde/recharge l’arène, revalide, génère previews et kit art, écrit rapport/configuration/manifeste, puis recharge une dernière fois.

Le dossier contient `arena.tres`, le profil éventuel, `thumbnail.png`, les previews Logique/Art/Jeu, `validation_report.json`, `test_configuration.json`, `production_manifest.json` et `art_kit/`. Le kit peint/hybride contient les cinq PNG demandés, `arena_definition.tres`, `art_brief.txt` et le rapport.

Si l’empreinte source correspond déjà à un résultat valide et intact, la seconde production réutilise les octets existants sans réécriture. Le résultat **SALLE PRÊTE** n’apparaît qu’après rechargement et validation. Aucune scène manuelle ni ressource de gameplay existante n’est remplacée.
