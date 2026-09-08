# Refuge des Braises — sanctuaire interactif

Le Sanctuaire est accessible depuis le menu, la sélection et une halte de
Catabase. La scène **`SanctuaryPrototype.tscn`** peut aussi être lancée avec
**F6** ou `tools/sanctuary_concepts/run_sanctuary.ps1` pour une visite de préparation.

## Jouer

- Cliquer sur le sol pour déplacer Achille ; un nouveau clic remplace sa destination.
- Cliquer sur le marchand, l'oracle ou le passage : Achille les rejoint avant
  d'ouvrir l'interaction. **E** permet aussi d'interagir à proximité.
- **1**, **2**, **3**, ou les boutons inférieurs rejoignent respectivement le
  marchand, l'oracle et le passage. **I** ouvre l'inventaire.
- **Échap** ferme d'abord le panneau, puis revient au menu ou à la halte d'origine.
  Le clic droit arrête le déplacement. **F1** affiche le contrôle de navigation.
- **Tab**, **Maj+Tab** et les flèches parcourent les actions du panneau ; la
  confirmation de l'oracle et le départ restent visibles sous la zone défilante.

Pendant une halte, le marchand affiche les vrais équipements et prix en oboles
de la run. L'oracle expose ses services de mémoire, de découverte et de soin.
Chaque transaction utilise `GameManager.use_catabase_hub_service` : objets,
solde, effets et reçus sont ceux de Catabase, avec sauvegarde et reprise.
Le passage termine la halte ; le retour à la halte permet de poursuivre ses
préparatifs sans la consommer. Les vues peintes de la carte restent disponibles.

Avant une run, les habitants expliquent les services futurs ; aucun achat ni
bonus fictif n'est attribué. Le passage ouvre la sélection ou reprend la
sauvegarde existante. `SanctuarySession` adapte les API de GameManager sans
posséder d'économie indépendante ni convertir les anciennes drachmes du prototype.

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

La scène de test `tools/sanctuary_concepts/VerifySanctuaryRuntime.tscn` exécute
`verify_sanctuary_runtime.gd` après les autoloads, charge la vraie scène, injecte des
clics, suit les déplacements et vérifie achats, oracle, annulation et blocage
des commandes pendant les panneaux. Avec `-- --capture` et un renderer actif,
il produit les captures et contrôle la variation des pixels d'eau. Le rapport
est enregistré dans
`artifacts/project_audit/2026-09-08/sanctuary/runtime_validation.json`.
Les résolutions couvertes sont 1200 × 896, 1280 × 720 et 1920 × 1080.
Trois victoires servent de préparation explicite au test ; les transactions de
halte et leur restauration passent ensuite par les services réels et un fichier
isolé. La sauvegarde du joueur est vérifiée inchangée.
Le même test restaure aussi cette halte avec le singleton de production et son
interface persistante : entrée au Sanctuaire, fermeture du panneau avec Échap,
retour à la halte par bouton puis par Échap, sans consommer ses services.

Les captures et le rapport de livraison indiquent les vérifications effectivement
exécutées. La validation par clics dans Godot ne constitue pas un test des pilotes
de souris Windows ni une partie complète de Catabase.
