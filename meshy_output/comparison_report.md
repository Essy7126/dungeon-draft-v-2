# Comparaison Meshy / Higgsfield — 7 septembre 2026

Le test est terminé : quatre images générées et téléchargées avec le plugin Meshy. Sur cet échantillon, les icônes retrouvent une famille visuelle proche de Higgsfield ; Pro enrichit certains matériaux et détails. Pour la bibliothèque, Nano Banana 2 reste le plus proche de l'ambiance approuvée. Pro n'est pas un meilleur choix systématique.

## Méthode

Deux cas reprennent **mot pour mot** les prompts d'origine conservés dans `art/source/catabase/painted/manifest.json` : neuf objets d'inventaire, puis bibliothèque engloutie. Chaque prompt a été envoyé à `POST /openapi/v1/text-to-image`, une fois avec `nano-banana-2`, une fois avec `nano-banana-pro`. Les ratios restent respectivement `1:1` et `16:9`. Aucun conditionnement par une image de référence, aucune retouche, aucune conversion 3D.

Higgsfield avait reçu `nano_banana_pro`, mais son résultat déclarait `nano_banana_2`. Cette différence est conservée ; le nom rapporté ne permet pas de certifier le fonctionnement interne des deux plateformes. Les nouvelles réponses Meshy déclarent bien les modèles demandés.

La bibliothèque source est une **illustration de halte lore**. Son prompt précise qu'il s'agit d'un concept d'environnement et non d'un plan technique de niveau. Ce test ne valide ni grille de combat, ni collisions, ni ligne de vue, ni raccordement au jeu.

## Résultats visuels

| Critère | Meshy Nano Banana 2 | Meshy Nano Banana Pro |
| --- | --- | --- |
| Neuf objets et ordre 3 × 3 | Respectés ; marges régulières, objets séparés | Respectés ; marges régulières, objets séparés |
| Style des icônes | Volumes peints et matériaux lisibles ; accessoires plus simples que Higgsfield | Détails supplémentaires sur le verre, la patine, le coffre et la bague ; encore moins ornementé que la référence |
| Ambiance de la bibliothèque | Palette pétrole/turquoise/ambre proche de Higgsfield | Fond parchemin clair et contours sombres : écart marqué avec la référence |
| Composition du lieu | Diorama isolé, pont orienté vers les étagères du fond gauche | Vignette isolée, architecture réduite, escalier au premier plan |
| Accès au portail | Pas de chemin continu clairement raccordé au seuil droit | La plateforme s'interrompt avant le seuil |

Les deux bibliothèques s'écartent du décor plein cadre de Higgsfield. La source relie visuellement le chemin au portail ; aucune sortie Meshy ne reproduit cette continuité. Le rendu Pro du lieu peut convenir à une vignette de carnet, mais ne remplace pas directement la halte peinte existante.

La revue des quatre images et des références a été réalisée par deux lecteurs indépendants. Elle porte sur **un seul échantillon par cas et modèle** : elle ne prouve pas une supériorité générale d'une plateforme. Les aperçus du comparateur sont redimensionnés et compressés uniquement pour l'affichage ; les PNG originaux sont conservés.

## Résolution et fichiers

| Cas | Modèle Meshy | Dimensions | Taille du PNG | Coût réel | Fichier |
| --- | --- | --- | --- | --- | --- |
| Neuf icônes | Nano Banana 2 | 1024 × 1024 | 1 125 503 octets | 6 crédits | [PNG](20260907_170912_compare-higgsfield-inventory-i_01a07c6a/image.png) |
| Bibliothèque | Nano Banana 2 | 1376 × 768 | 1 401 755 octets | 6 crédits | [PNG](20260907_170912_compare-higgsfield-flooded-lib_01a07c6a/image.png) |
| Neuf icônes | Nano Banana Pro | 1024 × 1024 | 1 039 181 octets | 9 crédits | [PNG](20260907_171046_compare-higgsfield-inventory-i_01a07c6b/image.png) |
| Bibliothèque | Nano Banana Pro | 1376 × 768 | 1 523 805 octets | 9 crédits | [PNG](20260907_171046_compare-higgsfield-flooded-lib_01a07c6b/image.png) |

Les références Higgsfield mesurent 2048 × 2048 et 2752 × 1536. Les sorties Meshy ont ici la moitié de la largeur et de la hauteur des références. **Pro n'a pas augmenté la résolution dans ce test.** Le corps des requêtes ne spécifie pas de résolution ; la documentation du point d'entrée text-to-image n'en expose pas comme paramètre.

Les quatre images sont en PNG RGB, sans transparence. Ce sont des sources de travail ; des exports individuels et leur contrôle à la taille du jeu seraient nécessaires pour produire des icônes intégrées.

## Crédits et traçabilité

Solde initial : **1 426**. Solde final : **1 396**. Dépense réelle : **30 crédits**, confirmée à la fois par la différence du solde et par la somme des quatre `consumed_credits`. Les deux traitements ont coexisté : le solde de fin d'un sous-lot inclut aussi l'autre sous-lot ; utiliser les champs des tâches pour attribuer les coûts.

| Cas | Modèle | Identifiant Meshy |
| --- | --- | --- |
| Icônes | NB2 | `01a07c6a-8adf-725f-8c86-192588b5e2d6` |
| Bibliothèque | NB2 | `01a07c6a-8b93-7691-b726-1eca1c087710` |
| Icônes | Pro | `01a07c6b-fbaf-71bd-8f72-c1ea9d42c688` |
| Bibliothèque | Pro | `01a07c6b-fc63-74bf-8f10-fd366629d6f4` |

Chaque dossier conserve `comparison_request.json`, la réponse `task_<id>.json`, `comparison_result.json` et `metadata.json`. Les empreintes SHA-256, tailles et modèles sont regroupés dans [comparison_metrics.json](comparison_metrics.json). L'historique du plugin est conservé dans [history.json](history.json). Les liens d'images de l'API sont présents dans les réponses des tâches ; les PNG ont été téléchargés pour ne pas dépendre de leur expiration.

La clé a été lue sans écho et utilisée uniquement dans l'environnement des processus Python. Les deux processus ont été fermés. Aucune clé n'a été enregistrée dans un fichier du dépôt.

## Vérifications et portée

- Les quatre réponses API portent `SUCCEEDED`.
- Les quatre PNG passent `Pillow.Image.verify()` ; dimensions, taille et SHA-256 ont été relevés.
- L'identité de chaque prompt envoyé avec le prompt original du manifeste a été vérifiée.
- Les quatre `consumed_credits` totalisent 30, cohérents avec le solde final.
- Les ressources de jeu n'ont pas été remplacées. Les résultats restent dans `meshy_output/`, exclu de l'import Godot par `.gdignore`, et non suivis par Git. Aucun test moteur n'est revendiqué pour ces images de comparaison.

## Décision suggérée

Pour des objets isolés, Meshy est une piste crédible ; Pro mérite une sélection au cas par cas lorsque ses détails ajoutent de la lisibilité. Pour les haltes et maps dans le style Higgsfield, ce test ne démontre pas encore une substitution directe. Le prochain essai pertinent serait de conditionner la génération sur la référence approuvée, avec une contrainte explicite de décor plein cadre et, pour une arène, son guide géométrique. Cet essai supplémentaire n'a pas été lancé.

Sources : [API Text to Image](https://docs.meshy.ai/en/api/text-to-image), [tarifs Meshy](https://docs.meshy.ai/en/api/pricing), [production Higgsfield du projet](../docs/design/achilles/catabase_higgsfield_production.md).
