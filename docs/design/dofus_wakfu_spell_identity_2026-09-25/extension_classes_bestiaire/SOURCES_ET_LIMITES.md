# Sources, versions et limites de la nouvelle lecture

Consultation : **25 septembre 2026**. Les 155 fiches individuelles sont liées dans les deux fichiers de classes. Les onze guides de rencontres sont liés dans les deux bestiaires. Aucun contenu intégral de guide n'est recopié ; les fiches sont des synthèses et l'application à Catabase est une proposition originale.

## Corpus et qualité de preuve

| Corpus | Méthode de lecture | Limite à conserver lors de la reprise |
|---|---|---|
| [DOFUSDB.com](https://dofusdb.com/) | Catalogues, 80 pages de sorts, dernier grade, description et effets visibles | Site communautaire, pied de page 3.6.9.9 ; pas de contrôle client live. Portées/contraintes secondaires parfois incomplètes. |
| [WAKFULI](https://wakfuli.com/encyclopedia/spells) | Catalogues des quinze classes restantes ; 75 panneaux Effets, coûts et Conditions ; relecture du panneau Description de 28 fiches ambiguës | N245 ; build du site distinct du patch de données ; branches et états parfois mal dépliés. |
| Dofus pour les Noobs | Sorts/passifs, principe des six rencontres, exceptions et révisions visibles | Source explicative communautaire ; observer la date et ne pas mélanger anciennes stratégies et effets modernes. |
| MethodWakfu | Cinq familles, sorts, passifs, seuils et stratégie | Certaines pages conservent d'anciens paliers Stasis ou une ancienne étiquette de version. |
| [Publications officielles WAKFU sur Steam](https://steamcommunity.com/app/215080/allnews/?l=french) | Lecture de l'annonce 1.93 et du devblog économique dans le flux du studio | Flux évolutif ; retrouver titre/date. Intention annoncée ne signifie pas livraison déjà effective. |
| Dépôt Catabase | Fichiers de salles, règles, IA, écosystème et un sort de préparation relus | Lecture statique ; aucun import, combat ou test Godot effectué pour cette étude documentaire. |

## Registre des onze rencontres

| ID | Guide | État de version / prudence |
|---|---|---|
| D1 | [Royalmouth](https://www.dofuspourlesnoobs.com/serre-du-royalmouth.html) | Révision indiquée 21/06/2026 ; bonus associés aux invocations inclus. |
| D2 | [Ben le Ripate](https://www.dofuspourlesnoobs.com/epave-du-grolandais-violent.html) | Révision 13/04/2018 : historique, pas certifié live. |
| D3 | [Tengu](https://www.dofuspourlesnoobs.com/taniegravere-givrefoux.html) | Guide accessible ; conditions de déverrouillage lues, pas testées. |
| D4 | [Comte Harebourg](https://www.dofuspourlesnoobs.com/donjon-du-comte-harebourg.html) | Mentions explicites 3.5/3.6 ; incohérence interne Stridicule conservée. |
| D5 | [Nileza](https://www.dofuspourlesnoobs.com/laboratoire-de-nileza.html) | Contrat sans invulnérabilité et avec Mélange Instable ; ne pas utiliser le vieux guide comme état actuel. |
| D6 | [Vortex](https://www.dofuspourlesnoobs.com/oeil-de-vortex.html) | Règles de calendrier lues ; détails d'anciens builds recommandés non repris. |
| W1 | [Bouftous](https://methodwakfu.com/pvm/donjons/paturages-des-bouftous/) | Réserve sur étourdissement du Chef et condition de Foudre Royale. |
| W2 | [Steamers](https://methodwakfu.com/pvm/donjons/donjon-steamers/) | Divergence de rayon et bug ancien signalé par le guide ; pas de choix silencieux d'une version. |
| W3 | [Clan de Bworkana](https://methodwakfu.com/pvm/donjons/donjon-clan-de-bworkana/) | Article 18/03/2026 ; nom Zulrana/Zulnara varie dans le texte ; même rencontre. |
| W4 | [Vandaliénés](https://methodwakfu.com/pvm/donjons/donjon-vandalienes/) | Page 22/05/2025 ; anciens paliers Stasis encore présents. |
| W5 | [Crocodailles](https://methodwakfu.com/pvm/donjon-des-crocodailles/) | Étiquette WAKFU 1.66 ; seuil imprécis ; nombre de salles incohérent entre introduction et corps. Référence historique. |

## Recoupements qui ont changé l'interprétation

**Panneau d'effets seul insuffisant.** La relecture des descriptions a permis de préciser Hémophilie (poison différé classé mêlée), Déphasage (protection contre perte des PA), Corruption WAKFU (transparence et baisse de production), Bombe collante (mort ou échéance), Coagulation (soi et alliés proches) et Intermédiaire (PM remplaçant des PA). Les coefficients ou opérateurs manquants restent inconnus ; ils ne sont pas reconstruits à partir du nom.

**Descriptions parfois en décalage.** Refus de la mort parle de résistance dans Description sans valeur correspondante dans Effets. Duel affiche une valeur de Parade anormalement grande à N245. Brèche temporaire décrit deux modes que l'onglet Conditions ne relie pas correctement. Ces cas ne doivent pas être des lignes de données prêtes à importer dans un simulateur.

**Versions DOFUS incompatibles.** Le [guide ancien Nileza de Tofus](https://www.tofus.fr/donjons/nileza) conserve des règles létales à grande distance. La [synthèse historique des simplifications de 2017](https://www.millenium.org/guide/273667.html?page=3) documente la suppression d'une invulnérabilité et de certaines sanctions. Nous retenons le contrat du guide D5 pour l'analyse contemporaine, sans additionner les couches historiques.

## Communication créateur : économie et disponibilité des changements

L'annonce officielle du 22 septembre présente **1.93 en ligne**, avec modifications Sacrieur, Roublard et Huppermage. Cela justifie une vigilance particulière sur leurs fiches ; cela ne certifie pas que WAKFULI reflète chaque correction. Le studio annonce aussi Bellaphone pour une période future : une classe annoncée ne rejoint pas notre inventaire des kits actuellement lisibles. [Flux officiel, titres du 22 septembre et du 15 juillet](https://steamcommunity.com/app/215080/allnews/?l=french).

Dans **« Devblog : les coffres de fin de saison »**, le 2 septembre, Ankama décrit deux problèmes : multiplication des récompenses par personnages et arrivée massive différée perturbant leur valeur. Le studio prévoit une attribution plus immédiate et une limite liée au compte, avec application annoncée au **1er octobre 2026**, donc future à notre date de lecture. [Publication officielle](https://steamcommunity.com/app/215080/allnews/?l=french).

Notre déduction pour Catabase : attacher un droit économique à une identité stable et livrer une ressource quand elle sert encore à la progression. Cela soutient des sacs gagnés sur les mobs pendant la run, tout en interdisant que résurrections ou invocations multiplient artificiellement les droits au butin. Cette proposition n'importe pas la monétisation ni les limites par compte du MMO.

## Frontière honnête de la connaissance obtenue

- Toutes les classes encore absentes sont représentées par cinq fiches ; leurs kits complets ne sont pas reconstruits. Variantes, innés et sorts d'invocations restent partiellement ouverts.
- Onze rencontres couvrent des structures différentes. L'ensemble des bestiaires DOFUS/WAKFU n'a pas été lu.
- Les guides apportent une expertise d'auteur, pas une distribution de comportements de joueurs. Aucun « les joueurs préfèrent » statistique n'est déduit de ces pages.
- Les chiffres externes ne sont pas des paramètres directement transférables : niveau, maîtrise, résistance, équipe, carte et Stasis changent leur valeur.
- Les seize calculs sont des modèles fermés, certains directement liés aux fiches, d'autres propres à nos propositions. Ils ne représentent pas une validation globale des 155 sorts ni une simulation de run complète.

## Reprise recommandée

Pour une fiche incertaine destinée à guider une implémentation, récupérer la description complète de l'état dans le client/version cible, puis observer une séquence normale et un cas limite. Relever paiement, position avant/après, états avant/après, dégâts, expiration, sources et identité des unités. Pour Catabase, exécuter ensuite la matrice de validation du dépôt adaptée aux changements réellement faits. La présente tâche ne modifie que la documentation et ses calculs.
