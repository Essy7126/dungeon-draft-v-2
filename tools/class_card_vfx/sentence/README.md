# Sentence du rempart — comparaison

```powershell
./tools/class_card_vfx/sentence/run.ps1
```

Ouvre un combat de production isolé, avec IA suspendue, une main préparée et deux
boutons **Rejouer V1** / **Rejouer Blender**. Le troisième bouton alterne la caméra
normale et le détail. Les deux boutons passent par le vrai SpellCaster ; la V2
utilise la même préparation que le lancement normal. Les PV et PA sont restaurés
entre les essais pour comparer le même coup. Ce laboratoire ne simule pas une
partie complète et ne mesure pas les performances GPU.

```powershell
./tools/class_card_vfx/sentence/run.ps1 -Capture
./tools/class_card_vfx/sentence/run.ps1 -Workshop
./dev.ps1 test cards
./dev.ps1 test audio
```

La capture échantillonne 63 images par variante, soit 126 vues natives Godot.
Le contrôle Workshop réutilise le service Studio pour créer un document éditable
et vérifier la restitution des pixels/durées. Les rendus sources restent sous
`artifacts/dev/class_card_vfx/sentence/hammer/` et doivent être présents pour
régénérer ce document.

La capture contrôle aussi le parcours de commande normal (armement, verrouillage,
revalidation des PA), le son au contact et le bilan/sauvegarde/reprise via les
services du jeu. La victoire de ce dernier contrôle est provoquée par la fixture ;
elle ne constitue pas une partie gagnée en jouant.

Le document Studio utilise le suffixe de direction `E` exigé par son format.
Le marteau est un effet local à la cible, avec une seule vue fixe, sans promesse
de variantes directionnelles. L'export de clip vérifie le marteau seul ; la
capture Godot vérifie sa composition avec le contact, le retrait et les débris.
Le document Studio sert ici à la revue du clip. Une retouche de ses durées ne
modifie pas automatiquement le lecteur du pilote : celui-ci lit l'atlas à
30 images/s et garde son repère de contact explicite. Les changements de rythme
doivent donc être reportés dans l'animation Blender et le lecteur, puis recapturés.

Les GIF `sentence_v1.gif` et `sentence_v2.gif` se régénèrent avec `encode.cjs`
(Node + sharp) après une capture complète. Ils conservent les dimensions natives
et le rythme de 30 images/s, avec uniquement la quantification de palette GIF.
Ils sont muets ; utiliser le laboratoire interactif pour entendre le son.
Si sharp n'est pas installé dans la résolution Node habituelle, `SHARP_PATH`
peut indiquer son dossier de module.

La nouvelle présentation ne concerne que `g_crash` dans une session Cartes.
Le début du lancer attend 0,5 s de préparation avant `begin_cast`, qui revalide
les conditions et dépense les ressources. Le report confirmé fait basculer le
marteau au contact ; un appel direct à SpellCaster commence directement au contact.
La V1 des autres cartes est conservée. Le son de bronze utilise le bus SFX et
le réglage d'effets du combat ; une absorption totale conserve le son de blocage.

Sources éditables : `art/source/vfx/sentence_rempart/sentence_rempart.blend`,
`build_hammer.py`, `pack.py`, `vfx/class_cards/sentence/hammer_player.gd`.

La retouche `bronze-contact-02` conserve les poses et le repère de contact du
pilote : ombres brunes plus profondes, manche bleu sombre et émail turquoise.
Le flash éclaire seulement les faces chaudes claires du marteau. Au contact,
un éclat comprimé sous la tête tient deux poses de 1/15 s, puis se fragmente.
Deux accents de pression au sol disparaissent en 0,29 s, deux langues de
poussière en 0,40 s, et six éclats à facettes en 0,67 s après le contact.
Le retrait du marteau garde son intervalle 0,63–0,99 s après le début du lancer.

L'état accepté avant cette retouche est conservé dans
`artifacts/dev/class_card_vfx/sentence/polish_before/` (source Blender, script,
atlas, lecteur, shader et GIF). Le bouton **V1** compare toujours au premier
effet cel, antérieur au pilote Blender ; ce n'est pas ce précédent état du pilote.
