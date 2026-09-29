# Validation S30 — Seconde aurore et Grâce du bronze

28 septembre 2026. **109 tests distincts, 16,269 assertions, huit lancers réels et 226 contrôles runtime : PASS.**

## Rapports actuels

| Périmètre | Tests | Assertions | Rapport strict |
| --- | ---: | ---: | --- |
| Passe-Rive | 56 | 6097 | [20260928-214415-test-passe-rive-1fc6cd0c](../../../artifacts/dev/20260928-214415-test-passe-rive-1fc6cd0c/gut-strict-report.json) |
| VFX partagés | 34 | 3551 | [20260928-214541-test-test_unit_test_class_card_vfx.gd-e18d0479](../../../artifacts/dev/20260928-214541-test-test_unit_test_class_card_vfx.gd-e18d0479/gut-strict-report.json) |
| Animations natives | 13 | 6589 | [20260928-214640-test-test_unit_test_passe_rive_autosprite.gd-3cd28471](../../../artifacts/dev/20260928-214640-test-test_unit_test_passe_rive_autosprite.gd-3cd28471/gut-strict-report.json) |
| Récupération des sorts | 6 | 32 | [20260928-214742-test-test_unit_test_spell_visual_recovery.gd-a27340f7](../../../artifacts/dev/20260928-214742-test-test_unit_test_spell_visual_recovery.gd-a27340f7/gut-strict-report.json) |

Capture finale : [passe-rive-renew-20260928-213045](../../../artifacts/dev/passe-rive-renew-20260928-213045/report.json), 80 images enregistrées dont 49 frames de film. Aucun SCRIPT ERROR ou ERROR dans le journal final. Les douze poses du corps apparaissent dans les échantillons. Le GIF est assemblé à partir des captures du moteur avec leur temps mesuré (arrondi GIF cumulé : 1 ms), sans retouche du personnage.

## Cas vérifiés en combat

| Carte | Variante | PV rendus | Garde ajoutée | Fin automatique du tour |
| --- | --- | ---: | ---: | --- |
| i01 | base | 66 | 18 | 1 |
| i01 | upgraded | 83 | 18 | 1 |
| i01 | full_hp | 0 | 18 | 1 |
| i01 | guard_cap | 66 | 0 | 1 |
| l02 | base | 27 | 9 | 0 |
| l02 | upgraded | 32 | 9 | 0 |
| l02 | full_hp | 0 | 9 | 0 |
| l02 | guard_cap | 27 | 0 | 0 |

Ces nombres correspondent au personnage de la fixture (110 PV max et 18 P), pas à des constantes de gameplay. La variante améliorée de Seconde aurore rend 83 PV selon l'arrondi du moteur. Chaque carte consomme sa copie ; le soin et la garde correspondent au rapport réel, avec leurs plafonds. Aucun effet de soin confirmé à PV pleins, aucune nouvelle facette au plafond de garde. Un lancement sans PA est refusé sans animation, aura ni consommation.

Seconde aurore consomme l'activation, vide ses PA/PM restants et fait avancer la file une seule fois, après le retour à l'idle natif. Grâce du bronze coûte 2 PA et conserve l'activation. Les VFX n'ajoutent aucune résolution. La fixture emploie le vrai Battle et le runtime Cartes ; seule l'écriture du checkpoint est remplacée par un succès local, la main est préparée et l'IA ennemie reste en pause.

## Contrats du lecteur et revue visuelle

- Base/améliorée, deux cartes, huit orientations : un seul marqueur, orientation conservée, nettoyage à la fin.
- Trois tailles de profil : échelle constante, ancrage du pied constant ; le volume du VFX ne modifie jamais la taille du corps.
- Résultat absent, mauvais identifiant ou confirmation répétée : pas de faux soin/garde ; soin et garde indépendants.
- Annulation avant/après résolution, changement de mode, mort, autre sort et arrêt : pas d'aura résiduelle ni de marqueur tardif.
- Pic de lumière recalé sur chaque paume SE ; test des extrémités et de l'ordre des couches au-dessus du terrain.
- Capture examinée : repos, préparation, pleine ouverture, retombée, Grâce du bronze et PV pleins. Palette et hauteur cohérentes, masque et mains visibles, traînées non coupées. Le dessin reste plus net que l'idle natif à ce zoom ; petites différences de forme de capuche possibles.
- Nouveau corps SE uniquement. Les autres directions gardent leur incantation existante et les VFX de restauration ; elles ne sont pas annoncées comme huit nouvelles animations dessinées.
- Trois nouveaux scripts formatés avec `--verify-structure`, contrôle de format et `git diff --check` sur les fichiers suivis concernés. Les changements parallèles du routeur et du jeu sont préservés.

## Diagnostics corrigés, conservés comme historique

- `20260928-211550-test-passe-rive-8cf32220` : échec de typage au premier import, zéro test ; corrigé par un bool explicite dans le routeur.
- `20260928-211926-test-passe-rive-79bc7953` : première suite de 54 tests / 6 084 assertions PASS, antérieure aux deux contrôles ajoutés après la revue visuelle. Non additionnée au total final.
- `passe-rive-renew-20260928-212148` : premier lancement valide, fixture ne rouvrant pas sa main après la fin d'activation ; relance de `start_turn` et arrêt propre en cas de refus. Capture révélant aussi des VFX derrière les dalles : ordre des enfants corrigé sans z négatif.
- `passe-rive-renew-20260928-212656` : huit mécaniques correctes mais contrôle de doublon déclenché par l'effet de garde créé durant la préparation du cas plafond. Nettoyage des effets de fixture avant le lancement ; aucun affaiblissement du contrôle sur les effets produits par la carte.
- Le formateur a rejeté deux expressions ternaires trop longues : extraction de la variable de métadonnées, puis vérification structurelle réussie. Le candidat temporaire dans le workspace n'est pas un script runtime.

Sources et prompts : [README](README.md). [Planche](review/raccord_en_jeu.png), [GIF](review/seconde_aurore_en_jeu.gif) et [provenance](review/provenance.json).
