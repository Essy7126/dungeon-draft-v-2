# Trois sorts regardés, puis reconstruits — 22 septembre 2026

Périmètre : recherches et atelier Godot pour la **run Cartes**. L’utilisateur a
retenu **A — Animation cel** après comparaison le 22 septembre 2026.
[Décision et références retenues](achilles/cards_vfx_cel_2026-09-22.md).
Les VFX du combat restent ceux du jeu ; la sélection de DA ne valide pas encore
toutes les animations d’étude comme animations finales.
[Lancer l’atelier](../../tools/class_card_vfx/reference_study/README.md).

## Ce que les recherches permettent de dire

Je n’ai trouvé aucun classement public fiable du nombre de lancements de chaque
sort dans les trois jeux. Un guide de build indique une utilisation conseillée,
pas une fréquence globale, ni une appréciation de l’animation. Les trois études
ci-dessous ont été choisies parce que leur animation était directement observable.
Deux sont des références historiques : elles ne prouvent pas le rendu actuel.

Pour l’usage actuel, le [guide Iop WAKFU de Timtoobias et ChatonCharge96,
17 février 2026](https://guidactik.com/wakfu/guide-du-iop-sur-wakfu-builds-sorts-et-astuces/)
recommande notamment Épée céleste pour les dégâts de zone, Iop Punch pour exploiter
Courroux et les remboursements de PA, et décrit l’Étendard comme un outil de zone,
de résistances et de repositionnement. Cela explique l’intérêt de les jouer,
sans établir pourquoi les joueurs aimeraient leurs VFX.

Pour WAVEN, [ce build Paladir Hioplite](https://guidactik.com/waven/guide-et-build-du-iop-paladir-hioplite-sur-waven/)
inclut Frappe du Dragon dans son fonctionnement avec Boueux. C’est une piste pour
une prochaine étude de sort joué ; elle ne permet pas de qualifier Deux Doigts de
sort populaire aujourd’hui. Je n’ai pas remplacé cette absence de données par une
liste inventée de « sorts les plus joués ».

## DOFUS : Épée céleste

**Référence regardée :** [Coverer Dofus, toutes les animations du Iop,
24 septembre 2024, vers 00:39–00:41](https://www.youtube.com/watch?v=Dw2tuzw_CJk&t=39s).
Le chapitre commence à 00:33 et montre le nom anglais *Celestial Sword*. Il s’agit
d’une démonstration Unity de 2024, pas d’une capture de la version de septembre 2026.
La séquence a été mise en pause puis parcourue image par image.

**Ce que j’ai vu :** une lame cyan, pointe en bas, se forme au-dessus de la cible.
Elle reste un instant suspendue, blanchit et tombe très vite. Le contact produit
une colonne blanche, une gerbe claire, des fragments sombres et un anneau cyan au
sol. La lame disparaît ; une traîne courbe termine le mouvement.

**Pourquoi cette séquence est intéressante à reproduire — mon analyse :** on sait
avant le choc quel objet va frapper et dans quelle direction. Le bref passage au
blanc est compréhensible parce qu’il arrive après une lame encore lisible. Les
cailloux restent visibles sur la lumière et matérialisent le sol touché. Dans nos
anciens essais, une volute presque constante ne racontait pas aussi nettement
« cette lame tombe ici ». Ce constat porte sur cette séquence précise, pas sur
tous les sorts de DOFUS.

**Retours réellement consultés :** sous cette vidéo, un joueur préfère l’ancien
couple son/animation de Tempête de Puissance ; d’autres critiquent la Colère ou
l’omniprésence des épées. Un commentaire apprécie Pygmachia tout en trouvant les
figures divines d’autres sorts trop statiques. Ces avis contredisent l’idée que
les nouvelles animations seraient unanimement aimées. Ils ne jugent pas tous
Épée céleste et ne constituent pas un sondage.

**Reconstruction :** apparition de 0,12 à 0,32 s ; suspension jusqu’à 0,63 s ;
chute en 0,09 s ; contact à 0,72 s ; flash jusqu’à 0,805 s ; extinction avant
1,72 s. Ces temps sont les réglages de notre étude, **pas des mesures certifiées
de la vidéo**. Le corps de la cible reçoit un bref recul activable séparément.
La zone de dégâts, le lanceur et son animation ne sont pas simulés.

## WAVEN : Deux Doigts

**Référence regardée :** [GIF du sort dans la note de ToT du 13 septembre 2018](https://totaime.wordpress.com/2018/09/13/waven-note-18-les-icones-et-fx-de-sorts/),
[animation directe](https://totaime.wordpress.com/wp-content/uploads/2022/09/22e2a-spell_sram_deuxdoigts_v2-1.gif?h=295&w=268).
Le chemin du média contient 2022 ; l’article qui le présente est daté de 2018.
C’est un prototype historique.

**Ce que j’ai vu :** une main d’eau aux deux doigts parallèles jaillit sous la
cible. Le bord blanc décrit les doigts, de longues pointes verticales prolongent
la montée, quelques pierres sont projetées. La main ne reste pas comme une statue :
elle retombe en eau, éclabousse puis s’aplatit en flaque.

**Mon analyse :** le nom se comprend dans la silhouette, et la matière se comprend
dans la fin de l’animation. Le moment où les doigts cessent d’être une main est
donc aussi important à reproduire que la pose haute. Une image de main bleue
simplement fondue en transparence perdrait cette partie du geste.

**Retours :** dans les commentaires de l’article, Geoffrey s’intéresse précisément
au retour des doigts vers la flaque ; Félicien Auguin apprécie la visibilité sans
surcharge ; Pabll Guinard relève le manque de réaction des cibles. Ce petit
échantillon concerne le prototype. Il ne démontre pas l’appréciation actuelle.

**Reconstruction :** montée de 0,14 à 0,39 s, contact à 0,36 s ; pose haute puis
écrasement/élargissement de 0,63 à 0,99 s ; gouttes et flaque s’éteignent vers
1,65–1,70 s. La déformation d’un sprite est une approximation : il manque encore
des dessins intermédiaires où les doigts se déchirent vraiment en nappes d’eau.
La version peinte ressemble davantage à une matière minérale ; ce défaut est
visible dans la comparaison et reste à juger, pas à masquer par une description.

## WAKFU : Étendard de bravoure

**Référence regardée :** [vidéo officielle du Iop, 2015, vers 00:38–00:39](https://www.youtube.com/watch?v=DoTwvemkBYE&t=38s),
parcourue image par image. L’objet est identifié comme l’Étendard par l’épée
plantée, la zone et la description du sort ; son nom n’est pas incrusté à cet
instant dans la vidéo. Les mécaniques actuelles du guide de 2026 ne sont pas
attribuées rétroactivement à la version 2015.

**Ce que j’ai vu :** une grande épée grise à garde rouge-orange occupe une case
près du Iop. Des emblèmes orangés marquent le sol autour. L’objet subsiste pendant
que le personnage est libre de bouger.

**Mon analyse :** on peut désigner l’endroit où se trouve le sort. Sa présence ne
nécessite pas une aura qui recouvre le personnage. C’est le cas concret le plus
utile de ce lot pour étudier un effet durable. Je n’ai pas trouvé de témoignage
établissant que les joueurs aiment particulièrement ce VFX ; son utilité tactique
est mieux documentée que son appréciation esthétique.

**Reconstruction :** pose entre 0,14 et 0,48 s, contact court puis épée immobile
sur une position voisine. Les marques sont centrées sur l’épée. Le maintien ne
dépend pas d’une minuterie d’animation : seul « Retirer l’étendard » le termine.
L’atelier vérifie aussi son maintien à 600 s. Le GIF boucle artificiellement pour
la présentation ; la fenêtre interactive conserve l’objet.

## Comment ces essais ont été fabriqués

La note de ToT documente le passage des icônes de Franho/Aisk aux FX de
Sylvain/Sébastien. Elle ne fournit pas les fichiers de travail ou un pipeline
d’export complet. [Deeamo décrit son travail de FX 2D image par image pour DOFUS](https://deeamo.fr/dofus-x-deeamo-lanimation-de-fx-dans-le-jeu-dankama/).
Son montage Iop a également été regardé ; ses quatre effets ne sont pas légendés
individuellement. Rien ici ne permet d’affirmer quels outils exacts produisent
les versions actuelles des trois jeux.

Notre chaîne reproductible est enregistrée dans le dépôt : observations avec
sources → silhouettes originales en PNG transparent → région alpha et ancrage
des pieds → chronologie GDScript → capture native Godot → comparaison à taille
de jeu. Les six PNG ont été générés avec l’outil intégré **image_gen**, copiés sans
retouche ; les prompts exacts sont dans `art/prompts.json` et
`art/standard_prompts.json`. Aucun asset Ankama n’a été importé dans le jeu.

Les colonnes utilisent **A, aplats cel**, **B, volume sculpté**, **C, encre et
pigments**. B reste un sprite 2D, pas un modèle Blender. Les mouvements sont
identiques entre colonnes pour pouvoir comparer le dessin. Les fragments, jets,
anneaux et courbes sont animés dans Godot. Ce n’est ni un flipbook entièrement
redessiné ni une reproduction image pour image des originaux.

## Cinq états sur une cible

La quatrième page compare les **shaders éthérés de production au moment de l’étude, désormais archivés dans le laboratoire** à deux essais : marque
au-dessus de la tête et entrave aux pieds ; ou étiquettes seules avec impulsion
ponctuelle de brûlure. Chaque colonne conserve le nom et la durée de chaque état.
La fixture utilise marque/entrave/faiblesse à une activation, brûlure/saignement
à deux : 5 états → 2 → 0, uniquement via « Fin d’activation ». Ce bouton est une
simulation explicite, pas un raccordement au cycle réel du combat.

Cette page permet de juger le coût visuel du cumul sans décider encore quelle
solution convient à toutes les cartes. Les signaux localisés ne couvrent pas à
eux seuls les 23 états de production.

## Limites pour juger la satisfaction

L’atelier est **silencieux** ; le recul est un décalage du sprite, pas une animation
de blessure du personnage. Il ne reproduit pas l’ensemble son, lanceur, cible,
chiffres de dégâts et rythme d’un vrai tour. Il permet une première comparaison
du geste et des matières. Les captures et contrôles techniques ne prouvent pas
que le résultat est beau ou satisfaisant. L’animation cel étant retenue, le prochain
essai pertinent sera un seul sort branché sur une vraie résolution Cartes, avec
sa réaction et son son, avant toute déclinaison du catalogue.
