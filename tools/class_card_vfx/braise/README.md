# Braise tenace — planche E intégrée

Carte `cc2_t02`, normale et améliorée, run Cartes consommable actuelle.
Intention : `docs/design/vfx_avant_production_lot2_2026-09-27/e_braise_tenace.png`.

Un charbon facetté se comprime puis atteint le torse de la cible. Son cœur
crème s'ouvre en quatre flammes vermillon inégales, avec fragments de charbon.
L'anticipation et le trajet durent 0,30 s ; le contact attend la confirmation
réelle. L'impact dure 0,40 s. Un cast direct sans préparation affiche seulement
le contact confirmé, y compris sur la case initiale d'une cible tuée.

La brûlure utilise un seul petit charbon dans le rail compact des états.
Il reste immobile au repos, puis s'ouvre pendant 0,20 s sur les seuls dégâts
de brûlure effectivement appliqués aux PV. Un dégât de terrain, un saignement,
une réapplication ou une restauration ne rejoue pas cette pulsation. Une
absorption totale utilise le feedback de garde existant. Le signe disparaît
à expiration ou immédiatement à la mort ; les PV, déplacements et états
ne sont jamais écrits par les lecteurs VFX.

Sur eau dynamique transformable uniquement, trois volutes basses remplacent
le VFX générique de la surface vapeur. Elles restent attachées à la case pour
la durée réelle : une phase ennemie, deux pour la version améliorée. Le signe
de brûlure et la vapeur ont des durées indépendantes. Un marqueur de présentation
dans les flags déjà sauvegardés restaure la vapeur sans rejouer la réaction.

Source : `art/source/vfx/braise/braise.blend`, quatre scènes, 39 poses RGBA
à 30 images/s (charbon 8, impact 12, braise 7, vapeur 12). Matériaux cel à
aplats : charbon #291f2b, vermillon #d84725, orange #fa852b, crème #fff0c7,
vapeur #a9c3cf / #e2ece4. Les géométries sont des dessins originaux en facettes
et rubans. `pack.py` assemble les atlas sans retouche des pixels ; rerendu
du fichier .blend et export par le service Sprite Clip inchangé du Studio.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python tools/class_card_vfx/braise/build.py -- --render
# Avec Python + Pillow et Blender disponibles sur le PATH :
python tools/class_card_vfx/braise/pack.py
blender --background --factory-startup --python tools/class_card_vfx/braise/verify_source.py
python tools/class_card_vfx/braise/verify_pixels.py
./tools/class_card_vfx/braise/workshop_isolated.ps1
./tools/class_card_vfx/braise/run.ps1 -Capture
# Avec Node.js + Sharp (ou SHARP_PATH vers ce module) :
node tools/class_card_vfx/braise/encode.cjs
./tools/class_card_vfx/braise/run.ps1
./dev.ps1 test test/unit/test_consumable_cards_braise_vfx.gd
./dev.ps1 test cards
./dev.ps1 test terrain
```

La revue utilise la vraie troisième salle et son runtime Cartes. Deux victoires
préalables et le bilan final sont des fixtures. Elle place l'ennemi le plus
robuste de la salle à portée trois ; les deux exemples rétablissent les PV au maximum
normal. Les deux activations sont rapprochées pour montrer la brûlure, l'IA
reste immobile ; ce n'est pas une partie ni un test d'équilibrage. Les captures
visuelles masquent le HUD ; la commande publique et les reprises le conservent.
La sauvegarde est isolée, relue sur disque après le cast puis au milieu de la
brûlure. La reprise conserve coûts, consommation, PV, états et surfaces.

Livraison visuelle : `artifacts/dev/class_card_vfx/braise/combat/braise.gif`,
six secondes, détail sur sol sec puis caméra normale sur eau dynamique.
L'encodage GIF quantifie uniquement la palette des pixels natifs du viewport ;
les PNG source restent dans `detail/` et `combat/`. Aucun son dédié produit.
Résultats et limites : `docs/ai/BRAISE_TENACE_PRODUCTION_2026-09-27.md`.
Cartes : 281 tests PASS ; parcours visuel : 441 contrôles PASS. La suite
Terrain élargie conserve cinq échecs déjà observés avant cette production,
détaillés dans le suivi ; elle n'est pas déclarée verte.
