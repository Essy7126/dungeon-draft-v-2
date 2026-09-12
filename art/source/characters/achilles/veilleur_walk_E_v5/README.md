# Veilleur — marche E V5, articulations affinées

12 septembre 2026. Demande : continuer d’améliorer la marche. Le « Ok » précédent
autorise la poursuite ; il n’établit pas une validation artistique finale de la V4.

## Changements depuis la V4

- Coudes articulés, flexion relative de 2° à 8°, avec un léger décalage du
  balancement. Avant-bras proche devant la tunique quand il la recouvre ; bras
  lointain derrière. Longueurs des segments conservées, mains opposées aux pieds.
- Pantalon formé d’une surface continue. La rotation et l’allongement projeté sont
  interpolés séparément autour du genou. Les repères de déformation sont recentrés
  dans le tissu, indépendamment du centre du motif peint de la rotule. Le squelette
  de mouvement de la V4 est conservé. Pas de rétrécissement correctif par paliers.
- Zones manquantes du pantalon sous la tunique et la main complétées une fois,
  puis réutilisées dans toutes les poses. Détails de la retouche ci-dessous.
- Retour du pied moins haut : maximum mesuré environ 7,94 px contre 12,96 px
  dans la cellule 512². Le maximum de levée intervient plus tôt dans le retour.
- Transitions adoucies pour la position, la levée et l’inclinaison du pied :
  disparition du saut de vitesse angulaire présent dans la V4 à la sortie d’appui.

Toujours 48 PNG RGBA 512², 800 ms, distance horizontale 59,5 px/cycle, bottes rigides
d’origine, amplitude du corps 1,6/3,2 px. Une direction E sans équipement.
La comparaison V4/V5 aligne les phases, l’échelle, la cadence et le déplacement.

## Retouche limitée avec ImageGen

Un appel **ImageGen intégré**, en mode retouche, pour compléter les surfaces cachées
des deux pantalons. Cible : `legs_repair_input.png`. Résultat brut conservé :
`legs_repair_generated.png`. Prompt exact : `legs_repair_prompt.txt`.

Le résultat contient un damier peint, pas une transparence réelle. Le détourage
logiciel déjà autorisé a donc été appliqué uniquement aux zones de tissu sombre.
Ce masque par couleur ne convient pas aux parties ivoire du personnage.

Le résultat est recalé selon le cadrage de l’entrée. Seules des régions bornées,
sans pixels d’origine, sont retenues dans `leg_L_completed.png` et
`leg_R_completed.png` : 1741 pixels ajoutés côté L, 2315 côté R à la résolution
source. **Zéro pixel existant modifié**. Les bottes de la génération ne sont pas
utilisées. Les fichiers acceptés de `veilleur_proportions_v1` restent inchangés.
`repair_report.json` et `source_lock.json` conservent ce périmètre et les empreintes.

## Vérifications

`audit_report.json` : **20 contrôles réussis** sur les exports, la construction et
les transitions, dont :

- APNG/WebP : 48 images identiques aux pixels visibles des PNG, durée exacte
  800 ms ; atlas 4096×3072 identique aux 48 PNG. Délais de fichier 16/17 ms.
- Sept PNG source inchangés ; aucune modification des pixels existants dans les
  deux jambes complétées ; tous les cadres contenus dans la cellule.
- Segments des jambes et des bras constants dans leur plan de construction ;
  ordre de profondeur des jambes fixe ; aucune inversion de surface sur les pixels
  du pantalon pendant les 48 poses. Des triangles dans l’espace transparent du
  maillage peuvent se replier ; ils ne couvrent aucun dessin et sont exclus.
- Trajectoires des mains opposées aux pieds du même côté sur tout le cycle :
  corrélations horizontales mesurées environ −0,93 / −0,89.
- Contacts annotés talon/semelle/pointe fixes dans le monde. Suivi supplémentaire
  des **PNG composités réels** sur 17 images d’appui à plat de la semelle proche :
  aucun déplacement au pixel entier détecté après compensation du déplacement.
  Cette mesure ne couvre pas toutes les surfaces de contact des deux bottes.
- Les fonctions de trajectoire réelles sont évaluées des deux côtés des raccords
  d’appui/retour. Les écarts estimés de vitesse tendent vers zéro pour la position,
  la levée et l’angle. Le rapport donne le pas d’échantillonnage implicite du contrôle
  dans le script (10⁻⁵ du cycle) ; ce n’est pas une mesure de toutes les accélérations du sprite.
- Le déplacement dernière → première image n’excède pas les plus grands écarts
  internes des chevilles. Les contrôles de fichiers ne constituent pas une validation
  de qualité artistique.

Essais écartés : joint formé de deux pièces rigides et d’un disque de genou
(`rejected_rigid_joint_01.jpg`), puis déformations qui inversaient encore des
triangles sur le dessin. Les repères recentrés et la surface continue sont retenus.

La revue passe **26 contrôles navigateur**, sans erreur JavaScript : 48 états
avant/après alignés et distincts, gros plans montrant des pixels différents,
lecture/pause/ralenti, curseur, six décors/versions, même déplacement, ressources
et affichages ordinateur/mobile. Captures du détail des jambes, des bras et du
décor inspectées. Rapport : `verification.json`.

## Limites

Le tissu reste une déformation 2D d’ombres peintes : le contour est plus continu,
mais cette méthode n’équivaut pas à des poses entièrement redessinées. Chaque botte
n’a encore qu’une orientation peinte. Aucune acceptation artistique utilisateur de
la V5 n’est reçue. Les décors sont des photomontages, pas une nouvelle intégration
Godot. Aucun autre angle, idle, transition ou équipement n’est livré ici.

## Sources et sorties

`tools/veilleur_walk/walk_v5_refined.py` utilise `articulation_v5.py`, les deux
jambes complétées et les pièces d’origine. `complete_leg_parts_v5.py` reproduit
le prélèvement de la retouche conservée, sans refaire un appel ImageGen.
`audit_walk_v5.py` vérifie les sorties indépendamment du rendu.

Sorties : `artifacts/spine_trial/veilleur_walk_E_v5/`.
Revue : <http://127.0.0.1:8734/files/veilleur_walk_E_v5/review.html>.
La revue propose des gros plans des jambes ou des bras, le ralenti, une lecture
image par image et trois décors. Aucun code du moteur commun modifié ; tests
natifs Godot non relancés pour cette correction de l’atelier.
