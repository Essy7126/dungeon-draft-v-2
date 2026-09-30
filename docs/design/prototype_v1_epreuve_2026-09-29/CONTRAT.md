# Contrat proposé après épreuve du Prototype v1

29 septembre 2026. **Propositions de conception, pas règles déjà installées.**
Le contrat actif reste `docs/current/prototype_v1.md`. Les propositions chiffrées
sont dans [candidats.json](candidats.json) ; aucune n'est chargée par la run.

## 1. Les axes indépendants

| Axe | Fonction | N'entraîne pas automatiquement |
|---|---|---|
| Classe | Attaque permanente, passif, spécialisation, fréquence de butin | Un élément obligatoire, une interdiction de cartes étrangères |
| Élément | Maîtrise d'une composante et, à terme, résistance de la cible | Une fonction imposée : Terre peut protéger ou attaquer, Soleil aussi |
| Nature | Direct, périodique, marque stockée, réaction, garde, soin, utilitaire | Un multiplicateur caché de classe ou de rareté |
| Canal défensif | Physique ou magique pour les dégâts | L'élément : une attaque physique peut être Eau |
| Géométrie | Portée, ligne de vue, aire, déplacement réel | Une caractéristique de puissance |
| Rareté | Disponibilité, complexité admise, puissance par copie à examiner | Un facteur de dégâts universel |
| Provenance | Carte consommée, action permanente, statut, surface, relique | L'autorisation de réamorcer tous les passifs |

Ces axes sont des données. On peut inventer un Assassin Soleil ou un Gardien Eau
sans rebaptiser leurs classes ni écrire une nouvelle formule pour chacun.

## 2. Les statistiques de personnage

Conserver pour cette itération : P lié au niveau, six maîtrises, quatre aptitudes,
PA/PM/main limités, défense physique/magique existante. Les maîtrises d'objets
sont des **points de pourcentage**, jamais des points soumis aux paliers du niveau.
Ne pas ajouter maintenant un attribut générique « puissance des effets » : il
augmenterait à la fois contrôle, durée, marque et dégâts et recréerait une stat
universelle presque incontournable.

Conserver provisoirement les paliers +3/+2/+1. Une pondération 80/20 n'est pas une
promesse de build équilibré ; c'est une composante à dominante forte. Évaluer
l'hybridation sur le répertoire réellement disponible et sur plusieurs besoins.

Afficher dans le dossier : points investis, maîtrise finale, bonus des objets,
gain du prochain point, valeur avant/après sur les copies préparées **et** l'action
permanente. Une différence arrondie nulle doit apparaître comme telle.

## 3. Proposition : l'inflexion de l'attaque permanente

Problème actuel : une classe peut investir n'importe quel élément, mais son
attaque permanente conserve un élément déterminé par sa classe. Après épuisement
des copies, certaines maîtrises offensives ne servent donc plus à cette attaque.

Proposition expérimentale : `basic_element`, un choix explicite parmi les six
éléments à la création, modifiable lors d'une correction autorisée entre combats.
Ce choix change **uniquement les poids des composantes de dégâts originales** de
l'attaque permanente, bonus conditionnel inclus : 100 % dans l'élément choisi.
Il ne modifie ni PA, portée, condition, mouvement, nature physique/magique, ni
passif. La garde Soleil du Gardien reste Soleil. Pas de sélection automatique du
meilleur élément à chaque coup, pas de menu d'élément pendant le combat.

Mode de migration envisagé : valeur absente = comportement actuel ; le prochain
passage en préparation propose l'inflexion. Une ancienne bataille conserve ses
poids jusqu'à la victoire. Il faut versionner ce changement, tester sauvegarde et
aperçu, et comparer son impact avant intégration.

Exemple au niveau 6 : Tir de rive .24P vaut 10 sans maîtrise avec P=40 ; une
inflexion Feu et 14 points Feu donnent .24×40×1.26 = 12.096, donc 12. La portée
2–4, le bonus après deux cases et l'Ancre restent ceux de l'Arpenteur. Un Gardien
Feu conserve sa frappe de contact et sa garde. On ouvre une voie, pas une classe
interchangeable.

Coût d'opportunité : un seul élément permanent, pas d'hybride gratuit sur cette
action ; la réorientation reste aux moments autorisés. La conversion du 80/20
Thaumaturge en 100 % choisi exige une comparaison explicite, car elle augmente
son rendement monoélément. Cette proposition n'est pas incluse dans les résultats
de combat joints, qui mesurent les attaques actuelles.

## 4. Un paquet d'effet explicite

Chaque composante quantitative devrait décrire :

```text
source_id, owner_id, cast_id, origin
operation, target, damage_kind, element_weights
basis (P ou dégâts réellement retirés), coefficient
scaling_policy (original / captured / derived)
trigger_permissions, condition, duration_clock, duration
stack_key, refresh_policy, per_round_cap, per_combat_cap
```

Les composantes originales appliquent leur maîtrise une seule fois. Une Marque
capture sa valeur et ses canaux à la pose ; sa libération ne réapplique pas les
maîtrises. Un soin dérivé de PV retirés applique son ratio puis les seuls bonus
de soin autorisés. Une conversion de garde déjà calculée ne réapplique ni
Protection ni les éléments d'origine.

Les distances de poussée, PM retirés, cartes piochées, portée et durée sont des
entiers utilitaires. Ils évoluent par une modification explicite de carte, pas
par `×(1 + maîtrise)`. Le soin et la garde n'interrogent pas la résistance ennemie.

Tous les effets d'un même lancer partagent `cast_id`. Une réaction ou un statut
ne crée pas un nouveau lancer de carte consommable. Les limites de classe
existantes s'appliquent une seule fois, même pour une carte à plusieurs effets.

## 5. Résistances élémentaires : une extension bornée

Le moteur actif ne fait pas encore cela : il applique une défense physique ou
magique bornée à 40 %, avec un élément de dégâts `NONE` dans l'adaptateur Cartes.

Pour les nouveaux paquets, proposition de laboratoire :

```text
raw_e = P × coefficient × poids_e × (1 + maîtrise_e + bonus_applicables)
defense_e = clamp(defense_physique_ou_magique + resistance_element_e, -0.15, 0.40)
damage = arrondi_unique(somme_e(raw_e × (1 - defense_e)))
```

La défense existante et la résistance élémentaire s'additionnent dans **un seul
plafond**, évitant deux grands multiplicateurs de réduction. Les vulnérabilités
sont autorisées jusqu'à -15 %. Une défense de base .20 et un trait Feu +.15 donnent
.35 sur le Feu, pas .20 puis .15 successivement.

Exemple : P=40, coefficient=1, Eau/Nuit 50/50, maîtrises .20/.12, défense magique
.10, résistance Eau +.15, Nuit -.10. Résolution :
`24×.75 + 22.4×1 = 40.4 → 40`. Sans trait élémentaire : `46.4×.90 → 42`.
Les poids du sort et ceux des résistances doivent rester associés jusqu'au bout ;
appliquer une résistance moyenne après fusion ferait perdre cette information.

Parade fixe : répartir la soustraction proportionnellement aux paquets positifs
avant leurs résistances, minimum zéro. Perforation : ignorer seulement la défense
physique/magique, conserver les résistances élémentaires explicitement annoncées.
Les réductions finales existantes restent appliquées à leur étape actuelle. Les
dégâts sont ensuite absorbés par la garde ; le drain utilise les PV effectivement
retirés. Pression de salle : indépendante de ces défenses.

Les bonus de classe actuellement sans élément restent des paquets sans élément,
soumis à la seule défense physique/magique ; ne pas leur attribuer arbitrairement
la couleur du dernier sort. Les réactions et la Marque utilisent leurs paquets
capturés, puis les défenses **actuelles** de la cible au moment du dégât.

Premier essai de bestiaire : un seul trait élémentaire par ennemi, une résistance
+15 et une faiblesse -10 maximum ; aucun changement de PV simultané. Afficher
ces deux valeurs avant l'attaque. Garder au moins un ennemi neutre dans chaque
groupe. Ne pas publier immédiatement une matrice de 36 interactions.

Condition de compatibilité obligatoire : avec toutes les nouvelles résistances
à zéro, retrouver exactement les résultats du moteur actif, y compris arrondis,
parade, Marque, garde et réactions. Le test des seuls dégâts directs ne suffit pas.

## 6. Résistance aux effets et rafraîchissement

Deux mécanismes différents sont proposés :

- **Appui stable** retire une case au premier déplacement forcé admissible par
  activation ennemie. L'icône s'éteint après consommation et se rallume à son
  activation. Il ne se cumule pas avec une résistance de même famille existante.
- **Peau ventilée** réduit de 25 % les dégâts de Brûlure et Saignement, sans
  réduire leur durée. Elle n'affecte ni dégâts directs, ni Marque, ni surface,
  ni Pression. Les résistances de cette famille prennent leur maximum.

Pas de jet caché « votre carte consommée échoue ». Les immunités et la protection
contre le contrôle dur déjà prévues pour les boss restent explicites. Dans le
premier essai, ne pas combiner Peau ventilée et peau élémentaire sur le même ennemi.

**Défaut de contrat actuel à trancher** : le rafraîchissement conserve séparément
le maximum de puissance et le maximum de durée. Une charge forte courte peut
ainsi emprunter la durée d'une charge faible longue. Ce n'est pas un bug prouvé
d'équilibrage avec toutes les cartes actuelles ; cela devient risqué dès que les
durées et les objets se diversifient.

Proposition : chaque application conserve un paquet entier. Pour Brûlure et
Saignement, comparer `intensité × activations restantes` avant défense ; remplacer
seulement si le nouveau total est strictement supérieur. Égalité : conserver
l'ancien paquet et sa provenance. Pour une Marque, comparer sa valeur capturée.
Le contrôle compare sa force puis sa durée, en conservant également une application
entière. Exemples : 10×1 contre 4×3 → conserver 4×3 ; 10×2 contre 4×3 → conserver
10×2. Aucun 10×3 artificiel. Limite assumée : le joueur peut préférer un gros tick
immédiat ; l'aperçu doit annoncer le résultat et permettre de renoncer au lancer.

## 7. Équipements : budget local, pas prix universel fictif

Pour l'emplacement amulette, première grille offensive proposée :

| Offre | Bonus | Compromis |
|---|---|---|
| Sceau mono actuel | +12 % à un élément | Pic le plus haut sur ce canal |
| Sceau double candidat | +8 % à chacun de deux éléments | Meilleure couverture, pic inférieur |
| Éventuel sceau universel | +6 % à tous les éléments | À tester, pas dans le catalogue candidat |

Un double ne donne pas +16 % sur un sort 50/50 : il donne +8 %. Sur une palette
composée à moitié de deux éléments, il apporte +8 % de la base couverte contre
+6 % en moyenne pour un mono +12 %. Le mono devient meilleur si sa part dépasse
2/3. Ce seuil ne compare que des effets quantitatifs couverts, pas PV, portée,
coûts, progression ou rareté.

Six doubles sont proposés pour tester la règle, pas pour décréter les seules
paires autorisées. Les neuf autres paires peuvent employer le même contrat.
Ils occupent tous le même slot ; aucune addition de six sceaux sur le personnage.

**Butin** : tirer d'abord une famille d'équipements ou un slot avec poids explicite,
puis une définition compatible. Ajouter six amulettes ne doit pas mécaniquement
raréfier les bottes. Ne pas changer simultanément la probabilité globale de trouver
un équipement : on veut isoler la distribution, pas injecter plus de puissance.

## 8. Trois ressources à équilibrer pour chaque carte

Toujours publier : rendement par PA, rendement par copie consommée, délai/risque
avant effet. Ajouter l'aire réellement atteignable et le coût de préparation.

Exemple : Estoc .55P/1PA fournit .55P par PA et par copie. Tir de relais .80P/2PA
fournit .40P par PA mais .80P par copie, à distance, avec une pioche conditionnelle.
Deux Estocs exigent deux copies **et deux tours** avec la limite d'une même famille
par tour. Déclarer Estoc strictement supérieur au seul ratio par PA serait faux.

Garde brève vaut .45P, pondérée Soleil, contre .25P pour la garde permanente, qui
n'a actuellement **aucune pondération élémentaire** dans sa définition. Protection
agit sur les deux. À P=16 sans bonus : 7 contre 4 ; avec quatre points Soleil :
8 contre 4. Ce socle neutre est une exception utile à déclarer explicitement pour
que la survie minimale ne demande pas un investissement Soleil à toutes les classes.
Le bonus de Soleil sur les gardes consommables reste, lui, un choix de build.

Une relique annonce l'événement déclencheur, l'instant de résolution, les sources
exclues, la limite et la persistance. Les trois candidates ne rendent aucune copie
consommée, ne produisent pas de boucle de PA et ne se déclenchent pas elles-mêmes.

## 9. Ordre d'intégration recommandé

1. Mesurer et afficher les valeurs exactes ; préserver les contrats d'arrondi et
   de provenance ; corriger les défauts techniques reproductibles.
2. Compléter les cartes normales, surtout l'attaque Soleil ; tester les départs
   légaux de plusieurs éléments par classe et la continuité après consommation.
3. Expérimenter l'inflexion permanente et les offres de butin ciblées, séparément.
4. Introduire les composantes multiples et les doubles sceaux, avec les services
   Studio existants ; adapter le validateur qui attend actuellement 48 cartes.
5. Ajouter les paquets élémentaires et deux traits de bestiaire, puis seulement
   les nouvelles résistances aux effets et Révélateur.

Pour chaque lot : test du moteur, aperçu identique, sauvegarde/reprise,
consommation une seule fois, amélioration, interaction avec les huit reliques,
capture Passe-rive et campagne continue à graines identiques. Le catalogue
candidat décrit les dépendances requises : une formule documentée n'est pas une
fonction déjà implémentée.
