# Cartes et survol — 20 septembre 2026

Demande : icônes lisibles, portées visibles, fiche au survol avec explications
des effets sans gêner la sélection. Préserver le travail précédent non commité.

Choix : barre de 202 px au lieu de 258 px, icône + PA + PO ; fiche passive
après 220 ms au-dessus de la main, sans capture de souris ni prise de focus.
Même fiche dans le deck. Portées obtenues via SpellCaster, effets de classes
expliqués sans les confondre avec les statuts génériques du glossaire.

Fichiers : `ui/expedition/spell_hover_card.gd`, `catabase_card_hand.gd`,
`catabase_card_text.gd`, `class_card_tile.gd`, `class_card_presentation.gd`,
`class_workshop.gd`. Icônes et cadres existants réutilisés. Aucun changement
de coût, de dégâts ou de règles de combat.

Corrections issues des contrôles : réduire la taille réelle de la fiche après
la mise en page du texte ; résoudre le ScrollContainer seulement après l'entrée
de la carte dans l'arbre ; supprimer l'ancienne infobulle native de la tuile,
qui pouvait se superposer à la fiche passive malgré un tooltip_text vide.

Tests stricts : 15 tests, 300 assertions, PASS.
- `artifacts/dev/20260920-124322-test-test_unit_test_spell_hover_card.gd-23b4adf9/summary.json`
  : 4 tests / 204 assertions ; 60 cartes, portées avec bonus, survol temporisé,
  fermeture, absence de capture du pointeur, cycle de création de la grille.
- `artifacts/dev/20260920-123551-test-test_unit_test_recraft_combat_hud_v1.gd-1117b9f0/summary.json`
  : 11 tests / 96 assertions sur le HUD commun.

Validation visuelle finale : PASS, 334 contrôles et 48 captures à 1280×720
et 1920×1080 dans `artifacts/dev/card-hover-release/report.json`.
Captures de survol combat et deck inspectées ; plus de double infobulle,
grille et barre dégagées, aucun SCRIPT ERROR dans le journal final.
Le scénario vérifie le pointeur et le clic réels, le lancement d'une carte,
le ciblage puis un tour ennemi ; les victoires suivantes sont injectées pour
contrôler les transitions de fenêtres. Ce scénario ne mesure pas l'équilibrage.
