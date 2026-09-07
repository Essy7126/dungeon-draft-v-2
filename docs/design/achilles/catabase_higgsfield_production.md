# Catabase — production artistique avec Higgsfield

Date : 7 septembre 2026. **Style validé ; 18 exports intégrés et testés ; production globale partielle, bloquée par les crédits (`partial_blocked_credits`).**

Ce document reprend le périmètre artistique de la tâche « Refondre l'arbre d'Achille ». Il inventorie des illustrations pour les contenus existants : aucun sort, objet, destination, coût ou effet gameplay n'est ajouté. Les catalogues runtime restent autoritaires, et les comptes rendus de la tâche de gameplay restent inchangés.

Le [manifeste versionné](../../../art/source/catabase/painted/manifest.json) associe les IDs, familles, chemins, références, prompts et états. **Les deux références sont `existing` ; les seize icônes pilotes, le camp et la bibliothèque sont `integrated_tested` ; le reste demeure `pending`.** Les associations des formes et les nœuds ne sont pas comptés comme des exports supplémentaires. Un chemin prévu ne signifie pas qu'un fichier existe. Le dossier source porte un `.gdignore` ; les exports destinés au jeu sont séparés sous `assets/catabase/painted/`.

## Direction choisie et provenance

L'utilisateur a choisi la direction des images créées au début de la tâche Higgsfield : les **neuf icônes d'inventaire** et la **bibliothèque engloutie**. Il a demandé de poursuivre la production avec ce plugin. Cet accord sur le style est acquis. Le lot pilote a reçu une revue visuelle et une validation dans le moteur aux deux résolutions cibles. Le périmètre et les limites de ces contrôles figurent ci-dessous.

| Référence | Job Higgsfield | Source |
| --- | --- | --- |
| Icônes d'inventaire | `e4a45c02-674a-4f7d-b4b2-9ba80ec6448d` | [PNG 2048 × 2048](https://d8j0ntlcm91z4.cloudfront.net/user_3Ixm0qCahpQeob0xcZCb9tdKY43/hf_20260907_113139_e4a45c02-674a-4f7d-b4b2-9ba80ec6448d.png) |
| Bibliothèque engloutie | `2bf07a34-7aa1-4c05-9c90-969d0bf3fb14` | [PNG 2752 × 1536](https://d8j0ntlcm91z4.cloudfront.net/user_3Ixm0qCahpQeob0xcZCb9tdKY43/hf_20260907_113139_2bf07a34-7aa1-4c05-9c90-969d0bf3fb14.png) |

Les prompts complets sont conservés dans `references[].prompt` du manifeste. La tâche source est `01a07ba1-c5c9-7471-af8f-0d7ff8421bca`, génération du 7 septembre à 11:31:39 UTC. Les captures de 11:33:28 et 11:33:35 UTC ont été inspectées dans son historique local. Les originaux sont maintenant conservés sous `art/source/catabase/painted/references/`. Le modèle demandé était `nano_banana_pro` ; le résultat du plugin annonce `nano_banana_2`. Ces deux valeurs restent séparées.

Le vocabulaire commun est une **peinture stylisée en relief** : silhouettes généreuses, volumes simples et biseautés, contours colorés discrets, ombres graduées, matériaux lisibles et rehauts contrôlés. Les objets associent bois miel, métal vieilli, verre coloré et accents précieux. Les lieux associent pierre bleu pétrole sombre, eau ou magie turquoise, bougies ambre, bronze oxydé et mousse olive. Le prompt source prescrit le fond `#101824`. Le fond mesuré et conservé dans les exports pilotes est **`#141d2e` — RGB `(20, 29, 46)`**. Les autres couleurs décrivent les images, sans prétendre être des mesures colorimétriques.

L'ancien Achille classique n'est pas la référence principale de ce lot. Sa silhouette et ses accessoires peuvent aider à lire une action existante ; les deux images Higgsfield imposent le traitement artistique.

## Couverture et état du lot

| Catégorie | Couverture | État actuel |
| --- | --- | --- |
| Arènes | 10 peintures sur leurs géométries existantes | pending |
| Haltes | 17 destinations : 14 principales, 2 secrètes et 1 variante aléatoire | 2 exports intégrés et testés ; 15 pending |
| Sorts | 21 familles associées aux 46 IDs runtime | 16 maîtres intégrés et testés pour 37 IDs ; 5 familles et Tempête pending |
| Glyphes de statistiques | 9 glyphes pour 14 liaisons | pending |
| Emblèmes | 3 doctrines et 2 branches découvertes | pending |
| Équipements | 12 objets du catalogue | pending |
| Route | 8 types de destination actifs, badge secret et sceau de position | pending |
| Fonds UI | Parchemin et fresque séparés | pending |
| VFX | 9 familles, puis exports et séquences temporelles appropriés | pending |

Les 55 nœuds d'arbre se répartissent en **41 nœuds associés à des sorts et 14 liaisons statistiques**. Les 41 reprennent l'art des sorts ; ils ne constituent pas 41 commandes supplémentaires. `exp_tempest` est un choix du jalon XII, extérieur à ces 55 nœuds. Les 46 sorts ne nécessitent pas 46 maîtres sans relation : on prévoit 21 familles et 25 associations de formes, chacune revue explicitement.

## Premier lot repris dans la tâche de production

Le premier lot intégré et testé contient **16 icônes de familles, Le camp des compagnons et La bibliothèque engloutie**, soit **18 PNG**. Le camp et la planche de seize icônes proviennent de deux nouvelles générations. La bibliothèque réutilise directement la référence approuvée : elle n'a pas occasionné une troisième génération.

Les seize icônes sont exportées en **256 × 256**, sur fond mesuré `#141d2e`, et ont été inspectées à **48 et 64 pixels** par la tâche de production. Le camp et la bibliothèque sont exportés en **1920 × 1200** et inspectés à cette taille. Les tests confirment que le registre associe les maîtres à **37 des 46 IDs de sorts**, avec ressources canoniques préservées et les deux apparences d'Achille couvertes. Cette couverture d'icônes ne valide pas de nouvelles animations en combat. **Tempête du Péléide exige un motif distinct** et reste en attente avec les familles élémentaires et les serments.

| Source pilote | Job terminé | Traitement et sortie |
| --- | --- | --- |
| Planche de 16 icônes | `10757605-4fba-4fe8-8af9-ac4c98ee28b0` | `art/source/catabase/painted/generations/icons_martial_sheet.png` → `assets/catabase/painted/icons/` |
| Camp des compagnons | `71aaec1c-eabf-45a3-a23e-327eedc9cfe9` | `art/source/catabase/painted/generations/camp_compagnons.png` → `assets/catabase/painted/halts/camp_compagnons.png` |
| Bibliothèque engloutie | Réemploi du job `2bf07a34-7aa1-4c05-9c90-969d0bf3fb14` | Référence conservée → `assets/catabase/painted/halts/bibliotheque_engloutie.png` |

Les deux jobs pilotes sont annoncés `completed`, modèle retourné `nano_banana_2`. Les prompts et URLs complets figurent dans `production_generations` du manifeste et dans [generation_requests.json](../../../tools/catabase_art_pipeline/generation_requests.json). Le [relevé des exports](../../../art/source/catabase/painted/pilot_exports.json) conserve dimensions, boîtes sources et SHA-256 ; les 18 fichiers installés concordent avec ces empreintes.

Le traitement média a été exécuté **uniquement dans le sandbox Higgsfield**, avec le [pipeline conservé](../../../tools/catabase_art_pipeline/build_pilot.py) : extraction des motifs, rééchantillonnage uniforme, recadrage central des lieux. La découpe de Contretemps et Marche a été affinée à `y = 1460` pour séparer leur composante jointe. Les sources ne sont pas écrasées ; aucun redessin n'est effectué hors Higgsfield. Les libellés de revue du relevé brut d'export décrivent sa création ; le suivi de revue courant est porté par le manifeste principal.

## Lots bornés et coût

Le pilote a dépensé **4 crédits** : deux nouvelles images à 2 crédits chacune. Le solde est passé de **4,5 à 0,5 crédit**, confirmé par l'outil Higgsfield à **14:41 UTC le 7 septembre 2026**. Une vérification ultérieure par la tâche de production confirme toujours **0,5 crédit**. La recharge demandée reste en attente ; aucune commande supplémentaire n'est considérée financée. Les tarifs vérifiés dans la tâche de production sont **2 crédits par image Nano Banana 2k**, **2 crédits par image GPT Image medium 2k**, et **4 crédits par image Nano Banana 4k**. Vérifier le solde et le coût affiché avant toute nouvelle génération. Les tarifs indiquent une image générée, pas une icône extraite d'une planche.

Le budget de travail reste **60–80 crédits hors retouches**. L'estimation initiale était de 38 images / 76 crédits. Le réemploi de la bibliothèque retire une commande : le plan actualisé représente **37 nouvelles images / 74 crédits**, dont **2 images / 4 crédits déjà dépensés** et **35 images / 70 crédits encore estimés**. À solde constant, il manquerait 69,5 crédits pour ce plan précis. Cette projection n'est pas un débit ni une obligation de suivre tous les lots sans réemploi supplémentaire. Les retouches, formes distinctes supplémentaires et sorties 4k peuvent augmenter le coût.

| Lot | Images / requêtes maximum | Contenu | Estimation 2k |
| --- | --- | --- | --- |
| 01 — pilote | 2 terminées | Camp et planche de 16 familles ; bibliothèque réemployée en plus | 4 crédits dépensés |
| 02 — petits assets | 6 | Planche des 5 familles restantes + Tempête ; 12 objets ; 9 glyphes ; 5 emblèmes ; 10 marqueurs ; parchemin | 12 crédits |
| 03 — fresque et VFX | 4 | Fresque, 3 planches de 3 familles VFX | 8 crédits |
| 04 — arènes A | 6 | Porteurs, Citerne, Braises, Péristyle, Digue, Mesures | 12 crédits |
| 05 — arènes B | 4 | Nécropole, Offrandes, Escalier, Moires | 8 crédits |
| 06 — haltes A | 5 | Étal, Stèle, Autel, Forge, Mémoire de Chiron ; bibliothèque déjà exportée | 10 crédits |
| 07 — haltes B | 6 | Bivouac, Pacte, Marché, Foyer, Feu avant Pâris, Ultime offrande | 12 crédits |
| 08 — haltes C | 4 | Obole, Atelier, Tombeau, Défi du serment muet | 8 crédits |

Chaque soumission contient **au plus six requêtes**, chacune avec `count = 1`. Attendre les résultats et contrôler le lot avant le suivant. Une planche conserve une grille, des marges suffisantes et un index stable de case vers ID. Les douze techniques martiales et les douze équipements peuvent chacun tenir sur leur propre planche lorsque ce conditionnement est retenu. Une planche supplémentaire peut regrouper jusqu'à douze **formes déjà existantes** qui nécessitent une composition distincte : sélectionner leurs IDs après revue et comptabiliser son coût hors plan de référence.

Le plan couvre les sources artistiques et leurs exports statiques. Les trois planches de VFX ne livrent pas à elles seules neuf animations jouables : leurs séquences, ancrages, marqueurs d'impact et durées restent à produire ou régler puis à tester. Le budget n'affirme pas financer toutes ces itérations.

## Arènes : suivre les guides existants

| ID runtime | Nom | Guide |
| --- | --- | --- |
| `catabase_porteurs_v1` | La Porte des Porteurs | `data/rooms/catabase_expansion/porteurs/grid_reference.png` |
| `catabase_citerne_v1` | La Citerne des Échos | `data/rooms/catabase_expansion/citerne/grid_reference.png` |
| `catabase_braises_v1` | La Galerie des Braises | `data/rooms/catabase_expansion/braises/grid_reference.png` |
| `catabase_peristyle_v1` | Le Péristyle Brisé | `data/rooms/catabase_expansion/peristyle/grid_reference.png` |
| `catabase_digue_v1` | La Digue du Léthé | `data/rooms/catabase_expansion/digue/grid_reference.png` |
| `catabase_mesures_v1` | La Cour des Mesures | `data/rooms/catabase_expansion/mesures/grid_reference.png` |
| `catabase_necropole_v1` | La Nécropole des Vœux | `data/rooms/catabase_expansion/necropole/grid_reference.png` |
| `catabase_offrandes_v1` | Le Carrefour des Offrandes | `data/rooms/catabase_expansion/offrandes/grid_reference.png` |
| `catabase_escalier_v1` | Les Degrés de Cendre | `data/rooms/catabase_expansion/escalier/grid_reference.png` |
| `catabase_moirai_v1` | L'Atrium des Moires | `data/rooms/catabase_expansion/moirai/grid_reference.png` |

Chaque guide possède son `geometry_manifest.json` voisin. Composer sur le canvas 1920 × 1200 en respectant son origine, ses accès et ses obstacles. Les cases, collisions et lignes de vue restent autoritaires. Les chemins `assets/catabase/painted/arenas/<id>.png` du manifeste sont une proposition de sortie, pas un raccord actif. Les cinq arènes historiques restent un contrôle de continuité ; elles ne sont pas comptées parmi les dix nouvelles peintures.

## Haltes : titres et clés

| Clé artistique stable | Titre du catalogue | Type |
| --- | --- | --- |
| `camp_compagnons` | Le camp des compagnons | hub |
| `etal_passeur` | L'étal du passeur | merchant |
| `stele_noms` | La stèle des noms | lore |
| `autel_serments` | L'autel des serments | sanctuary |
| `forge_cuirasses` | La forge des cuirasses | merchant |
| `memoire_chiron` | La mémoire de Chiron | lore |
| `bibliotheque_engloutie` | La bibliothèque engloutie | lore |
| `bivouac_memoires` | Le bivouac des six mémoires | hub |
| `pacte_sixieme_geste` | Le pacte du sixième geste | sanctuary |
| `marche_dernier_feu` | Le marché du dernier feu | merchant |
| `foyer_revenants` | Le foyer des revenants | hub |
| `feu_avant_paris` | Le feu avant Pâris | hub |
| `ultime_offrande` | L'ultime offrande | sanctuary |
| `obole_dernier_passage` | L'obole du dernier passage | merchant |
| `atelier_sous_racine` | L'atelier sous la racine | sanctuary |
| `tombeau_serment_intact` | Le tombeau du serment intact | lore |
| `defi_serment_muet` | Le défi du serment muet | sanctuary |

Le catalogue `ui/expedition/catabase_halt_art_catalog.gd` associe ces clés aux titres et ancres. Les destinations de route possèdent des IDs calculés par profondeur et voie : ne pas les remplacer par une clé artistique dans la sauvegarde. Prévoir un PNG indépendant par clé sous `assets/catabase/painted/halts/`, même si plusieurs exports utilisent un maître commun. Camp et bibliothèque possèdent leur export cadré, leurs cibles mesurées dans l'image et des positions de libellés séparées. Les zones interactives, confirmations et transactions mémoire ont été testées à 1280 × 720 et 1920 × 1080.

Le canvas source des haltes est 1920 × 1200. Les repères suivants sont les **ancres génériques pour les prochaines haltes** ; les deux haltes pilotes utilisent les coordonnées mesurées propres à leur composition, conservées dans `halt_layout_contract.destination_targets` et `destination_labels` du manifeste. Ancres génériques normalisées du catalogue : achat `(0.22, 0.48)`, repos `(0.50, 0.72)`, mémoire `(0.79, 0.43)`, découverte et serment `(0.78, 0.79)`. Le marchand prévoit trois achats `(0.18, 0.46)`, `(0.43, 0.40)`, `(0.70, 0.46)`, puis repos `(0.29, 0.78)` et mémoire `(0.76, 0.80)`. Placer les accessoires autour de ces repères ; une ancre n'ajoute pas un service absent des données. Vérifier les réserves pour les panneaux après intégration.

## Sorts : familles et IDs exhaustifs

| Famille artistique | Technique | IDs runtime couverts |
| --- | --- | --- |
| `peleid_strike` | Frappe du Péléide | `achilles_peleid_strike`, `exp_frappe_ouverte`, `exp_tempest` |
| `fulminant_dash` | Percée fulgurante | `achilles_fulminant_dash` |
| `pelion_shot` | Tir du Pélion | `achilles_pelion_shot`, `exp_tir_de_guet` |
| `bronze_guard` | Garde d'airain | `achilles_bronze_guard`, `exp_garde_eaque` |
| `crochet` | Crochet | `exp_crochet`, `exp_crochet_mutation`, `exp_crochet_legend` |
| `fauchage` | Fauchage | `exp_fauchage`, `exp_fauchage_signature` |
| `entaille` | Entaille sacrificielle | `exp_entaille`, `exp_entaille_mutation`, `exp_entaille_legend` |
| `moisson` | Moisson vitale | `exp_moisson`, `exp_moisson_signature` |
| `rupture` | Trait de rupture | `exp_rupture`, `exp_rupture_mutation`, `exp_rupture_legend` |
| `marque` | Marque du chasseur | `exp_marque`, `exp_marque_signature` |
| `feinte` | Feinte latérale | `exp_feinte`, `exp_feinte_mutation`, `exp_feinte_legend` |
| `contretemps` | Contretemps | `exp_contretemps`, `exp_contretemps_signature` |
| `heurt` | Heurt d'airain | `exp_heurt`, `exp_heurt_mutation`, `exp_heurt_legend` |
| `posture` | Posture d'airain | `exp_posture`, `exp_posture_signature` |
| `souffle` | Second souffle | `exp_souffle`, `exp_souffle_mutation`, `exp_souffle_legend` |
| `marche` | Marche du survivant | `exp_marche`, `exp_marche_signature` |
| `braise` | Trait de braise | `exp_braise`, `exp_braise_mutation`, `exp_braise_legend` |
| `givre` | Entrave de givre | `exp_givre`, `exp_givre_signature` |
| `foudre` | Ligne fulgurante | `exp_foudre` |
| `serment_rempart` | Serment du rempart | `exp_serment_rempart` |
| `serment_brasier` | Serment du brasier | `exp_serment_brasier` |

Les exports maîtres suivent `assets/catabase/painted/icons/<famille>.png`. Une forme peut disposer d'un override `<spell_id>.png`. Les 37 associations runtime testées réemploient actuellement les 16 maîtres. Les statuts `pending` des variantes concernent les illustrations distinctes encore à produire ; le manifeste laisse leurs exports non décidés à `null`. Ce réemploi ne crée pas 37 nouveaux fichiers. La source, les coordonnées de découpe éventuelles et la décision de réemploi doivent être enregistrées avant validation.

Les variantes sont non destructives : conserver le maître original et son job ; découper, cadrer ou assembler des calques conservés séparément ; faire produire toute nouvelle peinture ou modification de composition par Higgsfield. Un simple changement de couleur ne prouve pas qu'une nouvelle fonction est bien représentée. Les textes, cadres de mutation/signature/légende, prérequis et coûts demeurent des éléments de l'interface.

## Glyphes, emblèmes, équipement et route

| Glyphe | Liaisons exactes |
| --- | --- |
| `force` | `briseur.liaison_a` — Levier |
| `attack_power` | `briseur.liaison_b` — Élan brutal ; `sang.liaison_b` — Prix du courage ; `chasseur.liaison_b` — Œil du Pélion ; `elements.liaison_b` — Conduction |
| `max_hp` | `sang.liaison_a` — Sang dense ; `endurance.liaison_a` — Réserve du héros |
| `initiative` | `chasseur.liaison_a` — Lecture du terrain |
| `max_mp` | `danseur.liaison_a` — Appuis légers |
| `esquive` | `danseur.liaison_b` — Angle mort |
| `armure` | `airain.liaison_a` — Bronze épais |
| `resist_magique` | `airain.liaison_b` — Bronze gravé ; `elements.liaison_a` — Accord des éléments |
| `heal_budget` | `endurance.liaison_b` — Souffle profond |

Les cinq emblèmes sont `colere` (Colère du Péléide), `chiron` (Leçon de Chiron), `eaque` (Égide d'Éaque), `elements` (Affinités élémentaires) et `serment` (Serments du Styx). La fresque reste un fond indépendant ; l'ouverture des branches dépend de la progression réelle.

| ID équipement | Nom |
| --- | --- |
| `catabase_levier` | Levier des Myrmidons |
| `catabase_lame_sang` | Lame du talon |
| `catabase_javeline` | Javeline des longues vues |
| `catabase_xiphos_danse` | Xiphos des deux appuis |
| `catabase_masse_airain` | Masse du rempart |
| `catabase_fer_braise` | Fer de la fournaise |
| `catabase_cuirasse` | Cuirasse d'Éaque |
| `catabase_lin_survivant` | Lin du survivant |
| `catabase_sandales` | Sandales du détour |
| `catabase_sceau_chasse` | Sceau de la dernière chasse |
| `catabase_prisme` | Prisme de Chiron |
| `catabase_agrafe` | Agrafe du serment |

Les dix marqueurs sont `normal`, `elite`, `boss`, `hub`, `merchant`, `sanctuary`, `lore`, `unknown`, plus le badge `secret` et le sceau `current`. Les types `cache` et `event` sont réservés dans le code mais ne correspondent à aucune destination actuelle ; ils ne sont pas inclus dans les dix. Le parchemin ne contient ni chemins fonctionnels ni texte peint : états connus, disponibles, visités, inaccessibles et inconnus restent pilotés par l'UI. Une destination inconnue conserve un marqueur incertain.

## Revue et suivi

Pour chaque résultat : enregistrer le job, le modèle réellement exécuté, le prompt, le coût, la source, l'export, la correspondance d'ID et l'état de revue. Conserver la référence complète ; une capture de galerie ne remplace pas la source. Les états de génération, de revue et de validation runtime sont séparés.

Le pilote a passé l'import, les tests unitaires et deux probes GPU. Le [résumé final](../../../artifacts/catabase_painted_art/summary.json) rassemble les résultats ; le manifeste porte les états actuels. Les empreintes et la provenance des 18 exports restent inchangées.

| Vérification exécutée | Résultat | Preuve |
| --- | --- | --- |
| Import Godot | Code 0 ; aucun diagnostic | [import.log](../../../artifacts/catabase_painted_art/import.log) |
| GUT icônes et haltes | **18/18 tests, 6 438 assertions**, code 0 ; aucun diagnostic | [gut_summary.json](../../../artifacts/catabase_painted_art/gut_summary.json) |
| GPU 1280 × 720 | **319 contrôles, 0 échec**, code 0 ; 7 captures ; aucun diagnostic | [report.json](../../../artifacts/catabase_painted_art/1280x720/report.json), [journal](../../../artifacts/catabase_painted_art/runtime_1280x720.log) |
| GPU 1920 × 1080 | **319 contrôles, 0 échec**, code 0 ; 7 captures ; aucun diagnostic | [report.json](../../../artifacts/catabase_painted_art/1920x1080/report.json), [journal](../../../artifacts/catabase_painted_art/runtime_1920x1080.log) |
| Régression build | **1 000 contrôles, 0 échec**, code 0 ; diagnostics de libération à la fermeture | [regression_summary.json](../../../artifacts/catabase_painted_art/regression_summary.json) |
| Régression session | **301 contrôles, 0 échec**, code 0 ; aucun diagnostic | [regression_summary.json](../../../artifacts/catabase_painted_art/regression_summary.json) |

La suite build signale **8 allocations RID de textures, 409 instances ObjectDB et 168 ressources encore utilisées à la fermeture**. Son journal n'est donc pas propre. La cause n'a pas été établie dans ce lot ; les assertions réussies ne résolvent pas cette limite de libération.

Les probes passent par le vrai HUD initial, la route déterministe et les boutons de confirmation des deux haltes. Chaque transaction mémoire ajoute réellement **20 oboles**, conserve son reçu et rejette une seconde consommation. Les victoires intermédiaires servent de fixtures pour atteindre les lieux : ces probes ne valident pas une run entière jouée ni de nouvelles animations de combat. Les tests couvrent aussi les fallbacks, la priorité des icônes HUD, les ressources canoniques, les deux apparences, les sauvegardes, les graines, les aperçus inconnus et la reconfiguration.

Les 14 captures ont été inspectées par la tâche de production. Les icônes sont lisibles aux tailles testées ; les cibles des services suivent les objets peints et leurs libellés sont décalés pour les laisser visibles.

| Vue contrôlée | 1280 × 720 | 1920 × 1080 |
| --- | --- | --- |
| HUD initial | [Capture](../../../artifacts/catabase_painted_art/1280x720/opening_hud.png) | [Capture](../../../artifacts/catabase_painted_art/1920x1080/opening_hud.png) |
| Camp — mémoire sélectionnée | [Capture](../../../artifacts/catabase_painted_art/1280x720/camp_compagnons_selected_lore.png) | [Capture](../../../artifacts/catabase_painted_art/1920x1080/camp_compagnons_selected_lore.png) |
| Camp — transaction terminée | [Capture](../../../artifacts/catabase_painted_art/1280x720/camp_compagnons_lore_completed.png) | [Capture](../../../artifacts/catabase_painted_art/1920x1080/camp_compagnons_lore_completed.png) |
| Arbre Colère | [Capture](../../../artifacts/catabase_painted_art/1280x720/tree_colere.png) | [Capture](../../../artifacts/catabase_painted_art/1920x1080/tree_colere.png) |
| Arbre Chiron | [Capture](../../../artifacts/catabase_painted_art/1280x720/tree_chiron.png) | [Capture](../../../artifacts/catabase_painted_art/1920x1080/tree_chiron.png) |
| Bibliothèque — mémoire sélectionnée | [Capture](../../../artifacts/catabase_painted_art/1280x720/bibliotheque_engloutie_selected_lore.png) | [Capture](../../../artifacts/catabase_painted_art/1920x1080/bibliotheque_engloutie_selected_lore.png) |
| Bibliothèque — transaction terminée | [Capture](../../../artifacts/catabase_painted_art/1280x720/bibliotheque_engloutie_lore_completed.png) | [Capture](../../../artifacts/catabase_painted_art/1920x1080/bibliotheque_engloutie_lore_completed.png) |

Commandes exactes exécutées par la tâche de production, depuis la racine du dépôt. Import :

```powershell
& 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --headless --editor --recovery-mode --path . --import --log-file artifacts/catabase_painted_art/import.log
```

Probes GPU finaux :

```powershell
$catArtProbe = Start-Process -FilePath 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' -ArgumentList @('--path','.','--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--resolution','1280x720','--log-file','artifacts/catabase_painted_art/runtime_1280x720.log','res://tests/expedition/CatabasePaintedArtProbe.tscn','--','resolution=1280x720') -WindowStyle Hidden -PassThru; $catArtProbe.WaitForExit(); Write-Output ('CATABASE_ART_PROBE_EXIT=' + $catArtProbe.ExitCode)
```

```powershell
$catArtProbe = Start-Process -FilePath 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' -ArgumentList @('--path','.','--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--resolution','1920x1080','--log-file','artifacts/catabase_painted_art/runtime_1920x1080.log','res://tests/expedition/CatabasePaintedArtProbe.tscn','--','resolution=1920x1080') -WindowStyle Hidden -PassThru; $catArtProbe.WaitForExit(); Write-Output ('CATABASE_ART_PROBE_EXIT=' + $catArtProbe.ExitCode)
```

Tests GUT :

```powershell
& 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' '--headless' '--path' 'C:\Users\p.montebello\Documents\GitHub\dungeon-draft-v-2' '--log-file' 'C:\Users\p.montebello\Documents\GitHub\dungeon-draft-v-2\artifacts\catabase_painted_art/gut.log' '--script' 'res://addons/gut/gut_cmdln.gd' '--' '-gconfig=' '-gexit' '-gdisable_colors' '-gfailure_error_types' 'engine,gut,push_error' '-gjunit_xml_file' 'C:\Users\p.montebello\Documents\GitHub\dungeon-draft-v-2\artifacts\catabase_painted_art/gut.junit.xml' '-gtest' 'res://test/unit/test_catabase_painted_icons.gd' '-gtest' 'res://test/unit/test_catabase_halt_art.gd'
```

Régressions :

```powershell
& 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' '--headless' '--path' 'C:\Users\p.montebello\Documents\GitHub\dungeon-draft-v-2' '--log-file' 'C:\Users\p.montebello\Documents\GitHub\dungeon-draft-v-2\artifacts\catabase_painted_art/build_regression.log' 'res://tests/expedition/build_state_test.tscn'
```

```powershell
& 'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' '--headless' '--path' 'C:\Users\p.montebello\Documents\GitHub\dungeon-draft-v-2' '--log-file' 'C:\Users\p.montebello\Documents\GitHub\dungeon-draft-v-2\artifacts\catabase_painted_art/session_regression.log' 'res://tests/expedition/session_integration_test.tscn'
```

Le premier essai de probe, conservé dans `runtime_1280.log`, contenait une erreur de typage de tableau. Le probe a été corrigé puis les deux résolutions relancées ; seuls les journaux finaux nommés ci-dessus fondent cette validation.

Les **35 images restantes, estimées à 70 crédits hors retouches**, les nouvelles animations et les VFX restent à produire. Chaque futur lot devra passer ses propres contrôles de lisibilité, transparence si requise, import, ancrages, clics et captures. Les dix peintures d'arènes devront en plus respecter leur géométrie et leurs occultations ; les VFX devront vérifier la cohérence temporelle, la libération des effets et la visibilité des cibles. La fresque, les autres haltes et les autres petits assets demeurent `pending`. Le pilote est intégré et testé ; la production globale reste partielle et bloquée par les crédits.
