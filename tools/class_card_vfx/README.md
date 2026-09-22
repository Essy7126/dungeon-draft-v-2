# VFX cel — run Cartes

La production du 22 septembre remplace la DA éthérée par des poses dessinées.
112 cartes, 17 séquences de six poses, compositions spécifiques aux cartes fortes.
[Sources, prompts, règles et contrôles](../../vfx/class_cards/cel/README.md).

Les dossiers `ethereal/`, `power/`, `extension/`, `semantics/` et `persistence/`
conservent les preuves des passes antérieures. Les nouveaux rendus sont dans
`artifacts/dev/class_card_vfx/cel/`.

## Intégration et périmètre

- `class_card_vfx_catalog.gd` : recettes issues du catalogue vivant et correspondances explicites des sorts ennemis. Un nouveau sort inconnu fait échouer la couverture des tests.
- `class_card_vfx_player.gd` : six poses dessinées, couches arrière/avant et rangée compacte de signes persistants.
- `class_card_vfx_flight.gd` : trait dessiné calé sur le délai de vol existant ; liaison brève pour les tirs instantanés confirmés.
- `class_card_vfx_router.gd` : applications, annonces de sorts différés, invocations, arrivée des déplacements, 23 identifiants de statut, ticks, soins, absorption/rupture de bouclier, critique, esquive et immunité. Les autres états d’équipement sont associés selon leurs propriétés : soin, dégâts périodiques, entrave, baisse de PA, bonus ou malus.
- `class_card_vfx_ground.gd` : marques dessinées projetées sur les quatre coins réels de chaque surface dynamique ; maintien et dissolution à la disparition du terrain.
- `core/vfx_manager.gd` : active ce routeur uniquement si une unité de la vue de combat liée appartient à une session possédant `cards`. Le lanceur et les cibles doivent appartenir au combat lié. Un identifiant de carte seul ne suffit pas à activer cette DA en run classique.

Aucun coût, dégât, statut, portée, RNG ou délai de combat n’est modifié. Un tir en vol ne fabrique pas d’impact. Les annonces interrompues sont retirées ; les coups différés ne confirment l’impact que pendant leur résolution réelle, y compris lorsqu’un bouclier absorbe les dégâts. Les impacts restent sur la case d’avant poussée. Les états expirent lorsque leur dernière source disparaît ; un retrait forcé retire immédiatement le maintien. Les états et boucliers déjà actifs sont restaurés sans rejouer leur application, y compris après une création tardive ou un remplacement de vue. La fermeture du combat arrête cette restauration et nettoie les effets.

Les surfaces persistantes conservent le socle dessiné par `DynamicSurfaceVisualAdapter`. Le routeur y ajoute une couche cel animée, leur application, réaction, pulse de dégâts et disparition. Les braises, le givre et les résidus suivent la durée restante réelle du terrain. Le contrat de dégâts de terrain n’expose pas le sort source : son pulse exige donc un dégât élémentaire positif sans source, sur une surface encore active et enregistrée par le routeur. Cette limite ne change pas les règles du terrain.

## Vérification

```powershell
./dev.ps1 test cards
./tools/class_card_vfx/preview.ps1 -Capture
./tools/class_card_vfx/capture_combat.ps1 -Cel
node tools/class_card_vfx/encode.cjs
node tools/class_card_vfx/encode_semantics.cjs --cel
```

Le test lance réellement les 112 cartes et les 48 sorts adverses via SpellCaster.
Il contrôle les refus, impacts absorbés, annonces annulées, vols, terrains,
nettoyage et isolation de la run Classique. La suite cel ajoute le contrôle des
112 compositions, des atlas à six poses et du débordement des états.

Les résultats de cette passe sont consignés dans
[le suivi cel](../../docs/ai/CARDS_CEL_PRODUCTION_2026-09-22.md).
La galerie écrit aussi les contrats des 112 cartes depuis les règles chargées.
Les manifests conservent l’empreinte des PNG, scripts, shaders et profils ;
une source modifiée invalide la capture. Les GIF conservent les pixels natifs,
avec seulement la quantification de palette.

Le scénario cel produit 16 séquences de lancers réels, 960 images et un contrôle supplémentaire de Brûlure et des vues à caméra normale.
Il contrôle les fins d’état et de terrain, puis un cumul de huit états. Après
les lancers, une victoire de fixture ouvre le vrai bilan ; la sauvegarde/reprise
passe par les services et scènes de production. Ce n’est pas une victoire jouée
ni une mesure GPU en combat chargé. Une couverture technique complète ne vaut
pas approbation artistique individuelle.
