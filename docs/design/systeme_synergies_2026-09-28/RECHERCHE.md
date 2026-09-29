# Ce qui crée réellement un build — enquête comparative

Recherche du 28 septembre 2026. Les règles, intentions de développeurs, témoignages
et propositions pour Dungeon Draft sont distingués. Aucun de ces jeux n'a été
exécuté pour cette enquête ; il s'agit d'une lecture de règles, fiches de sorts,
correctifs et discussions, complétée par des calculs conditionnels. La vérification
des sources ne vaut pas mesure de leur métagame.

## 1. Baldur's Gate 3 : une statistique n'est pas nécessairement un bonus de dégâts

Le modificateur d'incantation dépend de la classe qui fournit le sort. Il intervient
dans l'attaque magique ou dans le DD de sauvegarde : `8 + maîtrise + modificateur`.
Il ne s'ajoute pas automatiquement aux dégâts de tous les sorts. Le multiclassage
partage certaines ressources mais conserve des contraintes de niveaux de classe.
La concentration limite à un seul effet de concentration actif : c'est une décision
de maintien et d'opportunité, pas une seconde couleur de dégâts.
[Règles communautaires des sorts](https://bg3.wiki/wiki/Spells),
[concentration](https://bg3.wiki/wiki/Concentration).

Larian présente officiellement le multiclassage comme une manière de combiner
les classes et retire les prérequis de caractéristiques du jeu de table ; la
réattribution permet l'expérimentation. Cela ne signifie pas que tout assemblage
est équivalent : investir un niveau ici retarde ce qu'on débloque ailleurs.
[Community Update 21, 12 juillet 2023](https://baldursgate3.game/news/community-update-21-forging-your-legacy_77).

Exemple lu au niveau du sort : Création d'eau coûte une action et un emplacement
de niveau 1, applique Mouillé ; Rayon de givre coûte une action, inflige 1d8 aux
niveaux 1–4 et réduit le déplacement. Mouillé rend vulnérable au froid et à la
foudre, résistant au feu ; les résistances préexistantes modifient ce résultat.
[Création d'eau](https://bg3.wiki/wiki/Create_Water),
[Rayon de givre](https://bg3.wiki/wiki/Ray_of_Frost),
[Mouillé](https://bg3.wiki/wiki/Wet).

Calcul isolé, cible ordinaire, attaques réussies, sans critique : deux rayons
valent 9 dégâts moyens en deux actions ; eau puis rayon vaut aussi 9, en dépensant
un emplacement. Sur trois actions, eau puis deux rayons vaut 18 contre 13,5 pour
trois rayons. La préparation s'amortit dans le temps ou avec plusieurs acteurs.
Ce n'est ni une rotation optimale de BG3 ni une preuve qu'une telle préparation
serait rentable dans notre combat solo à quatre PA.

**À retenir :** coût d'installation, exclusivité d'entretien, délai d'accès aux
pouvoirs. Copier seulement Mouillé et des multiplicateurs manquerait ces contraintes.

## 2. Divinity Original Sin 2 : apprendre, renforcer et déclencher sont trois axes

Explosion de cadavre demande Pyrokinésie 1 et Nécromancie 1, un cadavre, un point
d'action et un emplacement de mémoire. Elle inflige des dégâts physiques. Les
dégâts physiques profitent de Warfare : investir dans les deux écoles nécessaires
à l'apprentissage n'est donc pas nécessairement la meilleure manière d'augmenter
les dégâts. Le cadavre et son placement restent des ressources tactiques.
[Fiche communautaire](https://www.divinitywiki.com/index.php/DOS2:Corpse_Explosion),
[Warfare](https://divinity.fandom.com/wiki/Original_Sin_2_Warfare).

Un joueur rapporte un coefficient de 250 % après inspection des données ; un
guide le rapporte également. Nous n'avons pas extrait le jeu pour le confirmer.
Les sources consultées divergent sur le rayon : il n'est pas employé ici.
[Rapport du 30 mars 2020](https://www.reddit.com/r/DivinityOriginalSin/comments/frghc7/),
[guide de compétences](https://gamefaqs.gamespot.com/pc/179840-divinity-original-sin-ii/faqs/81674/skills).

Autre contrainte importante : les protections physiques et magiques sont
distinctes. Exemple volontairement simplifié : cible avec 100 PV et 40 de chaque
armure ; 40 physiques puis 40 magiques n'enlèvent aucun PV, alors que 80 physiques
en enlèvent 40. Un système peut proposer beaucoup d'hybridations et simultanément
inciter à concentrer le type de dégâts. Ce calcul ne tranche pas toutes les
compositions de groupe et ne mesure pas les contrôles.

Les joueurs décrivent des préparations de cadavres et regroupements très efficaces,
ainsi que des investissements minimaux dans certaines écoles pour leurs utilitaires.
Cela étaye deux hypothèses à vérifier chez nous : la géométrie donne de la valeur
au sort ; les petits investissements peuvent devenir des passages obligatoires.
[Exemple de pratique](https://www.reddit.com/r/DivinityOriginalSin/comments/vk7fw2/),
[discussion d'investissements](https://www.reddit.com/r/DivinityOriginalSin/comments/1hlcxge/).

**À retenir :** un prérequis bicolore seul peut produire une taxe d'accès, puis
un build qui maximise une troisième statistique universelle. Éviter ce piège.

## 3. Wakfu : les éléments peuvent changer le verbe du sort

Le devblog de mai 2015 sur les decks explique une volonté de faire choisir les
sorts et passifs disponibles, modifiables hors combat. Les passifs peuvent modifier
des mécaniques. Les nombres de places annoncés appartiennent à cette version
historique, pas à une description garantie du client actuel.
[Devblog Ankama relayé sur Steam](https://store.steampowered.com/news/posts/?appids=215080&enddate=1433928212).

La fiche communautaire Huppermage consultée, modifiée le 3 juillet 2026, montre
une hybridation qualitative. Papillons diurnes utilise les runes pour attirer,
pousser ou amplifier le déplacement. Éboulement peut retirer PA ou PM selon les
runes. Flèche de lumière modifie notamment sa zone, son coût ou sa poussée selon
la dernière rune. Des passifs comportent des contreparties : Antithèse échange un
gain de Brise Quadramentale contre une baisse des dégâts élémentaires. Cœur de
lumière peut reprendre la meilleure maîtrise : jouer plusieurs éléments ne prouve
donc pas à lui seul qu'il faut répartir ses investissements.
[Huppermage](https://wakfu.wiki.gg/wiki/Huppermage).

La page communautaire du correctif 1.92, daté du 16 juin 2026, précise notamment
les variantes Terre et Air de Flèche de lumière. Ce n'est pas une source officielle
indépendante ; les chiffres n'ont pas été contrôlés dans le client.
[Version 1.92](https://wakfu.wiki.gg/wiki/Update_1.92).

**À retenir :** un même sort peut changer de fonction. **À ne pas copier :** une
barre de quatre runes et une ressource supplémentaire par défaut. Notre main,
notre garde, nos surfaces et nos copies consommables constituent déjà des contraintes.

## 4. Waven : le déclencheur exact compte autant que la statistique

L'étude précédente avait comparé les fiches, passifs, équipements, compagnons et
rencontres. Elle est conservée dans [le dossier Waven](../waven_coeur_du_jeu_2026-09-26/README.md).
Pour les coefficients Pikuxala, elle utilise explicitement la version 0.17 PvE de
mai 2024 ; elle conserve les divergences entre bases communautaires au lieu de les
présenter comme des valeurs actuellement certaines.

La version 0.20, relue pour cette enquête, exige une permutation effectivement
réussie pour que Maîtrise Pikuxala donne Poussette. Cette nuance change le moteur
du build : tenter une action et réussir une transformation du plateau ne sont pas
des événements équivalents. La profondeur vient de la répétition possible, du
placement et du résultat de l'action, autant que de son coefficient.
[Correctif officiel du 8 octobre 2024](https://forum.waven-game.com/en/44-patchnotes-fr/6058-version-20-fr).

Les projets de refonte de 2025 et annonces Survie de 2026 ne sont pas additionnés
aux règles historiques pour fabriquer un système fictif. Les témoignages détaillés
du dossier précédent restent des expériences individuelles, pas une enquête
représentative des joueurs confirmés.

**À retenir :** les événements doivent être définis sans ambiguïté : déplacement
réussi, garde réellement perdue, marque effectivement consommée. Une action de
base de classe peut participer à cette grammaire sans devenir une carte gratuite.

## 5. Magic : un hybride peut signifier ET ou OU

Mark Rosewater distingue le multicolore qui exige deux couleurs et le mana hybride
qui accepte l'une OU l'autre. Les mages de guilde illustrent une autre construction :
accessibles avec une couleur, ils proposent des activations distinctes selon les
couleurs disponibles. L'accessibilité et l'expression complète de la carte sont
donc deux sujets différents.
[The History of Hybrid, Part 1, 12 février 2024](https://magic.wizards.com/en/news/making-magic/the-history-of-hybrid-part-1).

Application proposée : un sort reste jouable hors spécialisation ; une transformation
précise requiert un véritable investissement dans deux domaines. Tout sort à deux
icônes ne doit pas automatiquement exiger deux statistiques, ni être meilleur partout.

## 6. Gloomhaven : le temps et le partage rendent les éléments tactiques

Les infusions produites deviennent disponibles après le tour de leur créateur.
On ne produit donc pas un élément pour le consommer immédiatement dans ce même
tour ; leur disponibilité décroît. La FAQ officielle de la deuxième édition confirme
le décalage de production, notamment pour les monstres contrôlés. La présentation
Dized expose la règle d'infusion et sa dégradation.
[FAQ officielle 2e édition](https://cephalofairgames.github.io/gloomhaven2e-faq/),
[règles d'infusion](https://rules-test.dized.com/game/I7lEsCGOS2-zgol-ZRNf3g/QqqZSgPQSNWoHi88TtDLsg/elemental-infusion).

**À retenir :** générer puis consommer des éléments n'est pas une invention pour
Dungeon Draft. Ce serait une piste valable, mais il faudrait prouver son intérêt
pour un héros solo dont les cartes disparaissent. Nous ne la recommandons pas
comme couche supplémentaire à ce stade.

## Conclusion de conception

Les exemples convergent sur cinq contraintes : investissement exclusif, accès aux
outils, coût de préparation, condition réelle sur le plateau, sacrifice d'un autre
effet. Aucune ne se résume à « monter une couleur augmente les cartes de cette
couleur ». Notre proposition combine ces contraintes avec ce qui distingue déjà
Catabase : un stock de sorts consommé à l'échelle de la traversée, des intentions
ennemies et des rencontres sur un plateau resserré.

L'originalité recherchée est une cohérence de règles et de décisions ; il ne serait
pas sérieux de revendiquer que des éléments, variantes de sorts ou conversions de
ressources n'ont jamais existé ailleurs.
