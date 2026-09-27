# Validation S22 — 26 septembre 2026

## Résultats frais

- **Cartes : PASS, 103 tests / 11 089 assertions**, `artifacts/dev/20260926-133833-test-cards-e6fdef9e/summary.json`.
- **Animations natives : PASS, 13 tests / 6 589 assertions**, `artifacts/dev/20260926-134218-test-test_unit_test_passe_rive_autosprite.gd-9563f999/summary.json`.
- **Audit en scène : PASS**, `artifacts/dev/passe-rive-s22-20260926-133701/report.json`. 186 contrôles fonctionnels, 338 frames enregistrées et 43 captures fixes (567 contrôles en comptant les écritures). 11 lancements réels : sept attaques SE et quatre ruées Percée dans les axes autorisés. Repos dans huit directions, marche/course dans quatre axes, trajets de 1 et 3 cases, virage, retours au repos. Les tests unitaires couvrent les huit vues d’attaque et de ruée ; les cinq angles peints disposent chacun d’une planche de comparaison repos/départ/contact/retour.
- **Parcours réel : PASS**, `artifacts/dev/passe-rive-s22-flow-20260926-134325/appdata/s19_flow_report.json` : préparation Cartes, 8 sorts, 3 déplacements, 3 fins de tour, IA ennemie, victoire, sauvegarde disque et reprise avec Passe-Rive. Profil et règles de jeu réels ; sauvegarde utilisateur isolée.
- **Sources conservées : 50 PNG vérifiés**, `integrity.json`. Générateur S20 `--check` valide 36 atlas / 432 poses. Aucun dessin source n’a été repeint dans cette passe.
- Formatage ciblé des sept scripts : PASS. `git diff --check` ciblé : PASS. Aucun commit ni push.

## Inspection visuelle

Les cinq planches `scale_*.png` et les séquences marche/tir/ruée ont été inspectées. La marche utilise bien l’animation native et sa cadence est désormais liée au déplacement physique. La ruée dispose d’un départ, d’un trajet penché et d’une réception à la destination, sans second déclenchement. La réduction d’échelle des attaques et le recalage du sceau suppriment le grossissement global et le fragment d’effet sous les pieds.

Le lecteur `review.html` permet de parcourir toutes les captures. Les GIF `SE_1`, `SE_3`, `r_shot`, `a_sweep`, `dash_SE` et `dash_NE` reprennent leurs temps réels de capture. Aucune interpolation de pose n’est ajoutée.

**Limite graphique :** les attaques peintes restent plus massives dans les vêtements et différentes dans le modelé du rendu natif. La présente correction règle la sélection, la cadence, l’échelle et les contacts ; elle ne constitue pas une nouvelle passe de dessin uniforme. Les changements de hauteur dus à la flexion ou à la réception sont conservés.

## Traçabilité des reprises

Les premières captures ont permis de corriger : le budget du lanceur, les trajets interdits à Percée, le branchement de déplacement manquant dans le démarrage Studio, la lecture de `failed` absent sur les rapports de succès, puis l’ancien test de durée fixe par case. Ces essais interrompus ou en échec ne sont pas des preuves de validation finale.

Le rapport `133204` valide la version avant correction de cadence. La preuve finale de cadence est `133701`. Après cette capture, le champ de diagnostic `landing_duration_seconds` a été aligné sur les 0,30 s réellement jouées (l’ancien champ hérité affichait 0,08 s) et le code du banc a été reformaté sans modification du comportement. Les suites Cartes/natives et le parcours complet portent sur cette version finale.
