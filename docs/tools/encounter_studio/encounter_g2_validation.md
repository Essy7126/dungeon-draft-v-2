# G2 — Disposition responsive du Studio Rencontre

28 août 2026 — **WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION**.

## Prérequis et périmètre

**PROUVÉ** — G1 a été vérifié avant modification : aucun état/mode Guidé ou
Avancé dans EncounterStudioMain, interrupteur global masqué dans Rencontre,
analyses 10/100/1 000 disponibles, onglet Détails techniques présent, résumés
principaux sans JSON brut. La suite G1 initiale passe : 7 tests, 362 assertions.

**PROUVÉ** — Un seul fichier de production reçoit des changements G2 :
`addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd`.
Travail séquentiel, un fichier à la fois, sans sous-agent. Le runner G2 et sa
scène sont nouveaux ; les runners de baseline et de G1 sont conservés.

## Disposition

**PROUVÉ** — L'ordre est : barre documentaire, bannière du brouillon si
nécessaire, chronologie horizontale et actions, trois colonnes, validation,
puis bilan et commande permanente de repli.

- **PROUVÉ** — `Partie et salles` replie la colonne gauche et rend sa largeur au terrain.
- **PROUVÉ** — Le terrain reçoit l'espace supplémentaire ; les côtés gardent leurs largeurs préférées, bornées à la taille disponible.
- **PROUVÉ** — La chronologie défile horizontalement sans élargir le workspace. Son dernier affrontement est entièrement accessible après défilement.
- **PROUVÉ** — Les cinq onglets de propriétés sont représentés par des boutons exclusifs dans un HFlowContainer. Ils restent tous visibles, sur plusieurs lignes si nécessaire ; le TabContainer conserve les pages, leurs indices et leurs callbacks.
- **PROUVÉ** — Composition et Placement défilent verticalement avec suivi du focus ; Progression, Analyse et Détails techniques conservent leurs textes défilables. Les libellés longs reviennent à la ligne sans repousser les champs numériques.
- **PROUVÉ** — `Validation` ouvre/replie le panneau inférieur, fermé initialement. Son bilan reste visible. La hauteur ouverte est bornée pour préserver le terrain ; la liste conserve ses interactions et son diagnostic technique G1.

**PROUVÉ** — Tailles du terrain mesurées dans le vrai workspace :

| Disposition | 1280 × 720 | 1920 × 1080 |
|---|---:|---:|
| Colonnes ouvertes, validation fermée | 676 × 383 | 1316 × 743 |
| Colonne gauche repliée | 908 × 383 | 1548 × 743 |
| Colonnes et validation ouvertes | 676 × 226 | 1316 × 586 |

**PROUVÉ** — Les séparateurs utilisent `split_offsets` de Godot 4.7. Les
offsets se rapportent ici au début/à la fin du conteneur, selon les flags
d'expansion, et non à la taille minimale des panneaux. Ce comportement est
vérifié par déplacement réel à la souris et restauration de largeur exacte.
Voir aussi la [référence Godot SplitContainer](https://docs.godotengine.org/en/stable/classes/class_splitcontainer.html#class-splitcontainer-property-split-offsets).

## Mémorisation et invariants

**PROUVÉ** — `get_state_snapshot().layout` transporte les ouvertures des
panneaux gauche/inférieur et les trois dimensions préférées. Le service
`StudioUiStateService` et le snapshot du workspace existants assurent leur
persistance ; aucun nouveau fichier de préférences métier n'est introduit.
Un redimensionnement borne l'affichage sans écraser la préférence mémorisée.
La restauration de disposition fonctionne aussi pour un snapshot de brouillon,
avant le retour anticipé qui empêche de rouvrir son document depuis un chemin.

**PROUVÉ** — Le runner vérifie la stabilité du fingerprint, du dirty, de
l'historique et des sélections pendant ces opérations. L'instance de workspace,
la session, le contexte et l'autorité du brouillon Terrain sont conservés lors
des navigations et du détachement/rattachement. Un seul scan, génération 1,
aucune invalidation sans publication.

**PROUVÉ** — 118 fonctions existantes de EncounterStudioMain restent identiques
textuellement, dont les calculs, le placement, la validation, les transactions,
le cycle de vie, les confirmations de partage, la sauvegarde et la publication.
Les modifications dans Composition/Placement concernent uniquement le retour
à la ligne. Les autorités RunData/RoomData/EncounterDefinition, les working
copies et les services métier ne sont pas modifiés.

## Vérification

**PROUVÉ** — Les six suites ciblées passent : **67 tests, 2 543 assertions** :
G1, Encounter Studio v1, sécurité documentaire, graphe partagé, Studio v1.2.1,
aperçu runtime/test direct. Les scénarios incluent les décisions documentaires,
transactions/rollback, références partagées, historique et cycle de vie.
[Journal GUT](../../../artifacts/encounter_g2/gut_regression.log).

**PROUVÉ** — Après le dernier ajustement de largeur du titre, G1 est relancé :
**7/7 tests, 362 assertions**, sortie 0.
[Journal G1 final](../../../artifacts/encounter_g2/g1_final.log).

**PROUVÉ** — Les smokes graphiques vérifient les deux résolutions, le repli,
les séparateurs déplacés à la souris, le dernier affrontement, tous les champs
numériques atteints par défilement, tous les onglets, les analyses, la
persistance sur disque, le redimensionnement, le brouillon avec validation
ouverte et la création du premier affrontement.

**PROUVÉ** — Les deux passes finales passent chacune **807/807 contrôles**,
code de sortie 0, et produisent **32 captures** au total. Les vues canonique,
validation ouverte, brouillon, analyse et état vide ont été inspectées
visuellement. Le titre de l'état modifié est entièrement visible dans la
capture finale à 1280 × 720.
[Smoke 1280](../../../artifacts/encounter_g2/smoke_1280x720.json),
[smoke 1920](../../../artifacts/encounter_g2/smoke_1920x1080.json),
[codes de sortie](../../../artifacts/encounter_g2/capture_exit_codes.json).

**PROUVÉ** — L'import global Godot termine avec code 0, sans erreur de parsing,
compilation ou script. Il génère le `.gd.uid` du runner. Le journal contient
une erreur de lecture du magasin de certificats système et des diagnostics
de fuite à la fermeture ; ce n'est pas une exécution sans avertissement.
[Journal d'import](../../../artifacts/encounter_g2/import.log).

**PROUVÉ** — Les vérifications de débordement distinguent un contenu
volontairement défilable de son viewport : les contrôles ordinaires doivent
tenir dans la fenêtre ; les champs numériques sont amenés dans leur viewport
et leur rectangle complet est alors vérifié. Une carte de chronologie
partiellement visible à la limite de défilement n'est pas un débordement du
workspace.

## Captures

**PROUVÉ** — Captures réelles OpenGL Compatibility, issues de la scène
`encounter_workspace_g2.tscn`, sans maquette ni éditeur concurrent.

| Vue | 1280 × 720 | 1920 × 1080 |
|---|---|---|
| Rencontre canonique | [Capture](../../../artifacts/encounter_g2/canonical_1280x720.png) | [Capture](../../../artifacts/encounter_g2/canonical_1920x1080.png) |
| Tous les panneaux | [Capture](../../../artifacts/encounter_g2/all_panels_1280x720.png) | [Capture](../../../artifacts/encounter_g2/all_panels_1920x1080.png) |
| Brouillon, validation ouverte | [Capture](../../../artifacts/encounter_g2/room_draft_validation_1280x720.png) | [Capture](../../../artifacts/encounter_g2/room_draft_validation_1920x1080.png) |
| Analyse | [Capture](../../../artifacts/encounter_g2/analysis_results_1280x720.png) | [Capture](../../../artifacts/encounter_g2/analysis_results_1920x1080.png) |
| Premier affrontement | [Capture](../../../artifacts/encounter_g2/no_first_encounter_1280x720.png) | [Capture](../../../artifacts/encounter_g2/no_first_encounter_1920x1080.png) |

## Préservation et limites

**PROUVÉ** — Le manifeste initial G2 contrôle 3 944 fichiers hors du fichier
d'interface modifié ; aucun écart. La comparaison supplémentaire à la référence
G1 couvre les 383 fichiers de data/ et les artefacts du graphe partagé.
Le test existant du graphe réécrit son fichier `test_metrics.json` ; sa sortie
G2 est conservée séparément et l'ancien contenu a été restauré avec concordance
exacte du SHA-256 G1. Les 383 fichiers de data/ sont inchangés.
Le contrôle final confirme zéro écart sur les 3 944 fichiers de référence G2
et les 1 387 fichiers protégés de la référence G1.
[Préservation finale](../../../artifacts/encounter_g2/preservation_final.json),
[fonctions préservées](../../../artifacts/encounter_g2/function_preservation.json).
`git diff --check` ne signale aucune erreur.

**PROUVÉ** — Les premiers essais graphiques ont révélé un titre comprimé dans
un HFlowContainer et des offsets mal interprétés ; ces défauts ont été corrigés.
Un tooltip déclenché par la position réelle du pointeur a été compté comme
fenêtre résiduelle ; le runner place maintenant le pointeur sur une zone sans
tooltip avant ses contrôles, sans masquer les vraies modales.

**PROUVÉ** — Des avertissements de fuite à la fermeture restent présents.
La baseline G1 et la première passe G1 après refonte comptent chacune 210
orphelins ; les suites cumulées et les smokes ont des scénarios différents.
Le cumul GUT compte 392 orphelins et signale 7 555 ObjectDB / 777 Resources à
la fermeture ; chaque smoke final signale 876 ObjectDB / 68 Resources.
**À CONFIRMER** — L'attribution complète des fuites. La suite globale n'a pas
été exécutée : aucune revendication de zéro régression globale.

**PROUVÉ** — Le catalogue ennemi, les cartes de diagnostics, le langage graphique
du terrain, les couleurs finales, les icônes et les animations ne sont pas
refondus. Les ellipses internes à l'arbre/catalogue existants restent hors de
cette refonte ; leurs panneaux ne débordent plus de la fenêtre. Aucun commit,
publication ou promotion CURRENT n'est effectué.

## Reproduction

**PROUVÉ** — Godot 4.7 stable ; APPDATA et LOCALAPPDATA isolés sous
`artifacts/encounter_g2/` pour les exécutions de validation.

```text
--path . --rendering-method gl_compatibility
  res://addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g2.tscn
  -- --width=1280 --height=720
```

**PROUVÉ** — Même scène avec `--width=1920 --height=1080` pour la grande fenêtre.
