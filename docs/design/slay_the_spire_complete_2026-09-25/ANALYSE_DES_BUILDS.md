# Ce qui rend les cartes intéressantes ensemble

Les faits de cartes sont dans les cinq catalogues. Ce document expose **notre analyse de conception**, pas un classement statistique des meilleurs decks. Une combinaison possible n’est pas une combinaison disponible dans chaque run ; aucune fréquence de victoire n’a été mesurée ici.

## 1. Une carte possède plusieurs coûts simultanés

La valeur ne se résume pas à dégâts / énergie. Elle dépend aussi de la pioche occupée, du moment où elle arrive, des autres cartes nécessaires, du temps d’installation, du risque laissé à l’ennemi et des investissements de run. Une carte de coût 0 peut être chère sur cinq cartes piochées, sous Normality ou devant Time Eater.

| Dimension | Exemple concret | Conséquence |
|---|---|---|
| Coût immédiat | Bludgeon mobilise 3 énergie dans une carte. | Très dense en pioche, peu flexible en actions. |
| Avance nécessaire | Sneaky Strike rembourse sous condition ; Meteor Strike peut provoquer des évocations de Plasma. | Un bon bilan final ne garantit pas de pouvoir amorcer l’action. |
| Dette différée | TURBO ajoute Void ; Immolate ajoute Burn. | Le coût peut disparaître si l’ennemi meurt avant la prochaine pioche. |
| Installation | Demon Form, Creative AI, Deva Form. | Leur rendement final doit être comparé aux menaces pendant les premiers tours. |
| Condition d’accès | Clash, Grand Finale, Signature Move. | Un gros chiffre compense une contrainte, qui peut devenir triviale dans une configuration particulière. |
| Valeur de run | Feed, Self Repair, Lesson Learned. | Une action médiocre pour gagner maintenant peut préparer les combats suivants. |
| Coût d’opportunité | Searing Blow reçoit plusieurs améliorations. | La croissance inclut les soins et améliorations auxquels on a renoncé. |

Une grille d’évaluation utile distingue : **survivre à la prochaine intention ; éliminer une menace ; trouver les bonnes cartes ; financer leur jeu ; tenir la durée ; améliorer la run**. Une carte peut résoudre deux problèmes et en créer un troisième. Cela explique mieux son identité qu’un score unique.

## 2. Douze moteurs, leurs pièces et leurs points de rupture

Les exemples ci-dessous décrivent des services à assembler. Il n’est pas nécessaire de posséder toutes les pièces citées. Une carte assurant plusieurs services permet souvent à un moteur incomplet de fonctionner.

| Moteur | Construction et moment décisif | Ce qui fait échouer le plan | Lecture de conception |
|---|---|---|---|
| Ironclad — épuisement | Power Through produit blocage et Wound ; Second Wind convertit les non-attaques ; Feel No Pain ajoute une protection ; Dark Embrace renouvelle la main. Corruption permet une dépense rapide des compétences. | Installation tardive, manque d’attaques finales, épuisement prématuré des réponses, pioche saturée. Les Wound mises en main ne déclenchent pas Evolve. | Un déchet peut avoir plusieurs usages, à condition de distinguer production, pioche et sacrifice. Le joueur arbitre le moment de fermer ses options futures. |
| Ironclad — Force et santé | Inflame/Spot Weakness installent ; Pummel et Sword Boomerang multiplient les applications ; Limit Break amplifie ; Reaper transforme une fenêtre offensive en récupération. | Mauvais tirage d’installation, groupe qui disperse les coups, Force sans rafale, sacrifice de PV qui dépasse les soins réellement possibles. | Une même statistique relie attaque, défense indirecte et économie de santé. Le soin plafonné aux PV retirés empêche d’évaluer une cible presque morte comme une réserve infinie. |
| Ironclad — réserve de blocage | Barricade conserve, Entrench double, Body Slam convertit sans consommer ; Impervious sert d’amorce. | Barricade jouée sur une réserve vide, adversaire déjà létal, manque d’accès à la conversion. | La conversion sans consommation permet une réutilisation de capital. Dans notre jeu, Répercussion consomme la garde : le modèle économique est différent. |
| Silent — défausse | Acrobatics/Calculated Gamble choisissent et circulent ; Reflex remplace les cartes ; Tactician/Concentrate financent ; Eviscerate et Sneaky Strike valorisent la condition. | Main de Reflex/Tactician sans déclencheur, énergie insuffisante avant remboursement, moteur sans dégâts ou blocage. | Une contrainte devient une ressource. L’équilibrage doit vérifier les mains ratées et le démarrage, pas seulement une séquence déjà installée. |
| Silent — Shiv | Blade Dance produit ; Accuracy amplifie ; After Image protège par carte ; Finisher récompense le nombre d’attaques ; Envenom peut connecter le moteur au poison. | Manque de places, protections/ripostes par impact, compteur de cartes adverse, pouvoir amplificateur sans producteur. | Le jeton transporte trois dimensions : dégâts, action et épuisement. Renforcer le producteur et le bénéficiaire simultanément multiplie leurs gains. |
| Silent — poison et fenêtre sûre | Deadly Poison/Noxious Fumes amorcent ; Catalyst amplifie ; Burst peut répéter ; Well-Laid Plans aligne les pièces ; une protection achète les tics nécessaires. | Artefact, purge, cible morte trop tard, Catalyst pioché avant toute amorce, incapacité à défendre pendant la montée. | L’horizon de temps doit être annoncé dans les calculs. Une somme de poison sur sept tours n’aide pas si la rencontre se décide en deux. |
| Defect — Frost et Focus | Cold Snap/Coolheaded/Glacier installent ; Defragment/Consume renforcent ; Capacitor élargit ; Loop valorise la tête de file ; Fission transforme l’installation en tour actif. | Trop de capacité vide, installation sans réponse immédiate, Focus sans orbes, Consume qui réduit trop la capacité. | Trois paramètres indépendants créent la profondeur : production, puissance par emplacement et capacité. Augmenter l’un peut réduire un autre bénéfice. |
| Defect — Ténèbres | Darkness/Doom and Gloom chargent ; Frost protège ; Recursion réutilise ; Dualcast/Multi-Cast multiplient une sortie préparée. | Mauvaise cible aux PV les plus faibles, évocation prématurée, Intangible adverse, retard de la carte d’évocation. | Un sort chargé devient un problème d’ordonnancement et de ciblage. Les attaques ordinaires servent aussi à préparer les PV relatifs des cibles. |
| Defect — coût nul et récupération | Claw progresse ; Hologram/All for One récupèrent ; Scrape filtre ; Streamline rejoint progressivement le groupe gratuit. | Trop de cartes gratuites sans pioche, Scrape défaussant les installations, manque de défense, tours trop longs avant la croissance. | Le coût énergétique nul déplace le facteur limitant vers l’accès. La croissance de Claw porte sur la famille, celle de Streamline sur l’exemplaire. |
| Watcher — changements de posture | Une entrée Wrath bon marché dépense la sortie de Calm ; Rushdown apporte l’accès ; Inner Peace/Fear No Evil/Empty Mind referment ou prolongent la séquence ; Mental Fortress protège. | Entrée sans sortie, coût de Calm trop élevé, cartes absentes du cycle, contraintes par carte jouée, trop de cartes à éliminer avant de boucler. | Les postures modifient simultanément ressources, danger, accès et protection. Leur réseau est plus puissant qu’un simple multiplicateur ×2. |
| Watcher — rétention et fenêtre | Protect/Tranquility stockent la réponse ; Sands of Time et Establishment valorisent l’attente ; une entrée Wrath/Divinity active la réserve offensive. | Main encombrée, coût d’installation, devoir défendre maintenant avec une carte que l’on souhaitait conserver. | Retain achète du contrôle sur le moment de la dépense ; sa valeur dépend directement de la règle de pioche et de la capacité de main. |
| Watcher — Scry | Foresight prépare ; Cut Through Fate convertit la sélection en pioche ; Weave revient ; Nirvana protège. | Beaucoup de filtrage sans carte à jouer, moteur gratuit sans dégâts suffisants, pioche trop petite pour que le choix compte. | La qualité d’accès peut être récompensée sans fournir systématiquement une carte nette supplémentaire. C’est une piste adaptée à nos consommables. |

Ces moteurs ne sont pas des cases hermétiques. Glacier traite l’urgence et prépare Frost ; Corpse Explosion peut résoudre un groupe sans constituer un deck poison complet ; Headbutt prépare autant une défense qu’une attaque de croissance. **Les cartes de liaison rendent les récompenses imparfaites exploitables.** Cette propriété est particulièrement importante quand nos récompenses viennent de sacs aléatoires.

## 3. Cartes atypiques : pourquoi les garder dans l’étude

**Pressure Points** grandit vite en rejouage mais partage peu de bénéficiaires avec les attaques et postures. Cela crée une voie lisible, au risque de demander trop de copies d’une seule pièce. Ce n’est pas une preuve qu’une mécanique isolée est toujours mauvaise : il faut mesurer son accès et ses réponses défensives. Nos marques consommées au prochain coup n’ont pas ce fonctionnement.

**Grand Finale** ne réclame pas seulement de la pioche ; elle réclame la bonne quantité de pioche au bon moment. Une amélioration augmentant une pioche peut même changer les séquences possibles. Le plaisir potentiel vient de maîtriser un état exact. La frustration apparaît si l’interface cache cet état ou si le hasard laisse trop rarement une solution.

**True Grit** illustre une amélioration qualitative : passer de la perte aléatoire au choix permet de conserver sa condition de victoire tout en supprimant une nuisance. **Fission** passe de liquidation à récupération des effets de sortie. **Eruption** moins chère laisse de quoi exploiter puis quitter sa posture. Aucune de ces améliorations n’est correctement décrite par « +15 % de dégâts ».

**Hello World, Discovery et les générateurs** apportent des options à un paquet pauvre, mais peuvent polluer un moteur déjà précis. La génération n’est pas uniformément positive. Les pools de génération comptent aussi : des exclusions de cartes de soin évitent de confondre moteur de combat et source répétable de santé. [Génération incolore](https://slay-the-spire.fandom.com/wiki/Transmutation).

**Malédictions et statuts** ne sont pas de simples pénalités numériques. Normality taxe les séquences ; Regret taxe la main gardée ; Pain taxe le volume ; Writhe taxe l’ouverture ; Void taxe le financement au moment de la pioche. Une nuisance intéressante vise une dimension identifiable et offre plusieurs réponses. Un même Wound peut être handicap, combustible de blocage ou moyen de faire piocher selon le moteur.

## 4. Ce que l’évolution du jeu nous apprend

Dans sa présentation GDC de 2019, Anthony Giovannetti décrit un objectif où chaque carte trouve un contexte utile, sans domination excessive. Il associe itérations fréquentes, retours de testeurs et métriques ; ces dernières apportent des indices plutôt qu’une conclusion automatique. Les Ascensions servent notamment à différencier les niveaux de pratique. Cette présentation concerne l’époque des trois personnages, avant Watcher. [Présentation originale, pages 7, 10, 13–16 et 21](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf).

La mise à jour 2.2 fournit des cas concrets : Blade Dance normale passe de 2 à 3 Shiv ; Accuracy de +3 à +4 dégâts ; Reflex de 1 à 2 cartes piochées ; Phantasmal Killer de 2 à 1 énergie. Ce sont respectivement des changements de production, d’amplification, d’accès et d’installation. [Annonce officielle de Mega Crit, 29 novembre 2020](https://store.steampowered.com/news/posts/?appids=646570&enddate=1607901864&feed=steam_community_announcements).

Notre calcul M11 compare la paire Blade Dance + Accuracy déjà installée : 14 dégâts avant, 24 après, soit +71,43 %. Ce pourcentage décrit cette séquence, **pas** une hausse de victoire ou de puissance globale de Silent. Le raisonnement utile pour nous : deux améliorations modestes sur des maillons complémentaires peuvent produire une hausse combinée importante. Mesurer chaque carte isolément manque cette conséquence.

Reflex montre une autre direction : rendre un moteur plus viable en améliorant sa circulation peut conserver l’identité de ses attaques. Baisser un coût d’installation réduit le nombre de tours où le joueur paie sans retour. Il serait toutefois abusif de prétendre connaître la motivation exacte de chaque changement à partir des seules notes : ces interprétations sont les nôtres.

## 5. Ce que disent les joueurs, et ce que cela ne prouve pas

Des discussions sur les améliorations mettent en avant le contrôle de True Grit et les tours supplémentaires de Faible/Vulnérable d’Uppercut. Une discussion d’Accuracy après sa modification contient à la fois de l’enthousiasme pour la viabilité du paquet Shiv et une critique d’un jeu devenu trop automatique. Ce sont des **témoignages qualitatifs**, pas un sondage représentatif ni une mesure de balance. [Améliorations, mai 2024](https://www.reddit.com/r/slaythespire/comments/1ctnp10/), [Accuracy, avril 2021](https://www.reddit.com/r/slaythespire/comments/mo3hwg/).

Notre interprétation : réussir une combinaison plaît davantage quand le joueur comprend ce qu’il a organisé — une fenêtre, un sacrifice, une sélection, une cible — que lorsque toutes les cartes déclenchent automatiquement la même chaîne. Il faut tester cette hypothèse auprès des joueurs de notre jeu. Un fort rendement et une décision intéressante sont deux objectifs différents.

## 6. Protocole d’équilibrage à reprendre

1. **Écrire les services de la carte.** Urgence, accès, financement, préparation, amplification, croissance ou économie ; noter ses dépendances exactes.
2. **Tester le minimum et le réseau complet.** Carte seule ; une pièce de liaison ; moteur installé ; main ratée. Séparer coût d’installation et tour rentable.
3. **Varier l’épreuve.** Duel, groupe, rafale, gros impact, nuisances, pression de temps, protection par impact, adversaire qui se déplace. Pour Catabase, ajouter portée, ligne de vue et terrain.
4. **Mesurer l’accès réel.** Probabilité d’avoir les pièces, nombre de tours sans carte utile, part des cartes vues mais inutilisables, taille de main, budget d’actions. M38/M39 illustrent l’effet d’un passage de 15 à 30 cartes.
5. **Mesurer les choix.** Quelle carte gardée, quelle cible abandonnée, quel risque accepté ? Une victoire facile accompagnée de décisions répétitives ne valide pas l’objectif de gameplay.
6. **Séparer les populations.** Débutants, joueurs connaissant les règles, experts ; même graine pour comparer des variantes, puis graines variées pour observer les échecs. Un taux brut mélange progression, sélection des cartes et qualité de jeu.
7. **Conserver les contre-exemples.** Une réduction du nombre d’emplacements peut améliorer ou dégrader Frost (M22/M23). Une carte forte à horizon sept tours peut être trop lente à horizon trois (M15/M16).

Ce protocole est une proposition pour notre projet, pas une méthode attribuée mot pour mot à Mega Crit. Les [47 calculs](CALCULS.md) éprouvent des points précis ; ils ne remplacent pas ces essais complets.
