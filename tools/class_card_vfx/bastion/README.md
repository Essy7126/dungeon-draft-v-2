# Bastion vivant — pilote de protection

```powershell
./tools/class_card_vfx/bastion/run.ps1
```

Le laboratoire ouvre une arène du jeu, avec IA suspendue et une main préparée.
**Rejouer V1** et **Rejouer Blender** lancent le vrai `g_bastion`, puis deux coups
contrôlés de 8 points et du reste du bouclier. Ils passent par la transaction de
dégâts de Unit. **Tester expiration** déclenche l'activation suivante du porteur
après le déploiement. Le bouton caméra alterne le détail et la distance normale.
Chaque rejeu commence une activation réelle, pour respecter la limite d'un
lancer de Bastion par activation.
Ces actions de laboratoire ne représentent pas une partie jouée.

La protection est attribuée immédiatement : les plaques se déploient après ce
fait confirmé. Elles ne retardent pas la garde ni le paiement de ses 3 PA.
Trois verrouillages à 0,267 / 0,333 / 0,400 s, puis retrait des plaques avant
1,5 s. Le signe compact reste dans la rangée des états selon la source réelle
`class_g_bastion`, jamais selon une minuterie de VFX. Si cette source expire mais
qu'une autre garde reste, le signe générique revient. Un coup sur une autre
source ne déclenche pas une rupture de Bastion. Les réponses rapprochées se
remplacent. Le changement de source remplace le signe directement, sans sortie
superposée ; la fin de la dernière garde conserve sa petite sortie. Le son de
garde utilise le feedback existant du jeu.

Production : modèle original et animation dans `build_bastion.py`, source
`art/source/vfx/bastion_vivant/bastion_vivant.blend`, 48 poses à 30 images/s.
Deux plans de 384 × 384 conservent un centre ouvert et l'ordre autour du porteur.
`pack.py` copie les pixels dans deux atlas 3072 × 2304 avec marge transparente.
Le badge et les petits retours sont dessinés séparément dans le lecteur Godot.

```powershell
./dev.ps1 test cards
./tools/class_card_vfx/bastion/run.ps1 -Capture
./tools/class_card_vfx/bastion/run.ps1 -Workshop
```

La capture produit 90 images par variante, contrôle attribution, absorption,
rupture, durée par activation, cumul avec une autre garde, reprise des signes,
échec de lancer et bilan/sauvegarde/reprise. La victoire de ce dernier parcours
est provoquée par la fixture. Les sources sélectionnées et erreurs moteur sont
contrôlées par le lanceur ; les images doivent aussi être inspectées.
Le survol de souris est désactivé pendant l'enregistrement pour éviter qu'un
marqueur de grille entre dans le comparatif VFX.

`encode.cjs` encode les captures natives en deux GIF de 3 secondes, sans son.
Il utilise Node et sharp (`SHARP_PATH` peut indiquer le module installé).
`-Workshop` utilise le service Studio pour exporter séparément les deux plans,
avec leurs durées et leurs marqueurs. Le suffixe E est requis par le format
Studio : cet effet a une vue fixe, pas quatre directions promises. Le Studio
sert à la revue ; modifier ses durées ne reprogramme pas le lecteur 30 Hz.

Seul Bastion est concerné. Les sources et la présentation de Sentence du rempart
sont conservées. Pas de certification de performance GPU ni d'approbation
artistique automatique.
