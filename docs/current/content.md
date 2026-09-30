# Personnages et maps — statut du contenu

État consolidé le 21 septembre 2026, bestiaire Cartes actualisé le 28 septembre. « Absent du menu » ne signifie pas « sans
dépendance ». Le catalogue public est `ui/selection/character_selection_catalog.gd` ;
`get_entries(true)` ajoute seulement le scénario philosophe aux tests/laboratoires.
Le trio et la salle de l'Archiviste ont été retirés du produit.

| Contenu | Statut et raison de conservation |
|---|---|
| Achille original, peint et Passe-rive | Apparences publiques de la même aventure ; `data/runs/odyssey.tres` |
| Monstres Catabase | Ennemis du produit ; `data/units/enemies/catabase_*.tres` et catalogues d’expédition |
| Cartes consommables | Règles intégrées au parcours Cartes existant : 48 familles, 18 équipements et huit reliques sous `data/cards/consumable_v2/`. Les douze combats utilisent les cartes et apparences existantes ; les sept arènes 7×7 servent de fixtures de règles. [Guide et validation](cards_v2.md) |
| Paris | Référencé notamment par `data/units/enemies/catabase_shadow_paris.tres` ; pas un personnage à supprimer en bloc |
| Elfe, Mage, Guerrier | Modèles, textures et scènes spécifiques supprimés ; fiches de régression dans `test/fixtures/party_rules/`, sur un mannequin commun. Sorts et progressions partagés encore testés conservés dans `data/` |
| Mage philosophe | Le Dialecticien rejoint les nouvelles runs Cartes aux profondeurs 8 et 17, avec ses cinq sorts et son IA de soutien. `philosopher_trial` reste un laboratoire explicite |
| Famille squelette | Mêlée et archer à la profondeur 2 ; centurion de glace, chef rouge, mêlée et archer au premier élite (profondeur 6). Kits natifs adaptés aux budgets Cartes, deux invocations bornées sans butin supplémentaire. [Contrat du bestiaire](cards_bestiary.md) |
| Spectre | Ressources partagées par `philosopher_trial`, les laboratoires et les rencontres existantes ; ne pas supprimer sur la seule absence du menu |
| Salle de l'Archiviste | Supprimée avec son modèle, son décor, ses panneaux et ses outils spécifiques. Les anciens retours de run vont au titre |
| Refuge des braises, haltes et Seuil | Parcours actuels conservés, distincts de la salle de l'Archiviste |
| Maps Catabase et branches | Catalogues `core/expedition/`, `data/rooms/catabase_routes/`, `data/rooms/catabase_expansion/` et explorateur |
| Salles tactiques Cartes | Forge (5/Airain), sablier (6/Léthé et Styx), jardin (8/toutes branches), convoi (12/Styx), réservoirs (13/Airain et Léthé) ; trois rencontres spéciales par chemin, pour la route r6 avec écosystème Cartes actif ; `core/expedition/card_tactical_room_catalog.gd`, `battle/tactical_rooms/`. [Règles et essai](../../tools/tactical_rooms/README.md) |
| Forêt, montagne, caldeira et station historiques | Sept scènes de terrain isolées dans `test/fixtures/terrain/`, sans leurs fonds ni musiques. Les terrains peints forêt/volcan/station restent des fixtures actives des contrats de grille et du Studio |
| Laboratoires sous `tools/labs/` | Essais autonomes, pas automatiquement du contenu abandonné |
| VFX run Cartes | DA **Animation cel**, production du 22/09/2026 : 112 compositions, 17 séquences de six poses, lecteur/vol/sol et états compacts dans `vfx/class_cards/cel/`. Atelier natif et captures : `tools/class_card_vfx/`. [Décision et références](../design/achilles/cards_vfx_cel_2026-09-22.md) |
| Passe-Rive, sorts S18/S20 / intégration S23 / VFX S19 | Stature commune entre combat Cartes, haltes et seuil ; palette par matière commune au repos, aux déplacements et aux sept gestes conservés. Marche native liée à la distance, ruée avec réception à l’arrivée. Corrections de taille constantes et bornées par atlas. Les dessins gardent des différences de capuche et de vêtements : raccords parfaits non certifiés. S21 reste hors runtime. [Méthode, revue visuelle et audit S23](../../art/source/passe_rive_s23/README.md) |
| Passe-Rive, coup de pied haut S24/S31 | Heurt, Repousser, Choc de masse : huit vues dessinées, sans miroir ; 650 ms, impact à 310 ms, repères de talon et retour au repos natif. 24 lancers réels base/amélioration dans les directions légales de mêlée ; autres angles vérifiés dans le lecteur public. [Sources et preuves](../../art/source/passe_rive_s31/kick/README.md) |
| Passe-Rive, traction S25/S31 | Ramener au front : huit vues dessinées, 890 ms, résolution à 400 ms, main suivie par le lien et retour au repos natif. 16 lancers réels base/amélioration dans les huit orientations ; attraction uniquement confirmée par le combat. [Sources et preuves](../../art/source/passe_rive_s31/pull/README.md) |
| Passe-Rive, incantation S26/S31 | Huit vues dessinées pour Garde ferme, Bastion vivant, Sommeil marqué, Sceau ombreux, Jardin de givre et Résonance du sceau. 1,15 s, ouverture à 590 ms, échelle/appui fixes, retour natif et VFX propres à chaque carte. 96 lancers base/amélioration dans huit directions, contrôle supplémentaire de la stase. Grâce du bronze conserve S30. [Sources et validation](../../art/source/passe_rive_s31/incantation/README.md) |
| Passe-Rive, garde S27/S31 | Garde brève, Contre préparé et Garde de secours : huit vues dessinées, 12 poses, 0,72 s, protection à 240 ms. Appui et échelle fixes, arc orienté pour n02/secours ; effet dédié de Contre conservé. 40 lancers réels validés. [Sources](../../art/source/passe_rive_s31/guard/README.md) · [Validation](../../art/source/passe_rive_s31/guard/VALIDATION.md) |
| `web/achilles-run-lab/` | Prototype autonome expérimental, isolé de l’import Godot |
| Passe-Rive, Prélèvement S28/S31 | Carte `cc2_t07`, base/améliorée : huit vues dessinées, saisir puis absorber, 0,94 s, résolution à 330 ms. Filament attaché à la main, épaisseur constante ; flux selon les PV retirés, éclat selon le soin effectif. 33 lancers réels validés. [Sources](../../art/source/passe_rive_s31/drain/README.md) · [Validation](../../art/source/passe_rive_s31/drain/VALIDATION.md) |
| Passe-Rive, Passage spectral S29/S31 | Bond spectral, Au-delà du front et Permutation : corps dessiné et voile dans les huit directions, 0,86 s et résolution invisible à 310 ms. Poses complémentaires partagées avec Prélèvement, montage dédié. 48 téléportations/permutations réelles validées. [Sources](../../art/source/passe_rive_s31/spectral/README.md) · [Validation](../../art/source/passe_rive_s31/spectral/VALIDATION.md) |
| Passe-Rive, restauration S30/S31 | Seconde aurore et Grâce du bronze : huit vues dessinées, ouverture longue de 1,12 s / soin à 450 ms et brève de 0,82 s / soin à 250 ms. Deux paumes suivies, lumière/facettes selon les gains réels, stature fixe et repos natif. 64 lancers réels : base, amélioration, PV pleins et garde plafonnée ; fin d'activation vérifiée. [Sources](../../art/source/passe_rive_s31/renew/README.md) · [Validation](../../art/source/passe_rive_s31/renew/VALIDATION.md) |
| `art/source/` et `meshy_output/` | Sources, provenance et variantes artistiques ; ne pas supprimer sur le seul nom `v1` ou faute de chargement runtime |

## Nettoyage du 21 septembre

Les suppressions portent sur des vestiges ou copies sans usage identifié :
`gobtest.tscn` (deux dépendances absentes), `test_phase_1.tscn`, l’ancien `main.gd`
et son UID, deux journaux suivis, le second modèle `Lanternbound Archivist_1`,
et les cinq dossiers d’images `asset/map/painted/nouveau_terrain*`.

Les images de ces cinq dossiers sont identiques à
`asset/Background/montagne plateau.png`, conservée. Le second lot a également
retiré l'Archiviste original et ses textures. Les recherches de chemins,
UID et empreintes sont conservés dans le rapport local de nettoyage.

Cette opération ne retire aucune aventure publique ni aucune classe Cartes.
`RunHeroResolver` exige un
profil de contenu explicite, même si un ancien appel demande le fallback.
Les outils et tests de groupe passent explicitement `PartyRulesFixtures.HERO_PATHS`.
Le scénario philosophe reste un laboratoire explicite.

Trois anciennes scènes sans référence active ont ensuite été supprimées :
`battle_salle_crete_montagne_enneigee.tscn`, `battle_salle_montagne_iso.tscn`
et `battle_salle_montagne_chemin.tscn`, avec sa fiche `first_run_room_02_chemin.tres`.
Les variantes `iso_v2`, `iso_v3`, arène et plateau ne sont plus dans
`data/rooms/maps/` : leurs dispositions nécessaires aux tests sont dans les
fixtures de terrain. Les maps Catabase restent actives.

L'[audit de dépendances](../../tools/content_audit/README.md) fournit désormais
un inventaire reproductible des chemins et UID, avec les références entrantes.
Il ne déduit pas l'absence d'usage depuis une simple absence dans le menu.

## Règles de destination

- Nouveaux médias runtime : privilégier `assets/<domaine>/`. Les références
  existantes sous `asset/` restent valides ; ne pas les migrer massivement.
- Sources et provenance artistiques : `art/source/<domaine>/`, avec le livrable
  retenu indiqué dans le README local.
- Sorties reproductibles : `artifacts/` ; avant désuivi, distinguer preuves et
  fixtures, notamment `artifacts/item_studio/characterization.json`.
- Avant suppression : rechercher chemin exact, UID, chemins construits et
  dépendances d’édition/tests ; conserver les sources et crédits nécessaires.
- Après suppression : import, suite globale et scénarios concernés. Un graphe
  statique seul ne constitue pas une validation runtime.

## Échelle de Passe-Rive — 29 septembre 2026

La stature source reste 214 pixels. Le combat suit les calibrations du terrain et
les multiplicateurs artistiques de salle, comme les autres unités ; la hauteur
écran fixe qui compensait le cadrage du HUD a été retirée. Les haltes reprennent
la hauteur humaine de leur manifeste Studio. Vérification ciblée :
`./tools/class_card_vfx/play_passe_rive_s23.ps1 -RoomScaleOnly`.
[Décisions et preuves](../ai/ROOM_SCALE_DECK_MATERIALS_2026-09-29.md).
