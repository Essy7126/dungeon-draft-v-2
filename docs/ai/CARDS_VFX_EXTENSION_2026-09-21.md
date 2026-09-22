# Extension des VFX Cartes — 21 septembre 2026

Demande : décliner les autres cartes, augmenter la visibilité, concevoir le geste avant le rendu, respecter les durées réelles. DA éthérée conservée. Les quatre pilotes précédents sont une base historique, pas une preuve de cette passe.

Décisions : contrats explicites pour les 112 cartes actuellement jouables (dont 28 nouvelles initiations `i_`). Composants de matière partagés, silhouettes et rythmes choisis par carte. Lame = coupe directionnelle ; protection = pans autour du buste ; PM = liens aux jambes ; PA = dislocation au-dessus du buste ; marque = point de visée ; attraction = filaments convergents ; poussée = éventail divergent. Les variantes ne se limitent pas à changer de couleur.

Durées : impacts en secondes, états en activations réelles, sols en tours de terrain. Aucun délai de dégâts ajouté. Ne pas affirmer visuellement un bonus conditionnel absent du rapport de résolution. Le Venin du Styx provoque un saignement ; l'envoûtement attire et retire un PA ; Paris subit un malus PA à la place du saut d'activation de la stase. Garde améliorée : deux activations, suivies par le bouclier réel.

Périmètre : `vfx/class_cards/`, sondes et tests VFX, documentation. Préserver les modifications concurrentes des catalogues, de la sélection et de leurs tests. Validation moteur sérialisée avec `artifacts/dev/engine.lock`.

Implémentation terminée : 112 fiches dans `class_card_vfx_concepts.gd`, 20 motifs de matière (17 nouveaux dans `spell.gdshader`, 3 pilotes conservés), rémanences de 0,32 à 1,30 seconde. Largeurs explicites de 1,55 à 2,45 cellules et noyaux contrastés. Les cinq terrains ont leur motif propre : faille, îlots de braise, bûcher, dents de piège, jardin de givre. Le lecteur et le routeur restent cantonnés aux VFX Cartes.

Les états PM restent aux jambes, les états PA autour du haut du buste, la marque est suspendue et la garde laisse le centre de l'acteur visible. Départ et arrivée des mouvements ont des phases opposées orientées par les positions réelles. Une expiration conserve la silhouette du maintien, y compris le malus PA de Paris. Les secondes de présentation n'avancent aucune horloge de jeu.

## Vérifications de cette passe

- Suite VFX initiale : PASS strict, 23 tests / 1 328 assertions (`artifacts/dev/20260921-211459-test-test_unit_test_class_card_vfx.gd-10b67237/`).
- Suite **Cartes complète : PASS strict, 88/88 tests, 8 102/8 102 assertions**, aucune erreur, test ignoré ou fuite signalée. Rapport : `artifacts/dev/20260921-212544-test-cards-ffa0cabf/gut-strict-report.json`. Les 27 tests VFX comprennent les nouveaux contrats des 112 cartes, l'expiration des transitoires, la stase refusée sans marque, Paris et son outro, les gardes d'une/deux activations, les cinq vrais terrains jusqu'à expiration. Les autres suites exécutées couvrent les règles Cartes, les runs, les icônes et le HUD persistant.
- Douze vrais lancers en arène : **118/118 contrôles, 720 images**, Godot 4.7.1 / Forward+ / D3D12, aucune erreur moteur ou shader. Sorties et douze GIF : `artifacts/dev/class_card_vfx/extension/`. Captures inspectées à la caméra normale et ×2,4 : moisson, bastion, filet maintenu, stase avec marque/protection, dissonance, faille ardente, couronne, déplacement et disparition de la garde. Les zones de quatre dalles respectent l'obstacle qui ampute la croix théorique de cinq cases.
- Galerie complète régénérée : 112 cartes, 48 sorts adverses, 23 états explicites ; fiches `contracts.json` et document `docs/design/achilles/cards_vfx_contracts_2026-09-21.md`. Contrôle des planches des cartes d'initiation et des sols ; cadrage corrigé pour contenir les effets dans leurs vignettes. Les champs de terrain montrent une dalle témoin, le combat compose la croix réelle.
- Les scripts de capture consignent les empreintes avant/après ; les encodeurs refusent des sources VFX modifiées. Les PNG sont des pixels natifs, les GIF n'ajoutent qu'une quantification de palette.
- Neuf scripts GDScript formatés et vérifiés, syntaxe Node des encodeurs vérifiée. Après la suite Cartes, seule la présentation de la galerie a été retouchée, puis validée par une nouvelle capture native ; le code de production est inchangé.

## Limites et reprise

Les 112 fiches déclinent 20 composants de matière, pas 112 simulations indépendantes. Les 28 anciennes cartes `s_` utilisent toujours la compatibilité ; les `i_` du catalogue vivant sont couvertes. Les adversaires gardent leur association existante et bénéficient des nouveaux signes d'états communs en run Cartes.

Les captures utilisent une arène de production préparée, une IA suspendue et une horloge de présentation échantillonnée ; elles ne mesurent ni le coût GPU d'une scène chargée ni une partie manuelle complète. Les effets n'annoncent pas un bonus conditionnel que le rapport ne confirme pas séparément. Les longues durées doivent rester réglées dans les règles de jeu, jamais dans le shader.

Suite éventuelle : appréciation artistique sur les GIF et en partie, puis retouche ciblée des silhouettes ; profilage GPU d'un combat dense si cette direction est retenue. Les changements concurrents des règles, de la sélection et de leurs tests ont été préservés.
