# Animatique de Garde d’airain — étape 2

Depuis la racine : `node tools/guard_animatic/build.cjs`, puis `node tools/guard_animatic/verify.cjs`.

Le lecteur autonome est `artifacts/dev/guard_animatic_v1/review.html`. Il propose replay, pause/reprise, poses, curseur 0–500 ms, vitesses 1/0,5/0,25 et comparaison claire/sombre. Les GIF `animatic_normal.gif` et `animatic_slow.gif` montrent le même montage, agrandi 2×. Dans les GIF seulement : 400 ms de repos avant l’apparition, 700 ms de maintien après, puis 300 ms de repos. Ce retour de boucle n’est pas une dissipation dessinée.

## Fabrication

La source `art/source/vfx/guard_pipeline_study_v1/isolation_chroma_v2.png` vient d’imagegen. La première extraction RGB avec damier et traces de mannequin est rejetée ; elle reste conservée comme `isolation_v1.png`. Les prompts sont à côté des sources. La nouvelle extraction modifie légèrement les traits : elle est une dérivation de travail, pas une conservation pixel à pixel du storyboard.

Le script reprend les équations de chroma, décontamination et despill de `tools/achilles_painted_g_pipeline/build.py::chroma_key` dans Node/Sharp, sans suppression de composantes. Le code existant reste inchangé. L’alpha est reconstruit à partir du magenta : il ne s’agit pas d’un alpha natif fourni par imagegen. Les traits bronze, ivoire et turquoise sont dessinés dans la source ; aucun trait, reflet ou particule n’est créé par le script.

Comme `tools/guard_sprite_pipeline/build.cjs`, la préparation conserve source et empreinte, effectue découpe, échelle commune, copie RGBA et mesures de marge/alpha. Ici un recalage par translation est nécessaire car l’extraction générée a déplacé les points bas entre rangées. Les cinq origines manuelles sont explicites. La réduction linéaire remplace Lanczos, dont le dépassement de couleur sur les franges faibles introduisait un résidu rose ; aucun seuil alpha de gommage n’est appliqué.

Toile de travail 256×256, origine (128,210), échelle nominale 0,58 pour chaque dessin. Ces paramètres sont ceux du brouillon, pas un contrat d’atlas de production. L’erreur d’arrondi du repère ne mesure pas la précision du choix manuel des appuis.

Le personnage est la première image du vrai `idle_E` d’Achille peint, affichée à 0,35 avec origine (256,320), suivant son profil. La toile FX affichée mesure 130 px. Une seule orientation est comparée, sans geste corporel, sans caméra ni occlusion du moteur. Le lecteur compose tous les traits devant le personnage : le raccord avant/arrière reste à étudier.

## Vérifications et limites

`build_report.json`, `manifest.json` et `verification.json` sont dans le dossier de sortie. Le vérificateur contrôle les PNG décodés, les durées réellement encodées des GIF, marges, origines et syntaxe JS. Il ne simule pas une validation d’interface : le navigateur a bloqué l’URL locale de cette session. La planche `contact.png` sert à la comparaison statique à l’échelle du profil.

La phase active est 0–500 ms. La dernière pose est conservée, sans oscillation. Ce sont des poses tenues, pas encore une animation avec intervalles. Aucune ressource de sort ou de profil actif n’est changée.
