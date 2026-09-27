# Validation S20 — 26 septembre 2026

Correction active dans les combats Cartes de Passe-Rive. Les résultats ci-dessous
portent sur la sélection des vues, les actions réelles et les effets. Ils ne
constituent pas une approbation artistique de chaque dessin.

| Contrôle | Résultat / preuve relative à la racine du projet |
|---|---|
| Suite Cartes finale | 99 tests, 10 046 assertions, aucune erreur ; `artifacts/dev/20260926-002632-test-cards-65c19456/summary.json` |
| Audit natif des directions | 48 sorts légaux, 777 contrôles, 145 captures (arène initiale + 3 par sort) ; `artifacts/dev/passe-rive-s19-20260926-002403/report.json` |
| Dernière découpe de la riposte | 4 directions de mêlée, 73 contrôles, 13 captures ; `artifacts/dev/passe-rive-s19-20260926-003344/report.json` |
| Parcours réel contre l'IA | Préparation, 8 sorts, 3 déplacements, victoire, bilan et reprise de sauvegarde ; `artifacts/dev/passe-rive-s20-flow-20260926-003545/appdata/s19_flow_report.json` |
| Auto-test du lanceur | `artifacts/dev/20260926-002507-selftest--093555d1/summary.json` |
| Sources et génération des métadonnées | `python tools/class_card_vfx/build_s20_data.py --check` : 36 planches / 432 poses, données reproductibles ; 36 SHA-256 conformes à `generated_sources.json` |
| Préservation | Les 14 PNG S18/S19 correspondent toujours à `../passe_rive_s19/integrity.json` |

L'audit natif exécute le circuit Battle → préparation → décoche → SpellCaster →
récupération. Il vérifie l'absence de dégâts anticipés, la pose exacte de décoche,
la direction projetée, le choix d'atlas, le retour en garde, l'absence de projectile
ancien doublé et la profondeur des impacts. Les quatre axes nécessitant deux
cases sont exclus pour les cartes de mêlée de portée 1, sans modifier les règles.

Les tests unitaires couvrent aussi les 56 paires sept gestes × huit directions,
y compris celles qui ne sont pas jouables à portée 1 ; ils testent le lecteur,
pas la légalité de ces cibles. Ils vérifient annulation, décès, marche pilotée par
distance, changement de direction sans changement de pose, dimensions des atlas,
origine des VFX et durée de vie distincte des impacts et états.

Le parcours contre l'IA a observé `PR_WALK_SE`, `PR_WALK_NE`, `PR_IDLE_SE`,
`PR_SEAL_SE` et `PR_EMBER_SE`. Il utilise les règles normales, une sauvegarde
isolée et des intentions pilotées par script. Il ne force ni victoire ni dégâts.

## Audit visuel et corrections

Les planches générées ont été examinées, puis des captures représentatives des
sept gestes et des huit directions ont été inspectées. Constats corrigés :

- La vue de profil répétée en N/S a été remplacée par des poses de dos/de face.
- Le tir NE/N a été recadré lors de la génération pour préserver l'arc.
- La braise de dos et l'estocade de dos ont été reprises pour leur orientation.
- Une flèche peinte E/W pointant à l'envers est exclue du rendu, sans toucher au PNG.
- La volée SE/SW garde la corde tendue jusqu'à la vraie décoche.
- Les impacts des cibles arrière sont masqués par les personnages au premier plan.
- Les pointes de dague de la riposte SE/SW, à cheval sur deux cellules, sont
  attribuées à leur pose et exclues des voisines. Capture ciblée vérifiée après
  cette dernière correction de métadonnées.

Les captures ne prouvent pas à elles seules toute la continuité de l'animation.
Les limites artistiques restantes, dont les trois miroirs et les petites variations
entre dessins, sont explicites dans le [README](README.md). La suite globale du
projet n'est pas déclarée validée par cette campagne ciblée.

## Incidents de validation conservés

La première exécution après ajout des PNG a rencontré des préchargements avant
import, avec zéro test : `artifacts/dev/20260926-000833-test-test_unit_test_passe_rive_s19.gd-e8ef87fa`.
Elle est un échec conservé, pas une validation. Le passage après import a réussi
(5 tests / 1 139 assertions), puis les contrôles finaux ci-dessus l'ont remplacé.

Le premier auto-test du lanceur n'avait pas accès au dossier temporaire Windows
depuis le bac à sable : `artifacts/dev/20260926-002414-selftest--20138456`.
Son exécution avec les permissions adaptées a réussi. Aucune erreur n'a été
masquée dans les analyseurs stricts.
