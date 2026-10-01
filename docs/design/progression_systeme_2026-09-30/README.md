# Progression de personnage : profondeur et contrats communs

30 septembre 2026. Reprise de la tâche locale **« Auditer les idées de gameplay »**.
Le [Prototype v1](../../current/prototype_v1.md) reste le système jouable.
Ce dossier propose sa suite : [contrat complet](CONTRAT.md),
[candidats codifiés](candidats.json), [recherche](RECHERCHE.md),
[analyse reproductible](analyse.py), [résultats de cette exécution](../../../artifacts/dev/20260930-progression-systeme-final/resultats.json).

## Proposition centrale

**Conserver les maîtrises communes et faire évoluer la manière d'utiliser les
sorts dans les trois emplacements de perfectionnement existants.** Compléter
en parallèle l'accès au contenu et la continuité de l'attaque permanente.
Une montée doit permettre de répondre à plusieurs questions : quelle composante
renforcer, quelle forme préparer, combien de copies engager et quelle faiblesse
accepter dans son répertoire.

Les éléments ne déverrouillent aucune paire prédéfinie. Les formes de sorts ne
demandent aucun seuil élémentaire. Elles constituent une possibilité de contenu,
pas une obligation pour tous les sorts. Aucun compteur supplémentaire d'XP de
sort, de combo ou de puissance générale n'est proposé.

Le système complet possède cinq axes complémentaires :

| Axe | Décision du joueur | Budget et continuité |
|---|---|---|
| Classe | Attaque permanente, passif, spécialisation | Classe conservée pendant la run ; spécialisation au niveau 4 |
| Éléments | Renforcer les composantes réellement utilisées | 4 points au départ, 2 par niveau, 26 au niveau 12 ; règle +3/+2/+1 conservée |
| Aptitudes | Survivre, protéger, combattre au contact ou loin | 3 points aux niveaux 3/6/9 ; les futures aptitudes utilisent ce même budget |
| Perfectionnements | Choisir trois familles et, lorsqu'elle existe, une forme par famille | 1/2/3 emplacements aux niveaux 4/8/12 ; formes alternatives, sans cumul |
| Répertoire et objets | Composer avec le stock consommable, le butin et les emplacements | 15 copies au départ, deck ≤30, ≤3 par famille ; 6 équipements et 2 reliques |

Le [contrat](CONTRAT.md) définit la cadence, les sauvegardes, les sources de
bonus, la réorientation et le financement des nouvelles possibilités.

## Ce que les calculs apportent de nouveau

### Les allocations nombreuses ne suffisent pas à créer beaucoup de choix

Les **169 911 allocations légales** des 26 points dans six éléments ont été
énumérées pour cinq répertoires numériques, soit 849 555 évaluations exactes.
Les poids décrivent une contribution de base de même nature, jamais un mélange
arbitraire de dégâts, soins et garde.

| Répertoire de base | Allocation optimale | Bonus |
|---|---|---|
| Un élément | 26 | +38 % |
| 80/20 | 26/0 | +30,4 % pondérés |
| 65/35 | 18/8 | +26,5 % pondérés |
| 50/50 | 11 allocations, de 8/18 à 18/8 | +25 % pour chacune |
| Trois parts égales | 8/8/10 ou 8/9/9, avec permutations | +20,667 % pondérés |

Ainsi 13/13 n'est pas un optimum unique pour un effet 50/50. Onze répartitions
produisent exactement le même résultat. Ce plateau peut préserver une marge
d'adaptation ; il ne justifie pas d'afficher onze styles de jeu distincts.

Je conserve provisoirement cette courbe. Ajouter des taxes ou des seuils de
synergie masquerait le problème : il faut des composantes et des situations
qui départagent réellement les investissements.

### Certains gains de points sont invisibles après arrondi

Mesure sur les impacts directs originaux du catalogue et des attaques permanentes,
sans condition, équipement, défense ni passif. À chaque montée, on compare les
deux nouveaux points monoélément **à P identique au nouveau niveau** pour isoler
leur contribution. Une ligne correspond à un couple sort/élément pertinent ;
ce n'est pas une fréquence d'utilisation observée.

- Niveau 4 : **42/54** comparaisons gardent le même entier de dégâts.
- Niveau 12 : **18/54** gardent le même entier.

La hausse de P reste visible dans le jeu ; ces résultats ne disent pas que le
niveau ne sert à rien. Ils disent qu'un écran de points doit montrer le gain
réel, les autres composantes et le prochain seuil d'arrondi. On ne doit pas
vendre « +1 dégât » lorsque l'impact reste à 8.

### Protection et Vitalité n'offrent pas le même service

Au niveau 6, P=40 et PV de base=290. Un rang de Vitalité ajoute **23 au maximum**.
Un rang de Protection ajoute **5 de garde** sur une Garde ferme avec 14 points
Terre : 58→63, avant plafonnement par la garde déjà présente.

Il faudrait cinq productions comparables, entièrement absorbées, pour dépasser
ces 23 PV dans cette comparaison locale. Trois copies de Garde ferme ne suffisent
donc pas à elles seules. D'autres gardes, le secours permanent, le passif et la
spécialisation peuvent changer le résultat. Inversement, Vitalité ne fournit pas
23 PV courants gratuits lors d'une redistribution et augmente la Pression fondée
sur les PV maximaux. Cela appelle une mesure d'absorption et de soin disponible,
pas une augmentation aveugle de Protection.

Je n'ajoute pas immédiatement Soin ou Persistance au menu. Il n'existe aujourd'hui
aucun soin normal et seulement deux familles normales de Brûlure/Saignement.
Leur contrat futur est codifié, avec un seuil de couverture du contenu, et
utiliserait les trois points existants.

### Un build Soleil a encore un problème d'approvisionnement

Pour Assassin, Gardien ou Thaumaturge, un tirage normal actuel a **2,5 %** de
chance de donner un sort dont l'impact direct est au moins moitié Soleil.
Dans six tirages normaux indépendants : **14,09 %** d'en obtenir au moins un.
Pour Arpenteur : 5,833 % par tirage, soit 30,28 % sur six.

Cette métrique exclut volontairement les gardes, les cartes rares et la qualité
réelle de Volée croisée. Elle ne représente pas la probabilité d'un build Soleil
complet. Elle établit que les points Soleil offensifs ont très peu de débouchés
normaux dans les autres classes. Une offre orientée et davantage de contenu
normal sont prioritaires avant une résistance ennemie qui exigerait de changer
d'élément.

## Six formes de perfectionnement à essayer

Les exemples suivants occupent un emplacement existant et consomment les copies
normalement. Mesures arithmétiques à P=40 et 14 points dans l'élément concerné,
sans classe, équipement, défense ou autre perfectionnement. Ils ne sont pas
des résultats de combat Godot des nouveaux effets.

### Braise vive / Braise lente : gagner maintenant ou plus tard

- **Vive** : 2 PA, portée 1–3, 0,80 P Feu immédiat + 0,10 P Feu sur deux activations.
- **Lente** : mêmes coût et portée, 0,40 P immédiat + 0,34 P sur deux activations.

| Brûlures réellement résolues | Vive | Lente |
|---|---:|---:|
| Aucune | 40 | 20 |
| Une | 45 | 37 |
| Deux | 50 | 54 |

La première version lente utilisait 0,30 P par tic : elle atteignait seulement
20/35/50. La forme vive faisait 40/45/50 et la dominait sur ce critère. Ce candidat
a été rejeté. La version 0,34 fournit enfin une situation favorable à chaque forme.
Cela ne valide pas son coefficient : Pyre, Mèche obstinée, mitigation magique,
seuils de mise à mort et rafraîchissements devront encore être éprouvés.

### Trait précis / Trait traversant : concentration ou géométrie

- **Précis** conserve le perfectionnement actuel : 1 PA, portée 2–4, 0,60 P Vent.
- **Traversant** : même coût et portée de première cible, 0,35 P Vent par cible,
  deux ennemis au maximum, sur deux cases consécutives dans une direction cardinale.
  Mur ou obstacle bloque la seconde case ; pas de cible secondaire choisie librement.

Résultat : **30 contre 18** sur une cible ; **30 contre 36 répartis** sur deux.
Le second ennemi est au plus à cinq cases du héros. Les budgets de passif et de
spécialisation restent communs à tout le lancer, pas doublés par les impacts.
Il faut aussi tester les surfaces et les seuils de mort : 18+18 ne vaut pas
nécessairement une élimination à 30.

### Garde massive / Garde tissée : pic ou protection différée

- **Massive** conserve 1,40 P Terre, expiration normale : **71** ici.
- **Tissée** crée 0,90 P Terre : **45**, puis conserve une seule fois la moitié
  du reliquat de **cette source** au prochain début du héros, sans nouvelle maîtrise.

Contre 10 dégâts maintenant puis 50 à la phase suivante, sans nouveau sort :
Massive absorbe **10**, Tissée **28**. Contre 50 puis 50 : Massive absorbe **50**,
Tissée **45**. La forme durable ne copie pas la garde des autres cartes et ne
réamorce ni production de garde, ni relique, ni spécialisation.

## Trois nouvelles cartes pour donner du sens aux répartitions

Elles sont communes, normales, utilisables une fois par famille par tour, avec
trois copies au plus dans le deck. Leur affinité ne les réserve à aucune classe.

| Carte | Coût / portée | Composantes originales |
|---|---|---|
| Suture d'aube | 2 PA / soi | Soin 0,45 P Eau, puis garde 0,45 P Soleil |
| Lame d'équinoxe | 2 PA / 1–2 | Impact physique 0,65 P Soleil, puis Marque 0,25 P Nuit si la cible survit |
| Jet d'obsidienne | 2 PA / 2–3 | Impact physique 0,50 P Terre, puis Brûlure magique 0,20 P Feu sur deux activations |

Pour Suture d'aube au niveau 6 : Eau 14/Soleil 0 donne **23 soin /18 garde** ;
7/7 donne **21/21** ; 0/14 donne **18/23**. Les coordonnées restent séparées.
À PV pleins, le soin peut être entièrement perdu ; contre une attaque imminente,
la garde compte davantage. Cette hybridation vient des besoins successifs du
personnage, sans exiger une paire d'éléments dans un arbre.

Le JSON précise ordre, durées, amélioration, arrondi et dépendances. Ces trois
cartes complètent les [candidats précédents](../prototype_v1_epreuve_2026-09-29/candidats.json),
notamment Disque d'aube, Dette de rive et les sceaux doubles ; elles ne les remplacent
pas et ne sont pas chargées dans le jeu.

## Continuité, récompenses et extensions

Je retiens l'**inflexion explicite de l'attaque permanente** proposée le 29 :
un élément choisi en préparation, sans changer le coût, la portée, la condition
ou le passif de classe. Cela protège la valeur des points lorsque les copies
disparaissent. La garde Soleil du Gardien conserve son élément. Le contrat détaille
le coût d'opportunité et la migration des poids historiques du Thaumaturge.

Pour le butin, tester le remplacement du premier sac normal gagné par un choix
entre trois lots de **même quantité et rareté** : renforcer une maîtrise investie,
couvrir une fonction peu représentée, ou conserver le tirage ordinaire. L'offre
est engagée une seule fois et sauvegardée ; aucune copie supplémentaire gratuite.
Choisir entre trois lots augmente tout de même leur valeur attendue : la campagne
devra la mesurer avant de prétendre conserver la difficulté.

Les équipements modifient des statistiques existantes ; les reliques déclenchent
des événements bornés. Pas de bonus automatique natif supplémentaire pour cette
itération : un même sort doit servir différemment les passifs existants, plutôt
que recevoir une taxe cachée selon son origine. Une option native chiffrée pourra
être comparée plus tard, avec financement explicite.

Les résistances élémentaires restent un lot ultérieur indépendant. Préserver le
plafond défensif commun proposé dans l'épreuve précédente, la provenance et la
compatibilité lorsque les nouvelles résistances sont nulles. Ajouter six défenses
avant de fournir des répertoires alternatifs rendrait surtout certains départs
moins jouables.

## Vérifications nouvelles et limites

HEAD observé : `a3b0c7dc4c6841c722e5db3d90c6151696dec7b9`. Les sources numériques,
les candidats et les observations sont identifiés par SHA-256 dans les résultats.

- [Suite Cartes](../../../artifacts/dev/20260930-195411-test-cards-5380453a/gut-strict-report.json) :
  **PASS, 359 tests, 34 630 assertions, zéro erreur moteur**.
- [Passe-rive / Thaumaturge](../../../artifacts/dev/20260930-200422-prototype-v1-passe-rive-c8e6a567/summary.json) :
  **six essais réels, 59 lancers joueur, 27 lancers ennemis, zéro lancer joueur
  échoué, zéro erreur moteur**. Quatre victoires et deux observations arrêtées
  à la borne de six tours ; ce PASS valide le harnais, pas six victoires.
- **1 728 impacts directs Godot/Python concordants**, base/amélioré, niveaux
  1/6/12 et six orientations monoélément. Ensemble des clés vérifié, sans doublons.
- **3 607 contrôles analytiques et de contrat** réussis dans la dernière analyse,
  distincts des tests GUT. Allocations exactes, provenance des candidats, mains
  énumérées, garde sans duplication et situations opposées des formes proposées.

Deux des quatre captures de Battle ont été inspectées : Passe-rive et sa main
sont visibles au départ élite, la seconde montre la victoire. La bannière de
début de tour masque une partie du plateau dans la première ; aucune revue complète
du HUD n'est revendiquée. La comparaison interactive de points a aussi été vérifiée
en navigateur : valeurs et interactions, zéro erreur, aucun débordement à 320/736
pixels ; les deux captures correspondantes ont été inspectées.

Dans l'élite profondeur 6, le départ est au **niveau 5**, P=34, 240 PV, quinze
copies préparées et 27 copies possédées après le transit de laboratoire. Eau 12
gagne au tour 6 avec **76 PV avant le gain de niveau** ; Eau 6/Soleil 6 laisse
14 PV ennemis, avec 91 PV héros ; Soleil 12 laisse 43 PV ennemis, avec 111 PV héros.
Les essais inachevés ne sont pas directement comparables à une victoire en survie.
Ce résultat confirme l'adéquation du paquet actuel à Eau ; il ne teste pas un
véritable paquet Soleil ni les nouveaux candidats.

Les observations reprennent le harnais existant : transit déclaré, politique
limitée, pas de traversée continue ni de taux de victoire humain. La suite globale
et les autres gates CI n'ont pas été rejouées : le moteur actif n'a pas été modifié.
Le premier lancement sandbox a échoué à l'import et exécuté **zéro test** ; son
rapport reste conservé. Les analyses intermédiaires `-01` et `-02` sont des brouillons
antérieurs au dernier script ; seule la sortie `-final` correspond aux empreintes
actuelles. Aucune de ces vérifications n'atteste l'implémentation des candidats.

Reproduire avec un nouveau dossier :

```powershell
./dev.ps1 test cards
./tools/consumable_cards/verify_prototype_v1.ps1 -Class thaumaturge -TimeoutSeconds 480
python docs/design/progression_systeme_2026-09-30/analyse.py --output-dir artifacts/dev/<nouveau-dossier> --runtime artifacts/dev/<nouvel-essai-passe-rive>/observations.json
```

## Ordre proposé pour le prochain développement

1. Afficher gains exacts et manque de débouchés ; ouvrir et compléter les cartes
   normales de départ, en préservant classe, stock et économie.
2. Tester séparément l'inflexion permanente et l'offre de sacs orientée ; observer
   les ruptures de stock et la valeur des choix de récompense.
3. Versionner les formes et les applications de statut entières ; intégrer d'abord
   Trait traversant, puis Braise, puis la garde sourcée et les composantes multiples.
4. Comparer chaque candidat dans des campagnes identiques : tempo, absorption,
   soins utiles, consommation, géométrie, réorientation et lisibilité des montées.
5. Introduire les nouvelles aptitudes et résistances seulement lorsque leur contenu
   et leurs interactions sont effectivement couverts.

Ce dossier rend la prochaine implémentation reviewable ; il ne publie aucune
nouvelle règle comme déjà jouable. Le [journal de reprise](../../ai/PROGRESSION_SYSTEME_2026-09-30.md)
consigne fichiers, commandes et prochaine étape.
