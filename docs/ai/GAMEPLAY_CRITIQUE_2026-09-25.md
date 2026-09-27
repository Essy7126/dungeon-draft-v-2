# Audit critique des propositions de gameplay — 25 septembre 2026

## Périmètre et état

- Demande : examiner les dernières idées, les critiquer, comparer et proposer des alternatives chiffrées.
- Base Git lue : `c6ab5a72`. Arbre déjà modifié par d'autres travaux ; aucun fichier de gameplay existant à modifier.
- Corpus prioritaire : `consumable_v1`, applications Catabase des études StS/Wakfu, `spell_comparison_2026-09-25`, laboratoire économique.
- Distinguer le produit Godot, le modèle V1 et les propositions ultérieures non implémentées.

## Décisions

- Réévaluer les propositions récentes ; ne pas simplement reproduire leurs conclusions.
- Produire une note critique et des calculs reproductibles indépendants, avec hypothèses explicites.
- Conserver les détails exécutés dans `artifacts/dev/gameplay-critique-2026-09-25/`.

## Livraison terminée

- Rapport : `docs/design/gameplay_critique_2026-09-25/README.md`.
- Calculs : `calculs.mjs`, instantané `RESULTATS.json` ; contrôle par `verify.mjs`.
- Sensibilité du Gardien : `policy_probe.mjs`, `EXPERIENCE_GARDIEN.json` ; 20 graines appariées, 40 runs terminées.
- Sources V1 et fichiers de gameplay inchangés. Aucun commit ou push.

## Constats principaux

- Continuité d'une famille normale jouée une fois par combat : 8,46 % avec sacs seuls, 59,97 % avec un achat à chacun des cinq marchands, 99,22 % avec achat + troc, sous réserve de quinze normales à sacrifier et 40 or disponibles.
- Ouverture d'un duo de trois copies par famille en deck vingt : 33,09 %, contre 53,04 % en préparant une normale A parmi les cinq cartes.
- Recentrage ne tire qu'une carte à main pleine ; sa première amélioration n'y change rien.
- Deux propositions différentes de Répercussion ; Condensation sous-rémunère le sacrifice, sauf intérêt propre de l'extinction.
- Gardien : 19/20 victoires référence, 18/20 puissance ; 11,17 copies économisées sur les 18 paires gagnées par les deux. Pas de preuve de supériorité globale.
- Contrat des réservoirs à clarifier : puissance du héros dans le modèle, puissance de référence annoncée par le texte.

## Vérifications et suite

- Fraîcheur Git revérifiée : HEAD `c6ab5a72c1789e4cc285300c9bbae9c78524fa05` inchangé.
- 212 tests existants réussis, aucun ignoré ; livraison V1 et empreintes concordantes.
- Calculs StS : 47 scénarios / 50 assertions ; Wakfu : 15 / 15, modes `--check`.
- Nouveaux calculs : 270 assertions internes (dont normalisations), probabilités de mains contrôlées par énumération ; continuité contrôlée indépendamment par 100 000 trajectoires de ravitaillement, qui ne sont pas des combats.
- Les 40 nouvelles runs sont terminées, sortie `complete: true` et JSON présents ; ancien ensemble de 640 runs non réexécuté intégralement.
- Vérificateur de livraison de l'audit : empreintes concordantes, 12 liens locaux existants, 20 paires.
- Node v26.3.1. Aucun test humain, import ou runtime Godot ; le rapport ne les revendique pas.
- Suite proposée au lecteur : accès au plan, ouverture normale, une transformation par classe, rencontres tactiques existantes puis observation humaine. Aucune intégration gameplay demandée pour cet audit.
