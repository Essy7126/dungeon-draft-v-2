# Produit courant — Catabase

Référence consolidée le 21 septembre 2026. Mettre ce document à jour quand un
comportement public change ; les rapports datés gardent leur rôle de preuve historique.

## Parcours public

`ui/TitreEcran.tscn` → sélection d’Achille → cinématique → Seuil des Ombres →
préparation → parcours de Catabase. La reprise rejoint la sauvegarde de la variante.
Les apparences originale, peinte et Passe-rive jouent la même aventure solo.
Le refuge reste accessible depuis la sélection.

- **Classique** : six constructions personnalisables, arme, protection, deux
  techniques, relique permanente et éphémère ; mutations pendant la run.
- **Cartes** : Assassin, Gardien, Arpenteur et Thaumaturge. Cinq techniques choisies
  parmi sept cartes d’initiation, deux copies chacune ; dix cartes au départ,
  quatre en main, deux gestes de secours hors pioche, aucun équipement initial.
- Les sauvegardes Classique et Cartes sont indépendantes. Les anciennes révisions
  restent restaurables ; ne pas supprimer leur code parce qu’il n’est plus proposé
  pour une nouvelle partie.

## Progression et interactions

La route comporte vingt profondeurs, douze combats et trois refuges. Le bilan de
victoire Cartes précède les décisions de niveau, caractéristiques, maîtrises et
spécialisation. La sauvegarde reprend la décision restante sans répéter les gains.
Les cartes acquises rejoignent la réserve ; le joueur compose son deck entre
les combats. L’initiation ne tombe pas en butin.

Inventaire, caractéristiques et deck restent consultables pendant le combat,
avec modifications verrouillées. Le reçu de butin ne change pas après équipement,
vente ou rechargement. La carte est accessible pendant le combat.

Pour les chiffres, lire les catalogues dans `core/expedition/` et le contrat de
conception concerné, sans recopier tous leurs tableaux ici :

- [Règles de classes](../design/class_run_rules_v3.md).
- [Écosystème Cartes, compte rendu du 20 septembre](../ai/CARDS_ECOSYSTEM_2026-09-20.md).
- [Drops et Résonance, compte rendu du 20 septembre](../ai/CARD_DROPS_2026-09-20.md).
- [Six constructions Classique](../design/catabase_first_six_2026-09-13.md).

Les anciens trio et scénario philosophe sont accessibles seulement sur demande
explicite d’un laboratoire/test. Leur conservation est détaillée dans
[le statut du contenu](content.md).

L’état décrit ici n’est pas une déclaration de validation runtime : consulter
les rapports produits pour le commit et la modification en cours.
