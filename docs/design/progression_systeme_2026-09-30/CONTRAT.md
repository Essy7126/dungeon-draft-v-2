# Contrat proposé : progression extensible dans la run actuelle

Proposition du 30 septembre 2026. Les règles installées restent celles du
[Prototype v1](../../current/prototype_v1.md). Les exemples chiffrés sont dans
[candidats.json](candidats.json). Ce document étend les
[fondations du 28 septembre](../fondations_stats_cartes_2026-09-28.md) et le
[contrat après épreuve du 29](../prototype_v1_epreuve_2026-09-29/CONTRAT.md).

## 1. Invariants du personnage

1. La classe définit son noyau permanent, pas un élément obligatoire. L'apparence
   Passe-rive ne crée pas une classe ou une progression distincte.
2. Toutes les maîtrises sont accessibles à toutes les classes. Aucun point ne
   déverrouille une liste fermée de couples ou de sorts hybrides.
3. Chaque composante originale porte ses propres poids élémentaires. Leur somme
   vaut 100 % ; les composantes neutres sont explicitement sans élément.
4. La progression ne transforme ni PA, PM, cartes piochées, durée, portée ni
   déplacement en quantités multipliées par une maîtrise.
5. Une carte jouée est consommée une fois pour toute la traversée. Apprendre,
   changer ou retirer une forme ne restaure jamais ses copies.
6. Les bonus applicables s'additionnent dans leur étage. Une quantité capturée ou
   dérivée ne repasse pas implicitement par tous les bonus de l'effet original.
7. Aucun choix de progression ni d'équipement n'est modifiable dans une bataille.
8. Les nouvelles possibilités utilisent les budgets existants ; ajouter une
   catégorie au catalogue ne donne aucun point ou emplacement supplémentaire.

## 2. Le vocabulaire des statistiques

| Domaine | Grandeurs | Règle commune |
|---|---|---|
| Croissance | Niveau 1–12, XP, P, PV de base | Courbes explicites ; pas de récompense d'XP par usage de sort |
| Ressources | PV courants/maximaux, 4 PA, 3 PM de base, main 5 | Les sources exceptionnelles de PM/main gardent leurs plafonds ; pas de gain automatique par niveau |
| Maîtrises | Terre, Eau, Feu, Vent, Nuit, Soleil | 26 points finaux ; bonus d'objets ajoutés après conversion des points investis |
| Aptitudes | Vitalité, Protection, Contact, Distance | Trois points communs ; chaque aptitude a au plus trois rangs |
| Défenses | Physique, magique, garde actuelle sourcée | La garde est un état, pas un attribut acheté ; les nouvelles résistances constituent un lot distinct |
| Configuration | Spécialisation, formes équipées, élément de l'attaque permanente | Identifiants de choix, jamais multiplicateurs génériques cachés |
| Répertoire | Copies possédées, préparées, consommées, familles connues | Les quantités et les connaissances sont distinctes |

Conserver les clés actuelles de modificateurs d'objet lorsqu'elles existent :
`hp`, `armor`, `magicResist`, `guard`, `damage`, `magic`, `melee`, `ranged`,
`healing`, `mastery_<element>`, ainsi que les sources explicites de PM/main.
Ne pas créer une caractéristique par carte, forme, classe, rareté ou mot-clé.
Un mot-clé peut seulement filtrer du contenu.

### Étage de calcul

Pour une composante originale de coefficient c :

```text
raw = basis × c × (1 + Σ(weight_e × mastery_e) + applicable_bonuses)
```

`basis` peut être P ou une autre base explicitement définie. Les maîtrises
d'équipement sont des points de pourcentage, pas des points investis. Les ajouts
fixes `+0,25 P` de classe restent des ajouts distincts selon leur contrat actuel.
Ils ne deviennent pas élémentaires parce que l'impact qui les déclenche l'est.

La garde applique Protection et les bonus de garde, pas Contact/Distance. Un
soin applique ses bonus admissibles, pas une résistance ennemie. Une quantité
offensive périodique est capturée à sa création ; les défenses de la cible sont
interrogées à la résolution. Marque, conversion et drain conservent leurs politiques
spécifiques. La Pression reste indépendante des maîtrises et aptitudes offensives.

Arrondi moitié vers le haut à la résolution de chaque quantité finale. Plusieurs
tics sont plusieurs résolutions : ne pas arrondir leur somme théorique en une
seule fois. Une Marque garde sa valeur réelle jusqu'au dégât qui la libère.

### Aptitudes futures, avec contenu préalable

Les paramètres suivants sont codifiés pour des expériences ultérieures :

- **Persistance, +8 points de pourcentage par rang** sur les composantes originales
  de Brûlure, Saignement et surfaces dommageables. Aucun bonus sur la Marque,
  les ripostes, les conversions, les impacts directs ou les ajouts fixes P de
  classe/relique. Appliquer une seule fois lors de la capture.
- **Soin, +10 points de pourcentage par rang** sur les soins originaux ; sur le
  drain, seulement à l'étage de soin dérivé des PV effectivement retirés. Aucun
  effet sur les soins de niveau, halte, préparation finale, les événements en
  pourcentage des PV maximum ou la résurrection.

Ils utilisent les **mêmes trois points**, sans modifier les dates d'attribution.
Avant de les exposer, disposer d'au moins trois sources normales de leur fonction
accessibles à chaque classe et valider leur économie en campagne. Ces quotas sont
des conditions de livraison du contenu, pas des conditions à remplir par le joueur.
Le catalogue actif et les trois cartes candidates ne satisfont pas encore toutes
ces conditions. Aucune aptitude vide n'est proposée au départ.

## 3. Cadence d'une traversée

| Niveau | Budget élémentaire cumulé | Aptitudes cumulées | Perfectionnements | Autre choix |
|---|---:|---:|---:|---|
| 1 | 4 | 0 | 0 | Classe, copies, ouverture facultative, inflexion proposée |
| 2 | 6 | 0 | 0 | Adaptation au répertoire |
| 3 | 8 | 1 | 0 | Première aptitude |
| 4 | 10 | 1 | 1 | Spécialisation, première famille/forme |
| 5 | 12 | 1 | 1 | Consolidation ou couverture |
| 6 | 14 | 2 | 1 | Deuxième aptitude |
| 7 | 16 | 2 | 1 | Consolidation ou couverture |
| 8 | 18 | 2 | 2 | Deuxième famille/forme ; reset complet disponible au refuge admissible |
| 9 | 20 | 3 | 2 | Troisième aptitude |
| 10 | 22 | 3 | 2 | Consolidation ou couverture |
| 11 | 24 | 3 | 2 | Consolidation ou couverture |
| 12 | 26 | 3 | 3 | Troisième famille/forme, préparation du boss |

Les onze premières victoires donnent chacune un niveau. Le dernier combat ne
redistribue pas les récompenses de progression précédentes. L'écran regroupe les
points, aptitudes et configurations disponibles dans un brouillon avec aperçu.
Les points peuvent rester non dépensés. La spécialisation reste une décision
explicite ; fermer un écran ne sélectionne rien par défaut.

Au niveau 4, présenter spécialisation et perfectionnement dans la même préparation
avec conséquences avant/après, sans déplacer arbitrairement une récompense vers
un nouveau jalon. Aucun nouvel événement de progression n'est ajouté pour porter
les formes : elles remplacent le choix de perfectionnement de la famille concernée.

## 4. Perfectionnements à alternatives

### Affectation

- Chaque emplacement concerne une famille différente. Une famille expose son
  amélioration actuelle comme forme standard et peut exposer des alternatives.
- Choisir une alternative remplace entièrement l'amélioration standard de cette
  famille ; ce n'est pas un deuxième bonus superposé.
- Les alternatives ne demandent ni élément, ni classe native, ni couple investi.
  Il faut posséder au moins une copie pour une nouvelle affectation, comme aujourd'hui.
- Une affectation déjà présente peut rester sur une famille épuisée. Ses futures
  copies retrouvent cette forme ; son déplacement libère la famille normalement.
- Réaffectation gratuite hors combat dans les emplacements disponibles. On ne
  rembourse aucun consommable et on ne conserve aucun effet de la forme retirée.
- Le joueur peut toujours jouer la version de base en retirant l'affectation.
  Il n'y a pas de choix de forme à chaque lancer en combat.

Une forme définit des modifications de composantes, géométrie et timing. Les
poids, la nature physique/magique et les bonus de classe restent déclarés ; une
modification de coût, de durée ou de limite doit être écrite dans la définition.
Les candidats présents ne rendent aucun PA et n'élargissent pas la main.

### Critère de conception

Pour chaque alternative, chercher au moins une situation favorable et une
situation défavorable au même niveau, équipement et coût. Mesurer impact utile,
délai, copies, PA, absorption et risque. La somme dégâts+soin+garde n'est pas un
score universel. Un total retardé égal au total immédiat ne constitue pas à lui
seul un compromis : documenter l'avantage distinct ou rejeter la forme.

### Durées et applications entières

L'introduction de Braise lente nécessite de remplacer le rafraîchissement actuel
`maximum de puissance + maximum de durée` par un contrat d'application entière.
Sinon une brûlure forte courte emprunte la durée d'une autre.

Pour ce premier lot, conserver une seule application par famille de statut :
comparer valeur capturée × nombre d'activations restantes avant défense,
remplacer seulement si le nouveau total est supérieur, égalité = application
ancienne conservée. Ne jamais fabriquer une intensité/durée composée. Le joueur
voit le résultat avant de consommer. Cette règle peut refuser un tic plus fort
mais moins rentable au total : c'est un compromis assumé du premier laboratoire,
à éprouver contre les besoins d'élimination immédiate.

Les durées conservent leur horloge explicite. Pour les nouveaux candidats :
Brûlure au début d'activation de la cible, Marque décrémentée à la fin de phase
ennemie. Ni ouvrir le dossier ni recharger la sauvegarde ne fait avancer ces horloges.

### Garde tissée : règles particulières indispensables

Chaque production a un identifiant stable `cast_id + component_index`, une
quantité, une échéance et une permission de conservation. L'absorption consomme
d'abord la source expirant le plus tôt, puis l'ordre de création ; pas de choix
gratuit de la meilleure source à chaque impact.

Au début du héros : retirer les gardes ordinaires expirées ; conserver une fois
la moitié du seul reliquat tissé, arrondi selon le contrat ; appliquer le plafond
global 2,5 P ; puis produire normalement les autres gardes de début de tour.
La conservation ne recrée aucun événement `guard_produced`, ne réapplique aucun
bonus et expire au début du héros suivant. Une autre Garde tissée crée une source
distincte, avec la limite de famille habituelle. Sérialiser quantité, date et droit
déjà utilisé. Une sauvegarde globale de la garde sans ses sources est insuffisante.

## 5. Noyau permanent et origine de classe

### Inflexion élémentaire

Choix explicite d'un élément pour toutes les composantes originales de dégâts
de l'attaque permanente, bonus conditionnel inclus. Le choix donne 100 % de cet
élément ; il ne crée pas un deuxième impact. Il ne change ni coût 1 PA, limite
d'une utilisation par tour, portée, condition, nature physique/magique ou passif.
La garde Soleil de Frappe du rempart reste Soleil. La garde de secours neutre
reste neutre.

Choisir à la création ; ensuite modifier seulement lors d'une correction
élémentaire autorisée à une halte. Cette modification partage la validation
unique de la visite ; elle peut utiliser le droit de visite sans déplacer de
point. Elle ne prend aucun point supplémentaire mais interdit de changer d'élément
avant chaque ennemi. Une réorientation complète libère aussi ce choix.

Valeur absente dans une ancienne sauvegarde : conserver les poids historiques,
notamment 80/20 Eau/Nuit du Thaumaturge, jusqu'à une sélection explicite hors
combat. Ce passage à 100 % peut augmenter le rendement : comparer séparément
la continuité après consommation et la puissance, sans prétendre à une migration
numériquement neutre. Aucune attaque permanente n'hérite d'un perfectionnement
de carte ni des bonus réservés à la consommation.

### Pas de multiplicateur natif ajouté dans ce lot

L'Assassin peut exploiter l'isolement d'une carte étrangère, le Thaumaturge ses
applications de statut, l'Arpenteur sa distance et le Gardien sa protection.
Cela conserve l'utilité des emprunts et l'identité des noyaux.

Si un bonus natif devient nécessaire, l'introduire comme politique bornée de
composantes, dans la même somme additive, avec budget compensé et variante de
test. Il n'amplifiera ni déplacement, pioche, durée, PA ni toutes les ripostes.
Un +X % généralisé n'est pas la source de profondeur retenue ici.

## 6. Accès au contenu et réapprovisionnement

### Préparation de départ

Pour le laboratoire suivant, ouvrir le catalogue **normal** aux quatre classes,
en conservant filtre et recommandations de classe. Garder quinze copies et les
limites existantes. Mesurer les départs effectivement légaux, sans introduire
une rareté élevée comme solution obligatoire à une maîtrise vide.

Avant d'annoncer une orientation élémentaire complète pour une classe, fournir
au moins deux impacts normaux distincts et un outil complémentaire normal
renforcé par cette maîtrise ou soutenant son usage. Des familles communes peuvent
satisfaire cette couverture pour plusieurs classes. Ce critère sert à publier
le contenu ; il n'impose pas une composition au joueur. Une palette de six
éléments ne suffit pas à elle seule à satisfaire le critère.

### Offre de récompense orientée, expérimentale

Remplacer le premier sac **normal non perdu** attribué à la victoire par une
offre de trois lots de deux copies normales. Les autres sacs gardent leur contrat.
Si aucun sac normal n'est gagné, aucun lot n'est ajouté. Pas d'offre au boss qui
ne verse pas ces copies aujourd'hui.

1. **Renforcer** : échantillonner des familles dont une composante originale
   correspond à une maîtrise investie maximale, avec préférence de classe actuelle.
2. **Compléter** : échantillonner une fonction parmi celles représentées par le
   moins de copies préparables possédées : attaque, protection, soin, déplacement,
   contrôle. Une famille peut satisfaire plusieurs fonctions ; aucune paire fixe.
3. **Explorer** : deux tirages ordinaires selon le biais 70 % natif/commun existant.

Dans un lot, préférer deux familles distinctes lorsque le pool le permet. Tous
les lots ont même quantité et rareté. Un lot vide utilise le pool normal global ;
son libellé devient Explorer, sans promettre un élément absent. La définition
des fonctions s'appuie sur les effets, pas seulement le champ de rôle unique.

Graine dérivée de run/rencontre/sac/variante, engagement avant décision,
sauvegarde des trois lots et du lot choisi. Le lot provient de son sac légitime :
un sacrifice qui perd ce butin ne récupère pas l'offre. Recharger ne retire ni ne
recrée les choix. La récompense se valide une seule fois, sans cumuler les lots.

Le nombre de copies ne change pas ; la **qualité attendue augmente** par le
choix entre options. Mesurer cette hausse et les doublons/ruptures de stock avant
d'ajuster l'économie. Les probabilités calculées dans cette étude décrivent le
tirage actuel, pas un taux de succès de cette future offre.

## 7. Équipements, reliques et défenses

Les six emplacements d'équipement et deux de relique sont maintenus. Une maîtrise
d'objet ajoute des points de pourcentage indépendants des achats de progression.
Pour les amulettes, conserver la comparaison locale +12 mono / +8 dans deux
éléments du contrat précédent ; pas d'addition artificielle des couvertures sur
un même effet. Pour les drops, tirer slot/famille d'abord avec poids explicites,
puis définition : ajouter du contenu ne doit pas raréfier toutes les autres bottes.

Une relique décrit événement, instant, source admissible, cap par tour/combat,
ordre de résolution, permissions de déclenchement et état sérialisé. Les formes
et nouvelles composantes partagent **un seul cast_id** : aucune multiplication
du nombre de lancers pour réamorcer passif ou spécialisation. Une conservation
de garde ne produit pas une nouvelle garde ; un transfert ne crée pas une Marque
originale ; une réaction n'est pas une nouvelle carte jouée.

Conserver pour ce lot les défenses physiques/magiques actives. Le lot ultérieur
de résistances élémentaires reprend la proposition bornée du 29 septembre :
défense de canal + résistance élémentaire dans un plafond commun [-15 %,40 %],
pas deux grosses réductions successives. Il nécessite des paquets pondérés et
une compatibilité exacte à résistances nulles, incluant parade, garde, Marque,
drain et réactions. Ne pas l'embarquer avec les premières formes pour prétendre
isoler leur équilibrage.

## 8. Transactions, sauvegardes et compatibilité

### Brouillon et confirmation atomique

Le dossier prépare un état de progression candidat. Le service de règles
valide budget, identifiants, famille possédée, niveau, emplacements, hors-combat
et droits de réorientation. Il recalcule les aperçus, sauvegarde la transaction,
puis publie le nouvel état. Une erreur d'écriture ne laisse pas la moitié d'une
répartition appliquée ; le joueur garde un état cohérent et une action Réessayer.

Le bilan, les points gagnés et les décisions non terminées ont des identifiants
stables. Reprendre après le gain mais avant un choix n'accorde ni deuxième niveau,
ni deuxième lot. Les règles d'engagement, d'annulation et de consommation de la
Battle existante restent l'unique référence.

### Champs envisagés, sans deuxième run

```text
progression_schema: future version for these fields
basic_element: null | element_id
training_forms: { family_id: form_id }
pending_normal_offer: { receipt_id, bag_id, options, chosen_option }
guard_sources: [ source_id, amount, expiry, carry_fraction, carry_used ]
```

Maintenir identifiant de run, profil et chemin de sauvegarde existants. Le numéro
de schéma est arrêté au lot d'implémentation, sans confondre révision du Prototype,
schéma de sauvegarde et révision des définitions. Les références de forme et de
contenu deviennent stables ; ne pas les déduire d'un nom traduit.

Anciennes améliorations : migration vers la forme standard équivalente, sans
attribuer de nouveau point. Ancien combat en cours : conserver ses définitions
et états jusqu'à la victoire ; migrer dans la préparation suivante. Forme absente
d'une définition restaurée : proposer une réparation hors combat et libérer son
emplacement, en conservant les copies ; ne pas inventer un nouveau comportement
au milieu d'une bataille.

### Réorientation et PV

Avant le premier combat : libre. Chaque halte admissible garde son droit unique
de déplacer jusqu'à deux points ; une inflexion peut partager ce droit. Le reset
complet unique après le niveau 8 garde ses profondeurs et sa classe conservée.
Les formes restent réaffectables hors combat selon leur règle propre.

Changer Vitalité, objet ou configuration conserve le ratio de PV non arrondi.
Le premier gain de niveau attribue une seule fois son delta de maximum, avant
les choix du brouillon. Rééquiper, retirer une aptitude, fermer/rouvrir ou
recharger ne soigne pas et ne réinitialise pas un droit.

Entre runs, conserver codex, découvertes et options de départ de budget comparable ;
réinitialiser niveau, investissements et possessions de run. Aucun bonus permanent
de puissance n'est ajouté par ce dossier. Le contrat de compte futur reste à
définir si le produit veut un mode distinct de progression permanente.

## 9. Responsabilités et validation avant chaque livraison

Réutiliser `consumable_progression_v1.gd` pour budgets et validité,
`consumable_cards_state.gd` pour l'état, `consumable_card_math.gd` pour calcul et
aperçu, les services de sauvegarde et d'intégration pour les transactions.
Le résolveur de forme doit fournir les mêmes définitions détachées à l'aperçu et
au cast. L'UI ne recopie aucune règle. La publication et les validations de contenu
passent par les services Studio existants ; adapter les décomptes fixes du catalogue
avec un manifeste explicite, sans supprimer les autres contrôles.

| Lot | Cas indispensables avant de l'intégrer |
|---|---|
| Inflexion | Quatre classes × six éléments ; bonus conditionnel ; garde du Gardien ; ancien 80/20 ; copies épuisées ; reprise d'ancien combat |
| Formes | Affectation/retrait ; famille épuisée ; nouvelles copies ; cast/aperçu ; dégâts par cible ; limites par cast ; migration d'amélioration |
| Statuts entiers | Fort/court, faible/long, égalité, prochain tic, source disparue, defenses changées, save entre activations |
| Garde sourcée | Plusieurs dates, cap, absorption partielle, carry déjà utilisé, urne, Bastion, conservation sans proc, reprise au début du héros |
| Composantes multiples | Dégâts puis mort, absence d'effet post-mort, marque précédente/nouvelle, drain/garde, arrondi par composante, permissions de classe |
| Offres | Quantité conservée, sac perdu, pools vides, duplicates, choix inachevé, double confirmation, save avant/après choix |
| Aptitudes | Absence d'effet sur sources exclues ; contrepartie du même budget ; profondeur/copies de soin normales ; absence de soin hors combat gratuit |

Pour tout changement effectif de cartes/progression : suite Cartes, parcours public
et reprise, captures inspectées et scénarios impactés. Pour le moteur commun :
import, suite globale et gates CI obligatoires du dépôt. Ne pas annoncer un succès
avec zéro test, timeout, rapport absent ou diagnostic neutralisé.

La campagne comparative garde graines, adversaires, départs, récompenses proposées
et niveaux identiques. Comparer trois décisions **en changeant un seul facteur** :
forme, inflexion ou offre. Mesurer dégâts utiles, activations ennemies évitées,
garde créée/absorbée/expirée, soin utile/perdu, copies par combat et ruptures de
répertoire. Compléter par essais humains de compréhension et de décisions.
Un harnais à six tours et une projection arithmétique ne donnent aucun win-rate.
