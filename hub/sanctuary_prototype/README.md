# Refuge des Braises — prototype de sanctuaire

Scène autonome : **`SanctuaryPrototype.tscn`**, à ouvrir puis lancer avec **F6**
dans Godot. Le lanceur `tools/sanctuary_concepts/run_sanctuary.ps1` ouvre également
cette scène avec le renderer de compatibilité.

## Jouer

- Cliquer sur le sol pour déplacer Achille ; un nouveau clic remplace sa destination.
- Cliquer sur le marchand, l'oracle ou le passage : Achille les rejoint avant
  d'ouvrir l'interaction. **E** permet aussi d'interagir à proximité.
- **I** ouvre l'inventaire. **Échap** ferme le panneau ; hors panneau,
  **Échap** ou clic droit arrête le déplacement.
- **Recommencer** ou **R** remet la visite à zéro. **F1** affiche le contrôle de navigation.

Le marchand vend trois articles avec prix, stock, débit de drachmes et inventaire.
L'oracle propose trois bénédictions exclusives, avec sélection puis confirmation.
Le passage présente les provisions et la faveur choisie. L'état est local à la
visite : les objets et faveurs ne sont pas encore raccordés à une expédition ou
à une sauvegarde persistante.

## Construction

La direction **B4, Refuge des Braises texturé**, a été choisie par l'utilisateur
après inspection des générations par deux agents. Le décor conserve ses matières
peintes, avec une grande cour centrale. Le héros est le backend de sprites 2D
d'Achille déjà présent dans le projet. Marchand et oracle sont deux dessins
originaux générés avec Meshy pour ce prototype ; ils utilisent des poses fixes.

`refuge_layout.json` définit le repère natif **1536 × 1024**, les obstacles, les
approches, les surfaces d'eau, les braseros et les éléments d'avant-plan. La
navigation dispose d'une carte dédiée avec marge des pieds, refuse les trajets
partiels et les destinations bloquées. L'image est ajustée uniformément à la
fenêtre. Les personnages et les morceaux d'avant-plan sont triés selon leur
ancrage au sol.

L'eau reçoit un déplacement léger de la peinture et des reflets animés uniquement
sur ses polygones intérieurs. Les deux braseros portent une fumée procédurale
transparente. Une partie de la fumée et les flammes sont aussi peintes dans le
fond d'origine ; cette première intégration conserve ces détails.

Les silhouettes des habitants sont rendues avec `resident_alpha.gdshader` et un
masque de fond séparé : le PNG Meshy contient un damier peint. L'image originale
reste intacte ; le masque enlève le fond neutre connecté aux bords. La recette
est `tools/sanctuary_concepts/build_resident_mask.ps1` (PowerShell 7).

## Vérification

Les tests de session sont dans `test/unit/test_sanctuary_session.gd`. Les
composants de navigation et de sprites sont exercés par
`tools/sanctuary_concepts/smoke_sanctuary_components.gd`, et les panneaux par
`verify_sanctuary_panels.gd` dans le même dossier.

Le test complet `verify_sanctuary_runtime.gd` charge la vraie scène, injecte des
clics, suit les déplacements et vérifie achats, oracle, annulation et blocage
des commandes pendant les panneaux. Avec `-- --capture` et un renderer actif,
il produit les captures et contrôle la variation des pixels d'eau. Le rapport
est enregistré dans `artifacts/sanctuary_prototype/runtime_validation.json`.

Les captures et le rapport de livraison indiquent les vérifications effectivement
exécutées. La validation par clics dans Godot ne constitue pas un test des pilotes
de souris Windows ni une partie complète de Catabase.
