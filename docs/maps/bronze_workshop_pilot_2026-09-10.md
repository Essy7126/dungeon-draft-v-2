# Atelier du Bronze — pilote de création à échelle contrôlée

Pilote livré le 10 septembre 2026. Base Git observée au début et à la fin :
`2473c335fc11ccb8dfe1cb8257b0a4ee406d1788` ; changements locaux conservés.

## Jouer et éditer

Ouvrir `tools/labs/bronze_workshop_pilot/BronzeWorkshopPilot.tscn` puis **F6**,
ou lancer :

```powershell
./tools/halt_workshop/halt.ps1 open -Map res://data/halts/bronze_workshop_pilot_v1.json
```

Clic pour marcher, clic droit pour arrêter, molette pour zoomer, Espace pour
mettre en pause, H pour masquer les commandes. Les trois boutons rejoignent
l’établi, le seau et la porte. L’établi emploie le service marchand d’une visite
isolée. Le pilier peut être contourné et masque Achille lorsqu’il passe derrière.
Le feu combine déformation locale, lumière, petites particules et son positionnel.

Dans **Studio → Haltes peintes**, sélectionner **L’Atelier du Bronze**.
Le manifeste est `data/halts/bronze_workshop_pilot_v1.json`.
Le repère d’Achille utilise 21,2 % de la hauteur de l’image pour sa silhouette totale.
Le champ affiche désormais les dixièmes de pourcent sans arrondir 21,2 à 21,0.

Le fichier de peinture éditable est
[bronze_workshop_layers.ora](../../art/source/halts/bronze_workshop_pilot_v1/bronze_workshop_layers.ora),
compatible avec Krita 5.3.3, installé et vérifié dans `artifacts/dev-tools/krita/`.
Pilier, établi+marteau et seau possèdent leurs calques, avec le sol reconstruit dessous.
Les détails de manipulation sont dans
[LAYER_EDITING.md](../../art/source/halts/bronze_workshop_pilot_v1/LAYER_EDITING.md).

![Visite réelle Godot](../../artifacts/dev/20260910-161847-halt-verify-a8ed3992/1280x720_living_clean.png)

## Ce que la chaîne a effectivement produit

1. Maquette métrique Blender 5.1.2, 93 objets dans une collection dédiée, caméra
orthographique fixe et ouverture réelle de porte. Une instance propre reste sur
127.0.0.1:9877 ; son client vérifie PID, fichier, nonce et identifiant de scène.
La copie versionnée est `art/source/halts/bronze_workshop_pilot_v1/workshop_blockout_v1.blend`.
2. Mesure du sprite réel et trois comparaisons avec Achille avant peinture.
Le corps de référence **B** vaut 202 px entre les pieds (y=320) et la calotte du casque
(y≈118, ±2 px), hors plume et lance. Le crâne étant caché, c’est une convention avec
casque. La silhouette totale **H**, employée par le runtime, vaut 257 px.
3. Exports géométriques alignés sur Blender : profondeur 16 bits et mètres,
normales caméra, identifiants d’objets, masques et groupes RGBA. Leur méthode et
leurs empreintes figurent dans `guides.json` et `GUIDES.md`.
4. Illustration native **imagegen**, guidée par la maquette, la planche d’Achille
et la Halle comme référence de style. Original 1672 × 941 conservé octet pour octet.
Une seconde génération retire les trois objets et reconstruit le fond.
Les prompts exacts et les références sont conservés dans le dossier source.
5. Décomposition de la peinture en calques OpenRaster. La recomposition de ces
calques et un véritable import/export Krita rendent exactement les pixels originaux.
6. Registration du sol sur la peinture reçue, contrôle visuel des silhouettes,
calibration de la navigation et des effets, puis tests du moteur commun et du Studio.

## Proportions et enseignement

| Référence | Maquette |
| --- | ---: |
| Corps de conception | 1,80 m |
| Corps du seau, sans anse | 0,35 m |
| Surface de l’établi | 0,90 m |
| Hauteur libre de porte | 2,55 m |

La caméra projette le corps sur 15,7239 % de l’image de maquette. La conversion
`ratio = hauteur projetée du corps / hauteur image × 257/202` donne 0,2000516 pour
la silhouette entière avant peinture. L’image générée a légèrement changé le
cadrage : trois points de sol sont recalés, les silhouettes sont reprises sur
les pixels livrés, puis le ratio de jeu est réglé à 0,212. Les dimensions du tableau
sont celles de la maquette ; les proportions peintes ont été revues visuellement,
elles ne constituent pas une mesure métrique certifiée.

Cette distinction corps/silhouette est maintenant reprise dans le style commun,
les briefs des prochaines créations et le guide de l’atelier des haltes. La lance
ne doit plus servir à dimensionner la hauteur d’un seau ou d’un plan de travail.

## Vérifications

- Godot final : 251 contrôles, 40 captures à 720p/1080p, 3 166 échantillons de déplacement,
aucun hors zone, aucune erreur moteur ni fuite signalée.
  Rapport : `artifacts/dev/20260910-161847-halt-verify-a8ed3992/verification.json`.
- Tests natifs des haltes : 41 tests, 378 assertions, tous réussis.
  Rapport : `artifacts/dev/20260910-162230-test-halts-194d58a5/gut-strict-report.json`.
- Préparation et briefs Python : 23 tests réussis, après mise à jour du contrat B/H.
  Rapport : `artifacts/dev/20260910-162229-halt-test-7cf9c271/summary.json`.
- Studio final 1600 × 1000 : peinture, shader, catalogue et repère chargés ; capture
inspectée avec le champ 21,2 % après sa correction.
  Rapport : `artifacts/dev/20260910-162557-workshop-pilot-studio-final-ab74b536/summary.json`.
- OpenRaster relu et export réel Krita : 0 pixel différent de l’original.
  Preuve : `art/source/halts/bronze_workshop_pilot_v1/krita_batch_verification.json`.
- Les guides géométriques ont été inspectés et la connexion Blender dédiée reste
opérationnelle. Syntaxe Python, format GDScript ciblé et différences Git vérifiés.

## Limites utiles pour la prochaine création

Le générateur ne conserve pas exactement les pixels de la maquette : le recalage
et l’essai avec le vrai personnage restent des étapes obligatoires. Les guides
profondeur/normales ont été exportés pour l’édition et une future expérimentation
ControlNet ; ils n’ont pas été injectés dans le générateur natif comme contraintes
numériques de cette image.

Les ombres peintes sont des **patches de raccord de sol**, pas des ombres à alpha
physique. Si l’on déplace un objet, il faut reprendre ou régénérer son ombre. Les
parties cachées de l’établi n’ont pas été inventées. Le fond reconstruit permet
néanmoins de masquer les objets sans laisser leurs silhouettes dans le sol.

Godot emploie encore l’export aplati et les découpes de premier plan. Une retouche
dans Krita se publie dans une nouvelle version d’image, puis se calibre dans Studio.
Pour l’étape suivante, produire séparément les ombres et les objets dès l’habillage
rendrait les déplacements de mobilier plus souples. Le pilote démontre la chaîne
sur un petit atelier ; il ne généralise pas automatiquement sa géométrie à toutes
les prochaines maps.

La procédure technique est dans [tools/blender_halt_lab/README.md](../../tools/blender_halt_lab/README.md).
