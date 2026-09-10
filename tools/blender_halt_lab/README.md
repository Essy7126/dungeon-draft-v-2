# Atelier Blender des maps

Instance séparée de la Sentinelle, même Blender 5.1.2 et copie exacte de l’addon
MCP installé (1.6, protocole 5). Le connecteur Codex partagé reste sur 9876 pour
le personnage. Ce laboratoire utilise exclusivement `127.0.0.1:9877`.

```powershell
./tools/blender_halt_lab/open_lab.ps1
python tools/blender_halt_lab/client.py
python tools/blender_halt_lab/client.py chemin/commande.py
```

Le client vérifie le port, le PID, le fichier, l’identifiant de scène et la session
avant d’exécuter le script. Il ne relance pas une commande après une réponse
incertaine. Ne pas utiliser les outils MCP génériques pour modifier cette map :
ils sont encore reliés à la tâche du personnage.

La configuration de cette instance est sous `artifacts/dev/blender-halt-profile/`.
Le lancement conserve les préférences communes ; il ne ferme aucune autre fenêtre.
L’addon réutilise un serveur construit sur 9877 avant son enregistrement pour ne
jamais tenter d’occuper le port du personnage. Un port déjà occupé bloque le lancement.
Pour reprendre, utiliser ce lanceur : le fichier seul ne démarre pas sa connexion.

Le fichier de travail est
`art/source/blender/halt_scale_lab_v1/halt_scale_lab_v1.blend`.
Il contient maintenant la maquette métrique du pilote **Atelier du Bronze** :
93 objets dans une collection dédiée, caméra orthographique fixe, porte ouverte,
établi de 0,90 m, seau de 0,35 m et pilier d’occultation. La collection initiale
est conservée masquée. Une copie versionnée est dans
`art/source/halts/bronze_workshop_pilot_v1/workshop_blockout_v1.blend`.

La [fiche du pilote](../../docs/maps/bronze_workshop_pilot_2026-09-10.md) décrit
la peinture native imagegen, les calques Krita, la calibration et les preuves Godot.

Les dépendances Python de l’addon sont déjà présentes dans Blender. Aucun service
de génération ni asset distant n’est requis pour construire cette maquette.

## Vérification du 10 septembre 2026

Connexion native à la Sentinelle vérifiée en lecture seule : Blender 5.1.2, addon
1.6 et protocole 5 compatibles. Connexion séparée à la map vérifiée : lecture,
écriture d’un objet temporaire puis retrait, rendu Workbench et sauvegarde.
Une session volontairement incorrecte est refusée avant toute modification ;
l’erreur attendue `Expired Blender session` apparaît donc dans le journal de cet essai.
La copie de l’addon a le même SHA-256 que celle de l’installation existante.
Preuve : `artifacts/dev/blender-halt-profile/verification.json`.
La capture `initial_blockout.png` a été inspectée ; le cadrage et le vrai
personnage restent à travailler lors de l’essai de création de map.

## Reproduire les étapes techniques du pilote

Les scripts de création ciblent ce pilote précis ; une prochaine map doit recevoir
son identifiant et sa maquette, ses mesures et son propre manifeste. Les contours
peints ne sont jamais transportés aveuglément d’une image à l’autre.

```powershell
python tools/blender_halt_lab/client.py
python tools/blender_halt_lab/client.py tools/blender_halt_lab/build_workshop.py
# Python avec Pillow et NumPy (runtime Codex déjà disponible sur cet hôte)
python tools/blender_halt_lab/calibrate_reference.py
python tools/blender_halt_lab/client.py --timeout 120 tools/blender_halt_lab/export_guides.py
# Après génération native, conservation et revue des deux originaux :
python tools/blender_halt_lab/package_layers.py
python tools/blender_halt_lab/register_painting.py
./tools/halt_workshop/halt.ps1 verify -Map res://data/halts/bronze_workshop_pilot_v1.json -WaitForEngineSeconds 55
```

`build_workshop.py` reconstruit sa collection générée. Ne pas l’utiliser pour
conserver des retouches manuelles de cette collection ; travailler sur une copie.
`register_painting.py` refuse de remplacer une peinture existante et conserve
une calibration Studio différente, sauf option explicite `--refresh-calibration`.
La génération d’images reste une étape native séparée : ces scripts ne contactent
aucun service image et ne repeignent pas les sources.

Les guides (profondeur 16 bits, normales caméra, IDs, calques géométriques) correspondent
à la caméra Blender. La peinture a modifié légèrement le cadrage ; `registration.json`
conserve le recalage du sol et `layer_selections.json` les silhouettes réellement peintes.

Krita 5.3.3 portable est installé sous `artifacts/dev-tools/krita/` ; son exécutable,
la source officielle, le SHA-256 et la preuve sont dans `krita_runtime.json`.
Utiliser Qt Windows et un profil isolé pour les exports automatiques. Le fichier
OpenRaster s’ouvre directement dans Krita, avec ses objets et raccords séparés.
Les dépendances locales vérifiées sont Pillow 12.3.0 et NumPy 2.3.5 pour les scripts
externes ; Blender possède son propre NumPy. Les versions portables/outils restent
sous `artifacts/`, les sources et preuves de création dans `art/source/`.
