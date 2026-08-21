# Identité des objets et premier ensemble de huit objets

Statut : proposition de conception avant implémentation  
Périmètre : première phase d’équilibrage avec un seul héros jouable  
Rareté de référence : commune, sans niveaux ni variantes

## 1. Objectif

Les objets doivent créer des décisions de jeu qui restent valables quel que soit le héros choisi. Ils ne doivent pas remplacer les améliorations de compétences ni dépendre de l’identité d’un sort.

Le premier ensemble contient exactement huit objets universels. Après chaque salle éligible, le système actuel en propose deux aléatoirement et le joueur en choisit un. Un objet déjà possédé ou déjà proposé pendant la run ne revient pas dans les offres.

Les valeurs ci-dessous sont des valeurs de départ destinées aux tests. Elles ne constituent pas l’équilibrage final.

Les huit objets sont des équipements passifs persistants : une fois obtenus, ils restent actifs pendant toute la run. Aucun objet de cet ensemble n’est consommé après son activation. Les mentions « une fois par tour » ou « une fois par combat » décrivent uniquement une fréquence de déclenchement qui se réinitialise automatiquement.

## 2. Frontière entre compétence et objet

### Une amélioration de compétence

Une amélioration de compétence agit sur un sort identifié ou sur une mécanique appartenant directement à ce sort. Elle peut notamment :

- modifier ses dégâts, son soin, son bouclier, sa portée, son coût ou sa zone ;
- ajouter une poussée, une collision, un état ou une cible supplémentaire ;
- changer la manière dont ce sort se lance ou se résout ;
- créer une synergie entre deux sorts nommés du même personnage.

### Un objet

Un objet agit sur une règle transversale du combat ou de la run. Il réagit à un événement générique tel qu’un déplacement, une dépense de PA, une attaque reçue, une élimination ou une fin de salle. Il ne connaît ni `spell_id`, ni discipline, ni branche de compétences.

Un objet peut influencer indirectement l’utilisation des compétences, mais il ne modifie pas leurs données de base.

### Test de décision

Avant d’accepter un effet d’objet, appliquer ces quatre questions :

1. L’effet fonctionne-t-il avec tous les héros et toutes leurs compétences ?
2. L’effet peut-il être décrit sans nommer un sort ?
3. L’effet change-t-il une décision du joueur plutôt qu’une simple valeur sur une fiche ?
4. Le joueur peut-il comprendre clairement quand l’effet se déclenche ?

Si une réponse est « non », l’effet doit être réécrit ou déplacé dans les améliorations de compétences.

## 3. Règles communes au premier ensemble

- Les huit objets sont universels et n’utilisent pas `compatible_character_ids`.
- Chaque objet occupe l’emplacement Accessoire pendant cette première phase. Cela évite qu’un héros soit avantagé ou bloqué par un type d’arme ou d’armure.
- Aucun des huit objets n’est à usage unique, consommable ou détruit après activation.
- Aucun objet ne donne directement de dégâts, portée, poussée, soin ou bouclier à un sort.
- Aucun objet ne donne un bonus permanent brut de caractéristique.
- Les déclenchements limités « une fois par tour » se réinitialisent au début du tour du héros.
- Les déclenchements limités « une fois par combat » se réinitialisent au début de chaque salle de combat.
- Un effet ne peut pas se déclencher à partir des dégâts qu’il produit lui-même.
- Toute activation doit produire un retour visuel court sur le héros et sur l’icône de l’objet.
- Les objets ne se cumulent pas avec une seconde copie d’eux-mêmes, car une définition ne peut être obtenue qu’une fois pendant la run.

## 4. Les huit objets

### 1. Sablier fêlé

**Famille :** économie de PA  
**Effet :** la première fois par combat que le héros termine une action avec 0 PA, il récupère immédiatement 1 PA.  
**Intention :** permettre un tour exceptionnel et encourager le joueur à calculer précisément sa dépense de PA.  
**Limite :** une fois par combat ; le PA doit pouvoir être utilisé avant de terminer le tour.  
**Valeur initiale :** 1 PA.

### 2. Semelles du contrebandier

**Famille :** mobilité  
**Effet :** le premier déplacement volontaire de chaque tour coûte 1 PM de moins, avec un coût minimum de 0 PM.  
**Intention :** ouvrir des placements sans augmenter les PM maximum ni modifier la portée des compétences.  
**Limite :** ne s’applique pas aux poussées, téléportations ou déplacements forcés.  
**Valeur initiale :** réduction de 1 PM.

### 3. Égide patiente

**Famille :** défense et temporisation  
**Effet :** si le héros termine son tour sans avoir dépensé tous ses PA, les PA inutilisés sont convertis en bouclier jusqu’au début de son prochain tour.  
**Intention :** rendre une fin de tour prudente réellement intéressante au lieu d’obliger à dépenser toutes les ressources.  
**Limite :** le bouclier temporaire disparaît au début du prochain tour et ne se cumule pas d’un tour à l’autre.  
**Valeur initiale :** 2 points de bouclier par PA inutilisé, maximum 6.

### 4. Cuirasse d’épines

**Famille :** riposte défensive  
**Effet :** la première fois par tour que le héros perd des PV à cause d’un ennemi adjacent, cet ennemi subit des dégâts directs.  
**Intention :** donner une valeur tactique au corps à corps sans renforcer une compétence offensive particulière.  
**Limite :** une fois par tour ; exige une perte réelle de PV après bouclier ; ne répond pas aux dégâts de terrain ni aux dégâts auto-infligés.  
**Valeur initiale :** 4 dégâts directs.

### 5. Dent du prédateur

**Famille :** récupération sur élimination  
**Effet :** la première élimination réalisée par le héros pendant son tour lui rend une partie de ses PV maximum.  
**Intention :** créer une décision entre sécuriser une élimination maintenant ou conserver ses ressources pour une autre cible.  
**Limite :** une fois par tour ; ne se déclenche pas sur une invocation alliée ou une destruction sans tueur attribué.  
**Valeur initiale :** 8 % des PV maximum, arrondis au supérieur.

### 6. Idole du dernier souffle

**Famille :** survie d’urgence  
**Effet :** la première fois par combat que le héros passe à 30 % de ses PV maximum ou moins après avoir subi des dégâts, il gagne un bouclier temporaire.  
**Intention :** offrir une fenêtre de sauvetage sans annuler la défaite ni ajouter une résurrection.  
**Limite :** une fois par combat ; ne se déclenche pas si l’attaque tue le héros ; le bouclier expire à la fin du prochain tour du héros.  
**Valeur initiale :** 15 % des PV maximum, arrondis au supérieur.

### 7. Pacte écarlate

**Famille :** risque contre puissance d’action  
**Effet :** au début de son tour, si le héros possède 40 % de ses PV maximum ou moins, il perd 5 % de ses PV maximum puis gagne 1 PA pour ce tour.  
**Intention :** permettre un style volontairement dangereux et créer une décision claire autour du maintien à faible vie.  
**Limite :** l’effet ne se déclenche pas si son coût réduirait le héros à 0 PV ; le PA disparaît à la fin du tour s’il n’est pas utilisé.  
**Valeur initiale :** coût de 5 % des PV maximum et gain de 1 PA.

### 8. Encens du geôlier

**Famille :** affaiblissement et contrôle  
**Effet :** le premier ennemi qui fait perdre des PV au héros pendant un combat perd 1 PA au début de son prochain tour.  
**Intention :** permettre au joueur de choisir quel ennemi attirera sa riposte de contrôle, sans modifier les dégâts ou les propriétés de ses compétences.  
**Limite :** une fois par combat ; exige une perte réelle de PV après bouclier ; ne répond pas aux dégâts de terrain, aux dégâts auto-infligés ou aux effets sans source ennemie ; la pénalité ne peut pas réduire les PA de l’ennemi sous 0.  
**Valeur initiale :** retrait temporaire de 1 PA au prochain tour de l’ennemi.

## 5. Couverture des décisions

| Objet | Question posée au joueur | Moment principal |
|---|---|---|
| Sablier fêlé | Puis-je organiser mes actions pour atteindre exactement 0 PA ? | Pendant le tour |
| Semelles du contrebandier | Quel premier déplacement exploite le mieux la réduction ? | Début du tour |
| Égide patiente | Dois-je agir davantage ou conserver des PA pour me protéger ? | Fin du tour |
| Cuirasse d’épines | Puis-je accepter le corps à corps pour provoquer une riposte ? | Tour ennemi |
| Dent du prédateur | Quelle cible dois-je achever pour récupérer ? | Pendant le tour |
| Idole du dernier souffle | Puis-je survivre et exploiter ma fenêtre de bouclier ? | Situation critique |
| Pacte écarlate | Le PA supplémentaire vaut-il le coût et le risque ? | Début du tour |
| Encens du geôlier | Quel ennemi ai-je intérêt à laisser me toucher en premier ? | Tour ennemi |

Les huit effets couvrent ainsi des moments différents et ne sont pas de simples variantes d’un même bonus numérique.

## 6. Présentation des cartes

Chaque carte doit afficher dans cet ordre :

1. le nom ;
2. une phrase d’effet exacte ;
3. la limite de déclenchement ;
4. les valeurs numériques mises en évidence ;
5. un mot-clé de famille facultatif, par exemple « Mobilité » ou « Risque ».

Les illustrations ne doivent contenir aucun texte de règle. Le texte reste fourni par la `Resource` afin de pouvoir être équilibré et localisé sans refaire l’image.

## 7. Conséquences techniques prévues

Le modèle actuel sait surtout appliquer des modificateurs de statistiques et de sorts. Il ne suffit pas pour ces huit effets événementiels.

L’implémentation devra introduire une définition data-driven des effets d’objet et un service de résolution abonné aux événements génériques du combat. Les valeurs, seuils et limites resteront dans les `Resource`; le service contiendra uniquement les règles communes d’exécution. Aucune branche ne devra tester un `item_id` particulier.

Le système actuel de paquet aléatoire, de deux propositions, de sélection unique, d’inventaire et de non-répétition peut être conservé sans mécanique de relance des récompenses.

## 8. Critères de validation avant équilibrage

- Chaque objet fonctionne avec un seul héros et sans donnée propre à une classe.
- Aucun effet ne modifie directement une `Spell` ou un `SpellModifier`.
- Deux propositions valides sont produites tant que le paquet le permet.
- Les activations limitées ne se produisent jamais deux fois pendant leur fenêtre.
- Les dégâts de riposte ne déclenchent pas une nouvelle riposte.
- Les effets temporaires expirent au moment annoncé.
- La sauvegarde de run conserve les objets et leurs états temporaires sans jamais retirer un objet après son activation.
- L’interface explique chaque activation sans demander au joueur de consulter un journal technique.
- Les valeurs peuvent être ajustées dans les `Resource` sans modifier le code.

## 9. Décision requise avant implémentation

Valider ou corriger les huit concepts et leurs valeurs initiales. Après validation, l’étape suivante sera la conception du modèle de données des effets d’objet, dans un seul fichier de code, avant la création des huit fichiers `.tres`.
