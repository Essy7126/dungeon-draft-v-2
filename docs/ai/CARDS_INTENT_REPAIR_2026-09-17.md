# Reprise des intentions Cartes — 17 septembre 2026

Base : main@4e6c0201, arbre propre. Demande : corriger la variante hybride.
Référence : étude du 13 septembre, complétée par le butin acquis/réserve/revente
du 16 septembre. Les cartes et reliques expérimentales de l'étude ne sont pas
considérées comme du contenu déjà accepté ou équilibré.

Contrat retenu : deux gestes d'arme fixes, 10 manœuvres initiales, main de 4,
2 copies/famille maximum au deck, minimum 8, ouverture mélangée reproductible.
Préparation dédiée avec aperçu/composition ; décisions Cartes à la progression,
pas de copies automatiques issues des maîtrises. Objets, caractéristiques et
spécialisations permanentes conservés. Classique inchangé.

Compatibilité : validation des anciennes sauvegardes avant migration en mémoire ;
copies acquises conservées en réserve, anciens Gestes archivés hors deck ; aucun
accès en écriture à la sauvegarde réelle du joueur pendant le développement.

Mise en œuvre : `CatabaseCards` révision de règles 2, migration après validation
v1, nouveaux départs personnalisables (5 familles × 2 copies), gestes fixes via
le SpellCaster commun, choix de progression unique et persisté. Les améliorations
de famille dépensent les points de destin existants ; l'arbre reste limité aux
gestes d'arme et spécialisations permanentes. Aucun nouveau multiplicateur de rareté.
Le deck n'a pas de plafond arbitraire de 18 ; retirer exige au moins 8 cartes.
Les anciens Gestes restent archivés hors deck. Les offres de progression sont
figées à la victoire, pour empêcher un changement de deck de relancer le tirage.

Vérifications finales :

- Tests Cartes : 22/22, 579 assertions, PASS strict sans erreur moteur.
  `artifacts/dev/20260917-132723-test-test_unit_test_catabase_cards.gd-4c162ad1/`
- Stress Cartes : 7/7, 77 988 assertions, PASS strict sans erreur moteur.
  `artifacts/dev/20260917-132343-test-test_unit_test_cards_studio_audit.gd-33871236/`
- Interface : 30 captures 720p/1080p, 264 contrôles PASS. Inspection visuelle du
  départ, combat, progression et butin ; libellés et vente à 720p corrigés.
  `artifacts/catabase_run_balance_validation/cards_intent_repair_v3/`
- Simulation des six armes, seed 2401, normal, politique balanced : six exécutions
  sans erreur moteur. Une route terminée, quatre défaites du bot, un affrontement
  signalé pour examen d'équilibrage. Ce résultat ne prouve pas l'équilibrage humain.
  `artifacts/catabase_run_balance_validation/cards_intent_repair_six_weapons/`
- Suite Catabase étendue : 484 tests, 469 PASS, 15 FAIL hors tests Cartes ; résultat
  global FAIL. Les 19 tests de parcours guidé passent après restauration des deux
  initialisations r5 perdues au merge. Échecs restants : glyphes (1), art Meshy (2),
  icônes peintes (3), sélection/lancement (2), seuil (3), formations (2), inventaire
  reliques (2). Accès Nil grid_layout et ressources non libérées dans ces tests.
  Aucun masquage d'erreur ni assouplissement de CI. Pas de comparaison intégrale
  sur un checkout vierge de HEAD : leur antériorité n'est donc pas certifiée ici.
  `artifacts/dev/20260917-132029-test-catabase-7fa43c12/`
- `git diff --check` propre.

Historique : le merge 4e6c0201 conserve les 36 fichiers ajoutés par ea379158
« run deck ». Aucun fichier supprimé entre le 13 et le 17 septembre dans
l'historique examiné. Le mélange provenait du parcours partagé avec Classique.
Le profil de capture reçoit désormais un `.gdignore` afin que Godot n'importe
pas ses caches shader isolés.

Livraison locale, sans commit ni push. Relancer le jeu pour charger ces scripts.
Les anciennes sauvegardes Cartes migrent lors de leur reprise ; les tests ont
utilisé des profils isolés, sans écrire dans la sauvegarde réelle du joueur.
