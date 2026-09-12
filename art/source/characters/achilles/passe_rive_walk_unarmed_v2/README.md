# Passe-rive — marche ordinaire V2

12 septembre 2026. Demande : mouvement plus ordinaire, fluide et coordonné.
**Nouvelle révision produite ; appréciation artistique utilisateur attendue.**

[Aperçu avec comparaison avant/après](http://127.0.0.1:8734/files/passe_rive_walk_unarmed_v2/review.html).

Les quatre orientations réutilisent exactement les pièces dessinées de la
[V1](../passe_rive_walk_unarmed_v1/README.md). Aucune image générée de nouveau,
aucun changement de design ni d'équipement. Les exports V1 sont conservés.

## Corrections de mouvement

L'inspection des courbes a révélé trois défauts de coordination que les précédents
contrôles d'alpha et de boucle ne détectaient pas :

1. Le bassin se décalait vers la jambe en l'air pendant les phases d'appui simple.
2. Les translations des coudes/poignets allongeaient et raccourcissaient les bras.
3. La courbe de levée du pied comportait une accélération très brusque à ses extrémités.

V2 dirige le transfert de poids vers la jambe porteuse, remet la rotation du bassin
dans le sens de la jambe avancée, et celle des épaules en opposition. Les bras
oscillent maintenant avec des segments de longueur constante et des coudes légèrement
fléchis. La récupération du pied utilise des courbes continues en position, vitesse
et accélération aux jonctions. Pas raccourcis, levée du pied et mouvements du tissu
réduits ; la tête amortit légèrement les oscillations du corps.

## Mesures comparatives du modèle de mouvement

Ces valeurs décrivent les repères de construction ; ce ne sont pas des mesures
biomécaniques effectuées sur une personne ou un suivi indépendant des pixels.

| Mesure | V1 | V2 |
| --- | ---: | ---: |
| Durée d'une boucle à deux pas | 0,8 s | 1 s |
| Cadence | 150 pas/min | 120 pas/min |
| Longueur du cycle | 0,82 m | 0,72 m |
| Dégagement maximal de la semelle pendant le retour | 13,85 cm | 5,98 cm |
| Débattement vertical de la tête | 3 cm | 1,4 cm |
| Longueur du bras supérieur | 27,44–33,08 cm | 27,5 cm fixe |
| Longueur de l'avant-bras | 21,60–26,50 cm | 22,5 cm fixe |
| Transfert latéral vers l'appui pendant l'appui simple | 0 % des échantillons | 100 % |

L'export comporte **60 images par seconde**, soit 60 images par direction et 240 au
total. Chaque image est recalculée depuis les pièces et les nouvelles courbes ;
ce n'est pas une interpolation optique des anciens PNG. Même canevas 768 × 768,
même pivot (384, 662), atlas 8 colonnes × 8 lignes avec quatre cases inutilisées.

## Vérifications réalisées

- 240 PNG RGBA sans découpe au bord, 2 880 points d'articulation couverts dans le voisinage contrôlé.
- 9 600 poses intermédiaires contrôlées pour la portée des jambes.
- Longueurs des deux segments des bras constantes ; transfert de poids vers l'appui et continuité de la vitesse des pieds testés.
- Fermeture des quatre boucles : variation des pixels au raccord inférieure à la variation médiane de la boucle, ratios 0,62 à 0,83.
- Les attaches talon/pointe restent stationnaires au sol en phase d'appui dans le modèle. Inspection des poses clés des quatre vues et des quatre captures sur carte.
- Navigateur : quatre directions, 60 images/vue, lecture/pause, image par image, fermeture, ralenti, comparaison V1/V2 dans chaque angle et format mobile, aucune erreur JavaScript.
- **Godot 4.7.1 : 267 contrôles réussis avec rendu GPU**, vraie grille et recherche de chemin, arrivée, pause, obstacles, quatre captures natives inspectées. Format des deux scripts modifiés vérifié par le harnais.

Preuves sous `artifacts/spine_trial/passe_rive_walk_unarmed_v2/` :
`motion_measurements.json`, `asset_verification.json`, `browser_verification.json`,
`godot_walk_report.json`, `godot_walk_visual.log`, `*_poses.jpg`, `browser_*.png`,
`godot_walk_*.png`. Mesures V1 dans son propre dossier d'aperçu.

Ces validations ne prouvent pas la qualité artistique finale. Les attaches au sol
ne sont pas un contrôle exhaustif de la semelle dessinée. Les changements de direction
restent instantanés et l'image se fige à l'arrêt : les transitions et l'idle ne font
pas partie de cette révision. Aucun nouveau sort n'a été commencé.

## Source éditable et reprise

- `motion.json` : valeurs courantes.
- `E/S/N/W_attachments.json` : attaches conservées de V1.
- `E/S/N/W_editable.ora` : assemblages en calques ouvrables dans Krita.
- Pièces originales : dossier `../passe_rive_walk_unarmed_v1/parts/` ; ne pas les régénérer pour une correction de cadence ou d'appui.
- `tools/passe_rive_unarmed/natural_motion.py` : nouvelles courbes et articulations.
- `tools/passe_rive_unarmed/build_walk.py E --natural` : reconstruire une vue V2 ; ajouter `--preview` pour ses poses clés. Sans `--natural`, le moteur utilise le profil V1.
- `verify_assets.py --natural`, `measure_motion.py --natural`, `verify_browser.mjs --natural` : vérifier V2.
- `tools/passe_rive_unarmed/WalkReview.tscn` pointe maintenant vers V2. F6 pour jouer dans le laboratoire.

Comparer le mouvement à vitesse normale en premier. Si une correction reste nécessaire,
identifier l'angle et le moment du pas, modifier ce mouvement puis revérifier les quatre
vues avant d'aborder une autre animation.
