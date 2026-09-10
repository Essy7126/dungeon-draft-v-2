# Kit d’animations de la Sentinelle

Livraison d’essai du 9 septembre 2026 : **24 clips, quatre directions E/S/W/N**.
Révision retenue : `sentinelle_kit_v5`. Les versions précédentes sont des essais
locaux conservés dans `artifacts/` ; elles ne sont pas la livraison courante.

## Examiner

```powershell
./tools/spine_trial/kit.ps1 start
```

[Galerie de la version courante](http://127.0.0.1:8734/files/sentinelle_kit_v5/review.html) :
six animations, comparaison des quatre vues, vue agrandie, pause, curseur,
vitesses ×1 / ×0,5 / ×0,25 et répétition facultative des actions.

Dans Godot : ouvrir `tools/spine_trial/SentinelleKit.tscn`, puis **F6**, ou :

```powershell
./tools/spine_trial/kit.ps1 godot
```

| Clip Spine | Durée | Comportement |
|---|---:|---|
| `idle` | 2,40 s | Respiration, garde ; boucle |
| `walk` | 0,72 s | Deux pas, pieds levés à tour de rôle ; boucle sur place |
| `attack` | 0,80 s | Préparation, estoc, reprise ; `attack_release` à 0,40 s |
| `cast` | 0,88 s | Charge au bouclier, émission ; `cast_release` à 0,44 s |
| `hit` | 0,20 s | Recul et reprise des appuis |
| `death` | 0,80 s | Affaissement, chute et pose finale conservée |

Les événements `footstep_left` / `footstep_right` sont à 0 / 0,36 s ;
`body_landed` est à 0,72 s. Les actions ne bouclent pas par défaut dans les
galeries. La translation du personnage, les effets, les dégâts et le changement
d’état restent à la charge du jeu. Aucun VFX ni son n’est inclus dans ce kit.

## Sources et reprise

Le paquet conservé dans **`art/source/spine/sentinelle_kit_v5/`** contient, pour
chaque direction, `sentinelle.json`, l’atlas, sa texture, les PNG découpés dans
`images/` et la provenance. `kit.json` décrit les clips et leurs événements.
Le lanceur restaure ce paquet dans `artifacts/spine_trial/` si sa copie locale
a été supprimée. Il préserve un dossier de travail déjà présent.

Dans **Spine Trial → Import Data**, choisir par exemple
`art/source/spine/sentinelle_kit_v5/E/sentinelle.json`, échelle **1**, images
`./images/`. Le kit est du JSON Spine **4.2.22**. L’éditeur trial installé est
**4.3.26** ; son import et son aller-retour restent à constater manuellement.
La trial ne sauvegarde ni n’exporte : aucun fichier `.spine` n’est livré.

L’adaptateur réutilise `humanoid_parts.build_parts` et `PaintedSkeleton`.
Les quatre dessins sont indépendants, sans miroir. Le rig possède **16 os** :
les épaulières peintes sont séparées du bras, les pieds disposent de leurs
propres articulations. Le bassin est ajusté pour garder les cibles des pieds
à portée des jambes ; la chute se termine au niveau du sol. La conversion
conserve les pixels des régions de l’atlas et contrôle les transformations.

Les recettes sont dans `tools/spine_trial/sentinelle_kit.py`, le pont Spine
dans `prepare_sentinelle.py`. Pour produire une nouvelle révision :

```powershell
./tools/spine_trial/kit.ps1 build
# ou un nom explicite inédit :
./tools/spine_trial/kit.ps1 build -Revision sentinelle_kit_v6
./tools/spine_trial/kit.ps1 verify -Revision sentinelle_kit_v6
```

Ne pas régénérer sur un dossier édité : le générateur refuse l’écrasement.
Conserver la révision et les hachages du manifeste lors de retouches manuelles.

## Validation et limites

Il s’agit d’une **première proposition artistique complète**, à examiner en
mouvement. Les volumes proviennent de peintures rigides articulées ; les grands
croisements de bras et les chutes restent les poses à regarder en priorité.
Le kit n’a pas remplacé les ressources du combat et n’est pas déclaré approuvé
pour la production finale. L’installation du runtime reste celle de l’essai.

La vérification comprend le chargement de tous les clips dans les runtimes
officiels web et Godot, leurs durées, mouvement, raccords et pose finale,
les événements natifs, ainsi que des captures. Les mesures géométriques
contrôlent les appuis aux clés, la direction de la lance et le contact au sol.
Les rapports détaillés et les planches sont dans `artifacts/dev/` ; leurs
chemins sont conservés dans `validation.json` à la racine du paquet.

```powershell
./tools/spine_trial/kit.ps1 verify
./dev.ps1 test smoke
```

Le lint Spine ne signale aucune erreur. Ses avertissements `key-density`
proviennent des articulations calculées puis échantillonnées à environ 30 Hz ;
ce kit d’essai ne remplace pas ces courbes par des contraintes IK natives de
l’éditeur. Les informations `loop-pop` concernent la mort, volontairement non
bouclée. Les planches fixes sont aussi conservées dans le sous-dossier `review/`
du paquet, afin de pouvoir les examiner sans démarrer le serveur.
