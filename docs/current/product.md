# Produit courant — Catabase

Référence consolidée le 21 septembre 2026. Mettre ce document à jour quand un
comportement public change ; les rapports datés gardent leur rôle de preuve historique.

## Parcours public

Le menu propose **Classique** et **Cartes**. Les nouvelles règles de
[copies consommables](cards_v2.md) s'appliquent directement au parcours Cartes.

`ui/TitreEcran.tscn` → sélection du personnage → cinématique → Seuil des Ombres →
parcours de Catabase. En Classique, la préparation a lieu au seuil ; en Cartes,
apparence, classe, quinze copies normales et difficulté se choisissent dès la sélection.
Le seuil utilise ce deck sans refaire les choix. La reprise rejoint la sauvegarde de la variante.
Les apparences originale, peinte et Passe-rive jouent la même aventure solo.
Le refuge reste accessible depuis la sélection.

La sélection Cartes présente les apparences en galerie, un aperçu animé sur socle
et un résumé permanent du deck et de la difficulté. Les cinq étapes se revisitent
avant le départ ; Échap revient à l'étape précédente. Une composition personnalisée
est conservée lorsqu'on consulte une autre classe puis revient à la première.
La sélection Classique conserve sa fiche de caractéristiques et ses techniques,
avec des portraits d'apparence agrandis et un rappel de la préparation au seuil.

- **Classique** : six constructions personnalisables, arme, protection, deux
  techniques, relique permanente et éphémère ; mutations pendant la run.
- **Cartes** : Assassin, Gardien, Arpenteur et Thaumaturge ; quinze copies normales,
  trois au plus par famille, main complétée à cinq, deux secours hors pioche.
  Chaque copie jouée disparaît de la traversée. Aucun équipement initial.
  Six emplacements d'équipement, deux reliques distinctes, huit spécialisations.
- Les sauvegardes Classique et Cartes sont indépendantes. Les anciennes révisions
  restent restaurables ; ne pas supprimer leur code parce qu’il n’est plus proposé
  pour une nouvelle partie.

## Progression et interactions

La route comporte vingt profondeurs, douze combats et trois refuges. Le bilan de
victoire Cartes précède les décisions de niveau, caractéristiques, améliorations et
spécialisation. La sauvegarde reprend la décision restante sans répéter les gains.
Les cartes acquises rejoignent la réserve ; le joueur compose son deck entre
les combats. La réserve ne peut pas être utilisée directement pendant un combat.

Inventaire, caractéristiques et deck restent consultables pendant le combat,
avec modifications verrouillées. Le reçu de butin ne change pas après équipement,
vente ou rechargement. La carte est accessible pendant le combat.

Pour les chiffres, lire les catalogues dans `core/expedition/` et le contrat de
conception concerné, sans recopier tous leurs tableaux ici :

- [Règles actuelles Cartes](../design/cartes_refonte_v2_2026-09-26/REGLES.md).
- [Règles de classes historiques](../design/class_run_rules_v3.md).
- [Sélection et audit des cartes du 21 septembre](../design/card_catalog_and_selection_audit_2026-09-21.md).
- [Écosystème Cartes, compte rendu du 20 septembre](../ai/CARDS_ECOSYSTEM_2026-09-20.md).
- [Drops et Résonance, compte rendu du 20 septembre](../ai/CARD_DROPS_2026-09-20.md).
- [Six constructions Classique](../design/catabase_first_six_2026-09-13.md).

Les anciens trio et scénario philosophe sont accessibles seulement sur demande
explicite d’un laboratoire/test. Leur conservation est détaillée dans
[le statut du contenu](content.md).

L’état décrit ici n’est pas une déclaration de validation runtime : consulter
les rapports produits pour le commit et la modification en cours.
