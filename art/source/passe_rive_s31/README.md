# Passe-Rive — les sept gestes approuvés terminés

29 septembre 2026. Travail effectué séquentiellement : une famille intégrée, testée et revue avant la suivante. Les sept familles S24 à S30 disposent maintenant de huit orientations dans le backend public du jeu. Aucun remplacement par un autre geste ne reste pour leurs directions manquantes. Les horloges et l'attribution aux cartes restent explicites ; marche, repos désarmé et ruée natifs sont conservés.

| Geste | Cartes actuelles | Vues | Lancers réels | Revue |
|---|---|---:|---:|---|
| [Coup de pied haut](kick/README.md) | Heurt, Repousser, Choc de masse | 8 | 24 | [Aperçu](kick/review/huit_directions.gif) · [Validation](kick/VALIDATION.md) |
| [Traction](pull/README.md) | Ramener au front | 8 | 16 | [Aperçu](pull/review/huit_directions.gif) · [Validation](pull/VALIDATION.md) |
| [Incantation](incantation/README.md) | Garde ferme, Bastion vivant, Sommeil marqué, Sceau ombreux, Jardin de givre, Résonance du sceau | 8 | 96 | [Aperçu](incantation/review/huit_directions.gif) · [Validation](incantation/VALIDATION.md) |
| [Parade](guard/README.md) | Garde brève, Contre préparé, Garde de secours | 8 | 40 | [Aperçu](guard/review/huit_directions.gif) · [Validation](guard/VALIDATION.md) |
| [Prélèvement](drain/README.md) | Prélèvement | 8 | 33 | [Aperçu](drain/review/huit_directions.gif) · [Validation](drain/VALIDATION.md) |
| [Passage spectral](spectral/README.md) | Bond spectral, Au-delà du front, Permutation | 8 | 48 | [Aperçu](spectral/review/huit_directions.gif) · [Validation](spectral/VALIDATION.md) |
| [Restauration](renew/README.md) | Seconde aurore, Grâce du bronze | 8 | 64 | [Aperçu](renew/review/huit_directions.gif) · [Validation](renew/VALIDATION.md) |

Les 16 contrôles supplémentaires de Sommeil marqué portent le total à **337 lancers réels / 8,534 contrôles réussis**, répartis dans les huit rapports de `integration_audit.json`. Base et amélioration sont exercées ; les bancs ajoutent selon le geste plafonds, rejet, mort, échange de position et riposte. Le coup de pied est exercé en combat dans les quatre directions légales de mêlée ; ses huit vues sont vérifiées dans le lecteur public. Les fixtures préparent les cartes et suspendent l'IA : ce sont des combats instrumentés, pas une run intégrale depuis le menu.

## Audit final

- Suite complète renforcée : **78 tests / 22 435 assertions PASS**, rapport `artifacts/dev/20260929-014145-test-passe-rive-96a51e08/gut-strict-report.json`.
- Cinq tests d'interruption réutilisaient auparavant une instance morte : nouvelle instance par direction, mort testée en dernier, réussite du lancement et présence du corps vérifiées avant annulation. Aucun contournement du verrou de mort du runtime.
- Sources : **56 vues**, textures présentes, empreintes correspondantes, régions dans les atlas et calibration anatomique positive. Preuve `source_audit.json`, outil reproductible `tools/class_card_vfx/audit_passe_rive_directions.py`.
- Métadonnées reproductibles depuis les sources conservées. Chemin du générateur d'incantation corrigé et reproduction exacte des métadonnées validées vérifiée ; son ancien statut de prototype SE est maintenant conservé comme donnée historique, séparé de son état intégré.
- Dix scripts de la dernière étape et des tests renforcés vérifiés par le formateur ; contrôle Git des espaces réussi sur le backend et les documents/configurations modifiés.

## Cohérence et limites

Une stature de référence fixe et des repères d'appui remplacent tout ajustement d'échelle par pose. Palette rapprochée du repos natif, directions dessinées sans miroir pour ces sept familles, points de mains/talon enregistrés, raccord natif et marqueur de résolution commun à toutes les vues. Les effets de protection, soin, drain et téléportation répondent aux résultats réels du combat.

Le SE approuvé est conservé pour chaque famille. Passage spectral partage les poses corrigées de Prélèvement dans ses sept nouvelles vues, avec son montage et son voile propres. Les dessins gardent des écarts mineurs de contour, de plis et d'occlusion ; cette V1 ne prétend pas à une identité pixel parfaite entre atlases.

Recentrage (n08) et Décret du dernier souffle (d01) restent sans prototype approuvé et ne font pas partie de ce lot. Les anciens gestes S18/S20 déjà directionnels restent en place selon leur convention de cinq vues et trois miroirs.
