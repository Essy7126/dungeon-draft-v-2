# Sélection des personnages : illustrations v2

Création du 6 septembre 2026 avec l’outil intégré `image_gen`. Ces assets sont originaux. Les captures de Dofus servent de référence de composition et ne sont pas intégrées au jeu.

## Livrables

| Asset livré | Source de génération | Utilisation |
| --- | --- | --- |
| `asset/ui/character_selection/sanctuary_v2.png` | `exec-f678607f-a007-4328-aeab-ad410c99ba80.png` | Décor de la sélection |
| `asset/ui/character_selection/portraits/trio_illustrated_v2.png` | `exec-a1ee340e-73d9-4293-b4a8-d5816de74ae0.png` | Planche de trois portraits, 2172 × 724 |
| `asset/ui/character_selection/portraits/achilles_illustrated_v2.png` | `exec-ef77ecd6-88ab-4869-8755-5e6f163bd3a6.png` | Portrait d’Achille partagé entre ses deux aventures |

Les originaux sont conservés dans `C:/Users/paolo/.codex/generated_images/01a071ac-57af-72e0-948e-eabbebdda416/`. Les PNG livrés sont copiés sans retouche. Trois ressources `AtlasTexture` découpent la planche en cellules de 724 × 724, de gauche à droite : Elfe, Mage, Guerrier. `filter_clip` évite que les cellules voisines débordent à l’échantillonnage.

## Direction donnée à la génération

Les indications ci-dessous résument les briefs ; ce ne sont pas des transcriptions verbatim des prompts.

**Sanctuaire.** Décor de sélection de RPG peint à la main, grec et mythologique, vue frontale légèrement surélevée sur un socle circulaire de bronze. Pierres ivoire, colonnes usées, ouverture monumentale sur une vallée embrumée bleu vert. Lumière chaude, contours picturaux précis, centre dégagé pour la silhouette du héros et côtés calmes pour les panneaux. Format panoramique 16:9, sans personnage, texte, logo ou interface incorporée. L’illustration est décalée de 58 unités vers la gauche dans le canevas pour aligner le socle avec l’aperçu.

**Trio.** Planche horizontale de trois portraits carrés, cadrés en buste, avec une même lumière chaude et un fond bleu vert discret. Elfe : peau claire, cheveux blancs, oreilles pointues, armure argent/ivoire et détail émeraude. Mage : homme âgé, longue barbe grise, grand chapeau mou anthracite et vêtement sombre. Guerrier : casque d’acier fermé, visage dissimulé, armure métallique. Traitement fantasy peint, silhouettes très lisibles à petite taille, sans texte ni cadre incorporé.

**Achille.** Portrait peint du champion grec, peau méditerranéenne hâlée, casque doré ouvert laissant voir le visage et cimier rouge, tunique de lin crème, bouclier bleu et or. Même gamme bleu vert et lumière dorée que les portraits du trio, cadrage rapproché et fond calme, sans texte ni interface.

Les portraits existants rendus depuis les modèles ont été inspectés avant de décrire les personnages. La tentative d’édition à partir de leurs chemins locaux a échoué à cause d’un problème d’ACL de l’outil. Les générations finalement utilisées sont donc des créations depuis ces descriptions, et non des retouches garanties pixel par pixel des modèles.

## Portée

Ces illustrations apparaissent uniquement dans la sélection. L’aperçu central reste animé à partir des assets réels du jeu : sprite pour Achille, modèles existants pour le trio. Aucune nouvelle tenue, animation de combat ou variante cosmétique n’est annoncée. Les anciennes ressources restent disponibles en repli.
