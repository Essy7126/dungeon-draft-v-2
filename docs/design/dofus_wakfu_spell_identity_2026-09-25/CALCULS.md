# Calculs : ce que les nombres disent réellement

Modèles documentaires reproductibles avec `node docs/design/dofus_wakfu_spell_identity_2026-09-25/calculs.mjs`. Résultats détaillés et chronologies : [resultats_calcules.json](resultats_calcules.json). Ces exemples ne simulent pas les moteurs Ankama et ne démontrent pas un équilibrage global.

## 1. Coût affiché, coût net et trésorerie d'actions

Pour une séquence, le minimum de PA initiaux est le maximum de : **dépenses nettes des actions précédentes + coût à payer avant le remboursement de l'action suivante**. Les remboursements futurs ne financent pas rétroactivement un lancement.

| Exemple | PA payés | PA rendus | Coût net | PA initiaux nécessaires |
|---|---:|---:|---:|---:|
| Une Suspension sur Cadran | 4 | 2 | 2 | 4 |
| Deux Suspensions sur Cadran | 8 | 4 | 4 | **6** |
| Pointe-heure avec échange | 2 | 1 | 1 | 2 |
| Pointe-heure avec échange + Cours du temps sous Distorsion | 2 | 2 théoriques | 0 | **2** |
| Bombance Sobre → Saoul → Sobre | 2 | 1 | 1 | **2** |

Sources : fiches individuelles de [Suspension](https://wakfuli.com/encyclopedia/spells/xelor?spell=751), [Pointe-heure](https://wakfuli.com/encyclopedia/spells/xelor?spell=767), [Cours du temps](https://wakfuli.com/encyclopedia/spells/xelor?spell=785), [Bombance](https://dofusdb.com/sorts/bombance-12804). Le cumul de Pointe est une conséquence théorique des deux textes, pas un test dans le client. Il reste limité par cibles, usages et événements éligibles.

Deux Suspensions avec 6 PA : `6 → paiement 4 → 2 → remboursement 2 → 4 → paiement 4 → 0 → remboursement 2 → 2`. Avec 4 ou 5 au départ, le second lancement est bloqué dans ce modèle.

**Application à nos cartes consommables :** deux lancements à zéro PA net peuvent quand même détruire deux copies. Il faut suivre simultanément PA disponibles, copies disponibles, emplacements de main et plafond de déclenchement. « Gratuit en PA » ne signifie pas « gratuit dans la run ».

## 2. Rendement de dégâts : conserver le contexte

| Cas | Résultat brut calculé | Ce qu'il faut éviter d'en déduire |
|---|---|---|
| Aiguille N245 pour 1 / 2 / 3 / 4 PA restants | 111 / 55,5 / 37 / 27,75 dégâts par PA | Quatre sorts distincts ou quatre niveaux de puissance : c'est le même dégât avec un coût de reliquat. |
| Éclair obscur sur première cible seule | 97 / 5 = 19,4 par PA | « Mauvais sort » sans considérer le rebond. |
| Éclair avec rebond | (97 + 181) / 5 = 55,6, répartis sur deux ennemis | 278 dégâts sur la cible prioritaire : elle ne reçoit pas les deux lignes par défaut. |
| Martel'heure, hypothèse trois cibles toutes mémorisées et éligibles | 249 + 166 + 83 = 498 pour 9 PA | Rotation certifiée : durée de mémoire et répétitions exactes restent à tester. |

Sources : [Aiguille](https://wakfuli.com/encyclopedia/spells/xelor?spell=754), [Éclair obscur](https://wakfuli.com/encyclopedia/spells/xelor?spell=752), [Martel'heure](https://wakfuli.com/encyclopedia/spells/xelor?spell=749) et clarification historique d'Aiguille dans [1.92](https://wakfu.wiki.gg/wiki/Update_1.92).

Le rendement de zone peut monter alors que la capacité à éliminer une menace urgente reste faible. Il faut conserver les dégâts **par cible**, l'ordre et le moment d'application.

## 3. Géométrie et ordre

Avec lanceur `(3,3)` et cible `(5,3)` : déplacer la cible autour du lanceur aboutit en `(1,3)` ; déplacer le lanceur autour de la cible aboutit en `(7,3)`. La formule est `destination = 2 × centre − position`. Même coût et même mot « symétrie », deux résultats tactiques opposés. Cases occupées, murs et immunités sont exclus de cet exemple géométrique.

Poussière passe de `[3,5]` à `[5,7]`, puis `[7,9]` tant que sa progression n'est pas réinitialisée. Une cible demeurée à distance 3 disparaît de sa fenêtre après le premier usage. Augmenter les deux bornes n'est donc pas un pur buff. [Fiche Poussière](https://wakfuli.com/encyclopedia/spells/xelor?spell=753).

## 4. Retrait : une valeur nominale n'est pas un résultat garanti

Le modèle communautaire WAKFU donne `E = retrait nominal × clamp(0,5 + différence de Volonté / 200 ; 0 ; 1)`. Une cible gagne 10 Volonté par PA/PM effectivement perdu jusqu'à la fin de son tour. Source : [règles générales MethodWakfu](https://methodwakfu.com/bien-debuter/informations-generales/).

Pour un paquet nominal de 2, avec différences de Volonté −100 / −50 / 0 / +50 / +100 : retraits attendus 0 / 0,5 / 1 / 1,5 / 2. Deux paquets sur la même cible initialement à égalité donnent 1 puis 0,9 attendus, soit **1,9** ; sur deux cibles fraîches : **2**. Hypothèses : assez de PA, pas d'autre modificateur, pas de remise à zéro entre les deux. Ce n'est pas la rotation exacte de Ralentissement, qui modifie lui-même la Volonté.

Pour notre jeu, observer le nombre d'actions dangereuses réellement empêchées : passer de 5 à 4 PA ne vaut pas passer de 4 à 3 si une attaque en exige 4. Le choix du coût des sorts ennemis fait partie de l'équilibrage de l'entrave.

## 5. Protection : montant, probabilité, calendrier

À N245, Rempart WAKFU affiche `166 × ennemis au contact` : 166, 332, 498 ou 664 pour un à quatre ennemis. L'Orbe affiche 499 si sa condition de non-dégât tient. Avec une probabilité hypothétique de réussite de 50 %, son armure moyenne serait 249,5 — sans compter son autre bénéfice, son timing et ses modificateurs. Cela n'établit aucune supériorité générale. [Rempart](https://wakfuli.com/encyclopedia/spells/feca?spell=6980), [Orbe](https://wakfuli.com/encyclopedia/spells/feca?spell=6978).

Fermentation DOFUS à N200 donne 480 par application. Deux vagues de 800 sur ses deux fenêtres peuvent voir 960 dégâts absorbés ; une seule rafale initiale de 960 n'en voit absorber que 480. Additionner les deux boucliers en « 960 immédiats » change faussement la survie. [Fermentation](https://dofusdb.com/sorts/fermentation-12819).

Dans le modèle continu de résistance WAKFU, la fraction reçue vaut `0,8^(R/100)`. Un gain de 100 réduit le **restant** de 20 % : 100 → 80 à R0, 80 → 64 à R100, 40,96 → 32,768 à R400. Arrondis par paliers et plafond des joueurs sont exclus ici. Trêve confère ce gain aux deux camps : elle peut sauver un ennemi que l'on voulait finir. [Règles générales](https://methodwakfu.com/bien-debuter/informations-generales/), [Trêve](https://wakfuli.com/encyclopedia/spells/feca?spell=6983).

De même, ajouter 50 points de DI à 100 déjà présents fait passer le facteur de 2 à 2,5 : **+25 % relatifs**, pas +50 %. Un bonus additif ne doit pas être confondu avec un multiplicateur final.

## 6. Calculs volontairement non produits

Pas de DPS total de Distorsion, de Synchro, de Rayon Obscur renforcé, ni de combo chiffré Six Roses : les coefficients ou branches nécessaires ne sont pas certifiés. Pas de classement PvM/PvP sur ces exemples. Le bon résultat d'un calcul dont l'entrée essentielle manque est « non déterminé ».
