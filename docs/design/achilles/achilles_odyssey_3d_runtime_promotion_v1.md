# Achille — correction du binding runtime 3D dans L’Odyssée V1

## Correction de preuve

```text
previous_report_claimed_3d_runtime = true
owner_observed_legacy_2d_runtime = true
claim_was_contradicted = true
binding_reverified_after_fix = true
```

Le verdict historique `ACHILLES_3D_ODYSSEY_RUNTIME_PROMOTION_READY_FOR_INTEGRATION_REVIEW`
était un faux positif. Le propriétaire lançait le checkout principal `main` au
HEAD `a54bc6d4c53741bc487807ff79ef292fe0b3c5ec`; sa façade
`AchillesIsoUnitView.tscn` liait encore directement `AchillesVisual2D`.
L’ancienne preuve exécutait un autre worktree et ne liait pas le `--path`, le
HEAD et le processus réellement joué.

Classification : `WRONG_WORKTREE_OR_PROJECT_LAUNCHED`.

## Binding candidat corrigé

- Décision conservée : **B, SubViewport 384 × 384**.
- Branche locale : `fix/achilles-odyssey-runtime-3d-binding-v1`.
- Base du correctif : `7bc3d69c0f434e8038bbb199300a96baae8443a4`.
- Commit runtime : `59464dbc200c2168e2757c76c414b6149abebee4`.
- Commit de preuve : `d632004f28a060dccec613fd58247564fea84423`.
- Commit d’intégration publié sur `origin/main` :
  `e0b42eb75f2de46d3daa08b8ac30ae1cc354d3da`.
- Le profil demande explicitement `VIEWPORT_3D` et charge le GLB canonique
  `res://assets/characters/Achilles/3d/achilles_rig_v1.glb`.
- Le fallback `LEGACY_2D_ON_VERIFIED_ERROR` est créé paresseusement seulement
  après une erreur 3D vérifiée et produit un diagnostic structuré.
- En fonctionnement nominal, le corps 2D n’est ni instancié, ni visible, ni en
  traitement. Il n’émet donc aucun signal concurrent.
- Le portrait 2D HUD, timeline et post-combat reste volontairement une icône
  d’interface ; ce n’est pas le corps affiché sur la grille.
- Aucun gameplay, sort, statistique, arme ou build theorycraft n’est modifié.

## Validation bornée à la salle II

La vraie `res://data/runs/odyssey.tres`, son héros Achille et la vraie salle II
ont été rejoués dans le worktree candidat avec Godot 4.7.1, Windows/Forward+.
La preuve contrôle le chemin projet et le HEAD dérivés par Git, puis observe :

- backend demandé et actif : `VIEWPORT_3D` ;
- un `SubViewport`, une caméra courante, un squelette de 52 os et un mesh
  visible ;
- instance issue exactement du GLB canonique ;
- `ViewportTexture` visible avec fond transparent et ancre pied alignée ;
- zéro `AnimatedSprite2D`, zéro nœud d’équipement et zéro fallback nominal ;
- façade gameplay visible et opaque.

Les 34 tests obligatoires du correctif passent, ainsi que les 35 tests de
non-régression adaptés. Le rapport final du paquet enregistre le HEAD exact de
la dernière exécution, les commandes, l’arbre runtime, les hashes et les
captures avant/après.

## Verdicts et limites

- `ACHILLES_3D_ROOM_II_RUNTIME_READY_FOR_OWNER_REVIEW`
- `LEGACY_2D_BODY_NOT_VISIBLE`
- `FALLBACK_NOT_ACTIVE`
- `PUBLISHED_ON_ORIGIN_MAIN`
- `OWNER_REVIEW_REQUIRED`
- `NOT_PRODUCTION`

Les salles I et III, les transitions et l’écran de résultat n’ont pas été
réexécutés. Ils restent en pause jusqu’à la confirmation exacte du propriétaire :

```text
CONTINUE ACHILLES 3D BINDING FIX
ROOM_II_3D_CONFIRMED
```

Le root motion source reste non classifié, les temps GPU ne sont pas mesurés et
Godot signale encore des diagnostics de ressources au teardown. Ces limites ne
sont pas présentées comme une validation trois salles.
