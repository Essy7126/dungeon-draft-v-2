# Blender — pilote Sentinelle

## Orientation actuelle — dessin guidé par Blender, 10 septembre 2026

L'utilisateur valide le gain de cohérence du mannequin, mais rejette l'habillage
`sentinelle_armor_v1`, trop éloigné du sprite original. Il propose désormais
Blender comme référence des poses et des appuis, avec génération des dessins
complets depuis le sprite original. Le kit initial apprécié est celui d'Achille.

La [fiche de l'essai guidé](../../art/source/sprite_workshop/sentinelle_guided_v1/README.md)
contient quatre poses techniques de l'estoc E et le prompt. La génération reste
bloquée par une erreur d'accès aux images du bac à sable Codex : aucun nouveau
sprite ni résultat artistique validé à ce stade. Les sections suivantes
conservent l'historique ; l'armure 3D n'est pas la référence artistique à poursuivre.


## Retour utilisateur — cohérence du pilote

Le 10 septembre 2026, après consultation de la revue Blender :
> C'est vraiment beaucoup plus cohérent

Conserver `sentinelle_blocking_v1` et son estoc comme référence de mouvement pour
la suite. Ce retour confirme le gain de cohérence perçu. L'habillage peint,
les autres actions et leur intégration au combat restent à produire et à revoir.
Ne pas repartir des recettes V7 pour remplacer cette base de mouvement.


Installation et premier travail du 10 septembre 2026, Git de départ `2473c335`.
La demande autorise l'installation des outils utiles puis le début de la production.

## Correction du bouclier — 10 septembre 2026

Suite au retour demandant une tenue plus diagonale : inclinaison latérale de
32° autour de la prise, avec une orientation de -10° en garde et -2° pendant
l'estoc. Les deux actions sont corrigées ; le reste du mouvement est conservé.
`pose_estoc.py` reproduit cette tenue et `tilt_shield.py` l'applique à la scène
existante avant inspection et sauvegarde explicite.

Le contrôle `shield_tilt_validation.json` compare 194 instants sur les deux
actions : aucun déplacement de la prise ni changement des matrices des autres
os. Copie précédente : `artifacts/dev/sentinelle-shield-before-20260910/`.
Les 43 rendus, le GIF et la revue locale ont été régénérés depuis la copie
sauvegardée corrigée ; fraîcheur des 43 images contrôlée. Inspection des six
poses dans les quatre vues, puis vérification web : 5 contrôles réussis, aucune
erreur de chargement ou de script. Les images utilisent une version de cache
`shield-diagonal-1` pour éviter de revoir la pose précédente.
La correction visuelle reste à apprécier par l'utilisateur.

## État utilisable

- Blender **5.1.2**, RTX 4070 Laptop, rendu Cycles **OptiX**.
- Serveur MCP déjà disponible dans Codex : `blender-mcp` **1.9.1**.
- Extension correspondante installée depuis ce paquet : **MCP for Blender 1.6**, protocole **5**. Connexion vérifiée sur **127.0.0.1:9876**.
- Ancienne extension `blender_mcp_addon` 1.2.0 : autre implémentation, désactivée dans les préférences, fichiers conservés. L'installateur générique pouvait la confondre avec son propre addon ; le fichier compatible a donc été copié séparément en `blender_mcp.py`.
- Petit addon **Dungeon Draft - Pose Lab**, source `dungeon_draft_pose_lab.py`, installé et activé. Le panneau **N → Sentinelle** propose quatre caméras, six poses, deux modes de lecture et l'affichage des contrôles.
- Les préférences antérieures sont sauvegardées dans `artifacts/dev/blender-setup-backup-20260910/userpref.blend`. Le consentement à la télémétrie détaillée du nouvel addon est désactivé.

Exécutable : `C:/Program Files/Blender Foundation/Blender 5.1/blender.exe`.
Le contrôle Windows de Codex a échoué deux fois au démarrage sur l'erreur ACL
`apply deny-read ACLs`. Une nouvelle instance a donc été lancée par l'interface
Python de Blender, sans fermer le `test2d` original. La fenêtre à utiliser est
**sentinelle_blocking_v1**, connectée au MCP ; son PID initial était 12900,
à ne pas réutiliser sans vérification. Aucun nouveau serveur MCP redondant n'a été ajouté.

## Ouvrir le travail

Fichier : [sentinelle_blocking_v1.blend](../../art/source/blender/sentinelle_blocking_v1/sentinelle_blocking_v1.blend).
Original conservé : `C:/Blender_AI_Test/input/test2d.blend`.
La scène source contenait une lumière et une caméra ; elles sont conservées dans
la collection masquée `Source_test2d_preserved`.

Dans Blender, ouvrir la copie ci-dessus, puis **N → Sentinelle**. L'extension MCP
activée démarre automatiquement ; vérifier la connexion depuis Codex avant toute
édition et vérifier `bpy.data.filepath` pour éviter de travailler sur une autre scène.
Les boutons **Poses tenues / Interpolé**, les six poses et le changement de caméra
ont été exercés via leurs opérateurs Blender.

[Revue locale](http://127.0.0.1:8734/files/sentinelle_blender_pilot/review.html), servie par le serveur Spine existant.
La vue E possède 25 rendus ; S/W/N proposent six poses tenues chacune. La page
n'invente pas d'interpolation pour les vues qui n'ont que ces six images.
Si ce serveur est arrêté : `./tools/spine_trial/kit.ps1 start`.

## Contenu du pilote

- Un mannequin de volumes bronze/ivoire, sans peinture finale : bassin, thorax,
  tête, épaules, bras, jambes, lance courte et grand bouclier.
- **27 os**, quatre contraintes IK natives, cibles des mains/pieds et pôles des
  coudes/genoux. Armure et accessoires rigides attachés aux os.
- Axe avant **+Y**, haut **+Z**, droite anatomique **+X**.
- Quatre caméras orthographiques depuis le même volume, élévation 30° et azimut
  diagonal. Cette élévation donne des axes du sol projetés en 2:1 ; il reste à
  comparer leur cadrage et les proportions au contexte exact du jeu.
- Estoc de **0,80 s**, contact à **0,40 s** / image 13 à 30 i/s. Six poses principales
  et trois poses intermédiaires pour les passages de pied et la récupération.
- Deux actions conservées : `Estoc_Blocking` et `Estoc_Preview`.

Scripts reproductibles : `build_blocking.py` construit la scène une fois ;
`pose_estoc.py` crée les poses ; ils refusent d'écraser un travail existant.
`render_review.py` rend une copie sauvegardée en arrière-plan ;
`package_review.py` assemble les aperçus. `bootstrap.py` sert au lancement initial
depuis `test2d` et ne doit pas être rejoué sur une autre scène sans vérifier le chemin.

## Vérifications et limites

- Handshake MCP : protocole 5 à jour, lecture de scène et exécution Python réussies.
- [Contrôle du rig](../../art/source/blender/sentinelle_blocking_v1/blocking_validation.json) :
  97 instants évalués, écart maximal aux cibles IK ≈ 0,00000454 m ; pointe à la cible
  au contact avec écart ≈ 0,00000051 m. Ce sont des mesures de géométrie, pas un jugement artistique.
- [Rendus](../../artifacts/dev/sentinelle-blender-review-20260910/report.json) : 43 PNG,
  processus Blender terminé avec code 0. Source, estoc E/S et planche des quatre vues inspectés.
- [Revue web](../../artifacts/dev/sentinelle-blender-review-web.json) : quatre vues au contact,
  chargement des images et lecture jusqu'à la fin, sans erreur JavaScript ou asset manquant.
- Le pied avant reste posé pendant l'engagement. Le contact précis de la semelle
  et du talon arrière reste à régler : les relevés du bas de la botte arrière vont
  de −0,005 m à +0,0061 m aux poses principales, pour un sol à −0,015 m.
- Cette étude ne valide ni le style final, ni l'équilibre artistique, ni une animation
  dans le combat. Aucune ressource de combat, de peinture ou de Spine n'est remplacée.

Le geste du mannequin a reçu un retour positif, puis le bouclier a été corrigé.
La suite courante est la proposition `sentinelle_armor_v1`, liée en tête de fiche :
revoir cet habillage, puis préparer les pièces peintes et le transfert Spine.
Ne pas étendre automatiquement aux 24 clips.

## Sources et versions

L'extension correspond exactement au fichier livré avec le serveur 1.9.1 :
SHA-256 `f43469c8518c7021e0060e32cfe52e3beb126b0f62fbae7293106642a3ebda89`.
La procédure et l'architecture ont été confrontées au
[dépôt du mainteneur](https://github.com/ahujasid/blender-mcp).
Il s'agit d'une intégration communautaire, pas d'un composant officiel Blender.
Conserver cette combinaison connue avant toute mise à jour.
