# Audit des 48 sorts — pistes d'affinités, pas données du jeu

Généré par `calculs.py` à partir du catalogue réel et d'une table d'interprétation explicite.
Une double étiquette n'implique ni dégâts partagés, ni réaction déjà codée. Les points
d'interrogation signalent un domaine particulièrement peu étayé. Ces rapprochements
thématiques doivent encore produire des choix de combat avant de devenir du contenu.

| ID | Sort actuel | Rareté | PA | Domaines candidats | Fonction et limite |
|---|---|---|---:|---|---|
| n01 | Estoc | normal | 1 | Commun | Impact simple ; repère neutre |
| n02 | Garde brève | normal | 1 | Commun | Protection simple ; repère neutre |
| n03 | Pas latéral | normal | 1 | Commun | Déplacement volontaire ; reste sans élément |
| n04 | Heurt | normal | 1 | Terre | Poussée courte ; préparer une position |
| n05 | Trait court | normal | 1 | Commun | Impact distant simple |
| n06 | Repérage | normal | 1 | Nuit | Préparer une marque, alternative à a01/t03 |
| n07 | Entrave légère | normal | 1 | Eau | Ralentissement ; attribution thématique à confirmer |
| n08 | Recentrage | normal | 1 | Commun | Accès à la main ; ne doit pas donner de dégâts élémentaires |
| a01 | Ouvrir la garde | normal | 1 | Nuit | Préparer une marque |
| a02 | Frapper la faille | normal | 2 | Nuit | Exploiter une marque ; gros impact direct |
| a03 | Entaille tenace | normal | 2 | Nuit | Blessure différée ; autre axe que les marques |
| a04 | Attaque oblique | normal | 2 | Nuit/Vent | Exploiter un déplacement volontaire |
| g01 | Garde ferme | normal | 2 | Terre | Préparer de la garde |
| g02 | Heurt du rempart | normal | 2 | Terre | Exploiter la présence de garde |
| g03 | Repousser | normal | 2 | Terre/Vent | Poussée longue ; attribution double à confirmer |
| g04 | Ramener au front | normal | 1 | Terre | Ramener une cible au front |
| r01 | Tir de relais | normal | 2 | Vent | Déplacement puis tir et renouvellement de main |
| r02 | Trait de recul | normal | 2 | Vent | Poussée distante |
| r03 | Flèche entravante | normal | 2 | Eau/Vent | Ralentissement distant ; pas encore de transformation hybride |
| r04 | Volée croisée | normal | 3 | Vent | Zone distante ; ne possède pas encore de rôle élémentaire distinct |
| t01 | Trait de givre | normal | 2 | Eau | Ralentissement et gel de l'eau |
| t02 | Braise tenace | normal | 2 | Feu | Brûlure ; vapeur déjà existante sur l'eau |
| t03 | Sceau ombreux | normal | 1 | Nuit | Préparer une marque magique |
| t04 | Onde du Léthé | normal | 3 | Eau/Nuit | Eau existante ; transport de marque proposé, absent du moteur |
| a05 | Bond spectral | elite | 2 | Nuit/Vent | Téléportation ; domaine Nuit encore à justifier |
| a06 | Dernier verdict | elite | 3 | Nuit | Exécuter une cible blessée |
| a07 | Pointe franche | elite | 2 | Soleil? | Ignore l'armure ; piste de révélation, aucun système solaire |
| g05 | Contre préparé | elite | 2 | Terre | Garde et contre conditionnel |
| g06 | Choc de masse | elite | 2 | Terre/Vent | Poussée ; arrêt contre mur fixe donne de la garde, pas des dégâts |
| g07 | Dette du bronze | elite | 3 | Terre/Nuit | Exploiter la garde absorbée au tour précédent |
| r05 | Au-delà du front | elite | 2 | Vent | Téléportation longue |
| r06 | Pluie de pointes | elite | 3 | Vent | Zone en ligne ; aucun rôle élémentaire distinct actuellement |
| r07 | Trait harpon | elite | 2 | Eau/Vent | Attraction ; aide à faire traverser une surface |
| t05 | Bûcher des ombres | elite | 2 | Feu/Nuit | Zone de feu persistante ; domaine Nuit non prouvé par le nom |
| t06 | Jardin de givre | elite | 2 | Eau/Terre | Zone de glace ; domaine Terre hypothétique |
| t07 | Prélèvement | elite | 2 | Eau/Nuit | Drain fondé sur les PV réellement retirés |
| a08 | Couper le souffle | rare | 2 | Nuit/Vent | Affaiblir la prochaine attaque ; double domaine hypothétique |
| a09 | Sommeil marqué | rare | 3 | Nuit | Dépenser une marque pour neutraliser une activation |
| g08 | Bastion vivant | rare | 3 | Terre | Forte garde ; pas une condition d'accès au build |
| g09 | Répercussion | rare | 2 | Terre | Sacrifier de la garde pour un impact |
| r08 | Permutation | rare | 2 | Vent | Permutation ; immunité des boss conservée |
| r09 | La longue vue | rare | 3 | Soleil? | Longue portée ; thème solaire insuffisant en soi |
| t08 | Convergence | rare | 3 | Eau/Vent | Attraction puis impact de zone |
| t09 | Résonance du sceau | rare | 3 | Nuit | Exploiter une marque avec des dégâts magiques |
| l01 | Orage du passage | legendary | 3 | Vent | Zone magique ; nom Orage insuffisant pour inventer un type |
| l02 | Grâce du bronze | legendary | 2 | Terre/Soleil? | Soin et garde ; piste solaire seulement |
| d01 | Décret du dernier souffle | god | 3 | Nuit/Soleil? | Prévenir une mort ; ne peut fonder un build accessible |
| i01 | Seconde aurore | immortal | 4 | Eau/Soleil? | Soin et garde ; contenu exceptionnel, pas moteur de synergie |

## Couverture indicative

| Domaine proposé | Tous rangs | Normaux |
|---|---:|---:|
| Commun | 5 | 5 |
| Terre | 12 | 5 |
| Nuit | 16 | 7 |
| Eau | 9 | 4 |
| Vent | 15 | 6 |
| Feu | 2 | 1 |
| Soleil? | 5 | 0 |

Les comptes se recouvrent : un sort proposé Eau/Nuit apparaît dans deux lignes.
Ils ne prouvent pas qu'une branche possède un moteur complet. Le Feu n'a que Braise
tenace en normal et Bûcher des ombres en élite. Aucun normal ne fournit actuellement
une identité Soleil étayée. Certaines attributions Vent/Terre sont également de
simples hypothèses. Ajouter six statistiques immédiatement produirait des branches
très inégales ; il faut concevoir et distribuer les fonctions manquantes.

La marque a déjà trois préparateurs normaux (n06/a01/t03), mais les consommateurs
spécialisés ne sont pas uniformément accessibles au départ. L'eau dynamique dépend
de t04 en normal ; ralentir avec n07/r03 ne crée pas une flaque. Ne pas compter ces
trois sorts comme trois producteurs d'eau. t04 n'est actuellement proposé au départ
qu'au Thaumaturge. Une lignée hybride interclasse doit modifier l'accès de départ,
pas seulement espérer un butin étranger.
