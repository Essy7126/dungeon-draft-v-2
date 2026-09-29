# Prototype v1 — progression de Catabase Cartes

Cette configuration utilise la run publique Cartes, sa route de vingt profondeurs,
ses douze combats, sa sélection et sa sauvegarde. Les nombres constituent le premier
prototype jouable ; leur validation technique ne vaut pas validation d'équilibrage.

## Monter son personnage

| Moment | Décision |
|---|---|
| Création, récapitulatif | Classe, 15 copies normales, 4 points élémentaires |
| Niveaux 2 à 12 | 2 points élémentaires supplémentaires par niveau |
| Niveaux 3, 6, 9 | 1 point d'aptitude, séparé des éléments |
| Niveau 4 | 1 spécialisation parmi les deux de sa classe |
| Niveaux 4, 8, 12 | 1 emplacement de perfectionnement de sort |

Les onze premières victoires donnent chacune un niveau, donc le niveau 12 précède
le boss. Le budget final est de 26 points élémentaires, 3 aptitudes et
3 perfectionnements. Les points non dépensés sont conservés. Le dossier propose
un brouillon, un aperçu sur les sorts possédés puis une validation atomique ;
les valeurs ne changent pas pendant le combat. Pas de nouveaux PA, PM ou slots de main par niveau.

Terre, Eau, Feu, Vent, Nuit et Soleil sont accessibles à toutes les classes.
Chaque point coûte un point de progression : +3 points de pourcentage de maîtrise
pour chacun des quatre premiers, +2 pour les quatre suivants, +1 ensuite.
Ainsi 4/8/13/26 points donnent respectivement +12/+20/+25/+38 %.
Les bonus d'équipement s'ajoutent ensuite. Six sceaux de +12 % de maîtrise,
occupant l'emplacement amulette, rejoignent le catalogue d'équipement existant.

Les aptitudes ont trois rangs maximum chacune : Vitalité +8 % de PV de base,
Protection +10 % de garde créée, Contact +6 % de dégâts directs à une case,
Distance +6 % de dégâts directs à trois cases ou plus. À deux cases, ni Contact
ni Distance ne s'applique. Elles ne majorent pas une seconde fois les dégâts différés.

Un perfectionnement affecte toutes les copies actuelles et futures du sort tant
qu'il est équipé. Il faut posséder une copie pour l'attribuer ; le libérer est
gratuit entre combats et ne restitue aucune carte consommée.

## Attaques permanentes

| Classe | Attaque, 1 PA, une utilisation par tour | Éléments |
|---|---|---|
| Assassin | Pointe d'ombre : 28 % de P, +12 % de P sur une cible marquée, portée 1 | Nuit |
| Gardien | Frappe du rempart : 25 % de P, puis garde de 12 % de P, portée 1 | Dégâts Terre ; garde Soleil |
| Arpenteur | Tir de rive : 24 % de P, +8 % de P après 2 cases parcourues, portée 2–4 | Vent |
| Thaumaturge | Étincelle du Léthé : 22 % de P magiques, portée 1–3 | 80 % Eau, 20 % Nuit |

Ces actions ne consomment aucune copie. Elles ne consomment pas la Marque et ne
déclenchent pas les bonus réservés aux sorts consommables. Les passifs et les huit
spécialisations existantes restent actifs. La garde de secours commune est conservée.

## Calcul des effets

La Puissance de base aux niveaux 1–12 vaut
`16, 20, 23, 28, 34, 40, 47, 57, 66, 82, 86, 93`.
La courbe de PV reste inchangée : 110 au niveau 1, 675 au niveau 12.
La courbe historique du catalogue reste la référence des ennemis et des combats
anciens en cours ; le nouveau calcul concerne le personnage.

Chaque composante originale porte ses propres poids élémentaires, de somme 100 %.
Le facteur est `1 + somme(poids × maîtrise) + bonus applicables`.
Une carte mêlant dégâts et garde peut donc avoir deux répartitions différentes.
Les bonus sont additionnés avant application ; les valeurs restent réelles jusqu'à
l'arrondi final. Déplacement, pioche, portée, durée et taux de drain restent fixes.

Exemple : Onde du Léthé, 45 % de P, 80 % Eau / 20 % Nuit. Avec P = 100,
13 points dans chaque élément, +10 % dégâts d'équipement et deux rangs de Contact,
elle produit `45 × (1 + 0,25 + 0,10 + 0,12) = 66,15` avant défenses/arrondi.

La garde sacrifiée est déjà calculée : sa conversion en dégâts n'applique pas
une seconde maîtrise. Le drain part des PV réellement retirés puis applique son
taux et le bonus de soin. Brûlures, saignements, marques et surfaces stockent leur
valeur offensive à la création ; les défenses de la cible s'appliquent à la résolution.
Les utilitaires sans composante chiffrée élémentaire restent neutres.

## Corriger ses choix et reprendre sa partie

- Avant le premier combat : redistribution libre.
- À chaque halte (profondeurs 4, 7, 9, 11, 14, 16, 18, 19) : déplacer au plus
  deux points élémentaires, en une validation pour cette visite. Un rechargement
  ne restitue pas ce droit. Dépenser de nouveaux points n'utilise pas ce droit.
- Une fois à partir du niveau 8, aux refuges 11, 16 ou 19 : remboursement complet
  des maîtrises et aptitudes, choix de spécialisation libéré, classe conservée.
- Changer Vitalité, équipement ou répartition conserve le ratio de PV non arrondi.
  La montée de niveau applique une seule fois le gain de maximum aux PV actuels.

`prototype_revision = 1` est interne au profil existant ; ni identifiant de run ni
chemin de sauvegarde parallèle. Les anciennes sauvegardes consommables sont validées
avec leurs statistiques et PV historiques, puis migrées hors combat. Un combat actif
garde ses valeurs jusqu'à la victoire. Les anciens attributs sont remboursés ;
l'inventaire, les copies consommées, les niveaux, l'XP et les reçus restent conservés.

## Points d'entrée et validation

Règles : `core/expedition/consumable_progression_v1.gd` ; calcul :
`consumable_card_math.gd` ; sauvegarde/transactions : `consumable_cards_state.gd`,
`consumable_cards_integration.gd`, `expedition_save_service.gd` ; édition :
`ui/expedition/consumable_progression_editor.gd` ; contenu :
`data/cards/consumable_v2/catalog.json` et les ressources publiées via le Studio.

Les tests `test_consumable_cards_prototype_v1.gd` et
`test_consumable_cards_integration.gd` couvrent les calculs, la migration,
les droits de réorientation et le parcours public. Les exécutions et limites
sont consignées dans le [suivi d'intégration](../ai/PROTOTYPE_V1_INTEGRATION_2026-09-29.md).
