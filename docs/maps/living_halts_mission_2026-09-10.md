# Mission — haltes peintes interactives

Livraison du 10 septembre 2026, sur la base Git `2473c335`.
L’implémentation et ses validations ciblées sont terminées. La validation globale
du dépôt reste non concluante ; ses limites sont détaillées ci-dessous.

Le [correctif d’échelle humaine](halt_scale_review_2026-09-10.md) complète cette livraison : gabarit de la Forge, repère Achille dans Studio et grille de proportions avant génération. Il distingue la calibration corrigée des proportions de mobilier encore à revoir dans l’illustration.

## Livré

- **Dungeon Draft Studio → Haltes peintes** : cinquième mode, plan avant
  illustration, calques, sommets, ancres, annulation/rétablissement, sauvegarde,
  récupération locale, export SVG et essai de la copie non enregistrée.
- **Sanctuaire des Sources Émeraude** enrichi : courants par bassin, découpes de
  profondeur, audio localisé, approche des lieux puis interactions.
- **Forge des Racines** : illustration originale issue d’un plan spatial,
  même référence artistique, calibration propre, boucle autour de l’enclume,
  torches, son et trois découpes de profondeur ; aucune eau artificielle.
- **Catabase** : affectation des haltes ordinaires sanctuaire et marchand de
  l’étape VIII via `data/halts/route_bindings.json`. Identifiants de route,
  progression obligatoire, transactions, reçus et sauvegardes restent ceux
  du jeu. La preview possède une visite isolée.
- **Préparation native et CLI** : validation commune des champs, originaux
  immuables par version, détection des modifications externes, restauration
  des fichiers en cas d’échec, empreintes LF/CRLF/BOM et matières facultatives.
- Les six suites GUT des haltes sont incluses dans les contrats Studio de la CI.
  Les 17 tests Python sont ajoutés au workflow de développement existant.

Scènes d’entrée :
`addons/dungeon_draft_arena_studio/halts/HalteStudio.tscn`,
`hub/painted_halt/LivingHalt.tscn` (essai),
`hub/painted_halt/ExpeditionHalt.tscn` (session de production).
Les guides sont dans [l’éditeur](../../addons/dungeon_draft_arena_studio/halts/README.md)
et [l’atelier](../../tools/halt_workshop/README.md).

## Contrats conservés

Les coordonnées sont normalisées et la navigation reste explicitement calibrée.
L’image maîtresse commune est la Halle ; le plan, le prompt, les références et
la provenance de la forge sont conservés dans `art/source/halts/bronze_forge_v1/`.
Les deux originaux font réellement **1 672 × 941 pixels**. Le zoom ne crée pas
une source haute définition ; ce mode reste une scène peinte en 2D, sans PNJ
animés ni navigation à plusieurs étages.

`materials.png` encode eau/cascades/feuillage/reflets dans RGBA. `flow.png`
encode direction dans RG, vitesse/4 dans B et couverture dans A. Le manifeste
emploie `lf_utf8_v1` ; les images conservent leurs empreintes binaires exactes.
La préparation native et Pillow partagent le sens des canaux, avec un
adoucissement propre à chaque générateur, identifié dans `build.json`.

L’audio original est reproductible avec `synthesize_ambience.py`, importé en
PCM 16 bits, positionné autour d’Achille et arrêté en pause. Le contrôle de
fermeture exige la disparition des WAV privés et playbacks par `WeakRef`.
Les validations audio portent sur les données et le comportement du moteur ;
elles ne constituent pas une écoute artistique sur les haut-parleurs du joueur.

## Vérifications finales

Tous les dossiers ci-dessous sont sous `artifacts/dev/`.

| Contrôle | Résultat | Rapport |
| --- | --- | --- |
| Haltes GUT : service, édition, preview, runtime, Catabase, audio | **36 tests, 341 assertions, PASS**, aucune erreur | `20260910-142446-test-halts-64fd92f7/gut-strict-report.json` |
| Préparation Python | **17 tests PASS** | `20260910-135202-halt-test-7c1bd25c/prepare.stderr.log` |
| Sanctuaire, rendu 720p et 1080p | **271 contrôles, 28 captures, 5 594 positions, 0 dangereuse**, aucune erreur ni fuite | `20260910-142651-halt-verify-17cebbeb/summary.json` |
| Forge, rendu 720p et 1080p | **283 contrôles, 42 captures, 5 836 positions, 0 dangereuse**, aucune erreur ni fuite | `20260910-142839-halt-verify-59a2ae53/summary.json` |
| Vrai GameManager / production Forge | **46 contrôles, 8 captures, PASS**, HUD 720p/1080p, reçu sauvegardé, inventaire, parchemin et départ sans transition doublée | `20260910-143012-halt-production-merchant-297ca532/summary.json` |
| Éditeurs Sanctuaire et Forge | **4 captures réelles à 1600 × 1000**, inspectées ; image et shader visibles, 527 échantillons comparés à chaque original | `20260910-134650-halt-editor-final-capture/` |
| Format des scripts de la mission | **24 scripts PASS**, contrôle de structure | `20260910-143100-halt-delivery-review-50729c90/formatter-summary.json` |
| Consommateurs Studio existants | **39/41** ; VFX 23/23, Encounter 16/18 | `20260910-143122-halt-studio-consumers-e6c373bb/gut-strict-report.json` |
| Suite globale du dépôt | **Non concluante : délai de 900 s dépassé**, rapport JUnit final absent, erreurs déjà observées | `20260910-135623-test-all-dbd4aee6/gut-strict-report.json` |

Les images de jeu et d’éditeur ont été inspectées, dont le HUD réel à 720p.
Les tests passent de vrais clics dans l’éditeur et l’aperçu redimensionné,
contrôlent l’approche avant ouverture du panneau, l’annulation, la pause,
les achats uniques, les échecs de sauvegarde et leur reprise. Les captures
contrôlent aussi le passage devant et derrière les premiers plans.

## Limites de la validation du dépôt

Les deux tests Encounter restants sont :
`test_sauvegarde_enfants_parents_rechargement_recuperation_et_chemins_surs`
et `test_external_room_and_encounter_changes_survive_final_reopen`.
Ils échouent sur `recovery_verification_failed` après écriture et relecture
avec un **nouveau userdata isolé**. Les services Save et EditSession concernés
sont identiques à HEAD. Le défaut Haltes de restauration du canevas vide,
trouvé par cette même suite, est corrigé et couvert par une régression réussie.
Les deux erreurs Encounter ne sont pas masquées ni ajoutées à une allowlist.

La suite globale observe notamment des anciens tests exigeant un backend 3D
alors que la scène à HEAD déclare déjà `SPRITE_2D`, ainsi qu’un test appelant
`uses_compact_title()`, méthode déjà absente du shell à HEAD. Ces contradictions
ne permettent pas d’affirmer que tous les échecs d’exécution étaient préexistants :
aucune exécution complète séparée de HEAD n’a été réalisée. La CI globale ne
peut donc pas être déclarée verte. Les comparaisons de sources sont conservées
sous `20260910-143100-halt-delivery-review-50729c90/unchanged_dependency_evidence.json`.

La suite globale a réécrit deux artefacts d’arène versionnés, intacts avant son
lancement. Ils ont été restaurés aux octets d’origine ; les sorties produites
restent dans son rapport `tracked_fixture_outputs/`. Les autres modifications
en cours du workspace, notamment Spine et interface d’inventaire, sont conservées.

## Reproduire

```powershell
./dev.ps1 test halts
./tools/halt_workshop/halt.ps1 test
./tools/halt_workshop/halt.ps1 verify
./tools/halt_workshop/halt.ps1 verify -Map res://data/halts/bronze_forge_v1.json
./tools/halt_workshop/verify_production.ps1 -Kind merchant
```

Dans Godot, ouvrir **Dungeon Draft Studio → Haltes peintes → Explorer**,
ou lancer `HalteStudio.tscn` avec **F6**. Les essais et vérifications de production
emploient leurs propres données ; la partie personnelle n’est pas utilisée.
