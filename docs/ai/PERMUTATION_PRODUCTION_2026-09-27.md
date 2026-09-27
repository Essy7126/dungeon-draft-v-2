# Permutation — production

Autorisation : « Ok lance la création de permutation ». Planche G approuvée
pour production, `cc2_r08` uniquement, run Cartes consommable actuelle.

Contrat : 2 PA, échange avec un ennemi valide à portée 1–5 (1–6 améliorée),
boss exclu, aucun dégât propre, aucun portail persistant. Géométrie originale :
deux agrafes courbes jade/ivoire, fermoir bronze, fente lumineuse courte.
Deux sites synchronisés et fixes ; fermeture avant la résolution, réouverture
uniquement si les positions ont réellement été échangées. Pas de clones ni
de trajet entre les deux cases. Le lecteur ne modifie pas les unités.

Le swap existant émet déjà deux déplacements instantanés. L'observateur VFX
capture leurs positions de départ ; le contrôleur vérifie les positions finales.
Aucun changement du moteur commun ni du déplacement. Seuls l'observation de
`r08` dans `consumable_card_modifier.gd` et les branchements dédiés du routeur
commun sont ajoutés. Les travaux concurrents et Orage sont conservés ; le
statut Git reste largement modifié par ces travaux, sans commit de cette passe.

Livré : source Blender, trois atlas originaux, documents Sprite Clip, lecteur
et contrôleur `vfx/class_cards/permutation/`, outillage et revue sous
`tools/class_card_vfx/permutation/`. Fermeture à 8/30 s, fin à 20/30 s ; la
préparation attend une confirmation réelle, puis le tri avant/arrière suit
les nouveaux occupants. Aucun portail durable, clone, trajet ou dégât ajouté.

Vérifications finales :

- Source sauvegardée : 48/48 poses RGBA reproduites à l'identique,
  `artifacts/dev/class_card_vfx/permutation/source_verification.json`.
- Studio inchangé : trois clips exportés avec correspondance des pixels,
  `artifacts/dev/class_card_vfx/permutation/workshop_report.json`.
- Tests ciblés : 18 tests, 428 assertions, PASS,
  `artifacts/dev/20260927-201621-test-test_unit_test_consumable_cards_permutation_vfx.gd-50d061ab/summary.json`.
- Capture réelle finale : 84 frames et 233 contrôles, PASS, avec commande
  publique, positions échangées, PV inchangés, consommation et reprise disque.
  Rapport : `artifacts/dev/class_card_vfx/permutation/combat/report.json`.
- Inspection visuelle : anticipation, contact et dissipation aux deux échelles,
  plus source Blender en perspective. L'aperçu est constitué des pixels Godot.

- Suite Cartes complète : 254 tests et 18 225 assertions, PASS, aucune erreur,
  `artifacts/dev/20260927-202243-test-cards-b3ff8d52/summary.json`.
- Format : cinq fichiers GDScript de cette production conformes ; vérification
  des espaces du diff routeur conforme. Les assets et lecteurs Orage sont
  identiques aux empreintes de sa capture précédente.

La capture finale a été relancée après un formatage du script de revue.
Une tentative intermédiaire avait tous ses contrôles fonctionnels valides,
mais une erreur Godot de lecture du magasin de certificats Windows ; elle est
conservée dans `artifacts/dev/class_card_vfx/permutation/capture_certificate_error/`.
La capture finale, exécutée avec accès local autorisé, termine sans erreur
moteur et avec empreintes des sources stables. Aucun contrôle n'a été ignoré.
Le manifeste de capture et le rapport d'encodage sont dans `combat/` ; la
synthèse est `artifacts/dev/class_card_vfx/permutation/final_validation.json`.

Limites : revue sur placements de fixture à portée quatre, PV normaux ; les
victoires de préparation et le bilan sont forcés par le scénario. Ce n'est pas
un test d'équilibrage ni une certification de toutes les caméras et apparences.
Aucun son dédié produit. Le pilote interactif conserve l'audio normal du jeu.
