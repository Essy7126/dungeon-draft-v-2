# Incantation S26 — intégration acceptée

Demande : intégrer le prototype d'incantation approuvé aux sorts du jeu.

État : intégré au profil public Passe-Rive, mode Cartes. Sept identifiants explicites (`g01`, `g08`, `l02`, `a09`, `t03`, `t06`, `t09`), normales et améliorées. Nouveau dessin SE ; incantations directionnelles existantes pour les autres angles. VFX réels des cartes conservés. Voir [source et audit](../../art/source/passe_rive_s26/README.md).

Fichiers principaux : nouveau corps `characters/achilles/2d/passe_rive_incantation_body.gd`, atlas `assets/characters/PasseRive/sprites_s26/`, branche S26 du backend S19, sept liaisons dans `passe_rive_card_bindings.gd`. Les helpers de capture acceptent désormais une liste de cartes et une préparation de fixture spécifiques ; le banc S26 garde le backend de production sans le remplacer.

Preuves : 26 tests / 3547 assertions PASS (`artifacts/dev/20260927-201232-test-passe-rive-2af44e6b`) ; 14 lancers / 362 contrôles PASS (`artifacts/dev/passe-rive-incantation-20260927-201405`). Vérification visuelle du raccord, de la suspension et de la libération.

Correction de largeur fixe X=0,80 ; aucune variation d'échelle par pose. Le source original reste intact. Différences de dessin résiduelles et sept nouvelles orientations à produire ultérieurement.

Correction hors geste strictement nécessaire au chargement partagé : annotation `bool` pour `swapped` dans `vfx/class_cards/permutation/controller.gd`. Les autres travaux concurrents de cartes, UI et VFX ont été préservés.
