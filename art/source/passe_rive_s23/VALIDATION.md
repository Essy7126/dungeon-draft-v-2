# S23 — audit du 26 septembre 2026

Les corrections sont intégrées au projet. La taille de référence entre salles et la palette sont communes ; les silhouettes des dessins existants ne sont pas déclarées identiques. La marche native et les attaques approuvées sont conservées.

## Preuves visuelles

- [Revue S23, lecture et défilement image par image](../../../artifacts/dev/passe-rive-s23-review-20260926/review.html).
- [Rapport moteur S23](../../../artifacts/dev/passe-rive-s23-20260926-143603/report.json) : **168 contrôles réussis**, 98 captures, 17 scènes. Quatre salles peintes, cinq salles tactiques, sept haltes et le vrai seuil.
- Stature de référence : **89.999996 à 90.000004 px**, attendue 90 px dans la fenêtre 1440 × 950. C'est la stature calculée à partir de la référence debout et de la transformation du rendu, pas la hauteur du rectangle d'une pose accroupie. Zoom volontaire 1.5× conservé ; redimensionnement à 1280 × 720 et retour contrôlés.
- Cinq planches directionnelles : départ, contact, retour pour les sept gestes. Contrôle visuel de la palette continue, des appuis et du volume de la tête. Les 75 captures de raccord ne contiennent aucun fondu entre deux personnages.

## Gameplay et régressions

Une validation globale d'une autre tâche occupait le moteur du projet principal. Les tests ci-dessous utilisent une copie isolée, avec cache d'import et données utilisateur séparés, créée dans le workspace de cette conversation. Aucun processus de l'utilisateur ni de l'autre tâche n'a été interrompu. Les **13 fichiers runtime concernés sont identiques par SHA-256** au projet principal ; les autres modifications concurrentes ultérieures ne sont pas certifiées par ces résultats. La dernière mise en forme du backend, vérifiée sans changement de structure, précède les captures gameplay et le combat réel.

Racine de ces preuves : `C:/Users/paolo/Documents/Codex/2026-09-19/lis-la-conversation-x20/artifacts/s23_validation/project/artifacts/dev/`.

| Contrôle | Résultat | Dossier sous cette racine |
|---|---|---|
| Suite Cartes | **121/121**, 11 498 assertions | `20260926-144959-test-cards-a17db766` |
| Passe-Rive natif | **13/13**, 6 589 assertions | `20260926-145432-test-test_unit_test_passe_rive_autosprite.gd-91ac718b` |
| Suite haltes | **53/54**, un échec de parcours décrit ci-dessous | `20260926-145531-test-halts-edb6e3da` |
| Suite audio, comprenant aussi seuil et haltes | **102/106**, quatre échecs décrits ci-dessous | `20260926-145631-test-audio-f41610d2` |
| Marche → sept sorts → quatre ruées | **565 contrôles**, 11 lancers réussis | `passe-rive-s22-20260926-145900` |
| Préparation → combat IA → victoire → reprise disque | **PASS**, huit sorts, trois déplacements, trois fins de tour | `passe-rive-flow-20260926-150019` |

Le parcours visuel passe par les commandes de Battle et SpellCaster. La ruée présente ses images de trajet, ne commence sa réception qu'à la destination et émet une seule libération. Le banc Studio pause l'IA pour rendre ces essais reproductibles ; le dernier parcours du tableau laisse au contraire l'IA jouer, obtient une vraie victoire et recharge la sauvegarde écrite. Aucun ancien rapport S22 n'est utilisé comme preuve fraîche : ce nom reste celui du banc de locomotion.

Les suites haltes/audio ne sont **pas** déclarées vertes :

- `test_painted_halt_runtime::test_bindings_are_presentation_only_and_preserve_all_seeded_route_ids` attend quatre lieux aux profondeurs 4 et 8. Le catalogue r6 lie désormais les lieux par identité, avec cinq correspondances dans ce parcours, dont des profondeurs 7 et 9. Ce test manipule les données de parcours ; il n'instancie pas le personnage.
- Trois tests `test_catabase_threshold` attendent un départ immédiat en combat et un compteur `battles` incrémenté : `test_intro_handoff_preserves_selection_and_previous_save_until_the_gate`, `test_failed_first_checkpoint_retries_the_write_without_creating_another_run`, `test_resuming_a_checkpoint_bypasses_both_cinematic_and_threshold`. Ils exercent un faux gestionnaire de run, sans instancier la scène de seuil ni appeler les nouveaux réglages visuels. Ces attentes sont à réconcilier avec le flux actuel de préparation ; aucune règle de départ ou assertion n'a été modifiée pour cette tâche.

## Mesures et essais rejetés

- Les générateurs de palette et de recalage, puis l'audit de palette, passent en mode `--check`.
- 175 médianes matière sur 35 atlas d'attaque : distance RGB moyenne à la référence **20.43 → 2.58**, soit **87.39 % de réduction**. C'est une mesure de couleur aux médianes selon l'équation du shader, pas un score de qualité d'animation ni une preuve d'identité des silhouettes.
- Les 50 PNG S19/S20 contrôlés restent inchangés ; `source_integrity.json` contient le résultat. Les corrections sont appliquées au rendu.
- Les seuils de couleur abrupts causaient des points colorés : remplacés par des poids continus. Les réductions de 20–25 % issues de la seule surface des vêtements réduisaient trop les têtes : ajustement borné à 10 % après inspection. Le fondu repos/attaque produisait deux silhouettes : retiré.
- Le premier passage Cartes a trouvé un paramètre de shader non initialisé explicitement en mode headless. La valeur par défaut est désormais assignée à la création du matériau ; la suite Cartes fraîche ci-dessus confirme la correction et l'isolation des matériaux entre acteurs.
- Format ciblé et contrôle Git des espaces : réussis. Aucun formatage global, commit ou déploiement distant.

## Limite artistique restante

Les attaques gardent parfois une capuche plus ronde, un torse plus large et un modelé différent du repos natif. Une correction uniforme ne peut pas transformer ces constructions en un même dessin. Les images de raccord restent donc à reprendre sur une planche maître commune pour obtenir des transitions presque invisibles. La méthode de production et les critères de contrôle sont dans `README.md` ; cette passe ne prétend pas avoir redessiné les animations.

Les chemins complets, résultats stricts, mesures et empreintes runtime sont réunis dans [validation_evidence.json](validation_evidence.json).
