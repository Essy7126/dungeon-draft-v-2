# Enquête approfondie : ce que Dungeon Draft peut apprendre de ses références

23 septembre 2026. Dossier de recherche et d'audit ; aucune modification du gameplay.

## Lire le dossier

1. [Deckbuilders : cartes, moteurs, retours joueurs et décisions des créateurs](enquete_gameplay_2026-09-23_references.md).
2. [Ankama et Larian : classes, sorts, builds, refontes et attentes des joueurs](enquete_gameplay_2026-09-23_ankama_larian.md).
3. [Audit Catabase : inventaire, chiffres, redondances et propositions testables](enquete_gameplay_2026-09-23_catabase.md).
4. [Catalogue exécuté : 112 cartes, coûts, portées, effets, dégâts et recharges](../../artifacts/dev/20260923-135932-enquete-catalogue-corrige-8cb2b8cd/cards.csv).
5. [Rapport brut : catalogue et 7 200 tirages de butin](../../artifacts/dev/20260923-135932-enquete-catalogue-corrige-8cb2b8cd/report.json).

Les trois analyses détaillées représentent environ 10 700 mots et citent 59 URL distinctes. Le volume n'est pas une mesure de vérité : chaque section sépare règles documentées, explications du studio, expériences rapportées et interprétation pour notre jeu. La table d'inventaire et les calculs sont reproductibles ; les hypothèses de plaisir restent à confronter à des parties humaines.

## Ce que l'enquête change par rapport au premier rapport

Le premier rapport passait trop rapidement des références à des idées de cartes. Cette reprise examine les chaînes complètes : coût, préparation, effet, récupération, condition d'accès, limite, version et expérience contradictoire. Elle revient aussi sur les systèmes que leurs propres créateurs ont ensuite corrigés.

**Une classe mémorable change la manière de décider.** Corruption convertit des compétences répétables en tempo ; Little Fade convertit sa mort en développement d'un étage ; le Xélor peut avancer une récompense normalement différée ; l'Éliotrope fabrique le trajet de ses sorts. Dans chaque cas, ajouter un coefficient de dégâts n'expliquerait pas le système. Les dossiers donnent les règles et sources derrière ces comparaisons.

**Les exemples célèbres ont des échecs instructifs.** Les boucles de pioche de la Watcher peuvent réduire la variété des constructions ; un contrôle répété peut supprimer tout le combat adverse ; une classe à installation peut être pénible dans les combats courts. Il faut emprunter une décision intéressante avec sa contrainte, pas seulement son résultat spectaculaire.

**L'avis du créateur évolue.** Larian défendait en 2018 la prévisibilité des protections de DOS2 ; en janvier 2026, son responsable de conception annonce ne pas conserver ce système d'armure magique dans le prochain Divinity, pour rendre les capacités intéressantes utilisables plus tôt. Ce retour critique est central pour éviter une imitation aveugle. [Entretien de 2018](https://www.gamedeveloper.com/design/designing-drama-into-the-turn-based-combat-of-i-divinity-original-sin-2-i-), [AMA de l'équipe en 2026](https://www.reddit.com/r/Games/comments/1q870w5/larian_studios_divinity_ama/).

**WAVEN révèle une tension proche de la nôtre.** Le projet de simplification annoncé en 2025 et les réactions de joueurs montrent deux attentes : comprendre plus facilement, mais conserver le plaisir de construire un personnage riche jouable seul. Le dossier distingue cette annonce du guide Pikuxala de 2026 qui décrit encore l'ancien équipement ; il ne présente pas un mélange de versions comme un état live vérifié.

## Les constats les plus solides sur Catabase

| Constat | Preuve | Implication |
|---|---|---|
| 112 familles, 29 catégories d'effets | Export exécuté dans Godot | Le besoin principal n'est pas un nouveau lot de frappes |
| Douze spécialisations surtout fondées sur le premier bonus admissible | Catalogue + modificateur de classe | Les conditions varient davantage que l'économie de jeu |
| Deux pièces doublées sont réunies dans 40,48 % des premières mains ; trois dans 20,95 % | Calcul sur deck 10/main 4 | Concevoir une combo exige de concevoir son accès |
| Premier combat normal : 42,84 % de probabilité de zéro carte | Formule + échantillonnage indépendant | Vérifier la première occasion de transformer le deck |
| Maîtrise étrangère plafonnée à 2, amélioration de copie exigeant 3 | Règles de progression | L'hybride n'a pas les mêmes possibilités de mutation |
| Glace du terrain et ralentissement de classe utilisent des états distincts | Surface + prédicat du passif | Une synergie intuitive peut ne pas se déclencher |
| Disque, braise manipulable et urne existent déjà en Classique | Définitions et modificateurs | Le projet contient ses propres premiers moteurs de build |
| Les salles ajoutent stockage, délai, alimentation et origine de zone mobile | Catalogue actuel des salles | Tester les classes face à des objectifs, pas seulement des PV |

Ces constats ne permettent pas de déclarer une classe « injouable », la frappe de secours « dominante » ou une salle « équilibrée ». Pour ces conclusions, il manque des parties comparables et une observation du joueur.

## Recommandation

**Faire émerger quatre moteurs de classe avant d'élargir le catalogue.**

- Assassin : choisir une proie et convertir son élimination en décision sur la main.
- Gardien : convertir une protection réellement absorbée en ressource dépensable.
- Arpenteur : construire un trajet et un retour qui dépendent de ses déplacements.
- Thaumaturge : transformer une surface, en sacrifiant un effet pour en obtenir un autre.

Le dossier Catabase spécifie des premières paires de cartes, coûts de prototype, garde-fous, conditions d'acquisition et critères d'évaluation. Il propose aussi de conserver une spécialisation simple par classe : la complexité supplémentaire doit être un choix.

L'ordre recommandé est : rendre les états et déclenchements explicites ; donner une première expression du moteur avant le premier élite ; différencier quelques mutations ; revoir l'accès aux pièces et la promesse du multiclassage ; éprouver le tout dans les salles et sur plusieurs profils de joueurs.

## Ce qui est validé, et ce qui ne l'est pas

L'export du catalogue et les 7 200 tirages ont été exécutés. Le processus a terminé avec code 0, mais le journal comporte une erreur de lecture du magasin de certificats système : ce n'est pas une validation moteur sans erreur. Les calculs de main et de progression sont analytiques, appuyés sur les règles inspectées.

Il n'y a pas eu de campagne de parties humaines, de mesure de rétention ou de test de tous les sorts dans cette tâche. Les jeux externes ont été étudiés par leurs documents, guides, communications et témoignages accessibles, sans prétendre y avoir rejoué ni avoir regardé intégralement les vidéos. Les valeurs historiques et les incertitudes de version sont identifiées.

Les fichiers de salles modifiés par une autre tâche ont été préservés et relus dans leur état disponible. Aucun commit, aucune PR et aucun changement de règles de jeu n'ont été faits pour cette enquête.
