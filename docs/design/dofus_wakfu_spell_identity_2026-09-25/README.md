# Identité des sorts DOFUS / WAKFU — étude du 25 septembre 2026

**91 fiches directement lues : 36 sorts DOFUS et 55 sorts/passifs WAKFU**, centrées sur le Xélor et complétées par le Pandawa et le Féca. L'objectif est de comprendre la décision créée par chaque sort : paiement, accès à la cible, état préparé, chronologie, interaction de build, réponse adverse et levier d'équilibrage.

Cette étude approfondit le [premier audit comparatif](../spell_comparison_2026-09-25/README.md) avec des fiches plus détaillées et des corrections de version. Elle ne prétend pas couvrir toutes les classes, variantes ou capacités ennemies des deux jeux.

**Suite disponible : [extension classes et bestiaire](extension_classes_bestiaire/README.md).** Elle ajoute 155 fiches pour les 16 classes DOFUS et 15 classes WAKFU restantes, ainsi que 42 entrées de bestiaire dans 11 rencontres. Les deux dossiers représentent désormais toutes les classes des catalogues consultés, sans couvrir intégralement leurs sorts. Les inconnues et les limites de validation restent explicites.

## Lecture du dossier

**Approfondissement final : [personnages et builds WAKFU](../wakfu_character_builds_2026-09-25/README.md)**, avec 38 lectures complémentaires, 18 portraits et 15 calculs. Les trois études réunissent 166 identifiants WAKFU distincts ; les limites de lecture du client restent explicites.

| Document | Contenu |
|---|---|
| [DOFUS](DOFUS.md) | 22 sorts du noyau Xélor affiché, 8 Pandawa, 6 Féca ; chiffres du dernier grade, rôle, restrictions et inconnues. |
| [WAKFU](WAKFU.md) | 15 élémentaires, 6 actifs et 20 passifs Xélor ; 8 Pandawa et 6 Féca ; niveau 245 ; lecture des interactions. |
| [Identité et équilibrage](IDENTITE_ET_EQUILIBRAGE.md) | Grille d'analyse complète, risques, protocole de 16 situations à vérifier en jeu, conséquences pour nos cartes consommables. |
| [Calculs](CALCULS.md) | 14 exemples reproductibles : remboursements, minimum de PA, rendement par cible, géométrie, retraits, résistance et calendrier de protection. |
| [Sources et versions](SOURCES_ET_VERSIONS.md) | Provenance, changements historiques, contradictions résolues et champs toujours non certifiés. |
| [Résultats détaillés](resultats_calcules.json) | Hypothèses et chronologies des modèles ; export réutilisable. |

## Les conclusions qui changent notre manière de concevoir

**Un sort ne possède pas une puissance unique.** Éclair obscur est surtout dangereux par son rebond. L'Orbe défensif récompense une cible préservée ; Rempart valorise une cible encerclée. La situation, le bénéficiaire et le délai font partie de l'effet, au même titre que les dégâts.

**Le coût net n'est pas le coût de lancement.** Deux Suspensions sur le Cadran coûtent quatre PA après remboursements, mais il en faut six au départ sans autre revenu. Un échange remboursé peut coûter zéro PA net et rester impossible avec un seul PA disponible. Notre économie de cartes ajoute encore la copie détruite.

**L'identité d'une classe vient de ses transformations.** DOFUS Xélor prépare et exploite des Téléfrags. WAKFU Xélor coordonne ressources, heure courante et effets différés ; ses passifs peuvent remplacer un retrait par une autre fonction ou changer les règles de ciblage. Ajouter seulement des bonus de dégâts à un verbe commun ne produit pas la même profondeur.

**L'équilibrage peut échouer dans la préparation.** Après des baisses de puissance, les changements Xélor WAKFU 1.92 rendent plusieurs accès aux ressources plus souples. Il faut mesurer le tour de mise en place, les tours suivants et l'autonomie du kit, au lieu de tester seulement son meilleur combo installé.

**La précision exige de séparer les versions.** Le guide Xélor consulté attribuait encore des revenus de cycle à Connaissance du passé ; les données récentes et la note 1.92 lui donnent un rôle de durabilité du Cadran. Les additionner aurait inventé une synergie. Les contradictions Pandawa encore visibles sont conservées comme inconnues, sans calcul de faux rendement.

## Niveau de validation

Lecture documentaire et calculs réalisés ; **14 cas, 15 groupes de contrôles mathématiques et de couverture exécutés avec succès**. La couverture compte bien 36 + 55 fiches. Les hypothèses sont écrites avec chaque résultat.

Aucun test dans un client DOFUS/WAKFU ni dans Godot n'est revendiqué. Les limites de données empêchent encore une simulation fidèle de certains effets, explicitement listés. Aucun gameplay du dépôt n'a été modifié.

## Reprise sur un autre ordinateur

Le dossier est autonome et utilise des liens locaux relatifs. Commencer par `SOURCES_ET_VERSIONS.md` avant de reprendre un coefficient ; lire ensuite le jeu et le sort concernés. Pour recalculer :

```powershell
node docs/design/dofus_wakfu_spell_identity_2026-09-25/calculs.mjs
```

Base de dépôt observée pendant l’analyse : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`. Ces recherches sont désormais versionnées sur `main` ; récupérer cette branche sur l’autre ordinateur pour les reprendre. L’[étude complète des cartes de Slay the Spire 1](../slay_the_spire_complete_2026-09-25/README.md) prolonge la comparaison.
