# Sentinelle — révision des mouvements

**Retour utilisateur après V7 : cohérence toujours insuffisante.** Le
[diagnostic de méthode](diagnostic_methode_2026-09-10.md) précise les défauts
observés et le pilote recommandé avant de décliner à nouveau les animations.
Les corrections décrites ci-dessous sont les intentions de cette version ;
elles ne constituent pas une validation artistique.


Version courante du **10 septembre 2026 : `sentinelle_kit_v7`**.
24 clips, quatre directions E/S/W/N. La V5 reste conservée pour comparaison.
Son chargement technique était valide, mais ses mouvements ont été jugés
insuffisants par l’utilisateur : estoc, marche, chute et sort trop discret.

## Ouvrir et comparer

```powershell
./tools/spine_trial/kit.ps1 start
./tools/spine_trial/kit.ps1 godot
```

[Galerie courante](http://127.0.0.1:8734/files/sentinelle_kit_v7/review.html) ·
[Ancienne V5](http://127.0.0.1:8734/files/sentinelle_kit_v5/review.html).
Le lecteur propose les quatre vues, une vue agrandie, le ralenti, un curseur
et la répétition facultative des actions. Dans Godot, ouvrir
`tools/spine_trial/SentinelleKit.tscn`, puis F6.

## Corrections proposées

- **Disparition** : la chute est remplacée par une petite explosion noire.
  Le corps disparaît à 0,16 s ; les 17 bouffées et éclats se dissipent avant
  0,65 s. Aucune partie de la Sentinelle ni particule ne reste à la fin.
  L’effet est contenu dans les données Spine, donc présent dans les deux lecteurs.
- **Estoc** : mise en garde avant la poussée, pied avant posé, bassin et buste
  engagés, coude fléchi du côté anatomique prévu. La lance reste alignée pendant
  la poussée ; sa trajectoire est contrôlée séparément de la rotation du buste.
  Le bouclier se retire pour dégager l’arme.
- **Marche** : les deux genoux fléchissent vers l’avant pour chaque direction.
  Les pieds suivent des trajectoires parallèles ; appui pendant 60 % du cycle,
  semelles à plat, puis levée du pied. Le bassin oscille moins.
- **Sort** : charge plus profonde, mouvement du bouclier et engagement du buste
  amplifiés, puis retour en garde.
- **Raccords peints** : les plaques d’épaule et les biceps sont séparés ; les
  parties cachées des membres sont reconstruites avec le service de peinture
  existant. Le bras qui croise le buste est placé devant sa peinture.

| Clip Spine | Durée | Lecture / événement |
|---|---:|---|
| `idle` | 2,40 s | Repos en boucle |
| `walk` | 0,72 s | Marche en boucle ; pas à 0 et 0,36 s |
| `attack` | 0,80 s | `attack_release` à 0,40 s |
| `cast` | 0,88 s | `cast_release` à 0,44 s |
| `hit` | 0,20 s | Recul et reprise |
| `death` | 0,80 s | `death_burst` à 0,08 s ; `vanish` à 0,16 s |

Les actions restent non bouclées par défaut. La marche est calculée sur place :
la vitesse de référence du déplacement simulé est 40 pixels source par cycle.
Un branchement au déplacement du combat devra adapter cette distance à l’échelle
du personnage ; les ressources de combat n’ont pas été remplacées.

## Sources et contraintes de l’essai

Paquet conservé : **`art/source/spine/sentinelle_kit_v7/`**. Chaque direction
contient le JSON, son atlas, la texture, les images séparées et la provenance.
`kit.json` décrit les clips ; `validation.json` référence les preuves et hachages.
`review/` conserve les planches fixes. Le lanceur restaure une copie absente
dans `artifacts/spine_trial/`, sans écraser un dossier de travail déjà présent.

Le générateur est `tools/spine_trial/sentinelle_kit.py`, les mouvements sont dans
`sentinelle_motion.py`, la disparition dans `spine_burst.py`. Le pont commun
`prepare_sentinelle.py` garde son comportement par défaut ; le choix de flexion
est adapté localement par `DirectionalSkeleton`, sans changer le rig partagé
des monstres. Les dessins des quatre directions sont conservés sans miroir.

Dans Spine Trial → Import Data, choisir par exemple
`art/source/spine/sentinelle_kit_v7/E/sentinelle.json`, échelle 1 et images
`./images/`. Données **Spine 4.2.22**, éditeur trial installé **4.3.26**.
L’import dans l’éditeur et l’aller-retour ne sont toujours pas constatés.
La trial ne sauvegarde ni n’exporte ; aucun `.spine` éditable n’est livré.

## Vérifier et poursuivre

```powershell
./tools/spine_trial/kit.ps1 verify
./dev.ps1 test smoke
./tools/spine_trial/kit.ps1 build -Revision sentinelle_kit_v8
```

Le générateur refuse les révisions déjà présentes. Les mouvements sont
échantillonnés à environ 60 Hz ; il ne s’agit pas de contraintes IK natives
éditées dans Spine. Les courbes restent dans le JSON.

Le nouveau contrôle `verify_sentinelle_motion.py` lit les transformations du
JSON produit, y compris entre les clés : sens des genoux, stabilité de l’appui
dans le déplacement simulé, alignement et progression de la pointe, engagement
du corps, amplitude du bouclier et opacité finale. Les lecteurs web et Godot
contrôlent également les 24 clips, les événements natifs et la disparition.

Ces contrôles portent sur la cohérence mesurable et la lecture des fichiers.
La V7 est une nouvelle proposition artistique à revoir avec l’utilisateur ;
un rapport technique réussi ne vaut pas approbation du mouvement.
