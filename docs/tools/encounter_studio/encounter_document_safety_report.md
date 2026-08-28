# Sécurité documentaire et actions du Studio Rencontre

Date : 2026-08-28. **WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION**.

## Périmètre et préservation

**PROUVÉ** — Travail séquentiel, sans sous-agent. Aucun changement de donnée de
gameplay de production. Les écritures des régressions sont des fixtures sous
`user://dungeon_draft_studio/encounter_document_safety`, avec APPDATA isolé sous
`artifacts/encounter_document_safety/appdata`.

**PROUVÉ** — Les 19 fichiers préexistants hors de ce chantier ont les mêmes
SHA-256 avant/après. Preuve : `artifacts/encounter_document_safety/preservation.json`.
Les six fonctions de choix d'édition partagée de Claude restent textuellement
identiques : `_draft_local_usage_count`, `_shared_acknowledgement_key`,
`_ensure_editable`, `_confirm_shared_edit`, `_on_shared_custom_action` et
`_duplicate_encounter_for_usage`. L'autorité de brouillon reste celle de Terrain.

## Fichiers, dans l'ordre de première modification

**PROUVÉ** — Des retouches successives ont ensuite été effectuées, toujours un
fichier à la fois.

1. `addons/dungeon_draft_arena_studio/encounter/domain/encounter_edit_session.gd`
2. `addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd`
3. `addons/dungeon_draft_arena_studio/encounter/services/encounter_save_service.gd`
4. `addons/dungeon_draft_arena_studio/services/room_draft_save_service.gd`
5. `addons/dungeon_draft_arena_studio/ui/dungeon_draft_studio_main.gd`
6. `addons/dungeon_draft_arena_studio/context/studio_project_context.gd`
7. `test/unit/test_encounter_document_safety.gd` — nouveau.
8. Le présent rapport — nouveau.

## État modifié

**PROUVÉ** — `is_dirty()` compare le graphe éditable à l'empreinte de dernière
sauvegarde ou de dernier brouillon confirmé. Une empreinte d'ouverture distincte
est conservée. Le parcours ordonné couvre les propriétés stockées, les salles,
les vagues, les rencontres, leurs liens partagés et les destinations des nouvelles
Resources atteignables. Les numéros de parcours remplacent les identifiants
mémoire dans l'empreinte. Les assets externes non édités sont des références par chemin.

**PROUVÉ** — Le mode brouillon ne mesure que la moitié Rencontre de l'autorité
Terrain. Le porteur RunData et les informations de contexte sont exclus. La
sélection, l'onglet, le mode guidé et la seed d'aperçu ne modifient pas le document.
Annuler jusqu'au point enregistré rend propre ; Rétablir rétablit l'état modifié.
Les destinations des ressources retirées restent disponibles pour Rétablir,
mais les ressources inaccessibles ne sont ni fingerprintées ni publiées.

**PROUVÉ** — Le plan de publication vient du contenu, et non de `dirty_resources`.
Un brouillon confirmé peut donc être propre tout en restant à publier : l'action
« Publier les rencontres » conserve cette possibilité.

## Transitions

**PROUVÉ** — Ouverture, sélection de salle, barre de contexte, navigation par
snapshot, récupération et changement d'autorité passent par le contexte partagé.
Il consulte l'état réel au moment de la demande, même avant un rafraîchissement UI différé.

| Décision | Contrat vérifié |
|---|---|
| SAVE | Transaction canonique en mode canonique ; enregistrement local via RoomDraftSaveService en mode brouillon. La sélection n'est appliquée qu'après réussite. |
| DRAFT | Écriture, relecture et vérification du brouillon ; capture du point propre ; application de la navigation en attente. Aucun fichier canonique publié. |
| DISCARD | Recharge la source canonique, ou restaure le dernier point confirmé de la moitié Rencontre du brouillon de salle. |
| CANCEL | Session, sélection visible, état de contexte et historique inchangés. |

**PROUVÉ** — Un handler manquant ou retournant un échec bloque la transition.
L'échec ultérieur d'un autre domaine restaure aussi les objets et l'historique
Rencontre ; après un SAVE déjà exécuté, son journal restaure les fichiers publiés.
La synchronisation n'émet pas de nouvelle demande de sélection depuis les signaux
de sélection. L'ouverture différée d'un brouillon termine également la navigation
vers l'onglet Rencontres.

## Brouillons récupérables

**PROUVÉ** — Le brouillon canonique utilise le format de récupération existant
`recovery/save_<horodatage>/working_run.tres` accompagné de `session.json`.
Seule une récupération confirmée après relecture est proposée comme dernière
récupération. Le manifeste transporte les sources par usage : réordonner les
salles et les vagues ne réattribue pas leurs rencontres aux mauvais fichiers.
Les horodatages relus depuis JSON sont normalisés en entiers, sans ignorer les
empreintes de conflit.

**PROUVÉ** — RoomDraftSaveService reste l'autorité d'enregistrement du brouillon
complet. Des identifiants de parcours préservent ses rencontres partagées après
relecture. La vérification porte sur le terrain et le graphe Rencontre. La
publication de salle complète n'est pas modifiée par ce chantier.

## Transaction et rollback

**PROUVÉ** — La publication utilise une copie séparée, avec écriture des enfants
avant les parents. Le plan vérifie les chemins et collisions. Chaque cible possède
un état initial `{exists, md5}` et un backup identifié par le SHA-256 de son chemin
complet. Le journal ordonné inscrit la cible avant l'appel d'écriture, couvrant
également une écriture partielle en échec.

**PROUVÉ** — Sur échec, le journal est parcouru en sens inverse : restauration des
octets des fichiers préexistants et suppression des seules cibles créées par la
transaction. Après restauration de tous les octets, relecture IGNORE_DEEP et
comparaison des empreintes initiales. Le rapport détaille chaque chemin,
opération, backup, code d'erreur, empreinte attendue/obtenue et résultat de relecture.
Un backup manquant est un échec explicite et ne provoque pas la suppression de la cible.

**PROUVÉ** — La réussite exige une relecture sans cache, la vérification du contenu
et des références externes, puis une réouverture propre de la working copy. Un
échec de réouverture déclenche le même rollback. La session ouverte n'est pas
modifiée pendant les écritures ; elle conserve son contenu et son état modifié
sur échec. Chemins de publication limités à `res://` / `user://`, `.tres` / `.res`,
sans remontée `..`, chemin absolu ou sous-ressource utilisée comme cible de fichier.

## Actions et disposition

**PROUVÉ** — Libellés de la barre commune, conservés également au format compact :

| Autorité / opération | Libellé |
|---|---|
| Brouillon de salle | Enregistrer le brouillon |
| Rencontre canonique | Publier les rencontres |
| Aperçu runtime | Tester |
| Publication complète du brouillon de salle | Intégrer à la partie |

**PROUVÉ** — Le tooltip canonique annonce une publication, jamais l'absence
d'écriture dans la partie. La barre locale conserve Ouvrir une partie, Générer
un placement et Rapport ; les doublons sauvegarde, Annuler, Rétablir, validation
et test sont supprimés. La barre commune peut revenir à la ligne.

## Contrôles exécutés

**PROUVÉ** — Godot 4.7 stable, GUT 9.7.1. Dernière passe : **20/20 tests,
721 assertions**, 66,539 s. Journal :
`artifacts/encounter_document_safety/verified_final.log`.

```text
Godot_v4.7-stable_win64_console.exe --path . --rendering-method gl_compatibility
  --resolution 1280x720 --script addons/gut/gut_cmdln.gd -gconfig=
  -gtest=res://test/unit/test_encounter_document_safety.gd -gexit
```

**PROUVÉ** — Couverture : empreintes et historique ; huit transitions
ouverture/salle × quatre décisions ; barre de contexte ; sélection visible de
l'arbre ; navigation différée ; handlers absents/en échec ; brouillons réussis
et en échec ; réordonnancement puis récupération/publication ; conservation du
partage ; rollback après deux fichiers homonymes, création et modifications ;
échec de réouverture ; backup manquant ; conflits de destination et chemins
interdits ; libellés et opérations de sauvegarde ; bornes des actions aux deux tailles.

**PROUVÉ** — Quatre captures du vrai StudioWorkspace inspectées dans
`artifacts/encounter_document_safety/` : `canonical_1280x720.png`,
`canonical_1920x1080.png`, `room_draft_1280x720.png`, `room_draft_1920x1080.png`.
Les barres et leurs actions sont dans les limites de l'écran. `git diff --check`
ne signale aucune erreur de whitespace.

## Limites ouvertes

- **PROUVÉ** — L'inspecteur Composition reste tronqué à 1280 px. Les captures
  brouillon montrent en outre un assombrissement hors de cette colonne ; la
  validation visuelle complète n'est pas revendiquée. **À CONFIRMER** — origine
  de cet assombrissement dans le runner.
- **PROUVÉ** — Le runner signale 14 orphelins ainsi que des Resources/RID non
  libérés à la fermeture. **À CONFIRMER** — attribution de ces diagnostics ;
  aucune baseline globale n'a été relancée pour les qualifier.
- **PROUVÉ** — Le rollback garantit les octets, l'existence et la relecture ; il
  ne restaure pas les métadonnées NTFS telles que le mtime. Les empreintes de
  conflit peuvent donc demander une réouverture après un rollback tardif.
- **PROUVÉ** — Pas de test manuel dans l'éditeur avec EditorUndoRedoManager,
  ni lancement d'un vrai combat, ni publication d'une salle de production.
- **PROUVÉ** — Aucune suite complète de brouillon de salle, publication de salle,
  baseline globale ou `test_encounter_studio_v1.gd` n'a été relancée. Les trois
  échecs historiques de cette dernière suite n'ont pas été corrigés ni requalifiés.
- **PROUVÉ** — Aucun commit, aucune promotion CURRENT et aucune affirmation de
  disponibilité en production.
