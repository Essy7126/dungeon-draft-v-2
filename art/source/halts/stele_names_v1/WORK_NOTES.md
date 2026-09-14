# La stèle des noms — livrée le 12 septembre 2026

Révision terminée après essai utilisateur : eau conservée ; treize contours
de saule/roseaux, lanternes fermées à vitrage et halo animés, cadres fixes.
`foliage_contours.json` conserve les silhouettes tracées ; deux pierres et une
hampe oubliée ont reçu des contrôles GPU dédiés. Dernières preuves dans
`shader_review.json` : 254 contrôles GPU, 74 captures et 60 planches temporelles,
52 tests GUT / 1 265 assertions, 29 tests Python. Les preuves ci-dessous et
`runtime_review.json` décrivent la première livraison et ses interactions.

Demande : une nouvelle halte, avec continuité eau/barque et références Styx/Charon.
Choix : rive funéraire sous un saule, pierres submergées, relief du passeur et
chemin sinueux. Le fil du fleuve est conservé avec une composition distincte.

Plan préalable avec trois gabarits H/image = 0,18. Image originale image_gen
1672 × 941, `exec-70f99430-631d-426b-82dd-eef4a8abd44b.png`, préservée octet pour
octet. Calibration manuelle dans `calibrate.py`, masques produits par l'atelier.
La stèle peinte est plus grande que le guide initial : environ 2,4 hauteurs de
corps, retenue comme monument funéraire. Offrande basse et borne à hauteur de
genou. Échelle inspectée à l'amarrage, au mémorial et sur le chemin de droite.

Deux interactions : mémoire près de la stèle et départ à l'amarrage. Service
de récit standard : 20 oboles, un secret et un reçu unique. Binding exact
titre/profondeur IV/type lore ; identités et liens du graphe inchangés.
La marche suit les dalles sèches, sans passage derrière le mémorial.

Corrections issues de la revue : reflets d'eau atténués, fondu vers le lointain,
paramètres validés dans Studio et Python, même rendu en aperçu et en jeu.
Le trajet nul ne bloque plus la relecture d'un lieu déjà atteint.

Preuves finales : 271 contrôles GPU, 42 captures, 4 168 points de déplacement
sans sortie du sol ; 96 contrôles de production avec sauvegarde/reprise/départ ;
49 tests GUT et 1 141 assertions ; 26 tests Python. Détails et rapports dans
`tools/stele_names_review/README.md` et `runtime_review.json` à côté de cette note.

Contexte partagé : travail démarré sur HEAD
`0bdfd5bffca5df5d5d7a8206dc651b050b7c7a43`. Les changements préexistants de
`hub/painted_halt/halt_interactions.gd`, du personnage, de l'audio et des VFX
appartiennent à d'autres tâches et n'ont pas été remplacés.

Reprendre : `tools/stele_names_review/open.ps1`. Toute nouvelle peinture exige
une nouvelle calibration ; toute modification du manifeste exige `prepare`.
