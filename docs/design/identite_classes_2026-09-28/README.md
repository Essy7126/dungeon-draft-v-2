# Identité des classes et caractéristiques — proposition du 28 septembre 2026

> **Proposition rejetée par l'utilisateur le 28 septembre 2026.** Conservée comme historique. Le modèle Force/Finesse/Esprit/Ténacité et les bonus d'expédition associés ne constituent plus la direction recommandée. Nouvelle recherche : `docs/ai/SYSTEME_SYNERGIES_RECHERCHE_2026-09-28.md`.

**Statut : étude de conception, non implémentée et non validée en partie.** Cette proposition concerne le mode Cartes de la run Catabase actuelle. Les chiffres sont des points de départ à comparer ; ce document ne remplace pas les règles de `docs/current/`.

État examiné : HEAD `5b3553c07472180d4af08ce4ebdd5ed42362766f`, avec modifications locales concurrentes. Les empreintes des sources de calcul figurent dans [CALCULS.json](CALCULS.json). Aucun fichier du moteur ou du catalogue n'a été modifié par cette étude.

## Décision proposée

Donner à chaque classe une attaque permanente qui amorce sa mécanique, conserver un passif distinct et la spécialisation, remplacer les trois caractéristiques universelles par quatre caractéristiques liées aux effets, et garantir un petit accès aux cartes natives dans les récompenses existantes.

Ne pas ajouter immédiatement un multiplicateur général de classe. Commencer par les effets et les prédispositions : un Gardien doit apprécier une carte étrangère parce qu'elle protège, pousse ou exploite sa garde ; la provenance seule ne doit pas décider de sa valeur.

Les caractéristiques auraient aussi une expression hors combat, sous forme de nouvelles options dans des haltes existantes. Cette couche demande du contenu supplémentaire : elle n'existe pas actuellement et n'est pas nécessaire pour mesurer le premier prototype de combat.

## 1. Diagnostic du jeu actuel

Sources : [mathématiques](../../../core/expedition/consumable_card_math.gd), [gestes de secours](../../../core/expedition/consumable_card_spells.gd), [état et progression](../../../core/expedition/consumable_cards_state.gd), [économie](../../../core/expedition/consumable_card_economy.gd), [catalogue](../../../data/cards/consumable_v2/catalog.json), [règles actuelles](../../current/cards_v2.md).

- Le calcul des statistiques ne reçoit pas la classe. Les caractéristiques actuelles sont Puissance (+5 % P), Vitalité (+6 % PV) et Résolution (+2 points de résistance physique, +5 % garde). La Puissance sert à de nombreux effets, ce qui limite la spécialisation par statistiques.
- Tous possèdent la même attaque de secours : 1 PA, contact, 0,28 P ; même garde de secours : 1 PA, 0,25 P. Chaque geste est limité à une fois par tour.
- Une copie jouée est consommée pour la run. Les cartes non jouées ne disparaissent pas automatiquement au premier combat. Le problème est l'épuisement progressif des fonctions du deck et l'incertitude de leur renouvellement.
- Les passifs et spécialisations donnent déjà des différences réelles. Ils ne sont pas, à eux seuls, une garantie de disponibilité des actions permettant de les utiliser.

### Le taux natif est plus faible que le taux annoncé pour le groupe favorisé

Pour chaque classe, le catalogue normal contient quatre familles natives, huit communes et douze étrangères. Le code donne 70 % au groupe **natives + communes**, avec tirage uniforme dans ce groupe.

| Origine d'une copie normale | Probabilité effective |
|---|---:|
| Classe choisie | 70 % × 4/12 = **23,33 %** |
| Commune | 70 % × 8/12 = **46,67 %** |
| Autre classe | **30 %** |

Pour un ennemi éligible au butin du premier palier, les canaux donnent en moyenne **3,105 copies**, dont **0,7735 réellement natives**, toutes raretés réunies. Probabilité de n'obtenir aucune native : **44,38 %**. Les canaux élite et rare ont ici 70 % de natives, car ils ne contiennent pas de communes. Le calcul suppose aucun abandon de butin et exclut le boss final ; il n'est pas une moyenne mesurée de runs.

Les achats ciblés et le troc existent déjà. Il faut les conserver et mesurer leur usage, plutôt que présenter leur ajout comme une nouveauté.

## 2. Ce que Dofus apporte à la réflexion

Le guide officiel de 2010 montre une même classe Crâ jouée en plusieurs orientations élémentaires, avec des compromis de portée, de contrôle et de polyvalence. L'enseignement utile est **classe + orientation de caractéristiques + sélection de sorts**. Ce document historique ne décrit pas la version actuelle et ne justifie pas une règle universelle « exactement un effet en combat et un hors combat » : les exemples Agilité/critiques/tacle du guide sont déjà plusieurs effets de combat. [Ankama/Pearson, guide officiel, pages 36–37](https://www.pearson.fr/resources/titles/27440100678110/extras/dofus_36_37.pdf).

Les discussions de joueurs sur la refonte 3.7 illustrent les deux faces des statistiques liées : certains apprécient leur identité ; d'autres jugent qu'une caractéristique donnant aussi la mobilité impose cette orientation et influence excessivement les valeurs des monstres. Ce sont des arguments de joueurs, sans mesure représentative ni preuve de l'état livré. Les pages officielles du devblog et du report sont bloquées par une vérification antirobot dans le lecteur utilisé ; aucune date de déploiement n'est affirmée ici. [Discussion et avis contradictoires](https://www.reddit.com/r/Dofus/comments/1squoso/discussion_update_37_characteristics/).

Notre interprétation : conserver des associations compréhensibles, mais éviter de rendre une caractéristique indispensable à toutes les classes pour se déplacer ou obtenir assez de cartes. L'étude [Waven précédente](../waven_coeur_du_jeu_2026-09-26/README.md) invite aussi à examiner les conversions action → dégâts/protection, pas seulement les coefficients.

## 3. Quatre attaques permanentes

Toutes coûtent **1 PA**, sont hors deck, sans consommation de copie, et utilisables **une fois par tour**. La garde de secours commune demeure dans le premier prototype. Une attaque n'est jamais gratuite en PA.

| Classe | Attaque proposée | Fonction dans le plan |
|---|---|---|
| Assassin | **Entaille d'ouverture** : contact, 0,22 P physiques ; pose une marque de 0,15 P pour la prochaine carte offensive admissible. | Préparer une frappe sur cible marquée même sans carte de marquage en main. |
| Gardien | **Coup de rempart** : contact, 0,20 P physiques et 0,20 P garde. | Activer les cartes exigeant de la garde et préparer une riposte. |
| Arpenteur | **Tir de repère** : portée 2–4, 0,28 P physiques ; à distance ≥3, ouvre l'ancre existante. | Fournir un vrai geste de tireur et un repli payé en PM. |
| Thaumaturge | **Étincelle** : portée 1–3, 0,15 P magiques et brûlure de 0,08 P sur une phase ennemie. | Amorcer une altération et le passif défensif sans dépendre de la pioche. |

Contrats du prototype :

- Les attaques de base peuvent déclencher **le passif de classe**, avec le compteur partagé avec les cartes ; aucun deuxième déclenchement gratuit. Les spécialisations déclenchées par un sort restent réservées aux cartes consommables dans ce prototype. Cela exige une modification explicite des exclusions `fallback` actuelles et des textes.
- L'Assassin ne consomme pas une marque avec son attaque de base. Sa petite marque ne remplace pas une marque plus forte et ne rafraîchit pas cette dernière. Si aucune marque supérieure n'est active, elle expire à la fin de l'activation suivante du héros. Une immunité au marquage reste respectée.
- La brûlure faible du Thaumaturge n'écrase ni ne prolonge une brûlure supérieure. Une application refusée ne déclenche pas le passif. Aucun remboursement ni pioche ne provient de ces attaques.
- L'ancre garde son coût de 1 PM, sa limite d'une utilisation, sa destination libre et sa distance maximale actuelle. Le tir ne fournit pas de PM ; l'Arpenteur doit encore prévoir sa position.
- Garde, riposte et soin conservent leurs plafonds. Le Gardien ne reçoit pas de soin via son attaque.

À P=40, sans caractéristiques/équipement/résistance : Assassin **9 dégâts + marque 6**, ou **19 dégâts** si son passif d'isolement est disponible ; Gardien **8 dégâts + 8 garde**, avec riposte conditionnelle existante de 10 ; Arpenteur **11 dégâts** ; Thaumaturge **6 dégâts + 3 différés**, plus 8 garde si son passif est disponible. L'attaque commune actuelle fait 11 dégâts. Ces totaux hétérogènes ne prouvent pas leur équilibre : portée, exposition, déclencheurs et dégâts évités doivent être mesurés.

Risque prioritaire : une attaque permanente trop complète réduit la consommation, finance la run indirectement et peut rendre l'attente optimale. Comparer les durées et copies dépensées ; la pression de fin de combat ne dispense pas de ce contrôle.

## 4. Quatre caractéristiques, liées aux effets

Remplacer Puissance/Vitalité/Résolution, sans superposer deux systèmes d'investissement. La valeur P demeure la puissance de base donnée par le niveau. Les types de résistance physique/magique restent distincts des caractéristiques offensives : aucune nouvelle série de résistances élémentaires dans ce premier prototype.

| Caractéristique | Effet par point proposé | Exemples |
|---|---|---|
| **Force** | +5 % aux frappes physiques, saignements et dégâts de collision provenant du héros. | Estoc, Frapper la faille, Heurt du rempart. |
| **Finesse** | +5 % aux tirs physiques et à la valeur des marques. | Trait court, Tir de relais, marques de l'Assassin et du Thaumaturge. |
| **Esprit** | +5 % aux dégâts magiques, brûlures, terrains magiques du héros et soins directs. | Braise tenace, Trait de givre, Grâce du bronze. |
| **Ténacité** | +5 % à la garde produite ; +3 % aux PV max. | Garde brève, Garde ferme, Bastion vivant. |

La catégorie frappe/tir est une propriété stable de l'effet de carte, affichée sur la carte : un projectile conserve Finesse même lancé au contact. Chaque composante a **une seule** caractéristique. Une carte mêlant frappe et marque affiche Force pour la frappe, Finesse pour la marque. L'étiquette « classe » est indépendante.

Pas de multiplication des nombres de cartes piochées, PA, PM, cases de poussée, distances de téléportation ou durées de contrôle. Ces avantages discrets restent dans les cartes, équipements et améliorations. Ajouter 1 PM à une base de 3 représente +33,3 % de déplacement ; ajouter une case à un déplacement de deux cases représente +50 %. Ce ne sont pas des équivalents d'un bonus de dégâts de 5 %.

Les cartes de déplacement, de pioche ou d'échange de positions restent utiles sans bonus numérique de caractéristique. Leur valeur vient de leur fonction et de leur synergie avec les passifs ; il ne faut pas leur inventer un pourcentage artificiel.

### Prédispositions et construction du personnage

Chaque classe reçoit **trois points innés fixes**, puis les six points libres déjà gagnés aux niveaux 2/4/6/8/10/12. Cap proposé : huit par caractéristique. Aucune conversion automatique d'anciens attributs ne peut être laissée implicite lors d'une éventuelle intégration.

| Classe | Répartition innée proposée | Autres orientations possibles |
|---|---|---|
| Assassin | Force 2, Finesse 1 | Marques puissantes ou saignements/frappes ; défense importée. |
| Gardien | Ténacité 2, Force 1 | Grande garde ou frappes/ripostes ; tirs pour couvrir son approche. |
| Arpenteur | Finesse 2, Ténacité 1 | Tireur ou combattant mobile hybride ; marquage importé. |
| Thaumaturge | Esprit 2, Finesse 1 | Brûlures/terrain ou marques ; protection importée. |

Trois points égaux ne garantissent pas une valeur égale : Ténacité sert à la fois les PV et la garde. C'est un point à comparer explicitement contre la consommation et le temps de combat. À huit points : +40 % aux effets concernés et, pour Ténacité, +24 % PV ; ces plafonds ne constituent pas une preuve d'équilibrage.

### Formules et conversions

Pour une composante ordinaire : `P_niveau × coefficient × (1 + 0,05 × caractéristique + bonus équipement admissibles)`, puis les protections et l'arrondi final. Les bonus d'une même catégorie s'additionnent. Les bonus de passif restent des composantes distinctes avec une attribution explicite ; ils ne sont pas amplifiés une seconde fois par la carte qui les déclenche.

PV : `PV_niveau × (1 + 0,03 × Ténacité + bonus PV équipement)`. Garde : coefficient × P_niveau × (1 + 0,05 × Ténacité + bonus garde), plafonnée à 2,5 P_niveau comme aujourd'hui.

Une marque est calculée à la pose et stockée : aucune amplification par la Force ou l'Esprit de la carte qui la consomme. Répercussion conserve sa conversion `1,5 × garde sacrifiée` **sans** deuxième amplification de Force sur ce terme ; seule sa composante propre 0,70 P est amplifiée. Le drain reste 50 % des PV effectivement retirés : ne pas ajouter encore Esprit au soin dérivé des dégâts déjà amplifiés. Les bonus de spécialisation demandent le même audit de conversion.

À P=40, sans passif, équipement ni résistance, avec comparaison caractéristique 0 → 4 :

| Effet | Sans investissement | Quatre points appropriés |
|---|---:|---:|
| Estoc, Force | 22 | 26 |
| Trait court, Finesse | 18 | 22 |
| Garde ferme, Ténacité | 46 garde | 55 garde |
| Braise tenace, Esprit | 22 + 2 × 7 = 36 | 26 + 2 × 9 = 44 |

La petite brûlure gagne plus de 20 % après arrondi ; afficher les résultats entiers réels. Les cartes étrangères restent jouables : un Gardien investi en Ténacité valorise la garde commune autant qu'une garde de sa classe, tandis qu'un Arpenteur profite d'une marque étrangère grâce à Finesse.

## 5. Un prolongement hors combat concret

La réserve actuelle est illimitée : un bonus de capacité d'inventaire ne résout aucun problème existant. Une statistique de gain d'XP modifierait le calendrier de niveau/spécialisation ; une hausse générale de rareté ferait dépendre la puissance future d'un choix économique précoce. Ces deux pistes ne sont pas retenues pour le premier prototype.

Proposition à développer : après les combats 3, 6 et 9, greffer une courte décision sur la transition/halte existante. Un choix commun demeure accessible à tous. Une caractéristique à **4** ouvre une option supplémentaire, jamais indispensable ; une seule option est prise, un reçu empêche de la rejouer. Ce sont de **nouveaux contenus**, pas des fonctionnalités déjà présentes.

| Caractéristique | Option illustrative d'expédition |
|---|---|
| Force | Briser un coffre scellé : récupérer 8 or. |
| Finesse | Fouiller une cache : choisir une copie normale parmi trois propositions distinctes. |
| Esprit | Déchiffrer un autel : transformer une normale possédée en une normale choisie parmi les communes et natives. |
| Ténacité | Supporter l'épreuve : récupérer 10 % des PV max, borné aux PV manquants. |

Ces valeurs sont des budgets de départ, **pas quatre récompenses équivalentes** : le soin vaut zéro à pleine vie, le choix de carte dépend du stock et la conversion consomme un bien. La fréquence, les alternatives communes et les textes de ces trois scènes restent à écrire avant intégration. Faire du palier une option de récit/gestion évite quatre microbonus économiques permanents supplémentaires.

## 6. Continuité du stock de classe

Tester d'abord une intervention indépendante du volume de butin : sur chaque victoire non finale disposant d'une normale récupérable, une normale **prédésignée** de la récompense peut devenir une normale native choisie parmi les quatre familles. Le joueur peut conserver le tirage initial. Une seule substitution par combat, sans copie supplémentaire ni hausse de rareté. Les cartes non récupérables restent exclues.

Pour un seul ennemi au premier palier, si le joueur accepte systématiquement : espérance native 0,7735 + (1 − 0,2333) = **1,5402**, avec toujours **3,105 copies totales**. Le gain de 0,7667 est **par combat**, pas par ennemi. Ce changement augmente la qualité et la continuité du stock : il doit donc être compté dans le budget économique malgré un volume inchangé.

Cette garantie apporte au maximum une copie du maillon choisi ; elle ne fournit pas une boucle infinie et ne couvre pas automatiquement toutes les dépenses. La sélection d'une carte d'ouverture existante complète ce mécanisme, et les marchands conservent leur rôle.

Alternative à comparer, sans cumul initial : passer les normales à 50 % natives / 30 % communes / 20 % étrangères. Cela réduit le risque mais ne garantit aucune fonction précise. La substitution choisie répond mieux au manque d'une carte essentielle et conserve le mélange actuel pour le reste du butin.

## 7. Pourquoi pas simplement ×1,25 sur sa classe ?

Un effet de 40 passe à 50, même si rien ne change dans la décision. Mais une mobilité de deux cases ou une pioche de deux cartes n'a pas d'équivalent continu. Un bonus global favorise les familles à gros chiffres, sans traiter équitablement déplacement, contrôle et information. Il ne reconstitue pas non plus une famille consommée.

Trois multiplicateurs de +25 % font 40 × 1,25³ = **78,125**, contre **70** avec trois bonus additifs : l'ordre des étapes compte. Ces valeurs illustrent l'empilement, pas une combinaison existante du jeu.

Si l'identité demeure insuffisante après les attaques et les caractéristiques, tester séparément un bonus natif modeste, par exemple +10 % sur les composantes explicitement admissibles. Ne pas l'introduire simultanément : on ne saurait plus quelle couche apporte le bénéfice ni laquelle écrase les cartes étrangères.

## 8. Lisibilité et validation avant intégration

La fiche du personnage affiche quatre nombres, leurs effets et les trois points innés. La carte affiche son résultat actuel ; une infobulle décompose base, caractéristique, équipement et condition. Les valeurs projetées sont calculées par le même chemin que les valeurs appliquées. L'attaque permanente est visible à côté de la main, avec son coût et son utilisation restante. La classe et la caractéristique ne partagent pas la même icône.

Intégrer, si retenu, dans les services du mode Cartes et le parcours public existant : aucun mode supplémentaire, aucune run parallèle. Étendre les définitions et services Studio ; ne pas dériver silencieusement frappe/tir d'un nom ou d'une portée. Inventorier les 48 familles composante par composante avant le portage. La sauvegarde actuelle exige exactement trois attributs : migration de schéma et remboursement explicite des points seront nécessaires, pas un simple changement d'UI.

Comparer successivement le témoin actuel, attaques seules, attaques + caractéristiques, puis continuité du butin. Ajouter les haltes à options après mesure du combat. Garder les mêmes graines et rencontres ; mesurer durée, PV perdus, copies consommées, stock des fonctions essentielles, répartition des dépenses, usage des cartes étrangères et victoires. Les bots doivent disposer d'une politique adaptée aux nouveaux gestes ; ajouter des essais humains pour la lisibilité et la tentation d'attendre.

Cas prioritaires : deck vide, marque plus forte déjà posée, brûlure existante, immunité, tir au contact, ancre bloquée/sans PM, garde au plafond, drain en sur-dégâts, Répercussion, première action consommant le compteur de passif, reprise entre récompense et choix. Aucune ouverture ne doit demander une carte précise absente pour que la classe exprime son premier choix tactique.

**Vérification réalisée :** `calculs.py` a exécuté 18 assertions arithmétiques et produit [CALCULS.json](CALCULS.json). Il lit le catalogue actuel, recalcule les probabilités pour les quatre classes et les exemples d'effets. Ce n'est ni une simulation complète, ni un test Godot, ni une validation de balance. Aucune suite moteur n'a été relancée pour cette étude documentaire.
