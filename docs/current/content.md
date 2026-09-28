# Personnages et maps — statut du contenu

État consolidé le 21 septembre 2026. « Absent du menu » ne signifie pas « sans
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
| Mage philosophe et spectre | Scénario `philosopher_trial`, laboratoires et tests ; conservés hors parcours public |
| Salle de l'Archiviste | Supprimée avec son modèle, son décor, ses panneaux et ses outils spécifiques. Les anciens retours de run vont au titre |
| Refuge des braises, haltes et Seuil | Parcours actuels conservés, distincts de la salle de l'Archiviste |
| Maps Catabase et branches | Catalogues `core/expedition/`, `data/rooms/catabase_routes/`, `data/rooms/catabase_expansion/` et explorateur |
| Salles tactiques Cartes | Forge (5/Airain), sablier (6/Léthé et Styx), jardin (8/toutes branches), convoi (12/Styx), réservoirs (13/Airain et Léthé) ; trois rencontres spéciales par chemin, pour la route r6 avec écosystème Cartes actif ; `core/expedition/card_tactical_room_catalog.gd`, `battle/tactical_rooms/`. [Règles et essai](../../tools/tactical_rooms/README.md) |
| Forêt, montagne, caldeira et station historiques | Sept scènes de terrain isolées dans `test/fixtures/terrain/`, sans leurs fonds ni musiques. Les terrains peints forêt/volcan/station restent des fixtures actives des contrats de grille et du Studio |
| Laboratoires sous `tools/labs/` | Essais autonomes, pas automatiquement du contenu abandonné |
| VFX run Cartes | DA **Animation cel**, production du 22/09/2026 : 112 compositions, 17 séquences de six poses, lecteur/vol/sol et états compacts dans `vfx/class_cards/cel/`. Atelier natif et captures : `tools/class_card_vfx/`. [Décision et références](../design/achilles/cards_vfx_cel_2026-09-22.md) |
| Passe-Rive, sorts S18/S20 / intégration S23 / VFX S19 | Stature commune entre combat Cartes, haltes et seuil ; palette par matière commune au repos, aux déplacements et aux sept gestes conservés. Marche native liée à la distance, ruée avec réception à l’arrivée. Corrections de taille constantes et bornées par atlas. Les dessins gardent des différences de capuche et de vêtements : raccords parfaits non certifiés. S21 reste hors runtime. [Méthode, revue visuelle et audit S23](../../art/source/passe_rive_s23/README.md) |
| Passe-Rive, incantation S26 | Nouveau geste SE partagé par Garde ferme, Bastion vivant, Grâce du bronze, Sommeil marqué, Sceau ombreux, Jardin de givre et Résonance du sceau. 1,15 s, effet à 590 ms, appui et calibration de taille fixes. Les autres vues conservent leur incantation existante ; chaque carte garde ses VFX. [Source, attributions et validation en combat](../../art/source/passe_rive_s26/README.md) |
| Passe-Rive, garde S27 | Garde brève, Contre préparé et Garde de secours : 12 poses SE, 0,72 s, protection à 240 ms et bref arc de bronze confirmé. Échelle fixe et retour au repos ; autres angles en garde neutre. Secours sans copie consommée, riposte au coup reçu. [Sources et vérification de cinq lancers](../../art/source/passe_rive_s27/README.md) |
| `web/achilles-run-lab/` | Prototype autonome expérimental, isolé de l’import Godot |
| Passe-Rive, Prélèvement S28 | Carte `cc2_t07`, base/améliorée : saisir puis absorber, 0,94 s, résolution à 330 ms. Filament lié aux PV effectivement retirés, éclat discret uniquement si soin réel. Échelle constante, repos natif en sortie ; nouveau dessin SE, autres directions conservées. [Source, limites et validation](../../art/source/passe_rive_s28/README.md) |
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
