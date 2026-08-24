# Studio des personnages et compétences — tutoriel complet

Ce document décrit la visite interactive du Studio. Il s’adresse à un utilisateur qui connaît déjà les règles du jeu, mais pas forcément les outils de création.

## Ouvrir et utiliser la visite

Le bouton compact **?** de la barre d’outils ouvre le sommaire. **Parcours complet** commence au début ; un chapitre permet un accès direct. La visite contient **10 chapitres, 104 étapes et 33 fiches d’effets**.

Chaque page propose **Montrer dans le Studio**. Le Studio sélectionne l’objet utile, ouvre l’onglet correspondant et entoure la zone. Le passage à l’étape suivante reste entièrement manuel. En mode guidé, les explications et les champs essentiels sont visibles ; le mode avancé montre aussi les réglages techniques.

| Chapitre | Étapes | Sujet |
|---|---:|---|
| 1 · Bien démarrer | 8 | contexte, zones, modes, historique et raccourcis |
| 2 · Personnage | 8 | identité, caractéristiques, défenses et présentation |
| 3 · Discipline et XP | 7 | cycle de vie, sort racine, rangs et seuils |
| 4 · Graphe et choix | 8 | nœuds, branches, prérequis, exclusions et disposition |
| 5 · Sort de base | 13 | tous les réglages éditables d’un sort |
| 6 · Effets | 38 | paramètres communs, 33 effets et modificateurs historiques |
| 7 · Tester et analyser | 8 | validation, simulation, aperçu, analyse, comparaison et recherche |
| 8 · Sauvegarde sûre | 6 | copie, brouillons, revue, transaction et orphelins |
| 9 · Non éditable ici | 5 | propriétés volontairement absentes du formulaire |
| 10 · Exercice sandbox | 3 | entraînement isolé et restauration |

## 1 · Contexte et commandes

- **Run** choisit la partie dont le profil de progression est édité.
- **Héros** choisit le personnage de cette run.
- **Salle** appartient à la barre commune, mais n’a actuellement aucun effet sur les compétences.
- **Portée** affiche le contexte commun ; la sauvegarde des compétences reste attachée au profil run/héros.
- **Mode guidé** montre aides, exemples et champs essentiels.
- **Mode avancé** affiche aussi les réglages techniques utiles au type choisi. Il ne change aucune donnée à lui seul.
- **Comment fonctionne cet effet ?** explique en lecture seule qui est affecté, quand, pendant combien de temps et comment plusieurs exemplaires se combinent.
- **Annuler/Rétablir** utilisent l’historique local de la copie de travail.
- **Ctrl+F** ouvre la recherche globale.
- **Ctrl+S** ouvre la même revue détaillée que le bouton Sauvegarder.
- **Ctrl+Z**, **Ctrl+Y** et **Ctrl+Maj+Z** parcourent l’historique.
- Dans le graphe, **Ctrl+C**, **Ctrl+V** et **Ctrl+D** copient, collent et dupliquent ; **Échap** annule une liaison en cours.

Le catalogue permet une recherche par nom ou identifiant, ainsi que les filtres **Ressources invalides** et **Document modifié**.

## 2 · Paramètres du personnage

### Général

| Paramètre | Fonctionnement |
|---|---|
| Nom affiché | Nom visible par le joueur. Le modifier ne doit pas changer l’identifiant stable. |
| Description | Résumé du personnage et de son style de jeu. |
| PV maximum | Quantité de dégâts supportée avant la mort. |
| Initiative | Position du personnage dans l’ordre de jeu. |
| PA maximum | Budget d’actions disponible à chaque tour. |
| PM maximum | Budget de cases de déplacement. |
| Puissance d’attaque | Valeur de base consultée par les calculs qui l’emploient. |
| Force de déplacement | Puissance et résistance lors des poussées et attractions. |
| Armure | Réduit les dégâts physiques avec rendement décroissant. |
| Résistance magique | Réduit les dégâts magiques avec rendement décroissant. |
| Esquive | Probabilité d’annuler une attaque ; `0,15` signifie 15 %. |
| Chance critique | Chance propre au personnage, ajoutée à celle du sort. |
| Multiplicateur critique | `1,5` produit 150 % de la valeur normale. |

### Avancé et apparence

| Paramètre | Fonctionnement |
|---|---|
| Identifiant stable | Clé utilisée par les sauvegardes et les références. Ne pas l’utiliser comme simple nom affiché. |
| Emplacements de sorts actifs | Nombre de sorts équipables simultanément, de 1 à 12. |
| Scène de présentation | `PackedScene` utilisée par les aperçus compatibles. |

Ces valeurs servent de base à la prochaine création du personnage. Une run déjà commencée conserve son état sérialisé tant qu’aucune migration ne le remplace.

## 3 · Disciplines, rangs et XP

Une discipline est un chemin de progression lié à un sort racine.

| Paramètre ou commande | Fonctionnement |
|---|---|
| Nouvelle discipline | Crée la discipline, cinq rangs aux seuils 0/5/12/21/30 et son sort de base dans une seule action annulable. |
| Dupliquer | Crée une discipline, un sort et des enfants indépendants avec de nouveaux identifiants. |
| Renommer | Modifie le nom affiché sans modifier l’identifiant stable. |
| Retirer | Détache discipline et sort après confirmation ; les fichiers externes existants ne sont pas supprimés silencieusement. |
| Nom affiché | Nom visible de la discipline. |
| Description | Promesse et style de jeu du chemin. |
| Identifiant stable | Relie discipline, sort, nœuds et sauvegardes. |
| Couleur de présentation | Code couleur de la discipline. |
| Icône | Texture de reconnaissance visuelle. |
| Sort associé | Sort dont `Discipline associée` correspond à l’identifiant de la discipline. |
| Seuil total d’XP | XP cumulée nécessaire pour atteindre le rang. Un seuil 12 après un seuil 5 coûte donc 7 XP supplémentaires. |

**+ Rang** ajoute un rang après le dernier. **− Dernier rang** annonce les nœuds qui seront retirés. **Preset** applique 0/5/12/21/30. **Répartir l’XP** espace les seuils jusqu’à la valeur du dernier rang.

**Vérifier le modèle 5 rangs**, visible en mode avancé, contrôle facultativement cinq rangs, la topologie 0/2/4/8/4 et seize configurations finales. Une autre topologie reste autorisée et produit des avertissements, pas une modification automatique.

## 4 · Graphe et améliorations

Le sort racine occupe le rang 1. Les colonnes suivantes représentent les rangs. Une liaison bleue continue est un prérequis ; une liaison orange pointillée est une exclusion.

| Paramètre ou commande | Fonctionnement |
|---|---|
| + Amélioration | Crée un choix avec nom, rang et identifiant stable unique. |
| Assistant de branche | Crée un nœud par rang restant et leurs prérequis dans une seule action annulable. |
| Nom affiché | Nom compris par le joueur. |
| Description | Résultat précis de l’amélioration. |
| Identifiant stable | Clé de sauvegarde du choix. |
| Rang | Déplace le choix sans le renommer. |
| Sort ciblé | Identifiant du sort transformé par les effets du nœud. |
| Icône compacte | Texture affichée dans les vues compactes. |
| Illustration de carte | Texture de présentation du choix. |
| Prérequis | Tous les identifiants listés sont obligatoires : plusieurs entrées forment un **ET**, jamais un OU. |
| Exclusions | Empêchent deux choix de coexister ; le Studio entretient la relation dans les deux sens. |

Le menu contextuel permet aussi dupliquer, supprimer, aligner et répartir. **Organiser** recalcule seulement la disposition visuelle. Un déplacement manuel épingle la position. Copier, coller et dupliquer produisent des Resources indépendantes.

La liste d’effets permet **Ajouter**, **Partager un effet existant**, **Copier**, **Unique**, **Retirer**, ainsi que les flèches de réordonnancement. **Unique** sépare une Resource partagée avant modification.

## 5 · Tous les paramètres du sort de base

### Identité, coût et disponibilité

| Paramètre | Fonctionnement |
|---|---|
| Nom du sort | Nom visible en combat. |
| Description | Explication non technique du résultat. |
| Identifiant stable du sort | Clé utilisée par les améliorations. |
| Discipline associée | Identifiant stable de la discipline propriétaire. |
| Coût en PA | PA consommés lors d’un lancement réussi. |
| Portée minimale / maximale | Bornes de distance autorisée. |
| Ligne de vue nécessaire | Interdit de cibler à travers les obstacles. |
| Temps de recharge | Nombre d’activations avant une nouvelle disponibilité. |
| Recharge initiale | Nombre d’activations avant la première disponibilité. |
| Utilisations maximales | Limite par combat ; zéro signifie illimité. |
| Une fois par activation | Empêche un second lancement pendant le même tour du personnage. |

### Cibles, zone et effets directs

| Paramètre | Fonctionnement |
|---|---|
| Cibler les ennemis / alliés / soi-même / une case libre | Chaque permission est indépendante. Les effets doivent rester compatibles avec elles. |
| Forme de zone | Cible unique, croix, carré ou ligne. |
| Taille de zone | Étendue utilisée par la forme. |
| Ligne depuis le lanceur | Oriente une zone en ligne à partir du lanceur. |
| Dégâts / soin de base | Valeurs avant les améliorations. |
| Type de dégâts | Physique utilise l’armure ; magique utilise la résistance magique. |
| Élément | Résistance élémentaire consultée. |
| Chance critique du sort | S’ajoute à celle du personnage. |
| Distance de poussée / attraction | Déplacement forcé en s’éloignant du lanceur ou vers lui. |
| Bouclier accordé | Bouclier direct fourni par le sort. |

### Terrain, statut, déplacements et conditions

| Paramètre | Fonctionnement |
|---|---|
| Effet de terrain | `TerrainEffectData` posé par le sort. |
| Statut appliqué | `StatusData` appliqué directement. |
| Statut lié à la source | Distingue les instances selon leur lanceur. |
| Remplacer le même statut | Remplace l’instance précédente de la même source. |
| Dégâts de collision | Dégâts lorsqu’une poussée rencontre un obstacle. |
| Pousser toutes les unités adjacentes | Applique la poussée autour du point d’impact. |
| Pousser les unités de la zone | Applique la poussée à toutes les unités affectées. |
| Bonus de regroupement | Dégâts supplémentaires selon les ennemis regroupés. |
| Drain de PA | PA retirés au prochain tour de la cible. |
| Téléportation dans le dos | Place le lanceur derrière la cible. |
| Bonus sur cible marquée | Dégâts ajoutés si le statut demandé est présent. |
| Identifiant du statut requis | Clé stable de la marque attendue. |
| Marque liée au lanceur | Exige que la marque provienne de la source attendue. |
| Forcer la provocation / durée | Applique la règle de provocation pendant la durée choisie. |
| Nom du bonus de soin / multiplicateur | Identifie et dimensionne le bonus conditionnel ; `1,5` signifie 150 %. |

### Apparence, résolution différée et invocation

| Paramètre | Fonctionnement |
|---|---|
| Icône, effet visuel, son | Resources de présentation du lancement. |
| Placement du VFX | Trajet lanceur-cible ou apparition sur la case ciblée. |
| Animation visuelle | Action par défaut, principale ou puissante. |
| Délai d’impact | Secondes entre animation et résolution. |
| Mode différé | Aucun, frappe/poussée différée ou invocation. |
| Consommer l’activation à la résolution | Reporte la consommation au déclenchement différé. |
| Texte et couleur d’annonce | Télégraphe présenté au joueur. |
| Unité invoquée / type stable | Donnée de l’unité et identifiant de l’invocation. |
| PV de départ | Zéro utilise la valeur par défaut de l’unité. |
| Maximum vivant dans l’équipe | Limite d’invocations simultanées. |
| Condition de PV | `-1` désactive ; sinon le lanceur doit être sous ou égal à la valeur. |
| Unité devant être absente | Interdit l’invocation si cet identifiant est déjà présent. |
| Recharges initiales des invocations | Dictionnaire `identifiant de sort → recharge initiale`. |
| Modificateurs permanents | Liste ordonnée de `SpellModifier` toujours actifs, indépendamment de la progression. |

## 6 · Paramètres communs des effets

| Paramètre | Fonctionnement |
|---|---|
| Nom de l’effet | Nom dans l’éditeur et les rapports. |
| Identifiant du sort ciblé | Filtre stable prioritaire. |
| Ancien filtre par nom | Compatibilité historique ; laisser vide si l’identifiant est renseigné. |
| Type d’effet | Choisit l’une des 33 mécaniques ci-dessous. |
| Cible de l’effet | Ennemi principal, allié principal, ennemis affectés, alliés affectés ou lanceur. |
| Quantité principale / secondaire | Valeurs interprétées selon le type. |
| Durée | Nombre de tours d’un statut. |
| Nom / groupe stable du statut | Présentation et politique de regroupement. |
| Seuil de PV | Ratio conditionnel ; `0,30` signifie sous 30 %. |
| Part du soin | Ratio partagé avec les alliés adjacents. |
| Charges | Nombre de déclenchements possibles. |
| Groupe d’effet | Identifiant stable servant aux combinaisons. |
| Mode du statut | `BASE` crée, `DELTA` ajoute, `OVERRIDE` remplace. |
| Type / élément du statut | Défense et résistance des dégâts périodiques. |
| Moment d’application | Début ou fin du tour. |
| Exiger une attaque dans le dos | Ajoute cette condition au déclenchement. |
| Exiger une cible alliée | Ajoute cette condition au déclenchement. |

### Les 33 types d’effets

1. **Dégâts supplémentaires** — ajoute la quantité à chaque unité de la cible d’effet.
2. **Dégâts sur la case centrale** — ajoute seulement sur la cellule centrale d’une zone.
3. **Dégâts sur cible affaiblie** — ajoute sous le seuil de PV.
4. **Dégâts dans le dos** — ajoute lorsque le lanceur est derrière la cible.
5. **Dos ou cible affaiblie** — déclenche si l’une des deux conditions est vraie.
6. **Portée** — augmente la portée maximale sans changer la portée minimale.
7. **Soin** — rend la quantité de PV aux alliés ciblés.
8. **Soin sur cible affaiblie** — soigne seulement sous le seuil de PV.
9. **Bouclier sur les cibles** — accorde la quantité aux alliés choisis.
10. **Bouclier au lanceur après un soutien** — se déclenche si la cible principale est un autre allié.
11. **PM à la cible au prochain tour** — applique un bonus ou malus de PM différé.
12. **PM au lanceur au prochain tour** — applique le changement de PM au lanceur.
13. **Dégâts sur plusieurs tours** — crée un statut périodique selon durée, type, élément et timing.
14. **Ralentissement** — retire des PM pendant la durée.
15. **Régénération** — rend des PV périodiquement pendant la durée.
16. **Vulnérabilité** — ajoute des dégâts aux attaques reçues ; charges limite les déclenchements et la quantité secondaire peut produire des dégâts adjacents.
17. **Dégâts infligés modifiés** — modifie les dégâts produits par le porteur du statut.
18. **Agrandissement cardinal** — ajoute des couches dans les quatre directions.
19. **Poussée supplémentaire** — ajoute à la distance de poussée de base.
20. **Poussée exacte** — remplace la distance finale par la quantité.
21. **Collision supplémentaire** — ajoute aux dégâts d’une collision réelle.
22. **Collision exacte** — impose la valeur finale ; plusieurs valeurs exactes conservent la plus élevée.
23. **Durée du terrain** — ajoute à la durée d’un terrain déjà créé.
24. **Dégâts du terrain** — ajoute aux dégâts d’un terrain déjà créé.
25. **Retrait d’effets négatifs** — retire jusqu’à la quantité de statuts négatifs simples.
26. **Soin partagé** — partage une proportion du soin reçu avec les alliés cardinaux.
27. **Bouclier aux alliés de la zone** — protège tous les alliés dans les cellules résolues.
28. **PM aux alliés de la zone** — modifie les PM du prochain tour des alliés de la zone.
29. **Bonus d’attaque** — quantité fixe pour un nombre d’attaques défini par Charges.
30. **Déplacement du lanceur** — déplace sur la case ciblée ou près de l’unité ; destination libre et alignement sont obligatoires. Le mode avancé peut aussi exiger que toutes les cases intermédiaires soient dégagées.
31. **Ciblage d’une case libre** — permission booléenne, sans usage de la quantité.
32. **Bouclier adjacent** — protège les alliés cardinaux autour de la cible, ou du lanceur sans cible.
33. **Bouclier au lanceur** — protège directement le lanceur après la résolution des dégâts.

Les treize classes historiques reconnues couvrent terrain, portée, PM, soin, poussée exacte, dégâts à portée minimale, collision, dégâts centraux ou de dos, statut, cible alignée, bouclier et poussée. Leur section **Comment fonctionne cet effet ?** expose en lecture l’unité, la cible, la condition, la durée, la fréquence et l’empilement ; leurs valeurs primitives éditables apparaissent en mode avancé.

Le sélecteur regroupe les 33 effets par familles. L’Inspecteur n’affiche que les propriétés réellement utilisées par le type choisi. Une ancienne valeur masquée reste stockée sans être effacée et produit un avertissement lorsqu’elle est devenue sans effet.

## 7 · Vérifier, tester et comparer

- **Valider** contrôle caractéristiques, stockage, identifiants, rangs, XP, sort racine, cibles, effets, relations, cycles et accessibilité. Une erreur bloque la sauvegarde ; un avertissement demande une décision.
- L’onglet **Erreurs** explique le problème et la correction. Activer une ligne sélectionne son propriétaire logique.
- **Simuler** applique les règles réelles à un total d’XP et explique les verrouillages de choix.
- **Statistiques** compte rangs, choix, relations et configurations ; **Tester tous les chemins** rejoue jusqu’à 1 000 configurations.
- **Outils > Prévisualiser le sort** compare le sort avant/après avec le vrai pipeline dans neuf scénarios déterministes, sans écriture.
- **Outils > Analyse complète de l’arbre** recherche chemins, nœuds inaccessibles, rangs morts, dominance et choix finaux.
- **Outils > Comparer deux parties** ouvre un sélecteur explicite de partie de référence, sans changer le contexte.
- **Outils > Vérifier les Resources orphelines** ouvre les actions de rattachement, archivage ou suppression protégée.
- **Recherche globale** trouve noms, identifiants, descriptions et résumés d’effets puis ouvre directement le bon objet.

## 8 · Sauvegarde sûre

Le Studio édite une copie profonde. Un badge **MODIFIÉ** signale l’écart avec la source et un brouillon récupérable est écrit toutes les 30 secondes.

Le bouton Sauvegarder, **Ctrl+S**, l’étape 10 et la sauvegarde demandée lors d’un changement de contexte passent par une revue : opération, fichier, propriétaire, état, différences et conflits. Une ligne de la revue permet de revenir à son propriétaire. Après confirmation, la transaction réserve les chemins, produit une récupération, stage et vérifie toutes les Resources, puis applique ou restaure l’ensemble.

Lors d’un changement de contexte, les choix sont **Sauvegarder**, **Garder comme brouillon**, **Abandonner** ou **Annuler**. Pour les Resources orphelines : **Adopter** rattache, **Archiver** retire avec récupération et **Supprimer** demande l’identifiant exact ; une référence entrante bloque le retrait.

## 9 · Propriétés existantes non éditables dans ce Studio

Ces propriétés existent dans les Resources, mais ne disposent pas encore d’un formulaire et d’une validation spécialisés.

### Personnage

- équipe et orientation initiale ;
- résistances élémentaires ;
- `SpriteFrames`, échelle, animation d’attente et scène visuelle runtime ;
- rôle, résumés de présentation/progression et badge ;
- activation de l’attaque de base et liste brute des sorts ;
- comportement et style d’IA, distances préférée/minimale/maximale, maintien de distance et profil IA ;
- faction, rôle tactique et rôle de commandant lié ;
- source, quantité et plafond de l’armure de proximité ;
- réduction spéciale du premier déplacement forcé.

### Sort

- **Exclure le lanceur des effets de zone** existe dans `Spell`, mais n’a pas de champ ici.

### Effet

- **Exiger un chemin libre** pour le déplacement du lanceur existe dans les données. Destination libre et alignement restent toujours vérifiés ; seule la vérification des cellules intermédiaires n’est pas éditable.
- Les propriétés complexes d’un modificateur historique sans éditeur spécialisé ne sont pas exposées comme si elles étaient prises en charge.

**Ouvrir dans l’Inspecteur Godot** sert à consulter ces données ou à assumer une édition technique hors du contrat guidé.

## 10 · Exercice sandbox

**Démarrer l’exercice sécurisé** crée un personnage vide uniquement sous :

`user://dungeon_draft_studio/tests/skill_tree_tutorial/`

Le parcours conseillé est : créer discipline et sort ; régler les rangs ; créer deux branches ; ajouter prérequis et exclusion ; configurer dégâts, statut et portée ; simuler ; prévisualiser ; valider ; revoir et appliquer une sauvegarde sandbox.

Pendant l’exercice, chaque nouveau chemin `res://data` proposé par les commandes historiques est remappé vers le dossier possédé avant validation ou sauvegarde. La transaction n’accepte que cette racine. **↺ Réinitialiser l’exercice** restaure le personnage vide initial sans toucher aux données de production.
