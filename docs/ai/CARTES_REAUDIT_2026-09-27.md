# Réaudit de l'intégration Cartes

Demande : vérifier à nouveau si toute la refonte est réellement raccordée.
Base : HEAD `c6ab5a72c1789e4cc285300c9bbae9c78524fa05`, nombreuses modifications locales préexistantes, dont des travaux concurrents de sprites/VFX/Studio. Audit sans modification des règles de production.

## Résultat
- Quatre défauts confirmés : cinq mécanismes de salle non raccordés (six combats), formation C7 absente sur le trajet sondé, garde absorbant la pression, phase de Pâris non actualisée après brûlure.
- Hypothèse initiale de perte d'état des mécanismes précisée : aucune salle à mécanisme n'est montée dans la nouvelle run. La reprise des mécanismes est à traiter avec leur intégration ; ce n'est pas une reproduction de rechargement active.
- VFX : 0/50 sorts reconnus au premier passage propre, puis 50/50 au passage final après modification du catalogue par le travail concurrent. Retiré des défauts ouverts ; pas de validation visuelle exhaustive.
- Suite fraîche `20260927-131503-test-cards-30af5308` : PASS, 192 tests / 15 010 assertions, aucune erreur.
- Sondages finaux `20260927-131648-cards-live-reaudit-4c8d82d7` : douze vraies scènes, micro-scénarios pression/boss, exécution terminée sans diagnostic moteur ; `NEEDS_CHANGES`, quatre écarts.
- Deux premières exécutions affectées par l'atlas S24 pas encore importé, une tentative bloquée par le verrou. Elles ne sont pas des preuves de succès.
- HEAD et huit sources centrales vérifiés à nouveau ; les sources de gameplay auditées sont inchangées. Aucun changement de gameplay par cet audit, aucune sauvegarde personnelle utilisée.

## Fichiers et suite
[Rapport final](../audits/cards_reaudit_2026-09-27.md), harnais `tools/consumable_cards/audit_live_integration.gd/.tscn/.ps1`. L'ancien audit porte désormais un renvoi vers ces réserves.

Corriger les mécanismes et les rôles attendus dans la run existante, puis pression/phase ; contrôler les VFX ; seulement ensuite mesurer la balance des quatre classes sur plusieurs parcours. Les transitions de victoire du sondage restent des fixtures, pas une campagne gagnée. Les anciennes gates globales rouges ne sont pas réexécutées pour cet audit sans changement de moteur.
