# Prototype v1 éprouvé avec Passe-rive

29 septembre 2026. Le système peut servir de fondation, mais **la présence de six
maîtrises ne garantit pas encore six voies viables par classe**. Les principales
limites observées concernent l'accès aux cartes, les actions permanentes, le butin
et certains bonus fixes d'effets. Une hausse globale des chiffres ne résoudrait
pas ces problèmes.

Ce dossier comprend l'[enquête sourcée et 21 décisions](RECHERCHE.md), le
[contrat de statistiques proposé](CONTRAT.md), un [catalogue candidat](candidats.json),
les [calculs exécutables](analyse.py), leurs [résultats](resultats.json) et une
[comparaison des 48 cartes par PA et par copie](cartes_par_pa_et_copie.csv).
Le contenu candidat n'est pas chargé par le jeu. La seule correction de production
de cette étude concerne un accès à une vue détruite dans le survol des unités.

## Ce qui a été réellement examiné

Catalogue actif : 48 cartes, quatre classes, huit spécialisations, 24 équipements,
huit reliques. Lecture de la progression, des paliers, de la préparation et des
copies, du butin, des modificateurs de cartes, des statuts, des défenses, des tours,
des ennemis et des particularités des scènes actuelles.

Passe-rive est une apparence publique compatible avec les quatre classes, pas une
cinquième classe. Le harnais instancie les scènes de la run actuelle avec le vrai
Battle, SpellCaster, l'IA, les animations et la consommation. Les profils de test
sont isolés dans `artifacts/dev`, sans modifier la sauvegarde du joueur.

La matrice compare trois répartitions à budget égal : dominante de classe
(Nuit/Terre/Vent/Eau), moitié de cette dominante et moitié Soleil, puis tout Soleil.
« Dominante » n'est pas une contrainte de classe. L'expérience teste les départs
standards existants ; elle ne mesure pas un deck Soleil spécialement préparé.

Deux scènes indépendantes : premier combat au niveau 1, puis salle élite de
profondeur 6 au niveau **5**. Profondeur et niveau sont différents, car la route
contient des haltes. La seconde fixture commence à 240 PV, P=34, 12 points,
Protection rang 1, première spécialisation de la classe, sans équipement ni relique.
Les victoires précédentes sont déclarées pour atteindre cette scène : cela ne
mesure pas la survie d'une campagne continue. Le butin de transit est possédé mais
le paquet préparé conserve les quinze copies de départ.

La politique automatique choisit une action légale selon dégâts immédiats, cible
achevable, Marque, un tick différé et garde ; elle se rapproche si nécessaire. Elle
n'optimise ni un futur tour complet, ni la valeur économique des copies, ni les
combinaisons complexes. La salle élite est bornée à six tours joués. Un arrêt avec
des ennemis vivants est une observation tronquée, **pas une défaite**.

Les résultats moteur et les validations finales sont consignés en fin de dossier.

## 1. L'hybridation est actuellement plus étroite que son vocabulaire

La maîtrise vaut +12 % à quatre points, +20 % à huit, +25 % à treize et +38 % à
vingt-six. Pour une composante de poids `w/(1-w)`, le bonus est
`w×M(points A) + (1-w)×M(points B)`. L'énumération des 27 répartitions de 26 points
donne :

| Pondération | Meilleure répartition A/B | Bonus optimal | Bonus 13/13 |
|---|---:|---:|---:|
| 100/0 | 26/0 | 38 % | 25 % |
| 80/20 | 26/0 | 30,4 % | 25 % |
| 70/30 | 22/4 | 27,4 % | 25 % |
| 60/40 | 18/8 | 26 % | 25 % |
| 50/50 | De 8/18 à 18/8 | 25 % | 25 % |

Pourquoi 80/20 reste mono : même après huit points dans la dominante, son prochain
point rapporte `.8×.01=.008`, contre `.2×.03=.006` pour le premier point secondaire.
Une dominante strictement supérieure à 75 % garde cet avantage marginal.

Une carte Eau/Nuit 80/20 peut néanmoins appartenir à un bon deck hybride si
d'autres cartes valorisent la Nuit. Le constat porte sur **cette composante isolée**.
Il faut distinguer trois choses : une carte à deux couleurs, un répertoire viable
dans deux éléments et une répartition optimale des points. Elles ne coïncident pas
automatiquement.

Je conserverais les paliers pour la prochaine expérience et ajouterais quelques
cartes à composantes distinctes : par exemple dégâts Nuit + garde Eau. Cela permet
d'investir selon les besoins du personnage sans imposer un combo prédéfini ou un
seuil d'accès artificiel.

## 2. Le problème le plus urgent est la couverture du catalogue

Comptage des cartes **normales** ayant au moins 50 % de l'élément dans la composante
de dégâts directs ; les doublons entre colonnes sont légitimes :

| Élément | Familles normales de dégâts ≥50 % | Familles concernées |
|---|---:|---|
| Terre | 3 | n01, g02, g03 |
| Eau | 5 | n07, g04, r03, t01, t04 |
| Feu | 5 | n04, a03, g03, r02, t02 |
| Vent | 5 | n05, a04, r01, r02, r04 |
| Nuit | 5 | n06, a01, a02, a03, t03 |
| Soleil | 1 | r04, Volée croisée, 3 PA, moitié Vent |

Soleil dispose de nombreuses cartes de garde ou de rareté supérieure ; cela ne
remplace pas une attaque normale facile à acquérir. Feu est présent dans seulement
six familles toutes raretés confondues, dont cinq normales : son développement
tardif repose beaucoup sur les mêmes familles et sur leurs interactions.

Le butin normal mélange 70 % de cartes de sa classe/communes et 30 % étrangères.
Les points investis n'interviennent pas. Pour un Assassin, Gardien ou Thaumaturge,
la probabilité d'une carte normale contenant une composante Soleil ≥50 % vaut
8,33 %. Après **six tirages normaux indépendants**, la probabilité de n'en recevoir
aucune est `(1-.08333)^6 = 59,33 %`. Elle vaut 47,51 % pour l'Arpenteur.
Ce n'est ni une probabilité d'échec de run, ni une mesure de tous les sacs réunis.

Ajouter Disque d'aube répond donc à un manque mesuré. Une future offre de trois
cartes pourrait garantir : une carte pertinente pour une maîtrise choisie, une
pour une voie secondaire et une libre. Choix explicite de la voie suivie, seuil de
pertinence de 50 % sur une composante quantitative, fallback documenté si le pool
est vide. Il faudra comparer cette offre au butin actuel à quantité et rareté
égales, pour ne pas confondre meilleure pertinence et inflation des ressources.

## 3. L'investissement doit survivre à l'épuisement des copies

Les attaques permanentes sont distinctes et utiles, mais leurs couleurs sont
fixes : Assassin Nuit, Gardien Terre avec garde Soleil, Arpenteur Vent, Thaumaturge
Eau/Nuit. Un Arpenteur Feu peut donc perdre l'usage offensif de sa maîtrise quand
ses copies Feu disparaissent.

La proposition d'**inflexion permanente** du [contrat](CONTRAT.md) garde la portée,
le coût, les conditions et le passif de la classe, mais permet de choisir un seul
élément de dégâts pour son attaque de base en préparation. Elle mérite un essai
séparé ; les combats de ce dossier utilisent encore les attaques actuelles.

À bas niveau, les arrondis masquent aussi une partie des choix :

| Attaque permanente, P=16, cible sans défense | Sans maîtrise | 4 points dans la dominante |
|---|---:|---:|
| Assassin, sans Marque | 4 | 5 |
| Gardien, dégâts seuls | 4 | 4 |
| Arpenteur, sans bonus de déplacement | 4 | 4 |
| Thaumaturge, quatre points Eau | 4 | 4 |

Cela n'annule pas le gain sur les cartes plus fortes, mais explique pourquoi le
premier combat peut sembler identique. Je n'ajouterais pas d'arrondi supérieur
systématique : il amplifierait artificiellement les petits impacts multiples.
L'aperçu doit présenter le résultat réel et le prochain seuil utile.

## 4. Ne pas confondre rendement par PA et économie des copies

Estoc fournit .55P pour un PA et une copie ; Tir de relais .80P pour deux PA et une
copie, à distance, avec une pioche après mouvement. Le premier a un meilleur ratio
par PA ; le second conserve davantage de valeur par copie et une utilité spatiale.
On ne peut pas jouer deux Estocs dans le même tour avec la limite par famille.

Garde brève fournit .45P de garde Soleil ; le secours fournit .25P, neutre, sans
consommer de copie. À P=16, sans bonus : 7 contre 4. Le secours est un plancher
de survie ; l'investissement Soleil améliore les gardes colorées, pas ce secours.

Les cartes périodiques demandent encore un troisième axe : le temps avant de
recevoir leur valeur. Braise tenace vaut .55P immédiatement et .18P à chacune des
deux activations suivantes. Une cible tuée avant les ticks n'a pas reçu .91P.
Une carte de Marque demande de compter le coût et la disponibilité du déclencheur.

Pour les prochaines campagnes, relever PV perdus, copies consommées par famille,
PA restants faute d'action pertinente, maîtrise utile sur les cartes effectivement
jouées, tours jusqu'à victoire et Pression subie. Un simple « taux de victoire »
masquerait des départs économiquement intenables.

## 5. Les reliques existantes imposent déjà de fortes contraintes de création

| Relique active | Contrat observé | Point d'audit pour le nouveau contenu |
|---|---|---|
| Fil | Rembourse 1 PM après le premier déplacement de carte du tour | Distinguer déplacement réel, téléportation et tentative bloquée |
| Bronze | .25P de garde au tour suivant si absorption | Protection et bonus de garde s'appliquent ; pas de maîtrise élémentaire implicite |
| Braises | +.10P par tick de brûlure/surface de feu | Les petits ticks et les longues durées gagnent disproportionnellement |
| Obole | +4 or par élimination directe admissible, plafond 20/combat | Les invocations et les chaînes de dégâts ne doivent pas contourner le plafond |
| Archive | Première carte de coût ≥3 : -1 PA, une fois/combat | Une baisse de 3 à 2 est +50 % de rendement par PA sur cette action |
| Miroir | Premier coup ennemi admissible : renvoi .40P | Provenance et absence de récursion, pas un nouveau lancer de carte |
| Coupe | Deux premières éliminations directes : soin .35P chacune | Pas de soin sur simple overkill théorique ni sur attaque permanente |
| Sceau | +.20P à la Marque posée | Le supplément est élémentarisé à la pose ; ne pas le recalculer à la libération |

Exemple calculé, P=40, 14 points Feu, cible sans défense, deux ticks intégralement
subis, sans autre bonus :

| Carte | Seule | Avec Braises | Braises + premier déclenchement Pyre |
|---|---:|---:|---:|
| Braise tenace, 2 PA | 46 | 56 | 66 |
| Tison de poche candidat, 1 PA | 25 | 35 | 45 |

Tison gagne 80 % dans ce cas contre 43,5 % pour Braise ; son ratio monte à 45
dégâts/PA contre 33. Ce n'est pas une preuve de domination dans toute rencontre,
mais c'est une raison suffisante pour **ne pas l'ajouter immédiatement**. Son
contrat candidat indique cette dépendance. Options à comparer : bonus relatif à
la base périodique, budget de relique par tour, ou abandon de ce petit sort.
Changer Braises et Pyre exige de rejouer tous les sorts concernés ; aucune
conversion générale n'a été appliquée ici.

Le Sceau présente un effet analogue : +.20 sur une Marque .40 représente +50 %
sur cette Marque, pas +20 % de toute la carte. Il faut publier les composantes
distinctes dans l'outil de création.

## 6. Équipement et aptitudes : comparer à emplacement et usage égaux

Les six amulettes élémentaires ont élargi un seul emplacement. Au premier palier,
14 définitions sont éligibles au tirage : six amulettes, trois armes, deux coiffes,
une armure, des bottes et une ceinture. Les amulettes représentent donc **42,86 %
d'un tirage d'équipement précoce**, contre 7,14 % pour les bottes. Ce sont des
probabilités conditionnelles à l'obtention d'un équipement, pas par ennemi tué.
Séparer le poids du slot et le choix de sa définition éviterait que chaque ajout
de contenu déforme involontairement l'économie.

| Groupe actuel | Comparaison pertinente |
|---|---|
| Lame +12 % contact, arc +10 % distance/+1 portée/-1 PM, bâton +12 % magique | Les bonus de distance et de type sont distincts des éléments ; à deux cases, le bonus Distance ne s'applique pas |
| Cuir +12 % PV, plaque +12 % physique/-1 PM, robe +12 % magique/+10 % garde | Survie attendue selon menaces, dégâts évités et mobilité sacrifiée |
| Coiffe +1 main, bronze .60P de garde d'ouverture, sage +15 % garde | Accès aux choix contre protection immédiate ou répétée ; +1 main n'est pas +20 % de dégâts |
| Bottes +1 PM, maintien +8 % contact/+4 % physique, flux +1 PM/+6 % distance/-10 % garde | Cap de PM et géométrie de la classe, pas somme brute des pourcentages |
| Ceinture +16 % PV, soins +30 %/+4 % PV, garde +20 % | Répertoire capable de convertir le bonus en survie effective |
| Coupe de vol de vie +10 %, éclat +8 % dégâts/-6 % PV, œil +1 portée/parade initiale | Soin plafonné par combat, défense réellement sacrifiée et seuils de portée |
| Six sceaux +12 % élément | Couverture des composantes, pas couleur de la classe seule |

À niveau 12, Vitalité rang 3 donne 162 PV de base supplémentaires. Protection rang
3 donne +.30 de coefficient de bonus sur la garde : sur Garde ferme 1.15P à P=93,
c'est environ 32 points bruts supplémentaires par utilisation avant plafond et
arrondi. Plusieurs gardes réellement absorbées peuvent rivaliser avec les PV ;
de la garde expirée ou excédentaire ne le peut pas. Comparer « 30 % contre 24 % »
sans les bases serait trompeur.

La Pression ignore les défenses et la garde. Entre les tours 9 et 12, sa somme
théorique vaut 25 % des PV maximum, avec de petits écarts d'arrondi. Le jeu doit
donc éprouver aussi les stratégies lentes et économes en copies.

## 7. Neuf cartes candidates, avec dépendances explicites

Toutes consomment une copie, maximum trois copies préparées par famille et une
utilisation par tour. Portée avec ligne de vue, cible ennemie unique sauf garde
personnelle. Aucun coût en point d'élément pour accéder à la carte. Coefficients
avant aptitudes, objets, classe, défenses et arrondi.

| Carte | Affinité / rareté | PA / portée | Composantes de base | Perfectionnement |
|---|---|---|---|---|
| Disque d'aube | Commune / normale | 2 / 2–4 | .80P magique Soleil | .95P |
| Fil d'eau | Commune / normale | 1 / 1–3 | .35P magique Eau | .45P |
| Tison de poche | Commune / normale | 1 / 1–2 | .30P magique Feu + brûlure .10P×2 | Impact .40P ; candidat à revoir avec Braises/Pyre |
| Pavé levé | Commune / normale | 2 / 2–3 | .85P physique Terre | 1P |
| Dette de rive | Assassin / normale | 2 / 1–2 | .60P physique Nuit + .35P garde Eau | Garde .50P |
| Talus vivant | Gardien / normale | 2 / 1–2 | .70P physique Soleil + .45P garde Terre | Garde .60P |
| Flèche de ressac | Arpenteur / normale | 2 / 2–4 | .55P physique Eau, pousse 1 ; si déplacement réussi : .30P garde Vent | Garde .45P |
| Cendre blanche | Thaumaturge / normale | 2 / 1–3 | .45P magique Feu + .30P garde Soleil | Impact .60P |
| Révélateur | Commune / élite | 1 / 1–3 | .20P magique Nuit ; exposition Soleil -10 points, un prochain impact solaire consommable, durée 2 activations | Impact .35P |

Les quatre premières comblent des accès simples. Les suivantes éprouvent le
modèle de composantes multiples. Révélateur dépend des futurs paquets élémentaires
et ne peut pas être implémenté comme un simple bonus de dégâts actuels.

Dette de rive à P=40 illustre un vrai arbitrage : 14 Nuit donnent 30 dégâts et 14
garde ; 7 Nuit/7 Eau donnent 28 et 17 ; 14 Eau donnent 24 et 18. Ni dégâts ni garde
ne représentent la même utilité dans toutes les situations. L'Assassin conserve
son passif d'isolement, le Gardien qui trouve la carte conserve le sien.

## 8. Équipements, reliques et bestiaire candidats

Six amulettes doubles, palier 2, prix de départ 65, +8 % dans chacun des deux
éléments : Scories Terre/Feu ; Étincelles Feu/Vent ; Ressac Vent/Eau ; Léthé Eau/Nuit ;
Éclipse Nuit/Soleil ; Argile claire Soleil/Terre. Ces paires servent d'échantillon,
elles n'interdisent pas les autres. Même slot que les sceaux mono +12 % : on choisit
entre intensité et couverture. Le prix est une hypothèse à comparer en campagne.

Trois reliques, règles complètes dans le JSON :

- **Empreinte de rive** : après deux familles offensives consommées successivement
  de dominantes de dégâts différentes dans le tour, .20P de garde, une fois/tour.
  Les cartes non admissibles entre les deux sont ignorées. Bonus non amplifié par maîtrise ou
  Protection ; actions permanentes, réactions et cartes neutres exclues.
- **Vase du surplus** : une fois/combat, si une garde consommable dépasse le
  plafond d'au moins .20P, piocher une copie déjà possédée. Aucune création ; limite
  de main respectée. Déclenchement dépensé seulement si une carte est piochée.
- **Balise inverse** : après une poussée/traction réussie d'au moins une case par
  une carte, récupérer 1 PM déjà dépensé, une fois/tour, sans dépasser son maximum.

Quatre traits d'ennemis : Peau de cendre Feu +15/Eau -10 ; Croûte claire Soleil
+15/Nuit -10 ; Appui stable réduit d'une case la première poussée/traction ; Peau
ventilée réduit de 25 % Brûlure/Saignement sans raccourcir leur durée. Les règles
de résistance, cumul, boss, expiration et affichage sont dans le contrat.

Le but est de varier les réponses utiles. On n'attribue pas à tous les ennemis une
immunité, six résistances élevées et des PV supplémentaires en même temps.

## 9. Prochain lot que je recommande

Priorité : couverture offensive Soleil, transparence des aperçus, continuité de
l'investissement après consommation et distribution des équipements. Ensuite,
cartes à composantes multiples et objets doubles. Résistances élémentaires et
nouveaux statuts arrivent après le contrat de paquets, pour que l'aperçu, le calcul
et les déclenchements parlent exactement le même langage.

Avant une publication : comparer les mêmes graines avec des départs légaux natifs,
hybrides et alternatifs, puis une traversée continue incluant achats, copies
consommées et adaptation. Mesurer la compréhension humaine des aperçus. Les
expériences actuelles permettent de décider quoi tester ensuite ; elles ne donnent
pas encore un classement définitif des classes.

## 10. Résultats mesurés et preuves

Exécution finale : [résumé strict](../../../artifacts/dev/20260929-233559-prototype-v1-passe-rive-3ea96521/summary.json),
[observations complètes](../../../artifacts/dev/20260929-233559-prototype-v1-passe-rive-3ea96521/observations.json),
[journal moteur](../../../artifacts/dev/20260929-233559-prototype-v1-passe-rive-3ea96521/probe.engine.log).
Durée 451,5 secondes, sortie moteur 0, aucun diagnostic moteur : **PASS**.
24 essais terminés, 202 lancers joueur sans échec, 100 lancers ennemis, 16 captures.
19 victoires et cinq observations arrêtées à la limite ; aucune défaite observée.
Ces nombres décrivent cette matrice, pas un taux de victoire généralisable.

Premier combat : douze victoires en deux tours, avec 108–110 PV sur 110 avant
le gain de niveau. Selon la classe et l'allocation, deux à quatre copies consommées.
Ce tutoriel n'est pas assez discriminant pour valider les répartitions.

Salle élite, quatre ennemis initiaux totalisant 264 PV. Tous les départs : 240 PV,
P=34, paquet préparé de quinze copies. Les PV du tableau excluent le soin automatique
de +50 dû au passage au niveau 6 après victoire. Ils sont reconstitués en retranchant
ce delta à la mesure de fin ; les deux valeurs sont conservées dans le JSON.

| Classe | Répartition | Issue / tour | PV du héros | PV ennemis restants | Copies consommées |
|---|---|---|---:|---:|---:|
| Assassin | Nuit 12 | Victoire T6 | 193 | 0 | 10 |
| Assassin | Nuit 6 / Soleil 6 | Victoire T6 | 191 | 0 | 10 |
| Assassin | Soleil 12 | Victoire T6 | 193 | 0 | 10 |
| Gardien | Terre 12 | Arrêt après T6 | 126 | 5 | 11 |
| Gardien | Terre 6 / Soleil 6 | Arrêt après T6 | 122 | 5 | 11 |
| Gardien | Soleil 12 | Arrêt après T6 | 138 | 29 | 11 |
| Arpenteur | Vent 12 | Victoire T3 | 147 | 0 | 6 |
| Arpenteur | Vent 6 / Soleil 6 | Victoire T3 | 147 | 0 | 6 |
| Arpenteur | Soleil 12 | Victoire T3 | 115 | 0 | 6 |
| Thaumaturge | Eau 12 | Victoire T6 | 76 | 0 | 9 |
| Thaumaturge | Eau 6 / Soleil 6 | Arrêt après T6 | 91 | 14 | 10 |
| Thaumaturge | Soleil 12 | Arrêt après T6 | 111 | 43 | 11 |

Lecture prudente : les PV préservés d'un personnage qui n'a pas terminé son combat
ne sont pas directement comparables à ceux d'un vainqueur. Le Gardien n'est pas
déclaré incapable de gagner : il lui reste jusqu'à 5 PV ennemis dans deux essais.
La politique ne gère pas spécifiquement les commandes de salle.

L'Arpenteur bénéficie fortement du contexte spatial. Dans l'essai Vent, les actions
enregistrées retirent 164 PV ennemis ; le journal attribue les **100 autres au
terrain** (26 + 25 + 26 + 23). Sa victoire rapide ne démontre donc pas que ses
coefficients de cartes sont globalement excessifs. À l'inverse, la survie de
l'Assassin Soleil avec un départ Nuit ne prouve pas qu'un répertoire Soleil
complet existe : ses dégâts de base, son passif, sa spécialisation et la salle
continuent à produire de la valeur.

Les 1 728 comparaisons Godot/Python concordent : 48 cartes × deux versions
(base/perfectionnée) × trois niveaux (1/6/12) × six investissements monoélément.
Elles vérifient l'impact direct sans condition, à distance 2, sans classe, objet ou
spécialisation, et sa réduction à 20 % de défense. Les cartes sans impact direct
produisent zéro ; ce décompte ne prétend pas vérifier tous leurs effets différés.
Les calculs des reliques et candidats sont des projections arithmétiques séparées.
Le fichier candidat satisfait 246 contrôles de structure et de cohérence.

Le survol tactique a révélé une vue libérée après la mort d'un centurion. Correction
dans `battle/tactical_hover_preview.gd` : vérifier l'instance **avant** l'affectation
typée. Un cas de régression laisse volontairement une vue détruite dans le registre.
[Suite ciblée : 10 tests, 37 assertions, aucun échec](../../../artifacts/dev/20260929-232932-test-test_unit_test_tactical_readability.gd-827d5ce9/gut-strict-report.json).
Le format des deux fichiers modifiés et du nouveau harnais est contrôlé.

Validation complémentaire terminée : [suite Cartes complète](../../../artifacts/dev/20260929-234438-test-cards-b2d3418b/gut-strict-report.json)
**PASS, 356 tests, 34 593 assertions, zéro échec, zéro erreur moteur**. Elle couvre
notamment les contrats de progression, effets, copies, aperçu, intégration et VFX
présents dans le manifeste. La suite globale du dépôt et les autres gates de CI
n'ont pas été rejouées pour cette étude ; ce PASS ne les remplace pas.

Les captures `thaumaturge_d06_start.png` et `assassin_d06_end.png` ont été inspectées :
Passe-rive est visible, les cartes de classe sont présentes et la scène affiche
la victoire. La bannière de début de tour masque une partie du plateau dans la
première capture ; ces images ne certifient pas une revue exhaustive du HUD.

Les essais préparatoires en échec restent conservés : premier accès incorrect à
la vue dans le harnais, puis ordre des paramètres d'aire inversé dans sa politique,
puis défaut réel de survol. Leurs sorties ne servent pas de preuve d'équilibrage.
Un premier test ciblé a aussi croisé l'ajout de deux SVG par un autre travail ;
après réimport, la même suite passe. Le dépôt a avancé de `86018f9c` à `0cde78b2`
pendant l'étude ; les sources numériques analysées sont identifiées par SHA-256
dans `resultats.json`. Aucun travail étranger n'a été réinitialisé.

Reproduction depuis la racine :

```powershell
./tools/consumable_cards/verify_prototype_v1.ps1
./dev.ps1 test test/unit/test_tactical_readability.gd
python docs/design/prototype_v1_epreuve_2026-09-29/analyse.py --runtime artifacts/dev/<nouvelle-execution>/observations.json
```

`-Class assassin` limite le harnais à six essais. Un timeout, un rapport incomplet,
une erreur moteur ou un lancer déclaré en échec empêche le verdict strict PASS.
