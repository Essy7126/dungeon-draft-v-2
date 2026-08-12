# Expérience gameplay Achilles

Statut : **EXPERIMENTAL_WEB_POC**. Toutes les valeurs, ennemis, cartes et récompenses de cette slice sont provisoires et ne doivent pas être promus comme baseline de production.

## Hypothèse testée

Achilles joue seul avec 100 PV, 10 armure, 6 PA et 3 PM. Quatre actions à 2 PA créent une séquence lisible par un unique tag `lastActionTag`. Ce tag n’est pas une ressource : aucune jauge, aucun cumul, aucune charge, aucune conservation et aucun coût associé. Il est remis à `NONE` à chaque activation.

Le mécanisme de liaison STEP → Estoc/Garde, SPEAR → Heurt et SHIELD → Traversée n’est pas validé. Il cherche seulement à donner un rythme positionnement/frappe/poussée/défense sans énergie, Élan, rage, combo ou télégraphie ennemie.

## Objectifs de playtest

- vérifier que les quatre capacités trouvent un usage distinct ;
- mesurer si la liaison est comprise sans être prise pour une jauge ;
- observer le coût d’opportunité des 6 PA et 3 PM ;
- vérifier la lisibilité des collisions, boucliers et ripostes ;
- mesurer l’attrition sur cinq salles et la valeur du soin inter-salles ;
- comparer les douze récompenses et détecter les choix dominants ;
- confirmer que l’absence d’intention future ennemie reste équitable avec l’état actuel visible.

## Métriques

Le rapport suit rounds, salle atteinte, PV restants, dégâts infligés/subis, PA/PM dépensés ou perdus, usage des capacités, récompenses, commandes et hashes. La simulation agrège win rate, P50/P90 rounds, morts par salle et taux de sélection.

## Questions ouvertes

- La cible humaine de 20–30 minutes est-elle réaliste ?
- Achilles survit-il assez pour que le build se révèle avant le boss ?
- Traversée sans cible est-elle utile ou brouille-t-elle son identité ?
- Le tag précédent est-il toujours perceptible sans devenir une ressource visuelle ?
- L’Archer et les renforts restent-ils lisibles sans afficher leurs décisions futures ?

Les résultats du bot heuristique V1 ne répondent pas à ces questions et ne remplacent pas un playtest humain.
