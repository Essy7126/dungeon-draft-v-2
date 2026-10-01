# Socle numérique de progression — contrat 1

Le personnage et la route ont deux horizons différents. Le profil numérique
décrit tous les niveaux autorisés d'une campagne. Un acte décrit ses rencontres,
ses récompenses et sa sortie. La fin de Pâris ne doit donc pas devenir, par défaut,
le plafond statistique de toute future campagne.

Le profil publié aujourd'hui reste `paris_act_1_v1`, douze niveaux. Aucun acte II
jouable ni nouvelle courbe d'équilibrage n'est livré avec ce premier lot.

## Source et contrat

`data/cards/consumable_v2/catalog.json` porte les valeurs. Dans `rules`,
`prototypeProgression` contient l'identité, la version de schéma, le plafond,
la puissance du personnage, les budgets élémentaires, les niveaux d'aptitude,
leurs gains et plafonds de rang, les paliers de maîtrise et la spécialisation.
Les PV, seuils XP, puissances historiques et niveaux de perfectionnement
utilisent les courbes existantes du même manifeste, sans copie parallèle.

`core/expedition/consumable_progression_profile.gd` valide puis détache ces
données. La validation du catalogue appelle ce même contrat avant publication.

| Grandeur | Contrat |
|---|---|
| Niveaux | 1 à `levelCap`, au plus 99 selon le profil Champion partagé |
| PV, puissances actuelle et historique | Un entier strictement positif pour chaque niveau |
| XP cumulée | Un entier par niveau, premier seuil zéro, suivants strictement croissants |
| Points élémentaires | Budget initial + gain entier par niveau ; aucune courbe implicite après le plafond |
| Aptitudes et perfectionnements | Niveaux uniques et ordonnés entre 2 et le plafond ; un choix par palier |
| Maîtrise | Paliers de points croissants ; dernier `upTo: 0` ouvert ; gains finis entre 0 et 1 |
| Spécialisation | Niveau existant dans le profil |

Les niveaux, budgets et courbes refusent les fractions, valeurs non finies,
chaînes, booléens et entiers incompatibles avec les tableaux 32 bits de Champion.
Les courbes de PV et de puissance ne sont pas forcées à croître : une future
courbe peut contenir un plateau. Ses effets sur le combat doivent être étudiés
séparément. Une identité publiée désigne un contrat figé ; modifier ses nombres
nécessite une nouvelle identité et une décision explicite de migration.

Une lecture hors profil renvoie `{}` pour les statistiques et lignes de niveau,
`-1` pour un budget. Elle ne revient jamais silencieusement au niveau 12.
L'allocation rejette les budgets négatifs. Les états de sauvegarde refusent eux
aussi les niveaux absents.

## Calculs et sauvegarde

`consumable_progression_v1.gd` charge le profil actif une fois, sans dépendre du
catalogue complet. Le validateur de profil reste pur, ce qui évite un cycle entre
catalogue, allocations et calculs. Ses anciens accès `POWER` et `APTITUDE_GAINS`
restent disponibles sous forme de vues détachées pour la présentation.

Les budgets, plafonds d'allocation, emplacements de perfectionnement et
choix de spécialisation de l'état Cartes utilisent le profil. `consumable_card_math.gd` utilise
les mêmes lignes de niveau et gains. Un profil validé peut être fourni aux
calculateurs de statistiques, de composantes et d'impact pour le laboratoire.
Les bonus élémentaires et d'aptitude reçoivent ce contexte dans chaque chemin.
Le profil optionnel ne sélectionne aucun contenu ni état de run jouable.

L'adaptateur `configure_profile` transmet le plafond et les courbes au service
Champion existant, qui garde le cycle de progression partagé et ses reçus de
victoire. L'état Cartes conserve son miroir XP/niveau mis à jour par l'économie ;
le chargeur de session exige leur concordance. Les points de choix restent dans
l'état Cartes : aucun nouveau compteur d'XP ou d'attributs n'a été créé. La puissance historique de cet
adaptateur intermédiaire est conservée ; la reconstruction Cartes applique la
puissance du personnage et les aptitudes comme auparavant.

Une sauvegarde Cartes porte désormais `progression_profile_id`. Un identifiant
inconnu est rejeté avant mutation de l'objet. Les sauvegardes qui ne possèdent
pas ce champ reçoivent l'identité **figée** `paris_act_1_v1`, jamais l'identité
d'une future campagne par défaut. La migration des anciens attributs hors combat,
la conservation du ratio de PV et le soin de niveau restent les contrats v1.

## Preuve d'extension et limites

`test/unit/test_consumable_cards_progression_profile.gd` utilise une fixture
complète de dix-huit niveaux. Elle franchit le seuil XP de Pâris puis celui du
niveau 18 avec le service Champion réel, vérifie le refus d'une victoire dupliquée,
les budgets de 38 points élémentaires, six aptitudes et quatre perfectionnements,
et les calculs avec des gains modifiés. Elle vérifie aussi l'absence de partage
mutable, les données invalides et la compatibilité atomique des sauvegardes.
Les nombres de cette fixture ne constituent pas une proposition d'équilibrage.

Les budgets d'action restent quatre PA, trois PM et cinq cartes de main de base.
Les plafonds de défense, les équipements et les effets dérivés suivent toujours
leurs règles existantes. Ce lot ne les rend pas tous paramétrables par campagne.

Les limites de route restent douze rencontres / vingt profondeurs. L'écran de
fin et les checkpoint de route décrivent encore une run Pâris. Le registre de
plusieurs profils historiques et le choix du profil à la création restent à
construire avant une campagne jouable prolongée. Supprimer ces limites seules
ne créerait ni rencontres supplémentaires ni transition valide.

Les gardes de poursuite de `expedition_session.gd` et `consumable_cards_run.gd`
ainsi que certains libellés/plafonds de présentation restent fixés à v1
(spécialisation 4, éléments 26, aptitudes 3). Ils sont cohérents avec le profil
publié ; les raccorder au profil fait partie du lot de campagne avant toute
publication avec des paliers différents. Le banc numérique optionnel ne passe
pas par ces gardes de route et ne prétend pas certifier cette publication.

L'économie actuelle ne verse pas la douzième entrée de `rules.xp` au boss final.
Les onze récompenses précédentes totalisent **2 440 XP**, soit **140 XP** au-dessus
du seuil 12 de 2 300. Les douze entrées déclarées totalisent 2 785 ; les additionner
sans lire la politique de récompense surestimerait l'XP réellement distribuée.
Le choix du seuil 13 et de la récompense de fin d'acte doit partir de cette trace
effective. Les 169 911 répartitions élémentaires complètes et vingt répartitions
d'aptitudes donnent 3 398 220 couples théoriques au niveau 12 ; ce nombre ne mesure
ni des builds distincts en combat ni leur disponibilité au cours d'une run.

## Ordre des lots suivants

1. **Campagne et actes** : registre de profils figés, manifeste d'actes, XP globale,
   indices locaux et globaux distincts, reçus de butin/récompense identifiés par acte
   et rencontre, transition sauvegardée une fois, sortie de
   Pâris et bilan intermédiaire. Une campagne prolongée utilise son profil dès le
   départ ; une ancienne run Pâris ne change pas de contrat sans migration.
   Fixer le sort des 140 XP excédentaires et l'interface de choix après le boss.
2. **Sources et effets** : contrat uniforme de composantes originales, conversions,
   valeurs stockées, limites de déclenchement et arrondi. Enregistrer une trace
   de calcul exploitable par les aperçus et les tests de cartes/reliques.
3. **Stocks et opportunités** : consommation, accès aux copies, récompenses,
   préparation et marchés sur plusieurs actes. Mesurer les ressources restantes
   après Pâris, les possibilités de reconstruction et l'accès aux nouvelles familles.
4. **Budgets de contenu** : évaluer une carte ou relique selon puissance, coût en PA,
   disponibilité, durée, conditions, cibles et économie de copies ; tester les
   combinaisons, les seuils de mise à mort et les cycles de déclenchement.
5. **Équilibrage d'acte II** : comparer des trajectoires de personnages et des
   rencontres complètes, puis décider les courbes et récompenses. Privilégier de
   nouvelles décisions et interactions avant une hausse générale des multiplicateurs.

Les rapports de recherche datés restent historiques après modification de leurs
entrées. Leurs scripts lisent désormais la courbe du manifeste ; une discordance
d'empreinte doit toujours empêcher de présenter un ancien combat comme preuve fraîche.
