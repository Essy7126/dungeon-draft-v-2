# Cartes : classes et butin, révision 3

Implémentation du 19 septembre 2026. Entrée : **Nouvelle partie → Cartes**.
Les sauvegardes Classique et Cartes restent séparées. Une ancienne partie Cartes conserve ses règles ; une nouvelle partie utilise la révision 3. Aucune conversion silencieuse de ses cartes ou de son équipement.

## Ce que le joueur choisit

1. Apparence d'Achille : purement visuelle, dont Passe-rive.
2. Classe : Assassin, Gardien, Arpenteur ou Thaumaturge. Un passif et un catalogue de départ, indépendants de l'ancien arbre.
3. Difficulté puis récapitulatif. La préparation du deck présente ensuite cinq choix successifs parmi quinze cartes de la classe, avec PA, portée, valeurs et rôle. Chaque famille choisie apporte deux copies.
4. Départ sans équipement ni consommable gratuit. Le Seuil et ses sorties physiques restent le premier choix de chemin : barque, puits ou porte.
5. Après victoire : annonce de niveau si nécessaire → caractéristiques → maîtrises/spécialisation → grille du butin acquis → retour au chemin. La collection et les caractéristiques permettent de reprendre une décision en attente.

La sélection utilise une navigation à gauche, un aperçu central et un panneau d'effets à droite. Le butin montre les icônes des cartes et objets obtenus, avec survol et détail sélectionnable. Le sac distingue les six emplacements portés, la réserve et les objets disponibles ; aucune carte reçue ne remplace automatiquement une carte du deck.

## Vocabulaire et règles effectives

| Terme | Fonction dans cette version |
|---|---|
| Apparence | Modèle/portrait ; aucun bonus de combat |
| Classe principale | Une des quatre classes, choisie au départ, conservée pendant la run |
| Spécialisation | Un des trois passifs de la classe, choisi au niveau 4 ; remplace le passif initial |
| Famille de carte | Identifiant d'une technique ; maximum deux copies dans le deck |
| Copie | Objet individuel possédé, avec identifiant, réserve/deck, éventuelle amélioration |
| Maîtrise | Rang de 0 à 4 d'une classe ; multiplie ses dégâts (directs, périodiques et bonus conditionnels) et sa garde par `1 + 0,1 × rang` |
| Perfection | Budget partagé entre maîtrises et améliorations individuelles |
| Palier d'équipement | Progression du butin selon la profondeur, de 1 à 3 |

Il n'y a pas de couche supplémentaire « divinité/culte » avec des règles implicites. Les douze spécialisations remplacent cette couche dans ce lot jouable. Leurs conditions ci-dessous sont l'implémentation actuelle, pas toutes les pistes spéculatives du dossier d'audit.

### Classes et spécialisations

Chaque passif se déclenche au maximum une fois par activation du héros ; une zone peut bénéficier du bonus sur plusieurs victimes du même lancement. Le marqueur est remis à zéro au prochain combat.

| Classe | Passif initial | Spécialisations, au niveau 4 |
|---|---|---|
| Assassin | +20 % au premier coup au contact contre une cible sans allié orthogonalement adjacent | Exécuteur : +35 % contre cible à ≤35 % PV. Embusqué : +30 % au contact après 2 cases parcourues. Traqueur : +30 % contre cible marquée. |
| Gardien | +20 % à la première garde | Rempart : +40 % à la première garde. Vengeur : +30 % après perte de PV depuis l'activation précédente. Percuteur : +35 % contre cible déjà déplacée/collisionnée pendant cette activation. |
| Arpenteur | +20 % au premier coup à distance ≥3 | Tireur : +35 % à distance ≥4. Escarmoucheur : +30 % après 2 cases parcourues. Chasseur : +30 % contre cible ralentie. |
| Thaumaturge | +20 % au premier coup magique contre cible marquée ou ralentie | Pyromancien : +25 % aux dégâts directs du premier sort de feu. Cryomancien : +35 % au premier coup magique contre cible ralentie. Dévastateur : +25 % au premier sort touchant au moins deux ennemis. |

Les passifs peuvent soutenir une carte étrangère compatible avec leur condition. La carte étrangère ne confère jamais le passif de sa propre classe.

### Deck et combat

- Exactement dix copies actives ; deux maximum par famille ; quatre cartes en main.
- Conservation, défausse, remélange et échange d'une carte contre 1 PA réutilisent le moteur Cartes commun.
- Deux gestes hors pioche : frappe de secours, 2 PA, 55 % de Prouesse au contact ; protection, 1 PA, 20 % de Prouesse en garde jusqu'à la prochaine activation, une fois par activation.
- Soixante techniques : quinze par classe. Marque, saignement, brûlure, ralentissement, affaiblissement, poussée, attraction, déplacement, garde, zone et dégâts conditionnels.
- Les contrôles, déplacements et gardes concernés portent une limite par activation de la **famille**. Posséder deux copies ne contourne pas cette limite.
- Une carte étrangère est jouable au rang 0, sans taxe de PA. Les dégâts/gardes évoluent avec sa maîtrise ; les déplacements, durées de contrôle et coûts restent fixes.
- Saignement/brûlure : deux activations de la cible, attribution à leur lanceur ; affaiblissement : une activation. Ils utilisent les statuts du moteur commun, pas une simulation parallèle.
- Hors combat, remplacement libre d'une copie par une copie de réserve. Les dix copies initiales sont liées : conservables en réserve, invendables.

### XP et perfection

L'XP vient des combats et conserve la courbe de niveau de la run. Ni l'utilisation répétée d'une carte ni son stockage ne lui donnent de l'XP. Pour cette variante, la Sagesse n'augmente pas l'XP et n'est pas proposée à la répartition. Les récompenses de perfection sont déterministes : 2 points aux niveaux 2, 4, 6, 8, 10 et 12, donc 12 au total.

| Investissement | Coût | Plafond |
|---|---:|---:|
| Classe principale : rang 2 → 3 | 3 | 4 |
| Classe principale : rang 3 → 4 | 4 | 4 |
| Classe étrangère : rang 0 → 1 | 2 | 2 |
| Classe étrangère : rang 1 → 2 | 3 | 2 |
| Améliorer une copie de carte | 2 | Une amélioration, maîtrise 3 requise |

Les améliorations changent une propriété : garde sur deux activations, déplacement franchissant les obstacles, tir ignorant la ligne de vue, ou +1 portée au contact. Les cartes étrangères ne peuvent pas atteindre la maîtrise 3 pendant cette run. Une amélioration est payée par copie ; vendre une copie améliorée ne rembourse pas ces points.

Exemples au budget final : maîtrise principale 4 + deux copies améliorées = 11 points ; principale 4 + secondaire 2 = 12 points ; principale 3 + secondaire 2 + deux copies améliorées = 12 points. Ce sont des budgets valides, pas des taux de victoire mesurés.

Dans une halte située au plus tard à la profondeur 7, une correction gratuite remet les maîtrises à 2/0/0/0, retire les améliorations, rend les points investis et réouvre la spécialisation. Une seule correction par run ; les ventes restent des ventes.

## Butin et économie

Le tirage utilise une graine dérivée de celle de la run et de l'identifiant de la salle. Un reçu par victoire évite le double gain lors d'une reprise ou d'un nouvel affichage.

| Rencontre | Cartes | Objets |
|---|---:|---|
| Normale | 1 | 1 équipement ; 30 % de chance d'une relique éphémère |
| Élite | 2 | 1 équipement + 1 rune + 1 relique permanente |
| Boss | 1 | 1 équipement ; 30 % de chance d'une relique éphémère |

Pour chaque carte : 15 % de probabilité d'une autre classe aux profondeurs 1–3, 35 % aux profondeurs 4–12, 45 % ensuite. Si elle est étrangère, les trois autres classes sont équiprobables ; tirage uniforme dans leurs quinze cartes. Aucun couple hybride précis n'est garanti. Les cartes étrangères ont donc aussi des fonctions autonomes, notamment déplacement, garde et contrôle.

La première pièce est toujours une arme, d'affinité aléatoire. Les suivantes tirent un des six emplacements. Palier 1 aux profondeurs 1–6, palier 2 aux profondeurs 7–13, palier 3 à partir de 14. Aucun emplacement complet ni objet précis n'est garanti.

Les 72 équipements sont **24 modèles déclinés en trois paliers**, pas 72 mécaniques indépendantes. Ils sont tous utilisables par toutes les classes.

| Emplacement | Bonus de base × palier |
|---|---:|
| Arme | +3 Prouesse |
| Armure | +8 armure |
| Accessoire | +6 résistance magique |
| Tête | +1 initiative |
| Ceinture | +15 PV maximum |
| Pieds | +2 points de pourcentage d'esquive |

Chaque pièce a également une affinité : +4 % × palier de dégâts au contact, +5 % de garde/soins, +4 % de dégâts à distance ≥3, ou +4 % de dégâts magiques directs. Les modificateurs suivent le calcul commun de l'équipement ; vérifier leur cumul en équilibrage, notamment avec six pièces d'une même affinité.

Une rune par équipement, sertissage irréversible : +4 Prouesse, +10 armure, +10 résistance magique ou +25 PV maximum. Elle est consommée, persiste avec l'instance et se retire des statistiques quand l'objet est déséquipé. Une reconstruction des statistiques ne la cumule pas à nouveau.

Réserve de cartes séparée du sac. Si le sac est plein, le reliquat d'objets reste récupérable ; une relique unique déjà possédée peut aussi y rester en attente. Les reliques permanentes sont actives dans le sac. Les éphémères s'activent depuis les Objets du combat.

Vente d'objet non porté : 12 oboles, 24 si rare. Cartes usuelles : achat 50, vente 8 ; cartes coûtant 3 PA : achat 75, vente 12 dans ce premier lot. Ce classement provisoire est économique, pas une mesure de puissance. Stock de trois cartes unique et conservé à chaque halte, hors dernière halte. Aucune relance du stock par réouverture du menu.

## Extension et persistance

- `core/expedition/class_card_catalog.gd` : catalogue source (identifiant, classe, nom, PA, portée min/max, coefficient de Prouesse, effet, valeur, rôle). Ajouter une technique implique sa définition, son pictogramme et un scénario de lancement dans le test du catalogue.
- `class_card_modifier.gd` : conditions et effets raccordés au contexte de lancement commun. Les définitions ne sont pas mutées pendant le combat.
- `class_cards.gd` : état de run, copies, maîtrises, amélioration, butin, magasins et validation des sauvegardes. Ressources de sorts stables par copie/rang pour la sélection dans le HUD.
- `class_equipment_catalog.gd`, `class_rune_catalog.gd` : production de définitions d'objets compatibles avec les services d'inventaire existants.
- `ui/expedition/class_workshop.gd` : collection, équipement et progression ; aucune mutation en lecture seule pendant le combat. Liste et fiche défilent séparément. Le bouton **Mon deck** est aussi accessible depuis la main de combat.
- `class_combat_results.gd` : bilan distinct, avec ligne personnage/niveau/XP/oboles/butin, quantités regroupées et fiches au survol ou au clic. Les reçus `battle_results` survivent à la vente et à l'équipement. Les anciennes sauvegardes restent acceptées sans cette nouvelle section ; les métriques historiques absentes ne sont pas inventées.
- Révision 3 vérifiée avec classe principale, plafonds de maîtrise, budget dépensé, journal d'améliorations, unicité des copies, deck valide, identifiants du butin et reçus. Une sauvegarde invalide ne remplace pas la session courante.
- Tests inclus dans `./dev.ps1 test catabase` et la suite globale CI grâce au préfixe `test_catabase_class_run.gd`.

## Références de présentation

La création reprend la séparation entre identité, classe et décisions expliquées de [Baldur's Gate 3, Community Update 21](https://baldursgate3.game/news/community-update-21-forging-your-legacy_77). Pour le butin, le [compte rendu illustré des interfaces Dofus 2.46](https://dofus.jeuxonline.info/actualite/54181/beta-246-astrub-interfaces-tour-proprietaire) sert de référence visuelle pour regrouper gains, objets et inspection. Les pictogrammes du lot sont originaux et dessinés en SVG ; aucun asset de ces jeux n'est repris.

Les résultats de validation et leurs limites sont consignés dans [la fiche d'intégration](../ai/CLASS_RUN_IMPLEMENTATION_2026-09-19.md). Les simulations de frontières de progression ne constituent pas une preuve d'équilibrage tactique des 12 combats pour tous les builds.

Le [contrôle tactique complémentaire](class_balance_readability_audit_2026-09-19.md) exécute 18 runs avec combats réels et une politique automatique explicitée. Il documente des écarts de confort à distance et les limites de la comparaison avec les anciens départs.
