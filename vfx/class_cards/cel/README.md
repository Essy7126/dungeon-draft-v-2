# Animation cel — run Cartes

17 atlas de six poses (3 × 2, 1536 × 1024), soit 102 dessins. `recipes.gd`
définit la composition des 112 cartes actives : séquence, orientation,
distribution des frappes et intention. Les initiations sont incluses. Les sorts
adversaires utilisent les correspondances sémantiques du catalogue.

Les PNG ont été créés avec l’outil intégré **imagegen**, puis copiés sans retouche.
[provenance.json](art/provenance.json) conserve les prompts complets et les chemins
sources de chaque génération. Ce sont des dessins originaux, pas des assets
extraits de DOFUS, WAVEN ou WAKFU. Les observations précises utilisées sont dans
[l’étude des références](../../../docs/design/vfx_reference_studies_2026-09-22.md).

Le contact correspond au fait de combat déjà résolu. Les six poses utilisent
des temps inégaux : attaque rapide, forme principale tenue, séparation des
fragments, disparition. La durée et la largeur propres à chaque carte restent
dans les profils. Les ticks utilisent une taille réduite ; une absorption partielle maintient la pose intacte de l’écu. Les cartes fortes disposent de silhouettes plus grandes
(faux croisées, rempart, marteau, couronne de feu) ou de compositions plus denses.
Le son et la réaction de cible restent ceux du retour de combat existant,
déclenchés par ses dégâts/soins/absorptions réels.

`sheet.gdshader` lit les poses et distribue le dessin devant et derrière l’acteur.
L’alpha faible des franges est éliminé à l’affichage ; aucun bruit éthéré n’est
ajouté. Les vols suivent le délai réel. Les tirs instantanés produisent seulement
une courte ligne de vitesse après confirmation.

Les états utilisent une rangée de signes de 21 px au-dessus du personnage,
un par statut, même avec plusieurs sources. Au-delà de six états : cinq signes
et `+N`, avec les informations complètes toujours dans le HUD. Le compteur
graphique ne consomme pas de tour. Les expirations restent de taille compacte ; lors d’une purge simultanée, un seul signe sort, avec priorité à la stase et aux restrictions de mouvement. Les textes génériques d’application/expiration sont retirés seulement dans le combat Cartes lié. Les dégâts, soins, absorptions et immunités chiffrés gardent leurs retours habituels.
Une garde intacte utilise sa pose intacte jusqu’à sa consommation/expiration.
Les terrains suivent les quatre sommets réels des cellules ; faille, braises,
pointes et jardin gardent des marques de sol distinctes.

## Reproduire les contrôles

```powershell
node tools/class_card_vfx/audit_cel_assets.cjs
./dev.ps1 test cards
./tools/class_card_vfx/preview.ps1 -Capture
./tools/class_card_vfx/capture_combat.ps1 -Cel
node tools/class_card_vfx/encode.cjs
node tools/class_card_vfx/encode_semantics.cjs --cel
```

Sorties : `artifacts/dev/class_card_vfx/cel/`. Les captures ne sont pas retouchées.
La galerie couvre chaque carte et chaque sort ennemi ; le scénario en arène
filme seize sorts via le vrai SpellCaster, contrôle aussi l’impact et le tick réel de Brûlure, et examine huit
états simultanés. Le bilan utilise une victoire de fixture après ces lancers,
puis la vraie sauvegarde/reprise : cela ne constitue pas une victoire jouée.
Les tests techniques ne prouvent pas la satisfaction artistique.
