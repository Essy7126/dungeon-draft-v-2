# Charon — suivi du prototype

Autorisation utilisateur : prototype jouable de Charon avant intégration à la run.
Référence initiale 9af4a96a ; cinq audits de recherche déjà présents, conservés.

Décision : laboratoire Godot séparé dans tools/charon_workshop, utilisant les
services Studio et le moteur réel pour grille, cartes, passifs, dégâts et états.
Aucune mutation des sauvegardes ni de la route publique. Présentation schématique.
Quatre classes, statistiques contrôlées, pioche reproductible.

Règles précisées : télégraphe fixe, traversée préparée/résolue sur deux activations,
rotation d'une borne une seule fois par préparation, paiement atomique ; herse
annule et inflige 35 ; déplacement du boss interrompt sa traversée. Victoire à sa mort.

Fichiers : profil de réglage, contrôleur, grille UI, scène/laboratoire et README ;
test/unit/test_catabase_monster_charon_prototype.gd.

Validation : le premier appel dans le bac à sable avait échoué avant GUT (zéro
test, certificats Windows et dossiers temporaires). Les relances autorisées hors
bac à sable utilisent le même harnais, sans assouplir ses critères.

- `./dev.ps1 test monsters` : PASS, 92 tests, 17 925 assertions, aucun échec
  ni erreur. Rapport : `artifacts/dev/20260922-123040-test-monsters-ca906af5/gut-strict-report.json`.
- Capture réelle inspectée en 1280 × 720 :
  `artifacts/dev/20260922-123446-charon-capture-1280x720-1af5b23c/charon.png`.
  Moteur terminé avec code 0, stderr vide. Plateau, cartes et commandes lisibles ;
  panneau droit défilant. Une première capture 1200 × 896 a aussi été inspectée.
- Quatre parcours automatisés, graine 42 : Assassin 9 tours/136 PV, Gardien
  9 tours/188 PV, Arpenteur 8 tours/164 PV, Thaumaturge 9 tours/134 PV.
  Ce ne sont pas des parties humaines ni une preuve d'équilibrage.
- `./dev.ps1 test cards` : FAIL, 76/77 tests réussis, 6 886 assertions.
  Échec de `test_every_live_card_and_crest_has_distinct_painted_art` sur les
  silhouettes des illustrations existantes, déjà relevé dans l'audit précédent.
  Aucun fichier d'illustration ou du catalogue commun modifié ici.
  Rapport : `artifacts/dev/20260922-123529-test-cards-39d64be3/gut-strict-report.json`.
- `./dev.ps1 test test/unit/test_catabase_monster_charon_prototype.gd` après les
  dernières corrections UI : PASS, 15 tests, 137 assertions, aucun échec ni erreur.
  Rapport : `artifacts/dev/20260922-124245-test-test_unit_test_catabase_monster_charon_prototype.gd-ec022d6c/gut-strict-report.json`.
  Import moteur réussi. Format des scripts vérifié avec `./dev.ps1 format` ciblé.
- Capture finale 1200 × 896 inspectée après ces corrections :
  `artifacts/dev/20260922-124358-charon-capture-final-1200x896-fc78b8c3/charon.png`.
  Moteur terminé avec code 0, stderr vide ; journal, main et commandes lisibles.

Corrections issues des vérifications : retirer le cadavre du Porteur de la grille
pour permettre le ramassage ; ne pas supposer l'ordre d'une main mélangée dans
les tests ; ajouter les gestes hors deck ; signaler l'interruption de traversée
après déplacement du boss. Aucun fichier de production commun modifié.

Suite : essais humains
sur les trois réponses (esquive, déplacement, bornes) et réglage de difficulté.
Le profil actuel est permissif ; pas encore d'intégration avant Pâris, de drops,
d'équipement ou de progression de niveau dans ce laboratoire.
