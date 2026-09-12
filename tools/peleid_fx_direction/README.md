# Préparation du pic de Frappe du Péléide

Depuis la racine du dépôt : `node tools/peleid_fx_direction/build.cjs`.

Prérequis : Node.js, `sharp` et `jszip`. Le script accepte les installations Node habituelles, puis `SHARP_PATH` / `JSZIP_PATH` (chemins de modules), puis le runtime Codex local. Il n'appelle aucun service de génération. Les prompts et les deux sources générées sont conservés dans `art/source/vfx/peleid_fresco_v1/`.

Entrée : `peak_v2.png`. Sorties régénérées : transparence, quatre calques PNG, source OpenRaster, manifeste et planche statique sous `artifacts/dev/peleid_fx_direction_v1/`. Ne pas peindre sur ces exports puis relancer le script : enregistrer d'abord une révision du maître sous un nouveau nom. Pour animer, garder un dossier de poses éditables distinct des exports générés.

Le script vérifie les dimensions attendues, la présence de quatre formes principales, leur reconstruction sans perte après détourage, l'entrée mimetype de l'archive et son image fusionnée après réouverture. Les composantes mineures restent dans le calque principal. Ces vérifications ne remplacent ni l'examen des contours, ni une ouverture dans un éditeur, ni l'essai en combat.

Le rapport est `art/source/vfx/peleid_fresco_v1/preparation_manifest.json`. L'intention, les critères artistiques et la suite sont dans `docs/design/achilles/peleid_fx_production_v1.md`.
