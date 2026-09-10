# Références de mouvement pour les ateliers

Recherche du 9 septembre 2026, après rejet du pilote de Sentinelle.
Les pages sources ont été consultées. Les animations externes ci-dessous n’ont
pas encore été importées ni validées visuellement sur nos personnages.

## Première sélection

| Besoin | Source primaire | Contenu confirmé | Usage proposé et limite |
| --- | --- | --- | --- |
| Sentinelle, estoc et orientations | [Spearman — Bleed](https://opengameart.org/content/spearman-bleeds-game-art) | Sprites isométriques, attaque, parade, mort, marche dans 8 directions ; CC-BY 3.0 affichée | Première référence à examiner pour une action à la lance et ses différentes vues. Morphologie, poids, bouclier et angle exact restent à comparer. |
| Brute / combattant lourd | [Orc Warrior — marcintokarski](https://opengameart.org/content/orc-warrior) | Attaque, mort, repos, réaction et marche dans 8 directions ; OGA-BY 3.0 affichée | Examiner appuis et engagement du tronc ; une autre arme implique une autre mécanique. |
| Molosse : marche, course, morsure | [LPC Wolf — Redshrike et William.Thompsonj](https://opengameart.org/content/lpc-wolf-animation) | Marche, course, morsure, hurlement et mort ; sources PSD disponibles | Étudier l’enchaînement des pattes, du dos et de la tête. Pixel art LPC : ne pas supposer une caméra identique à notre grille. Conserver les crédits des deux auteurs si utilisé. |
| Molosse : référence sous plusieurs angles | [Ultimate Animated Animal Pack — Quaternius](https://quaternius.com/packs/ultimateanimatedanimals.html) | 12 animaux et plus de 12 animations chacun annoncés ; FBX, glTF et Blend ; CC0 affichée | Option de référence animée déjà construite pour examiner plusieurs vues. Ce n’est pas une validation de retarget sur nos modèles. |
| Coordonnation générale | [Animating — Esoteric Software](https://esotericsoftware.com/spine-animating) | Méthodes par poses, par passes et combinaison ; avertissement sur les mouvements déconnectés entre parties | Construire les poses majeures du corps entier, puis compléter les détails et mouvements secondaires. |
| Anticipation et propagation | [Anticipation #7](https://esotericsoftware.com/blog/Anticipation-Animating-with-Spine-7), [Wave Principle #4](https://esotericsoftware.com/blog/Wave-Principle-Animating-with-Spine-4), [Arcs #6](https://esotericsoftware.com/blog/Arcs-Animating-with-Spine-6) — Esoteric Software | Vidéos pédagogiques avec exercices/projets associés | Comprendre préparation, décalages entre parties et trajectoires. Ces enseignements restent utilisables sans acheter Spine. |

Pour Achille, conserver la ruée déjà appréciée comme référence interne. Pour la
Lamie et le Rejeton, aucune référence complète de sort n’est encore sélectionnée :
la gestuelle dépend du sort et de la morphologie. Ne pas utiliser une référence
humaine debout pour un quadrupède ou une créature serpentine sans adaptation.

## Complément du 10 septembre 2026 — mouvements humanoïdes réutilisables

| Source | Contenu documenté | Statut et limite |
| --- | --- | --- |
| [Quaternius — Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) | Plus de 120 animations annoncées pour le pack complet ; humanoïdes, retarget et formats usuels ; CC0 affichée. | Source repérée, pas importée ni examinée sur Passe-rive. Seule une partie est gratuite ; vérifier le contenu de chaque offre. |
| [Adobe Mixamo](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) | Bibliothèque d'animations de bipèdes et outils de rig. | Source repérée, pas d'adaptation Passe-rive validée. Adapter garde, proportions, mains et caméra. L'usage de clips dans le jeu ne vaut pas autorisation d'entraînement d'un modèle. |

Le [dossier de recherche](../design/achilles/sprite_generation_research_2026-09-10.md)
propose de tester une bibliothèque existante avant de reconstruire chaque action.
La [mémoire courte](../ai/animation_memory.md) contient les retours utilisateur et
les cas internes à comparer. Les statuts ci-dessus ne constituent pas des preuves
d'examen visuel des animations.

## Ce qu’une fiche de mouvement doit contenir

- Personnage / famille, masse apparente, proportions, arme et main porteuse.
- Action précise : estoc court, frappe de massue, bond-morsure, projection de sort.
- Référence animée, auteur, URL, droits et fichier local autorisé le cas échéant.
- Vue de caméra et direction réelle dans notre grille ; équivalence de direction
  à vérifier visuellement, jamais déduite uniquement du nom N/E/S/W du fichier.
- Phases : préparation, engagement, contact, freinage, retour. Points à suivre :
  bassin, thorax, tête, épaules, mains, pieds et pointe de l’arme.
- Observations : pied d’appui, transfert de poids, rotation du thorax, maintien
  du regard, rôle du bouclier, raccourci de l’arme et passages devant/derrière.
- Statut séparé : source repérée / mouvement examiné / adaptation testée /
  adaptation approuvée. Un lien de référence ne vaut pas validation du mouvement.

## Prochain essai recommandé

1. Examiner le lancier de Bleed et retenir un estoc lisible dans une vue compatible.
   Écarter la référence si sa mécanique ou sa perspective ne convient pas.
2. Faire une courte séquence de poses complètes simplifiées : garde, préparation,
   engagement, contact, retour. Définir ensemble bassin, thorax, tête et appuis.
   Un squelette 2D est un repère ; il ne remplace pas le travail de volume et de
   parties masquées lors d’une rotation.
3. Vérifier le mouvement avec une flèche au sol indiquant la cible et des repères
   de bassin/épaules. Dans notre convention, E pointe vers le bas-droite de l’écran,
   S bas-gauche, N haut-droite, W haut-gauche ; recaler la référence sur la projection
   de la scène. Le côté anatomique portant chaque arme reste constant.
4. Faire approuver cette mécanique avant toute peinture détaillée. Ne pas imposer
   huit dessins si le geste exige d’autres poses ; le pilote précédent conservait
   huit images uniquement pour isoler sa variable expérimentale.
5. Habiller les poses validées avec le personnage, vérifier les volumes et les
   raccords, puis utiliser les exports et contrôles du lecteur déjà disponibles.

## Ajout utile à l’atelier existant — à implémenter

L’atelier dispose déjà d’une image de référence au repos, d’un original animé et
d’un candidat. Il manque une **piste distincte de référence du mouvement** :

- clip vidéo local ou séquence d’images, lecture ralentie et image par image ;
- synchronisation par phases (contact ↔ contact), sans forcer le même nombre
  d’images ni la même durée que le candidat ;
- repères de bassin, épaules, tête, pieds, direction et trajectoire de l’arme ;
- bibliothèque filtrable par morphologie, arme, action et vue ;
- comparaison des silhouettes et superposition optionnelle après recalage.

Le catalogue documentaire présent est créé ; ce panneau animé et ces repères
ne sont pas encore implémentés. Ne pas confondre cette proposition avec une
capacité de transfert automatique : même avec de bonnes références, l’outil de
génération d’images ne garantit pas la continuité temporelle ou la géométrie.
