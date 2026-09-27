# Passe-Rive : attribution aux cartes actuelles

Demande : conserver le coup de pied haut choisi, et corriger les cartes de tir qui déclenchaient une attaque de lame.

## Diagnostic et décisions

- La run actuelle produit des identifiants `cc2_*`. L'ancien fallback n'identifiait que les familles historiques : les nouvelles cartes aboutissaient à `a_ambush`.
- `passe_rive_card_bindings.gd` associe explicitement les 48 cartes et les deux actions de secours aux gestes disponibles. L'icône n'est pas utilisée comme identifiant d'animation : `n05` Trait court conserve une icône historique de dague mais doit tirer à l'arc.
- Les gestes sont partagés par sens : tir, volée, lancer de lame, frappe, entailles, sceau, feu, déplacement. Ne pas présenter ces correspondances comme 48 animations uniques.
- Huit cartes attendent un geste dédié et restent au repos pendant leur résolution : n02, n08, g01, g05, g08, l02, d01, i01. Même choix pour la garde de secours. Les téléportations conservent la posture neutre pendant le déplacement réel. La reprise S25 ajoute le crochet spectral de g04 en SE ; voir `PASSE_RIVE_PULL_S25_2026-09-27.md` pour son état et ses propres vérifications.
- Le coup haut initial est conservé sans retouche de pixels : SHA-256 `5cf34d3bf662489c6efe183bedec695604174909c0d5790613376c302eb35d02`. Il sert à n04, g03, g06 en SE. Les sept autres directions restent explicitement en attente ; pas de miroir trompeur.
- Les recettes VFX reconnaissent les mêmes cartes actuelles, tout en gardant leur véritable identifiant, cible et règles. Elles réutilisent les effets existants ; cette tâche ne constitue pas une production de 48 effets uniques.

## Fichiers

- `characters/achilles/2d/passe_rive_card_bindings.gd`, `passe_rive_s19_catalog.gd`, `passe_rive_s19_backend.gd`.
- `assets/characters/PasseRive/sprites_s24/kick_high.png` et `.json` ; ancien backend S24 devenu compatibilité avec le backend de production.
- `vfx/class_cards/class_card_vfx_catalog.gd`, `class_card_vfx_router.gd`, `passe_rive_heel_contact.gd`.
- Tests `test_passe_rive_s19.gd`, `test_class_card_vfx.gd`, `test_passe_rive_s24.gd`.
- Banc `tools/class_card_vfx/passe_rive_assignments.tscn` : 14 vraies demandes cc2 dans Battle lors des captures ci-dessous, puis ajout de g04 pour S25, avec main/cibles réinitialisées et IA suspendue. Ce banc n'est pas une traversée complète du menu public.

## Vérification

Backend : 13 tests / 2 847 assertions PASS dans `artifacts/dev/20260927-131256-test-test_unit_test_passe_rive_s19.gd-c6f4e5dd`.

- Suite Cartes : **193 tests, 15 516 assertions PASS**, sans erreur, `artifacts/dev/20260927-132458-test-cards-63a75e37`.
- Après l'ajustement des recettes eau/soin : **34 tests, 3 551 assertions PASS**, `artifacts/dev/20260927-133242-test-test_unit_test_class_card_vfx.gd-77e99d95`.
- Coup haut dans le backend de production : **3 tests, 45 assertions PASS**, `artifacts/dev/20260927-133406-test-test_unit_test_passe_rive_s24.gd-0430f9a6`.
- Première capture réelle : **14 lancers, 274 contrôles PASS, 125 captures**, `artifacts/dev/passe-rive-assignments-20260927-133105`. Chaque carte consomme sa vraie copie/coût, émet une seule libération avec le geste attendu et revient au repos. La marche et la téléportation restent distinctes.
- La capture finale `artifacts/dev/passe-rive-assignments-20260927-133519` nettoie aussi les états et surfaces entre essais : **14 lancers, 274 contrôles PASS, 125 captures**, aucune erreur moteur. Son champ hérité `card_count=112` décrit le catalogue historique du banc, pas la couverture actuelle : les 14 identifiants effectivement testés figurent dans `casts`. L'exhaustivité des 48 cartes et deux secours est vérifiée par les tests unitaires.
- Inspection des captures : arc sur Trait court, arc levé sur Volée croisée, lancer de lame sur Pointe franche, incantation de feu sur Braise tenace, pied haut sur Heurt et repos natif sur Garde brève. Les effets réutilisent l'art existant ; leur finesse et les animations manquantes restent un travail artistique distinct de l'attribution.

Pour revoir les cartes : `./tools/class_card_vfx/play_passe_rive_assignments.ps1` ; ajouter `-Capture` pour le scénario automatique.

Le dépôt contient des changements d'autres tâches, notamment sur les règles Cartes. Les préserver ; ne pas attribuer leurs validations ou leurs défauts à cette correction graphique.
