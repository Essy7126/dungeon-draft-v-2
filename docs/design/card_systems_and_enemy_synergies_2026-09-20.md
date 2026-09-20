# Systèmes de combat et groupes ennemis — recherche complémentaire

20 septembre 2026. Complément de l'audit des runs Cartes.

## Direction retenue

La profondeur doit venir de ce que les unités peuvent produire, transférer,
consommer, transformer et combiner. Connaître une prochaine attaque n'est pas
le moteur du gameplay recherché. Les propositions ci-dessous fonctionnent avec
des ennemis réactifs et des capacités immédiates ; l'interface explique leurs
règles et leurs états présents.

Un bon ennemi change la valeur des décisions du joueur. Un bon groupe change
encore cette valeur lorsque ses membres sont rapprochés, séparés, affaiblis ou
éliminés. Il faut pouvoir retourner une interaction contre ses utilisateurs.

## Tests supplémentaires

### Runs appariées : privilégier la défense suffit-il ?

12 nouvelles runs, mêmes classes, départs et graines 2401–2403. Seul le pilote
de combat change : sous 50 % de PV, il essaie une garde disponible avant sa
recherche habituelle de dégâts. Il ne devient pas un expert des combos.

53 combats réels, 252 activations du héros. Processus terminé avec code 0,
12 résultats présents, aucune erreur rapportée ni erreur/avertissement moteur.

| Classe | Politique précédente : graines 2401 / 2402 / 2403 | Priorité défensive : mêmes graines |
|---|---|---|
| Assassin | 5 / 5 / 3 | 5 / 6 / 3 |
| Gardien | 3 / 3 / 3 | 3 / 6 / 3 |
| Arpenteur | 6 / 6 / 8 | 6 / 6 / 6 |
| Thaumaturge | 6 / 20 gagné / 5 | 6 / 6 / 6 |

Trois parcours progressent davantage, deux moins loin, sept atteignent la même
profondeur. Aucun ne gagne avec cette politique. Le simple ajout d'une priorité
défensive ne résout pas le problème. Il ne faut en déduire ni que défendre est
inutile, ni que les classes sont injouables : le timing de la défense et son
interaction avec les autres cartes comptent.

[Résultats](../../artifacts/dev/card_synergy_survival_20260920/report.json),
[agrégation](../../artifacts/dev/card_synergy_survival_20260920/analysis.json),
[journal](../../artifacts/dev/card_synergy_survival_20260920/engine.log).

Commande : sonde `class_balance_probe.tscn`, arguments
`label=card_synergy_survival_20260920 seeds=2401,2402,2403 class_policy=survival legacy=false`.
Le mode sans argument conserve la politique précédente.

### Exposition des synergies dans les 99 combats initiaux

Comptage des rosters des quatre nouvelles classes, pas des anciens départs :

| Rôle | Combats où présent | Profondeurs observées |
|---|---:|---|
| Conducteur | 3 | 8 |
| Collecteur et porteur | 2 chacun | 12 |
| Officiant | 9 | 6 |
| Fondeur | 2 | 13 |
| Déplaceur | 6 | 13, 15, 17 |
| Oracle, Alpha, Guérisseur | 0 | — |

Le contenu disponible et le contenu effectivement rencontré sont deux choses
différentes. Les morts précoces et les routes choisies limitent cette exposition.
Ces chiffres ne disent pas que les rôles absents n'existent pas.

### Comparaisons contrôlées et défaut d'intégration confirmé

24 tests tactiques passent, 224 assertions : 20 tests existants et quatre nouveaux
scénarios, dont un diagnostic de raccordement à la rencontre réelle.
[Rapport strict](../../artifacts/dev/20260920-202151-test-test_unit_test_card_synergy_ablation.gd-34d56afe/summary.json),
[observations du moteur](../../artifacts/dev/20260920-202151-test-test_unit_test_card_synergy_ablation.gd-34d56afe/gut.engine.log).

- Avec les mêmes sorts et positions, le monstre choisit sa morsure sur terrain
  neutre, puis la poussée lorsqu'un feu occupe la case d'arrivée. Le contexte
  transforme donc réellement la meilleure action selon son évaluation.
- La marque du Conducteur disparaît lorsque sa source est tuée dans la grille.
  Le test respecte l'activation de recharge initiale du sort. Une première
  exécution l'avait omise : cet échec de montage a été corrigé, pas le gameplay.
- Avec son kit complet, l'Officiant choisit l'invocation à 2, 4 et 6 cases dans
  le champ de test isolé. L'absence d'invocations en run ne s'explique donc pas
  simplement par une préférence absolue de son IA pour les dégâts.
- **Défaut confirmé sur la vraie rencontre `d06_0`, graine 2401 :** quatre ennemis
  initiaux, plafond de rencontre quatre, alors que le sort annonce six. Le
  contrôleur renvoie `team_limit`. En ne laissant qu'un survivant dans le
  contrôle d'admission, il renvoie encore `summon_type` : le nouveau type
  `ecosystem_servant` n'est pas accepté par `EncounterRuntimeState`, qui ne
  gère que `normal` et `chief`. Les budgets d'invocation des rencontres ordinaires
  sont en outre initialisés à zéro.

Ce dernier scénario enregistre les motifs de rejet ; son PASS certifie le
montage et la collecte du diagnostic, **pas** le bon fonctionnement de
l'invocation en run. Réparer ce raccordement constitue une priorité avant de
bâtir d'autres synergies d'invocation : type, budget, plafond, comptabilité et
résolution doivent partager le même contrat. Le défaut reste non corrigé dans
cette passe d'audit. Les anciens tests isolés étaient insuffisants pour le révéler.

## Lecture du système actuel

**À conserver et approfondir :** lien collecteur/porteur avec rayon réel ; marque
du Conducteur qui disparaît avec sa source ; suivi de mouvement et déplacement
forcé ; boucliers avec sources ; altérations limitées ; réactions élémentaires
du moteur commun ; décisions ennemies réévaluées après chaque action.

**Limites :** beaucoup d'interactions ajoutent encore des dégâts ou de la garde.
Les nouveaux kits ennemis ajoutent souvent une technique à un rôle existant,
sans nouvelle ressource ni dépendance de groupe. Les ennemis utilisent un
répertoire de sorts avec contraintes et recharges, pas la même main de cartes
que le joueur. Ce n'est pas un problème en soi : imposer une pioche à tous les
ennemis n'est pas nécessaire pour créer des identités fortes.

Le moteur sait déjà faire feu + eau → vapeur, feu sur glace → eau et choc sur
eau. Cela ne signifie pas que les decks actuels donnent suffisamment de moyens
de construire ces situations. Il faut vérifier l'accès aux producteurs et
consommateurs avant d'ajouter de nouvelles réactions.

## Recherches : trois principes applicables

**Cassette Beasts — chimie des états.** Le studio décrit des interactions de
types produisant des états bénéfiques, néfastes ou une transformation de type,
avec la possibilité de favoriser volontairement un allié. L'ordre et la cible
changent donc le résultat, au-delà du multiplicateur de dégâts. Application
proposée : transformer un statut ou une dalle, transférer une altération, rendre
un ennemi dangereux pour son propre groupe.
[Article original du développeur, 2020](https://www.cassettebeasts.com/2020/05/11/chemistry/).

**Monster Train — ressource liée au lieu et à la composition.** Les Wurmkin
utilisent des Charged Echoes pour leurs dégâts et le soutien du groupe d'un
étage. Application proposée : une réserve locale alimentée par certaines
actions et consommée par différents rôles, que le placement permet de priver
ou de détourner. Pas besoin de copier les étages du jeu.
[Présentation officielle des clans, section Wurmkin](https://www.themonstertrain.com/clans).

**Battle Brothers — une identité de groupe, avec une faiblesse structurelle.**
Les anciennes légions combattent sur deux rangs : boucliers devant, armes
d'hast derrière. Leur puissance dépend de la formation, que le terrain difficile
gêne. Application proposée : des groupes dont séparer les membres est une
solution viable, et dont le soutien ne se résume pas à tuer d'abord le soigneur.
[Journal de développement original, 2016](https://battlebrothersgame.com/dev-blog-85-ancient-dead-part/).

Ces références inspirent les propositions suivantes. Elles ne constituent pas
une preuve d'équilibrage pour notre jeu.

## Quatre systèmes à développer dans un ordre maîtrisé

### 1. Liens entre unités

Un lien définit source, destinataire, portée et effet. Exemples : partager une
portion de garde, acheminer une ressource, transférer une altération. Déplacer
une unité, éliminer la source ou neutraliser le lien donne des solutions
distinctes. Réutiliser la logique du collecteur comme première base.

Commencer par deux liens par unité au maximum, sans transmission récursive.
Pas d'immunité totale tant qu'un soutien est vivant.

### 2. États que l'on peut consommer ou transformer

Une marque peut servir à frapper, à se déplacer ou à récupérer une carte ; la
consommer ferme les autres options. Une brûlure peut être laissée pour l'usure,
transférée ou consommée pour produire une zone. Une garde peut protéger ou
alimenter une collision. Les mêmes règles doivent fonctionner entre classes.

Normaliser d'abord les catégories d'états : l'incohérence actuelle entre
`class_slow`, `class_root` et `ecosystem_ice` empêche déjà des combinaisons attendues.

### 3. Ressources de groupe situées sur le plateau

Des cendres, oboles ou charges existent sur une dalle ou dans un porteur.
Certains ennemis produisent, d'autres transportent, d'autres consomment.
Le joueur peut déplacer le porteur, occuper la ressource ou la convertir.

Commencer par une seule ressource dans une famille de rencontres. Plafond
commun, dépenses effectives et destruction possible ; pas de génération infinie
par les invocations ou les effets déclenchés par d'autres effets.

### 4. Interaction avec la main, réservée à certains ennemis

Un adversaire peut donner une carte temporaire à double usage, taxer un type
de carte ou copier un effet admissible. Le joueur peut exploiter cette règle
en changeant son ordre de jeu. Cela crée une identité propre à la run Cartes.

Interdire la destruction permanente d'une carte, le verrouillage de toute la
main et la copie récursive. Garder une réponse par placement, dégâts ou dépense
de ressource ; la solution ne doit pas exiger d'avoir dropé une carte précise.

## Six groupes proposés — concepts à prototyper, pas contenu déjà jouable

### Convoi des oboles : flux et détournement

**Porteur, Collecteur, Débiteur.** Le Porteur détient une réserve visible de trois
oboles. Le Collecteur en dépense une pour soigner ; le Débiteur en dépense une
pour gagner un PA. Un transfert n'est possible qu'à courte distance.

Sorts : **Acheminer** transfère une obole à un allié ; **Solder** consomme une
obole pour dissiper un état ; **Saisie** déplace une obole au sol avec son porteur.

Le joueur peut épuiser la réserve, séparer le convoi ou récupérer une obole au
sol pour financer sa recomposition. Tuer le Porteur laisse sa réserve accessible
aux deux camps : ce n'est pas toujours le meilleur premier kill.

### Tisserandes du Léthé : redistribuer et rompre

**Tisseuse, Garde liée, Dévoreur de liens.** La Tisseuse relie deux alliés ; une
partie de la garde créée est partagée. Le Dévoreur peut consommer un lien pour
se soigner, sacrifiant la protection future du groupe.

Sorts : **Nouer** crée le lien ; **Découdre** transfère une altération entre ses
extrémités ; **Tension** échange deux positions liées si les cases sont valides.

Choix : concentrer ses coups, séparer les unités pour rompre le lien, ou déposer
une altération que le groupe risque de déplacer vers une cible plus vulnérable.
La rupture ne déclenche pas automatiquement des dégâts sur le héros.

### Verriers de braise : changer la matière

**Amphorier, Souffleur, Ramasseur.** L'Amphorier pose une substance inflammable ;
le Souffleur transforme les surfaces ; le Ramasseur consomme les résidus pour
fabriquer de la garde. La consommation retire réellement la surface du plateau.

Sorts : **Épandre** crée deux dalles ; **Vitrifier** convertit une braise en
éclats consommables lors d'une traversée ; **Recueillir** enlève une surface
pour une ressource défensive.

Choix : exploiter leurs surfaces contre eux, tuer le transformateur ou laisser
le Ramasseur nettoyer un passage dangereux. Feu/eau/glace réutilisent les
réactions existantes ; les éclats sont une extension ultérieure. Plafonner le
nombre de surfaces pour éviter un plateau entièrement recouvert.

### Chambre des échos : influencer l'adversaire par son ordre de jeu

**Scribe, Copiste, Reliquaire.** Le Scribe mémorise le dernier effet admissible
joué par le héros ; le Copiste en utilise une version limitée. Le Reliquaire
protège leur réserve d'échos mais peut être déplacé.

Sorts : **Empreinte** mémorise une catégorie simple ; **Reprise** joue une version
affaiblie ; **Effacer** consomme la mémoire pour une protection.

Choix : terminer sa séquence par un petit effet, profiter d'une mémoire défensive
pour attaquer, ou détruire la réserve. Copier des catégories compatibles, jamais
une ressource `Spell` arbitraire : pas d'invocations, de copie de copie ou de stase.

### Phalange d'airain : la formation comme ressource

**Porte-égide, Lancier, Percuteur.** La garde du Porte-égide bénéficie à un voisin ;
le Lancier peut frapper au travers d'un allié lié ; le Percuteur consomme une
portion de garde pour renforcer un déplacement forcé.

Sorts : **Prêter le rempart**, **Percer le rang**, **Dépenser l'appui**.

Choix : créer un trou, attirer le Lancier hors de la couverture, user la garde
ou exploiter une collision. La dépense de garde expose le groupe. Réutiliser
adjacence et lignes de cases, sans ajouter un système d'orientation à ce stade.

### Cour des cendres : exploiter les morts sans boucle infinie

**Récolteur, Réanimateur, Serviteur.** Une mort laisse une essence consommable.
Le Récolteur la déplace ; le Réanimateur choisit entre relever un serviteur
affaibli et transformer l'essence en protection.

Sorts : **Ramasser**, **Rendre un souffle**, **Disperser les restes**.

Choix : changer l'ordre des kills, prendre le contrôle des restes, pousser un
ennemi loin de son carburant ou employer l'essence pour sa propre carte.
Un corps ne peut être relevé qu'une fois ; les unités relevées ne produisent
plus d'essence. Éviter que toute victoire impose simplement de tuer le réanimateur.

## Ce que ces groupes apportent aux cartes du joueur

Les cartes doivent manipuler les mêmes systèmes : **Rompre un lien**, **Déplacer
une charge**, **Consommer une marque**, **Transférer une altération**, **Échanger
deux positions**. Une carte de poussée devient alors utile dans plusieurs
rencontres pour des raisons différentes.

Associer certaines familles de drops aux groupes vaincus, avec probabilités
variables et possibilités de zéro carte. Le butin enseigne ce que l'ennemi vient
de montrer. Une carte joueur peut adapter une capacité ennemie ; il n'est pas
nécessaire de donner toutes les capacités adverses telles quelles.

## Priorité de prototypage

Préalable : corriger et tester en contexte de rencontre le contrat d'invocation
et les catégories de ralentissement. Ne pas mesurer la richesse d'un catalogue
avec des capacités que ses rencontres empêchent d'utiliser.

1. **Convoi** : approfondit un lien déjà fonctionnel ; teste une ressource partagée.
2. **Phalange** : approfondit garde et déplacement ; peu de primitives nouvelles.
3. **Verriers** : relie les cartes à la chimie de terrain déjà présente.
4. **Tisserandes**, puis **Échos/Cendres** : nécessitent davantage de règles de
   propriété, copie et cycle de vie ; à introduire après stabilisation du socle.

Pour chaque prototype, comparer le groupe complet à sa version sans lien ou
sans ressource, avec les mêmes statistiques et positions. Puis déplacer un
membre sans le tuer et changer l'ordre de deux actions du joueur. Une profondeur
réelle doit produire des choix et des résultats différents dans ces expériences.

Mesurer efficacité de trois réponses (dégâts, placement, états), usage réel des
capacités distinctives, dépendance aux cartes rares et longueur des tours. Donner
au moins deux réponses accessibles ; aucun groupe ne doit exiger un drop précis.
Une rencontre introduit au maximum deux règles de groupe nouvelles à la fois.
