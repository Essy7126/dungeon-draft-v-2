# Veilleur — reprise de la marche E V2

12 septembre 2026. L’utilisateur accepte les proportions de
`veilleur_proportions_v1`, tout en précisant que la marche n’est pas bonne.
Cette version reprend le geste sans remplacer ce gabarit. Une direction,
sans équipement ; aucune acceptation artistique de cette nouvelle marche.

## Changements

- Le pantalon est un morceau continu autour du genou, au lieu de deux coupes
  rigides et de pastilles de raccord. Une bande déformable reprend les pixels
  du pantalon source. Sa ligne centrale passe par les hanches, genoux et chevilles
  mesurés ; les longueurs des segments et les largeurs des sections sont conservées.
  Le tissu peut se comprimer localement au pli : ce n’est pas une transformation
  rigide pixel pour pixel de l’ensemble de la jambe.
- Les bottes sont les pièces d’origine, simplement déplacées et pivotées.
  Bascule de −4 degrés au contact du talon, puis jusqu’à +5 degrés à la poussée.
  Le passage alterne avec l’autre jambe, avec une levée modeste.
- Le bassin utilise une courbe périodique lissée, suffisamment basse pour
  respecter la portée des jambes sans allonger les segments.
- **Erreur de phase corrigée :** le test antérieur avançait le bras avec la
  jambe du même côté. Les bras s’opposent maintenant aux jambes. Les déplacements
  de la main dans la direction projetée sont contrôlés sur les deux appuis opposés.
- 48 étapes continues pour 1,1 seconde. Ce sont des étapes calculées du montage,
  pas 48 dessins nouvellement créés. Aucune génération d’image pour cette reprise.

## Sources et sorties

`tools/veilleur_walk/walk_v2.py` relit les PNG de pièces dans
`art/source/characters/achilles/veilleur_proportions_v1`. Il ne les modifie pas.
`source_lock.json` conserve leurs empreintes, les repères et les contacts annotés.
`motion.json` conserve les positions produites. La base acceptée reste accessible
séparément, avec sa revue et ses 24 étapes d’origine.

Sorties : `artifacts/spine_trial/veilleur_walk_E_v2/` — 48 PNG RGBA de 512²,
atlas, APNG, WebP, planche de contrôle et revue avant/après synchronisée.
Le cadre et le pivot restent ceux de la base : 512², (256,442), échelle 0,32.
Les fonds sont référencés depuis le dossier de concept, sans nouvelle copie.

Revue : <http://127.0.0.1:8734/files/veilleur_walk_E_v2/review.html>.

## Vérifications et limites

`report.json` vérifie les longueurs, l’absence de modification des pièces sources,
le cadrage, la durée et les contacts annotés. La mesure de contact porte sur les
points dessinés du talon/de la pointe pendant un état d’appui inchangé, après
compensation du déplacement. Elle ne constitue pas un suivi de toute la semelle
ni une garantie de marche naturelle.

La nouvelle revue compare l’avant et l’après à phase et échelle identiques.
Elle permet aussi d’examiner le déplacement sur trois décors, avec ralenti,
pause et lecture image par image. `verification.json` expose les contrôles de
la page. Les captures servent à l’inspection des images réellement affichées.

Les occlusions, le naturel du pas et la jonction des mollets aux revers restent
à juger. Aucune intégration native Godot, idle, transition, autre direction ni
équipement. Les captures de combat utilisées sont celles du 5 septembre : la
comparaison sur décor est un photomontage, pas une nouvelle capture en jeu.

Aucun code du parcours public modifié ; tests du moteur commun non relancés.

Retour utilisateur reçu ensuite, 12 septembre : le pas n’est pas naturel.
Cette V2 n’est donc pas acceptée artistiquement. L’adaptation suivante,
`veilleur_walk_E_v3`, prend les poses observées dans la marche de Nicolas Détrain
comme référence directe, conformément à sa demande.
