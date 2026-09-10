# Passe-rive — socle idle et marche, première direction

Demande du 10 septembre 2026 : des animations belles et cohérentes, commencer par
marche et idle. Référence immuable : `../passe_rive_v1/reference_choisie.png`.
Première direction de travail E, trois-quarts vers le bas-droite. Les autres
directions restent à produire ; aucun miroir d'un équipement asymétrique.

## Contrat du premier essai

- Identité : même visage adulte, masque fendu, capuche pétrole, drapé jade,
  obole bronze, ceinture ivoire. Lance à droite anatomique, bouclier à gauche.
- Marche posée, cycle complet de huit phases en 1,12 seconde. Pas de phase
  aérienne. Les pieds suivent l'axe du déplacement. Le corps porte le poids.
- Arme rigide portée au-dessus du sol pendant la marche ; bouclier stable sur
  l'avant-bras. Les plis suivent le corps sans modifier la coupe du vêtement.
- Idle : pieds ancrés, faible mouvement du haut du corps et du tissu. Éviter
  l'alternance de dessins dont les proportions varient, problème de l'ancien kit.
- Contrôles : lecture à vitesse normale et ralentie, pause/image par image,
  comparaison à la référence, translation sur grille, retour de boucle.
- Aucun statut « parfait » automatique. Les contrôles mécaniques ne démontrent
  pas la qualité artistique des images générées.

## Sources et résultat

`tools/passe_rive_motion/build_guide.cjs` génère uniquement une référence technique
de locomotion. Longueurs de membres fixes, jambes et bras résolus en deux segments,
trajectoires séparées d'appui et de retour, vitesse de translation explicite.
`walk_guide.json` conserve les points 3D, huit phases et les mesures. Le PNG/SVG
est un diagramme de contrôle, pas l'habillage du personnage.

Revue : <http://127.0.0.1:8734/files/passe_rive_motion_v1/review.html>.
Fichiers livrés dans `artifacts/spine_trial/passe_rive_motion_v1/`.

**Audit après retour utilisateur : marche à reconstruire avant finition.**
La [recherche et les mesures](../../../../../docs/design/achilles/passe_rive_walk_audit_2026-09-10.md)
identifient un pied presque inchangé entre les dessins 1 et 2, des « passages »
mal sélectionnés dans le guide et une oscillation latérale du bassin de signe
opposé à l'intention. Les contrôles numériques ci-dessous ne valident pas ces
aspects. [Comparaison visuelle](http://127.0.0.1:8734/files/passe_rive_walk_audit/review.html).

- Marche : huit dessins individuels ImageGen intégré, natifs 1024 × 1536.
  Sources `walk_00_rgb.png` à `walk_07_rgb.png`, sur fond blanc uniforme.
  Exports retenus : `walk_00_rgba_v2.png` à `walk_07_rgba_v2.png`.
- L'utilisateur a explicitement autorisé le détourage logiciel. Traitement
  local CPU, rembg 2.0.84 et modèle `birefnet-general-lite`, sans envoi à un
  service externe. `tools/passe_rive_motion/cutout.py` conserve les originaux,
  retire le blanc résiduel et écrit un rapport avec les empreintes de chaque PNG.
  Le modèle reste dans `artifacts/dev-tools/rembg-models/` ; dépendance épinglée
  dans `tools/passe_rive_motion/requirements.txt`.
- Prompts conservés : `contact_left_prompt.txt`, `contact_right_prompt.txt`,
  `walk_01_prompt.txt`, `walk_02_prompt.txt`, `walk_03_prompt.txt`,
  `walk_05_prompt.txt`, `walk_06_prompt.txt`, `walk_07_prompt.txt`.
  `walk_prompt.txt` et `walk_sheet_attempt_v1.png` sont l'essai de feuille rejeté :
  damier peint et répétition de la même jambe. Ne pas les utiliser en production.
- Idle : texture originale exacte, animée en 3,2 secondes par
  `tools/passe_rive_motion/idle.gdshader`. Visage, pieds et lance fixes,
  mouvement local du buste et du tissu. Le shader est nécessaire : l'entrée
  `idle_E` de SpriteFrames contient une seule texture, pas une feuille animée.
- Atlas marche 4096 × 3072 assemblé sans rééchantillonnage, recadrage ni
  recentrage individuel selon le pied le plus bas. Le projet Godot autonome
  contient les textures, `passe_rive_sprite_frames.tres`, le shader et la scène.
  Aucune ressource du combat principal remplacée.

## Vérifications effectuées

Base Git vérifiée le 10 septembre 2026 : `2473c335`. Travail local non commité ;
préserver les autres modifications. Les preuves sont dans le dossier de revue.

- Guide : longueurs de segments constantes, pas de phase aérienne ni de
  pénétration du sol dans les échantillons, appuis immobiles après translation
  et retour exact de boucle à la précision numérique. Voir `walk_guide.json`.
  Ces mesures portent sur le guide, **pas sur les dessins générés**.
- Huit PNG RGBA natifs, alpha allant de 0 à 255, plus de 77 % du canevas
  entièrement transparent. Les pixels des huit cellules de l'atlas sont
  identiques à ceux des images sources retenues (`manifest.json`).
- Navigateur : huit poses chargées, commandes de lecture/image suivante et
  fonds testés, aucune erreur JavaScript. Entre les phases d'idle contrôlées :
  zéro pixel modifié dans les régions du visage et des pieds, 144 153 pixels
  visibles animés dans le reste du dessin ; retour à 3,2 s identique à 0 s.
  Voir `review_report.json` et les captures `review_*.png`.
- Godot 4.7.1 : import du projet autonome et exécution `--verify`, codes de
  sortie 0. Huit images de marche et shader chargés ; cycle exécuté.
  Voir `godot_import.log` et `godot_run.log`. Cette exécution headless ne vaut
  pas inspection visuelle du rendu Godot ; le shader WebGL a été rendu et testé.

## Évaluation artistique et suite

Statut : **essai visible, marche à reconstruire avant finition**.
Le visage et les équipements restent reconnaissables, les contours sont lisibles
sur fond clair et sombre. L'idle garde exactement le dessin choisi ; son amplitude
est volontairement faible. Les phases de marche restent trop proches dans le
buste et la progression du pied d'appui n'épouse pas suffisamment le guide.
Le transfert de poids et le risque de glissement restent à corriger.
Les accents jade des chaussures varient aussi entre certains dessins : deux
accents visibles aux phases 6 et 8, contre un sur plusieurs autres phases.
La référence ne prouve pas qu'une seule chaussure doit en porter.

Priorité suivante : corriger les contacts et passages dans cette seule direction,
en comparant les positions réelles des semelles après translation. Ne pas
décliner d'autres directions ou actions sur cette marche comme si elle était
approuvée. La transition idle → marche et la calibration de taille/vitesse dans
le jeu restent à produire. La vue Émeraude est une comparaison illustrative.

## Reproduction ciblée

Depuis la racine du dépôt, avec les dépendances locales déjà installées :

```powershell
node tools/passe_rive_motion/build_guide.cjs
node tools/passe_rive_motion/package.cjs
./tools/spine_trial/spine.ps1 start
node tools/passe_rive_motion/verify_review.mjs
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --headless --path artifacts/spine_trial/passe_rive_motion_v1/godot --editor --import --quit
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --headless --path artifacts/spine_trial/passe_rive_motion_v1/godot -- --verify
```

Le script de détourage refuse d'écraser une révision existante. Pour une
correction ultérieure, utiliser un nouveau `--revision` et inspecter les contours
avant de sélectionner ces fichiers dans `package.cjs`. Ne pas lancer à nouveau
la génération pour simplement reconstruire la revue.
