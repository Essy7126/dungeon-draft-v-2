# Achille classique — sprites polish v3

Ce pipeline assemble les dessins sélectionnés par ImageGen en sprites Godot. Il ne produit aucun dessin, miroir, déformation de membre ou déplacement de racine en jeu. Le choix concerne **Achille classique** ; le pack peint G reste indépendant.

## Reconstruction

```powershell
& 'C:/Program Files/nodejs/node.exe' tools/achilles_polish_v3_pipeline/build.cjs --inspect
& 'C:/Program Files/nodejs/node.exe' tools/achilles_polish_v3_pipeline/build.cjs
& 'C:/Program Files/nodejs/node.exe' --test tools/achilles_polish_v3_pipeline/build.test.cjs
```

Node et Sharp suffisent. Le script charge Sharp installé localement, puis le runtime Codex connu en secours. Le fichier `alignment.json` est l'autorité des sources, sélections, racines, échelles, substitutions et marqueurs. Chaque opération se résout depuis la racine du dépôt, indépendamment du répertoire courant du terminal.

Les originaux sont dans `art/source/characters/achilles/sprites_polish_v3`. Les atlas et SpriteFrames sont écrits dans `assets/characters/Achilles/sprites_polish_v3`. Les mattes de contrôle, feuilles sur fonds clair/sombre et GIF sont dans `artifacts/achilles_polish_v3_pipeline` et ne sont pas des textures de jeu.

## Détourage autorisé

L'utilisateur a explicitement autorisé le détourage par script des fonds générés. Les onze sources sélectionnées utilisent toutes un fond magenta. Les premières générations E à damier sont conservées comme historique et ne sont plus chargées par ce lot.

`matting.cjs` retire les pixels neutres bleutés reliés au fond du damier. Un trou fermé est retiré seulement s'il possède les deux valeurs du damier ; un reflet blanc fermé du plastron n'est pas supprimé. La clé magenta exclut le rouge chaud de la crête, le turquoise et l'ivoire. Pour les sources harmonisées, ses seuils rouge/bleu sont de 110 ; les deux sources des arcs S V6 utilisent 200 pour conserver leurs cordes fines. Le seuil de 45 effaçait des pixels sombres de corde malgré leur continuité dans la source. Chaque clé reste explicitement enregistrée par feuille. Les trous sont retirés et les traits de corde conservés. Après le premier détourage, seules les poussières neutres minuscules (16 pixels maximum) isolées à plus de deux pixels des silhouettes principales peuvent être retirées ; leurs comptes et rectangles figurent dans le manifeste.

Hors de l'option de correction de frange décrite ci-dessous, tous les pixels conservés gardent exactement leur RGBA source avant le redimensionnement uniforme. Les tests protègent spécialement l'ivoire, les reflets blancs, les contours et les trous des arcs. Les mattes ont été inspectées sur fond sombre ; cette inspection reste nécessaire pour toute nouvelle source. Les fonds de génération ne sont jamais introduits dans le jeu.

Seuls les quatre arcs S V6 activent `key.edge_despill`. Le détourage autorisé retire la contamination magenta estimée dans une bande de deux pixels depuis le fond effectivement retiré : `min(R,B)-G >= 12`, avec protection explicite des rouges `R >= 2*B`. La couleur de premier plan est estimée contre le fond connu `(255,0,255)` ; l'alpha reste strictement inchangé. Aucune correction ne s'applique aux pixels hors masque. Les intérieurs, appuis, boîtes et origines ne bougent pas. Le classement des poussières utilise le RGB original pour éviter toute nouvelle suppression après correction. Le manifeste indique le masque par ses règles et son nombre de pixels corrigés ; la reconstruction reste une estimation de bord, sans promesse de retrouver une couleur originale inconnue ni de conserver le même contraste sur tous les fonds. Les comparaisons clair/sombre et les vingt images normalisées confirment une corde continue et zéro différence alpha.

## Alignement et clips

- Canvas 512 × 384, point au sol `(256, 320)`, affichage du backend à `0.35`.
- Une échelle fixe par action/direction, mesurée sur le corps debout d'environ 220 pixels, indépendamment de la lance et de l'arc.
- Les trois gestes spéciaux d'une direction partagent la même échelle physique, calibrée sur la volée debout. Le tir agenouillé et la posture de puissance restent plus bas.
- Les racines de marche suivent le bassin ; les racines des arcs se situent entre les appuis visibles. Chaque racine source est explicitement enregistrée.
- Les coordonnées `release_grip_atlas` désignent la main qui tient l'arc au lâcher. `cast_origin_local = (release_grip_atlas - (256, 320)) × 0.35` ; ces coordonnées sont directement utilisables par le profil du backend.
- Le champ `crest_top` est une mesure automatique de composante rouge utile au contrôle. L'échelle reste la valeur explicitement revue dans `alignment.json`, et ne se recalcule jamais selon une posture ou une arme.

Les marches utilisent huit régions source, quatre images lues par case, avec contacts en indices de lecture 3 et 7. L'E emploie `[0,1,3,2,4,5,7,6]` pour placer les contacts sources 2/6 à ces indices. W suit désormais [0,1,2,3,4,5,6,7] : son guide de génération était déjà préordonné selon l'ancien mapping [0,0,2,3,1,5,6,7]. Il ne faut pas appliquer deux fois ce réordonnancement. N et S suivent également l'ordre identité.

Les quatre arcs S utilisent les deux sources V6 générées depuis le sprite original S seul, puis une correction des pointes de l'arc spécial par ImageGen. La marche de la base V6 est exclue pour mauvaise alternance ; `walk_S` conserve sa source harmonisée validée. Les appuis et les quatre origines de libération S ont été remesurés après ce remplacement. Les 16 autres atlas sont identiques par empreinte.

Les arcs de base utilisent huit régions source. Chaque variante `bow_piercing`, `bow_death` et `volley` ajoute quatre régions dédiées. Son clip de huit images est composé ainsi :

```text
bow[0], bow[1], special[0], special[1],
special[2], special[3], bow[6], bow[7]
```

Ces substitutions sont des références d'AtlasTexture déclarées dans `clip_overrides`, pas des copies ou modifications des pixels. La préparation, le retour et les mains restent issus de la même direction.

| Geste | Durée | Lâcher | Image du lâcher |
| --- | ---: | ---: | ---: |
| Arc de base | 0,74 s | 0,34 s | 4 |
| Perforante | 0,78 s | 0,38 s | 4 |
| Ligne de mort | 0,86 s | 0,44 s | 4 |
| Volée | 0,84 s | 0,42 s | 4 |

Les GIF de préparation respectent les poids avant et après le marqueur, avec arrondi au centième. Le runtime possède l'horloge réelle et les marqueurs uniques ; ces GIF ne remplacent pas les captures en combat.

## Livraison et vérification

Le lot contient **11 sources**, **112 régions source sélectionnées**, **20 atlas**, **20 nouveaux clips de huit images**, soit **160 références de lecture**. La ressource complète contient **48 clips** : les 28 clips v2 qui ne sont ni marche, ni arc de base, ni volée conservent leurs blocs exactement, y compris la ruée appréciée par l'utilisateur.

Le packing d'atlas copie les RGBA normalisés sans seconde recomposition. Chaque image possède une empreinte RGBA vérifiée après extraction de son rectangle de l'atlas. Les 112 régions ont été vérifiées sans coupe au bord du canvas. Les 32 poses de marche ont leur bord inférieur visible (dernier pixel alpha > 33, plus 1) exactement à Y = 320 ; leurs vrais appuis ont aussi été inspectés visuellement, car une baseline seule ne prouve pas une pose de contact.

Les quatorze tests Node couvrent détourage, conservation de pixels, compatibilité v2, substitutions, intégrité du lot et des atlas. Le pipeline n'exécute pas Godot, ne change pas la scène canonique et ne modifie aucune règle de combat.
