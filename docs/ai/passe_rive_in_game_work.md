# Passe-rive — intégration quatre vues, travail en cours

## Priorité ultérieure du 12 septembre — nouveau personnage après étude Ankama

La demande active est une recherche complète de la production Ankama, puis un
personnage recréé de zéro. [Audit consolidé et cible réalisable](../design/achilles/ankama_character_feasibility_2026-09-12.md)
et [fiche actuelle](ankama_character_pipeline_work.md). Ne pas reprendre la marche
Passe-rive automatiquement : son design n’est pas reconduit pour le nouveau héros.

Le dernier candidat conservé est la [marche ordinaire V2](../../art/source/characters/achilles/passe_rive_walk_unarmed_v2/README.md),
60 images par vue, 267 contrôles Godot GPU réussis, **avis artistique non reçu**.
Cette V2 corrige les appuis et la coordination du modèle de mouvement ; les
transitions et l’idle restent absents. Les sections suivantes conservent l’historique.

## Mise à jour du 12 septembre 2026 — marche refaite sans armes

Demande explicite : refaire complètement la marche, enseignements Dofus, sans équipement.
**Nouveau candidat produit**, quatre vues dessinées en pièces 2D stables, 48 images/vue,
cycle 0,8 s. [Sources, prompts, limites et reprise](../../art/source/characters/achilles/passe_rive_walk_unarmed_v1/README.md).
[Nouvel aperçu](http://127.0.0.1:8734/files/passe_rive_walk_unarmed_v1/review.html).
Laboratoire `tools/passe_rive_unarmed/WalkReview.tscn` : 219 contrôles Godot avec GPU réussis,
192 images, 2 304 points d'articulation couverts, boucle et navigateur vérifiés, quatre
captures natives inspectées. **Avis artistique utilisateur attendu**, ne pas annoncer
« niveau Dofus » ni reprendre les sorts avant le retour sur la marche. Le tissu reste
simple, départ/arrêt et idle non produits, virages instantanés. Ancien candidat conservé.
Pièces et calques Krita éditables, mouvement commun/attaches en JSON. N réutilise sa
sandale correctement orientée pour les deux pieds ; N/14 original erroné est exclu.
Aucun achat, installation ou essai vidéo externe consommé. Git ciblé vérifié ; autres
travaux du dépôt préservés. Les paragraphes ci-dessous décrivent l'historique antérieur.

## Consigne prioritaire du 11 septembre 2026

L'utilisateur a interrompu la production simultanée : **une animation à la fois, contrôlée dans tous ses angles avant la suivante**. Reprise par la marche seule. Les autres nouvelles planches sont des brouillons NON VALIDÉS. Ne plus lancer de lots de sorts en parallèle. Ne pas ajouter Passe-rive au menu public tant que le kit n'est pas validé et complet. La ligne du catalogue public a été retirée ; le raccordement runtime est un chantier inactif.

Critères pour la marche : bonnes vues E/S/N/W sans inversion de main, alternance des appuis, absence de glissement manifeste, pieds et lance non coupés, taille/couleurs stables, boucle et changement de direction, affichage sur carte. Une vérification technique ne vaut pas validation artistique. Conserver une fiche de défauts par direction et ne passer à l'idle ou à un sort tant que la marche reste incohérente.

Dernier retour utilisateur : **marche refusée pour manque de fluidité et qualité visuelle**, demande d'étudier la fabrication Dofus. [Dossier et protocole](../design/achilles/dofus_animation_method_2026-09-11.md) : charte de Julien Druant réellement examinée, marionnette commune de Nicolas Détrain, deux cycles de marche observés image par image. [Comparatif local](http://127.0.0.1:8734/files/dofus_motion_study/review.html) vérifié : deux références et nos 48 images. Nouveau pilote recommandé : source 2D éditable E, pièces stables, pieds de remplacement, pistes Godot + dessins Krita ; aucune nouvelle animation produite avec cette méthode à ce stade. Ne pas relancer une planche complète d'intermédiaires. Les trois autres vues suivent sur la même marche, avant idle/sorts. Aucun achat, aucun job externe soumis.

Mise à jour tardive du 11 septembre : la [recherche sur les réparations partielles](../design/achilles/passe_rive_partial_repairs_2026-09-11.md) répond à la demande utilisateur d'outils/vidéos/modèles extérieurs. Marche E reconstruite par 4 poses clés + 8 intermédiaires, toujours non approuvée. Suivi OpenCV installé isolément dans artifacts/dev-tools/walk-tracking : dérive verticale locale mesurée sur 4 images ; le réglage de vitesse seul ne suffit pas. Suivi perdu au croisement, donc aucune conclusion automatique sur le reste. Trois autres vues dessinées/contrôlées visuellement, contacts non quantifiés. Le laboratoire WalkReview.tscn utilise la vraie grille forêt ; la campagne reste inchangée. Un essai Genjutsu gratuit (4,8 s, E seule, 720p) est préparé sous passe_rive_walk_iso_v1/transfer_trial ; question utilisateur en attente pour consommer l'essai, aucun achat ni job soumis. Garder ce statut à jour après toute réponse.

11 septembre 2026. Demande utilisateur confirmée : **tout le kit dans les quatre vues**, pas seulement marche/idle. Dépôt relu ; préserver les travaux de titre et audio présents dans Git.

- Base conservée : 10 actions / 50 poses E, marche V3 / 12 poses, idle issu de la récupération.
- Le jeu utilise E/S/N/W logiques : écran bas-droite/bas-gauche/haut-droite/haut-gauche. Produire trois vues dessinées supplémentaires, sans miroir des mains/armes.
- Art : ImageGen intégré, détourage logiciel déjà autorisé. Garder les prompts et feuilles dans `art/source/characters/achilles/passe_rive_iso_v1/` ; sorties runtime sous `assets/characters/Achilles/passe_rive_iso_v1/`.
- Intégration prévue : variante visuelle Passe-rive sélectionnable et persistante, backend dérivé réutilisant l’horloge, la marche par distance et les événements du backend Achille. Aucun changement d’équilibrage.
- Vérifications à faire : rendu quatre directions, gestes et annulations, déplacements réels sur la grille, événements d’impact, échelle/tri visuel, sélection et sauvegarde ; import et tests existants pertinents via le harnais.
- État actuel : montage provisoire de 27 clips (126 poses) avec 17 clips encore absents. Ne pas livrer ce montage incomplet. Backend et scène Passe-rive préparés mais pas encore vérifiés ; registre de variante préparé, variante non exposée au menu. Recentrage sur une revue de marche dédiée.
