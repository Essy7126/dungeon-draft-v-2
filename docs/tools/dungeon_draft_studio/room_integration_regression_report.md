# Rapport de régression — Dungeon Draft Studio 2.0

Date : 7 août 2026  
Branche : `main`  
HEAD de travail : `29f307b5ff61822f266bbd2d14636ca8dcea2d95`  
Godot : `4.7.1.stable.official.a13da4feb`  
GUT : `9.7.1`

## Verdict

`ONE_CLICK_ROOM_INTEGRATION_AND_GUIDED_PIPELINE_COMPLETE_WITH_HISTORICAL_WARNINGS`

Le parcours Destination → Produire → Intégrer → Recharger → Sélectionner est
opérationnel sur fixtures. UPDATE et REPLACE ne recouvrent plus la même
opération. La politique de champs bloque toute propriété stockée inconnue et
UPDATE conserve les données gameplay de la salle.

## Contrats vérifiés

- La run principale reste `SINGLE_ENCOUNTER`, avec une rencontre et sans vague.
- La run de test reste `WAVE_CHAIN`, avec ses dix vagues, ennemis et paramètres
  de récompense.
- UPDATE unique conserve le chemin de salle, l’index et le fichier RunData bit
  à bit.
- UPDATE d’une salle partagée crée une copie spécifique à la run et ne modifie
  ni l’autre run ni la salle partagée.
- REPLACE change explicitement la référence, conserve l’ancien fichier et
  annonce le gameplay abandonné.
- INSERT/APPEND sauvegardent puis vérifient l’index exact et la validité finale.
- Une run finale invalide est refusée et le fichier RunData est restauré bit à
  bit depuis le recovery.
- Produire sans intégrer fonctionne sans run cible et ne modifie aucune
  RunData.
- Le journal one-click atteint `COMMITTED` uniquement après reload et contrôle
  des invariants.
- Le panneau Destination est hors du ScrollContainer, utilise UPDATE par
  défaut et affiche le libellé contextuel attendu.
- La visite guidée couvre les quatorze étapes du parcours débutant.
- « Réintégrer » désigne uniquement la fenêtre ; le contenu utilise
  « Intégrer à la run ».

## Résultats automatisés observés

| Gate | Résultat |
|---|---:|
| Room Integration + Guided Pipeline final | 8/8, 119 assertions |
| Arena / Encounter / Studio avec 7 tests de mission | 89/89, 4 424 assertions |
| Rollback supplémentaire après cette matrice | 1/1, 8 assertions |
| Skill Tree Studio + Run Content Isolation | 64/64, 2 014 assertions |
| Suite globale finale | 801/814, 52 242/52 299 assertions |
| Nouveaux échecs globaux | 0 |
| Échecs historiques | 13, mêmes scripts et mêmes causes |
| Scan éditeur | code 0, aucun parse error du patch |

La première globale de diagnostic a momentanément produit deux échecs dans
`test_start_hub_vertical_slice.gd`. Les deux tests ont passé isolément (1/1 et
1/1), puis la globale finale a retrouvé exactement les 13 échecs historiques.
Ce flake d’ordre Hub est déjà documenté sur la baseline et aucun fichier Hub
n’est modifié par cette mission.

## Échecs et avertissements historiques

Les 13 échecs restants concernent les captures absentes, des contrats de
progression historiques, les exports Mountain Pass, les copies de maps peintes
et une comparaison flottante de timeline. Ils sont identiques à la globale
post-push du correctif pierre (`793/806`).

Les suites conservent les avertissements de comparaison float/int et les leaks
RID, ObjectDB et Resource à la fermeture. Aucun de ces messages ne pointe vers
le service d’intégration ou la visite guidée.

## Écritures et isolation

Tous les tests d’intégration écrivent sous
`res://artifacts/studio_2_0/room_integration_pipeline` puis nettoient ce dossier.
Les deux artefacts Arena historiques réécrits mécaniquement par les suites ont
été restaurés exactement depuis HEAD. Aucune salle officielle, RunData
officielle, rencontre, récompense, ressource de progression ou ressource Skill
Tree n’a été modifiée.

## Limite transactionnelle explicite

La mutation canonique salle + RunData possède staging, recovery, reload,
vérification et rollback. Le bundle de production validé est traité comme une
phase préparée : si l’attachement échoue ensuite, il reste disponible pour
diagnostic mais n’est référencé par aucune run. Cette limite est affichée dans
le résultat et décrite dans le contrat vérifié ; la salle et la RunData
canoniques restent restaurées.

## Recette utilisateur courte

1. Ouvrir une arène de fixture et choisir Principale ou Test dans Destination.
2. Garder **Mettre à jour l’arène — recommandé** et choisir une salle.
3. Vérifier le résumé, les chemins, le partage et les fichiers affectés.
4. Valider, tester, puis cliquer le bouton contextuel d’intégration.
5. Contrôler le résultat `SALLE INTÉGRÉE ET RECHARGÉE`, la sélection de la
   salle et le chemin du journal.
6. Refaire sur une fixture partagée et vérifier la création d’une copie propre
   à la run.
7. Ouvrir la visite guidée et parcourir ses quatorze étapes.

