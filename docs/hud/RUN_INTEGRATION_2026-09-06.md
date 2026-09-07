# Catabase — intégration de la run, 6 septembre 2026

**État au 6 septembre, 08:46:51 UTC : raccordements implémentés, validation finale de l'état partagé bloquée.** Deux parcours natifs complets ont réussi avant les derniers travaux parallèles sur Paris. Le checkpoint constate encore l'absence de `assets/characters/paris/sprites_v1/paris_portrait.tres`, désormais référencé par la ressource ennemie. `data/characters/paris/animations.tres`, manquant dans les premiers journaux, est apparu entre-temps. Aucun substitut n'a été créé. Voir les [empreintes horodatées](../../artifacts/run_integration_20260906/verification_checkpoint.json).

## Périmètre et sources

Mission : raccorder le HUD remanié, Achille et son kit canonique, les cinq cartes enregistrées, le Mage philosophe, les récompenses et les sorties de run. Dépôt propre au départ de cette intervention, HEAD `745589d`. Les travaux de sélection « ashen » apparus en parallèle sont conservés et ne sont pas attribués à cette mission. Aucun commit, staging ou reset effectué.

Il s'agit du code et du rendu de **Dungeon Draft**. Aucun accès au compte, aux fichiers internes ou au gameplay de DOFUS n'est nécessaire à cette intégration. La référence DOFUS inspire la hiérarchie et la cohérence des interfaces, pas une copie d'assets ni des conclusions sur son implémentation.

## Raccordements effectués

| Source autoritaire | Consommateurs vérifiés | Changement de cette mission |
|---|---|---|
| Profil `data/runs/progression/odyssey/achilles_progression_profile.tres` | Sélection, Unit runtime, HUD, codex, galerie premium | Mappages explicites des quatre IDs canoniques ; fin du fallback silencieux vers l'ancien art |
| `CharacterHUDThemeData` raffiné | Slots en combat, bandeau de techniques et détail du codex | Même identité de texture ; fallback préservé pour un personnage sans thème |
| `data/units/enemies/philosopher_mage.tres` | Rencontre IV, fallback de salle, vue sprite, IA, sorts/VFX | Un Spectre remplacé par le Dialecticien, sans transformer ce dernier en héros jouable |
| Catalogue de classifications du Mage | Fusion Battle avec catalogue d'Achille | Axiome déclaré PROJECTILE dans Catabase ; classifications du héros conservées |
| `odyssey.tres` et ses cinq salles | Transitions, récompenses, résultat final, QA | Validateur historique débarrassé des hypothèses de trois rencontres et de l'ancien kit |
| Contexte de combat actif | HUD persistant, modales, raccourcis | Vérification de rebinding entre salles et nettoyage au retour au refuge |
| File de réactions de maîtrises | Codex et runtime champion | Relais de signal nommé à la place d'une lambda capturant son propriétaire RefCounted ; suppression d'une rétention mémoire démontrée |

Le kit joué est **Frappe du Péléide → Percée fulgurante → Tir du Pélion → Garde d'airain**. Les quatre alias historiques restent disponibles pour les anciennes fixtures. La nouvelle peinture d'arc identifie le Tir du Pélion ; elle ne remplace pas ses règles, coûts, animations ou VFX.

Les sprites, animations et VFX d'Achille et du Dialecticien ainsi que les cinq terrains existaient avant cette intervention : ils sont intégrés et retestés, pas revendiqués comme de nouvelles créations de cette mission.

### Rencontre IV : modification autorisée

L'utilisateur a explicitement confirmé « Oui, intégrer le Mage à Catabase ». La salle IV comporte désormais **Mage + Spectre + Skirmisher**, cap de trois ennemis. Le Mage reprend les bornes de placement de 12 à 17 cases de distance de chemin du Spectre remplacé. La base d'XP reste 160. Aucun changement de récompense, de progression, de géométrie ou de terrain.

La somme des PV ennemis passe de 173 à 185 : c'est la conséquence de remplacer un Spectre à 64 PV par le Mage à 76 PV, sans modifier leurs statistiques. L'ajout d'un soutien peut accroître davantage la difficulté que ces seuls 12 PV ; **l'équilibrage n'est pas certifié**.

Contrôle de conservation de `room_04.tres` : hors ajout de l'ext_resource du Mage et remplacement dans `enemies`, l'empreinte normalisée avant/après reste `7719E297240D3FFFBB436BC039D86AA7F2412C06B7E88EF1C3B293CE2387657A`. Les placements ont été testés sur 20 graines. L'Épreuve du Dialecticien dédiée reste distincte et inchangée.

## Preuves et protocole

Le [runner réutilisable](../../tools/run_integration_validation/README.md) démarre par la vraie sélection et l'intro, déploie normalement, utilise les boutons HUD et les points d'entrée publics de la grille. Il n'injecte ni PV/PA/PM supplémentaires, ni téléportation, ni appel direct à SpellCaster. Chaque lancement réussi exige un événement unique, son coût et un effet réellement résolu.

Après les actions réelles seulement, les victoires sont accélérées par `Battle._end_battle(true)` pour parcourir toutes les transitions. Les cinq victoires et l'éventuelle défaite accélérées sont nommées dans `forced_outcomes`. **Ce n'est ni une victoire organique, ni un test de souris physique/focus Windows.**

### Première validation native complète

- [Rapport 1200×896](../../artifacts/run_integration_20260906/e2e_1200/corrected/run_integration_report.json) : 317 assertions, zéro erreur de contrat ; dix lancements réellement résolus, quatre sorts distincts ; cinq salles puis nouveau départ et sortie après défaite.
- [Salle IV, repos après annonce de tour](../../artifacts/run_integration_20260906/e2e_1200/corrected/room_04_idle__20260906T083340__1200x896.png) : Achille, trois ennemis dont le Dialecticien, nouveau HUD et quatre icônes canoniques. L'annonce de tour est laissée se terminer naturellement.
- [Bilan victoire](../../artifacts/run_integration_20260906/e2e_1200/corrected/victory_result__20260906T083359__1200x896.png) et [bilan défaite](../../artifacts/run_integration_20260906/e2e_1200/corrected/loss_result__20260906T083407__1200x896.png).
- Les essais `e2e_1200/` et `e2e_1200/final/` conservent les diagnostics de la sonde QA (mauvaise classe attendue pour le Mage ennemi, référence d'écran libérée, typage de WeakRef). Ne pas les présenter comme les essais de livraison.

Cette première exécution complète n'a pas d'erreur de script pendant le parcours, mais signale à l'arrêt 2 790 ObjectDB / 390 ressources et des RIDs. Une réussite du JSON ne remplace pas la lecture de stderr. Les validations post-correctif sont consignées plus bas lorsqu'elles sont disponibles.

Le [second parcours, 1920×1080](../../artifacts/run_integration_20260906/e2e_1920/run_integration_report.json), réussit avec **314 assertions**, dix lancements et zéro erreur de contrat : [bilan victoire](../../artifacts/run_integration_20260906/e2e_1920/victory_result__20260906T083630__1920x1080.png). Même réserve de fermeture moteur. Les deux parcours utilisaient effectivement **Forward+ / D3D12, RTX 4070 Laptop** ; leurs graines étaient tirées aléatoirement par la configuration de production et sont consignées dans les JSON.

Ces deux preuves précèdent le correctif de mémoire et les nouvelles références Paris. Elles ne certifient donc pas l'ensemble du dépôt partagé actuel. Le runner a ensuite reçu une option de graine fixe sur copie mémoire (`--seed=2401`) et la collecte du renderer effectif ; son parsing a été vérifié, **pas encore son parcours final seedé**.

### Régressions fonctionnelles

| Groupe | Résultat exécuté | Preuve |
|---|---|---|
| Combat, progression cinq salles, sprites/VFX Achille et Mage, IA terrains | 99/99 tests ; 3 706 assertions | [Journal](../../artifacts/run_integration_20260906/test_logs/connected_combat_regressions.log) |
| États/matière HUD et identités d'icônes canoniques + historiques | 36/36 ; 687 assertions, sortie sans avertissement | [Journal](../../artifacts/run_integration_20260906/test_logs/hud_connected_regressions.log) |
| Mage IV, contenu vertical slice, terrains enregistrés, trial et classification Spectre | 23/23 ; 9 594 assertions | [Journal](../../artifacts/run_integration_20260906/test_logs/campaign_mage_gut_v2_stdout.log) |
| Codex et galerie canonique, première passe | 8/8 ; 85 assertions | [Journal](../../artifacts/run_integration_20260906/test_logs/codex_gallery_pass.log) |
| Attentes du validateur historique, kit et PM canoniques | 3/3 ; 20 assertions | [Journal](../../artifacts/run_integration_20260906/test_logs/odyssey_expectations_gut_v2_stdout.log) |
| Codex + maîtrises + nouvelle libération WeakRef, après correctif | **21/21 ; 367 assertions, aucune erreur ni fuite signalée** | [Journal définitif](../../artifacts/run_integration_20260906/test_logs/codex_mastery_lifecycle_clean.log) |

Les 99 tests incluent des fixtures de combat contrôlées ; notamment le smoke de maîtrises augmente les PV de sa fixture. Ils ne remplacent pas les actions sans boost du runner natif. Leur fermeture signale des ressources non libérées. La première passe codex/galerie signalait 26 ObjectDB / 6 ressources, isolées au codex, pas à la galerie.

Le correctif `MasteryReactiveRuntimeService` remplace seulement le relais lambda de `request_queued` par `_on_followup_request_queued`. Le nouvel objet reçu reste identique, le signal synchrone et unique, et `reset_run()` ne coupe pas le relais. Les WeakRef prouvent la libération du propriétaire et de sa file après abandon des références ; la sous-suite propre de 21 tests confirme la disparition de la fuite isolée. Cela ne démontre pas que toutes les fuites du lot combat ou du renderer sont résolues : leur revalidation reste à effectuer.

## Art et reproductibilité

L'[icône originale du Tir du Pélion](../../asset/ui/recraft_hud_v1/icons/achilles_painted_v2/ability_achilles_pelion_shot.png) est générée avec **image_gen intégré**. Maître 1254² intact ; import Godot 256² avec mipmaps, UID `dvtfl40x6n8r2` préservé, cache 129 194 octets. SHA-256 du maître : `A839E2400D6DAB6A6A5E0E27CA716819EBF1A67DF16D35654DBF5063EF3B2256`.

Le [prompt et la provenance](../../asset/ui/recraft_hud_v1/icons/achilles_painted_v2/PELION_SHOT_PROVENANCE.md) permettent de retrouver l'original et les contraintes artistiques. Aucun asset DOFUS en entrée. Import isolé, sans commande d'import global du dépôt.

La galerie premium utilise maintenant le loadout résolu par Catabase ; ses raisons d'indisponibilité restent **synthétiques et explicitement déclarées**. Les anciennes 44 captures de HUD_POLISH_V2 portaient sur le kit historique : elles prouvent les états des composants de cette livraison précédente, pas l'identité du kit joué aujourd'hui.

La dernière correction de galerie dérive aussi les PV max, PA, **3 PM**, l'identité, les scènes visuelles et `basic_attack_enabled=false` du héros résolu. Sa timeline consomme ce même UnitData. Les PV courants à 86/110 et la disponibilité restent des états d'art simulés. **Cette dernière extension de galerie n'a pas encore sa validation finale** : le préchargement Catabase est interrompu par les assets Paris en cours. Le [journal diagnostique](../../artifacts/run_integration_20260906/test_logs/codex_gallery_mastery_lifecycle_final.log) ne doit pas être lu comme un passage réussi de cette galerie, même si d'autres suites y passent.

## Reprise après stabilisation des deux tâches parallèles

Ne pas valider tant que les ressources Paris référencées et leurs dépendances ne sont pas présentes/importées. Ne pas rétablir l'ancien Paris par-dessus l'autre tâche pour contourner ce blocage.

1. Relancer GUT pour `test_hud_canonical_gallery`, `test_champion_codex`, `test_mastery_reactive_runtime_lifecycle`, puis les groupes contenu/combat du tableau.
2. Exécuter le runner avec `--seed=2401 --include-loss --resolution=1200x896` puis `1920x1080`, dans deux nouveaux dossiers. Exiger verdict JSON, code de sortie et absence d'erreur de script ; comptabiliser séparément les avertissements de fermeture.
3. Relancer `HudGrayboxCaptureRunner.tscn --premium-achilles --output-root=res://artifacts/run_integration_20260906/hud_canonical` avec un vrai renderer : **44 captures attendues, pas encore produites dans cette mission**.
4. Inspecter les captures natives du nouveau Paris, du codex et des états longs du kit canonique ; dater un nouveau checkpoint. Une modification concurrente postérieure nécessite une nouvelle validation ciblée.

Les commandes et limites détaillées se trouvent dans le [README du runner](../../tools/run_integration_validation/README.md). Aucun processus GPU de cette mission n'est laissé actif à la remise.

## Vérification manuelle conseillée

1. Lancer le projet normalement ; sélectionner Catabase et Achille, démarrer l'aventure.
2. Après déploiement : vérifier les quatre icônes, sélectionner puis annuler chaque technique ; ouvrir inventaire et codex, fermer et reprendre le combat.
3. Vérifier visuellement synchronisation départ/impact du Tir, arrivée de la Percée et durée de la Garde ; parcourir la récompense puis la salle suivante.
4. En IV : observer le Dialecticien soutenir ses alliés ; vérifier les conditions de tir autour des obstacles et ses coûts réels.
5. Terminer une run sans accélération QA pour juger difficulté, durée, lisibilité et rythme. Rejouer aussi après une défaite.

Restent hors certification : victoire normale et équilibrage statistique, performances mesurées sur plusieurs machines, toutes résolutions/localisations/échelles système, focus/saisie OS, reconnaissance des icônes chronométrée et accessibilité complète. Le résultat est une intégration testée, pas une promesse de run « parfaite ».
