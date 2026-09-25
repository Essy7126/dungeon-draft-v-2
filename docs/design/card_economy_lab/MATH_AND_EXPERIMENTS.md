# Cahier de calcul et d'expérimentation

## A. Ligne de drop

Écrire toute ligne sous la forme :

`source_id ; progression_id ; channel_id ; probability ; bag_size ; tier ; eligible_pool ; max_receipts`

Exemple conceptuel : `mob_02 ; fight_08 ; normal_b ; 0.25 ; 3 ; normal ; catalog_normal ; 1`.

La ligne s'ajoute aux autres lignes indépendantes ; elle ne les remplace pas. La réserve reçoit les cartes au bilan prévu. Le droit de tirage reste unique même si le mob est ressuscité. Le rang du sac est fixé au drop et son contenu ne dépend pas du moment où on clique pour l'ouvrir.

Pour des sacs de trois cartes, un succès donne trois unités corrélées. Ne pas remplacer dans un simulateur un jet de 55 % pour trois cartes par trois jets de 55 % : la moyenne reste 1,65, mais la variance passe de 2,2275 à 0,7425. Les queues de distribution seraient très différentes.

## B. Quantité par combat versus quantité par run

`stock_apres_combat = stock_avant − cartes_jouees + drops_utilisables`

Le stock doit pouvoir payer les cartes AVANT de recevoir le drop. Les achats de la halte suivante ne financent pas rétroactivement le combat. Pour un deck limité à trente, la réserve hors combat n'est pas disponible pour payer une trente-et-unième utilisation pendant la rencontre.

Le calcul global `stock_initial + tous_les_drops − toutes_les_depenses` ne détecte donc pas les pénuries temporaires. Le calcul exact du script propage une distribution de stocks et retire la masse impossible à chaque combat, avant d'ajouter les distributions de butin.

## C. Utilité et compatibilité

Définir séparément :

1. Compatibilité réglementaire : classe, maîtrise, restrictions.
2. Cohérence : interactions avec les autres cartes et passifs.
3. Accessibilité : présence dans le deck puis en main au bon moment.
4. Utilité situationnelle : cible valide, distance, coût en PA, état du terrain.

Le stress test 70 % ne couvre que la première, avec des rejets indépendants par carte. Pour une prochaine version, comparer également un rejet au niveau du sac : une collection incompatible peut rendre trois cartes inutiles ensemble. Ne pas traiter les deux variantes comme statistiquement équivalentes.

Mesure proposée : `taux_utile = exemplaires intégrés ou joués / exemplaires acquis`, segmenté par famille et palier. Ce taux ne doit pas servir directement à adapter secrètement le drop ; il sert d'abord au diagnostic du catalogue.

## D. Rareté et taille de catalogue

Rang exceptionnel : p très petit, peu de tentatives dans douze combats. Pour la table Airain, P(immortelle) ≈ 0,001399 par run complète exposée aux mêmes drops. Le nombre moyen de runs jusqu'à la première est 1/P ≈ 715 ; la médiane est `ceil(log(0.5)/log(1−P))` ≈ 496. La moitié des joueurs pourrait donc encore ne rien voir après plusieurs centaines de runs comparables. Les abandons précoces réduiraient encore l'exposition.

La chance de voir une carte précise décroît avec la taille de son catalogue. Avant d'ajouter cinquante références rares, recalculer le temps d'accès à une carte nommée. Le nombre de cartes du catalogue est lui-même un paramètre d'économie.

Ne pas appeler une carte « build central » si elle exige une immortelle que la plupart des joueurs ne verront pas. Les rangs extrêmes peuvent offrir une histoire mémorable, mais la profondeur ordinaire doit venir des normales, élites, passifs et interactions de terrain.

## E. Prix et absence de boucle profitable

Pour chaque transaction, comptabiliser le vecteur `delta_oboles, delta_normales, delta_elites, ...` et les exemplaires uniques consommés. Un prix de revente inférieur au prix d'achat exclut uniquement la boucle directe.

Cas à vérifier lors de l'implémentation : achat avec remise → compression → vente ; achat → contrat → vente ; vente → annulation après troc ; ouverture d'un sac → annulation de son achat ; rechargement avant réception d'une commande. Les stocks et contrats limités font partie des contraintes, pas seulement le prix.

Une fonction de valeur de liquidation V permet une preuve simple lorsque TOUTES les opérations répétables font décroître V. Les récompenses de combat et contrats ponctuels peuvent l'augmenter mais doivent avoir un reçu consommable une seule fois. Le modèle livré ne simule que les achats de ravitaillement : il n'est pas une preuve générale d'absence d'arbitrage.

## F. Atelier d'écriture de cartes

Pour chaque ligne de cards.csv, compléter après test : coût de remplacement, rendement par PA, rendement par exemplaire, risque d'être inutilisable, rôle, synergies, contre-jeu, état à sauvegarder, interaction avec la défausse.

Questions de revue :

- Pourquoi jouer cette normale après le huitième combat ?
- Pourquoi dépenser maintenant cette rare plutôt que l'épargner toujours ?
- La carte remplace-t-elle strictement une autre au même prix et même disponibilité ?
- Un effet de pioche, recherche ou copie peut-il produire une carte réellement nouvelle ?
- Quel est le pire cas si trois copies sont préparées ?
- L'effet s'explique-t-il sans trois règles supplémentaires ?

L'exemple d'Estoc a 0,45P pour 1 PA : rendement 0,45P/PA, alors qu'une frappe d'arme à 0,55P pour 2 PA vaut 0,275P/PA. La carte paie sa consommation par un gain d'efficacité, mais son impact individuel reste faible. Ce calcul ignore armure, passifs et portée : c'est une ligne de raisonnement, pas un résultat de combat.

## G. Plan des expériences suivantes

| Expérience | Variable changée | À garder fixe | Mesure principale |
|---|---|---|---|
| Départ A/B | Chances des sacs normaux aux combats 1–3 | Autres rangs et dépenses | Pénurie avant combat 5 |
| Compatibilité | 100 %, 85 %, 70 %, rejets par carte ou sac | Chances de sac | Stock réellement jouable |
| Taille de sac | 2/3/4 à espérance totale comparable | Catalogue | Variance et sécheresses |
| Dépense | Profils empiriques par classe | Tables et route | Quantiles de stock |
| Préparation | Decks 15/20/25/30 | Même stock possédé | Mains mortes et combos |
| Ouverture | Main 4, main 5, puis ouverture préparée | Catalogue | Régularité et abus |
| Commerce | Aucun, refuges, option précoce | Revenus annexes mesurés | Dépendance au marchand |
| Présentation | Ouverture individuelle ou groupée | Butin strictement identique | Temps et plaisir de découverte |

Protocole humain proposé, non exécuté : comparer des rencontres appariées avec quelques joueurs expérimentés et débutants, alterner l'ordre des variantes pour limiter l'effet d'apprentissage, noter les choix et demander les raisons de conservation. Fixer ensuite des objectifs de tolérance de pénurie ; ne pas inventer un seuil universel à partir du seul simulateur.

## H. Journal d'événements à instrumenter plus tard

Événements : `combat_started`, `card_drawn`, `card_cast_committed`, `card_unplayed_discarded`, `weapon_action_used`, `mob_loot_resolved`, `bag_opened`, `trade_committed`, `deck_prepared`, `combat_ended`.

Champs communs : version de règles, run, rencontre, palier, classe, difficulté ; identifiant de copie lorsque pertinent. À la fin : stock par rang/fonction, cartes compatibles, nombre de tours, PA dépensés, dégâts reçus, transactions, durée de préparation. Séparer les cartes gardées pour une raison tactique de celles oubliées dans la réserve par une courte question de fin de test.

Ces événements sont une proposition d'instrumentation locale. Aucune collecte ni transmission de données joueur n'a été ajoutée.
