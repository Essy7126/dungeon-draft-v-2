# Tests de monstres — Catabase

Quatre images maîtresses explorent des adversaires pour la run de Catabase : mythologie grecque des Enfers, contours sombres, volumes peints simples et silhouettes lisibles. **Ce sont des concepts générés et revus visuellement, approuvés par l’utilisateur le 8 septembre 2026 pour production ; l’animation et l’intégration font l’objet du lot suivant.** Les rôles ci-dessous sont des intentions de conception, pas des capacités implémentées.

| Concept | Silhouette et rôle envisagé | Candidat existant, à confirmer après revue |
| --- | --- | --- |
| Rejeton de braise | Petit bipède voûté, grandes mains ; tireur fragile qui garde ses distances | `catabase_frail_hellspawn` : le Rejeton chétif des Enfers utilise déjà un trait d’ombre et reprend ses distances. |
| Molosse du Styx | Quadrupède bas, tête massive et dos hérissé ; poursuivant de mêlée | `odyssey_skirmisher` : l’escarmoucheur possède 4 PM et une attaque de mêlée. Un remplacement visuel nécessiterait de revoir son identité de Myrmidon. |
| Sentinelle d’airain | Masse trapue, grand bouclier rond ; défenseur de contact | `odyssey_guard` : le garde myrmidon est déjà cuirassé et combat au contact. L’apparence ne lui ajoute aucune mécanique de blocage. |
| Lamie du Léthé | Buste étroit et queue en S ; contrôle à distance | Aucun adversaire actuel identifié avec ce rôle complet. Le `serpent_meduse` existant est un sbire fragile à morsure, pas une lanceuse de sorts de contrôle. |

Les correspondances s’appuient sur les ressources de [Rejeton](../../data/units/enemies/catabase_frail_hellspawn.tres), [escarmoucheur](../../data/units/enemies/odyssey_skirmisher.tres), [garde](../../data/units/enemies/odyssey_guard.tres) et [serpent](../../data/units/ennemie/serpent_meduse.tres). Elles ne modifient ni leurs statistiques, ni leurs sorts, ni les rencontres.

## Préparer les futures spritesheets

1. **Valider une identité et une pose maîtresse.** Vérifier silhouette, anatomie, accessoires, palette et lecture vers 110–150 pixels de hauteur. Conserver des repères simples et constants entre les poses ; approuver chaque monstre avant de décliner ses animations.
2. **Dessiner quatre directions indépendantes N/E/S/W.** Garder la même caméra, le même éclairage et les mêmes proportions. Ne pas fabriquer les directions opposées par miroir.
3. **Fixer cadrage et ancrage.** Les frames de 512 × 384 pixels avec ancre au sol `(256, 320)`, utilisées par le spectre, constituent un point de départ. Vérifier les limites de chaque silhouette et de chaque mouvement avant de retenir ce format, notamment la queue, le bouclier et les armes. L’ancre suit le contact/projeté au sol du corps, sans déplacement artificiel entre frames.
4. **Séparer personnage, VFX et ombre.** Préparer de vrais PNG RGBA à bords propres ; contrôler le détourage et les marges. Les particules, traits magiques et autres VFX restent séparés. L’ombre au sol appartient au moteur et ne doit pas être incrustée dans le personnage.
5. **Produire puis vérifier les animations réelles.** La base du spectre comporte, par direction, 1 frame de repos, 4 de déplacement et 8 d’attaque. Adapter les cycles aux anatomies et au profil retenu : quadrupède, serpent et bipède ont des appuis différents. Anticipation, impact et récupération doivent correspondre aux actions du jeu ; ces animations restent à produire.
6. **Valider dans Godot.** Après construction des atlas et des ressources `SpriteFrames`, vérifier import, alpha, cadres, ancre, quatre orientations, déplacement, timing d’impact et fin d’action. Tester les silhouettes dans une vraie rencontre avec grille et HUD, sur fonds clairs et sombres. Ces validations runtime restent à exécuter avant toute intégration annoncée comme réussie.

Références techniques : [pipeline du spectre](../../tools/spectre_sprite_pipeline/README.md) et [contrat de sa vue Godot](../../characters/enemies/spectre_greatsword/README.md). Leurs comptes de frames et dimensions sont un contrat pour ce personnage existant ; leur réemploi pour ces monstres demande une vérification dédiée.

## Fichiers livrés

Quatre PNG RGB de 1 024 × 1 024, avec fond gris opaque. Coût constaté : **36 crédits** ; solde final : **1 111 crédits**.

[Planche comparative](monstres_tests.jpg) · [Lecture réduite](lecture_reduite.jpg) · [Prompts, identifiants Meshy et provenance](manifest.json) · [Contrôle des fichiers](technical_review.json).

| Image originale | Taille | Identifiant Meshy |
| --- | --- | --- |
| [Sentinelle d'airain](../20260908_125834_01-sentinelle-airain_01a080ab/source.png) | 962 Kio | `01a080ab-7311-73c4-8341-3d2c41d37ac6` |
| [Rejeton de braise](../20260908_125835_02-rejeton-braise_01a080ab/source.png) | 735 Kio | `01a080ab-73c5-7446-81eb-aae8f20432cc` |
| [Molosse du Styx](../20260908_125835_03-molosse-styx_01a080ab/source.png) | 774 Kio | `01a080ab-747f-74b7-86ac-3e90e383f8a7` |
| [Lamie du Lethe](../20260908_125835_04-lamie-lethe_01a080ab/source.png) | 795 Kio | `01a080ab-7544-7071-bfc3-99bf44c08287` |

## Revue avant animation

Les quatre silhouettes et leurs membres sont lisibles dans la planche. Les images maîtresses ont été conservées intactes. L’aperçu à échelle réduite sert seulement à juger les masses, sans prétendre à un test dans le moteur.

- **Sentinelle d'airain** : Silhouette trapue et bouclier tres lisibles; lance tenue en diagonale. Verrouiller le cote des accessoires et harmoniser la plongee avant les quatre directions.
- **Rejeton de braise** : Anatomie bipede coherente, mains et gorge orange distinctives. Vue plus laterale que la sentinelle; harmoniser la camera avant les spritesheets.
- **Molosse du Styx** : Quatre pattes visibles et silhouette basse distincte. Prévoir un vrai cycle quadrupede et verifier les occlusions des pattes au changement de direction.
- **Lamie du Lethe** : Queue unique et silhouette en S distinctes. La sortie tient le baton de la main gauche, contrairement au prompt; fixer la lateralite du modele retenu avant toute animation. Crete plus elaboree que les trois pointes demandees.
