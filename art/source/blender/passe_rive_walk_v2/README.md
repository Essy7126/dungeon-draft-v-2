# Passe-rive — essai de marche Blender, 10 septembre 2026

État : mannequin animé et contrôle des appuis livrés pour examen visuel. Le transfert vers le dessin Passe-rive n’a pas encore été généré. Ce dossier ne contient pas de sprite peint final.

Retour utilisateur après visualisation : « Oui c'est bien mieux en terme de raccordement des pieds ». Conserver cette mécanique comme base du prochain test d’habillage. Ce retour concerne les appuis ; il ne valide pas l’apparence finale et ne constitue pas un accord d’utilisation de la génération gratuite en attente.

## Source actuelle

- `passe_rive_walk_v2_contacts.blend` : source éditable actuelle, avec clés supplémentaires aux changements de contact, quatre chaînes IK et action `Walk_E_Editable`.
- `passe_rive_walk_v2_refined.blend` : étape précédente, avant correction de l’interpolation entre les clés.
- `passe_rive_walk_v2.blend` : premier mannequin, conservé pour traçabilité ; ne pas utiliser comme livraison actuelle.
- `walk_validation.json` : contrôle initial de la version refined, aux images entières. Le contrôle final à 120 Hz est dans `artifacts/spine_trial/passe_rive_walk_v2/native_review.json`.

La scène Blender déjà ouverte par l’utilisateur n’a pas été modifiée : travail en processus séparé. Le serveur Blender MCP n’était pas joignable ; aucune installation supplémentaire n’a été nécessaire. Blender 5.1.2 est installé sur ce poste.

## Décisions de mouvement

Une direction E, trois-quarts face, +Y en avant. Cycle de 1,2 s, 0,90 m par cycle, 0,75 m/s ; 36 images à 30 i/s. Appui pendant 60 % du cycle, alterné entre les pieds : réception au talon, appui à plat, poussée sur la pointe, passage. Passage réel à la phase 0,29378, puis 0,79378. Bassin déplacé vers le pied porteur, thorax en contre-rotation. Lance à droite anatomique, bouclier à gauche en diagonale. Jambe gauche jade et droite bronze pour suivre leur identité.

Le mannequin rend les articulations lisibles ; ses volumes ne remplacent pas la direction artistique validée. Référence verrouillée : `art/source/characters/achilles/passe_rive_v1/reference_choisie.png`, SHA256 `178409524db1e7bf7dbef01e6ab5f7aee449c26fa1d90853682d509207d61330`.

## Livraison et vérifications

Revue locale : <http://127.0.0.1:8734/files/passe_rive_walk_v2/review.html>.

`artifacts/spine_trial/passe_rive_walk_v2/` contient les 36 PNG RGBA 640 × 960, une vidéo H.264 de 4,8 s (quatre cycles), les mesures natives et le rapport navigateur. Les anciennes images dans `check/` précèdent l’amélioration des bras et du cadrage.

Contrôle final : 145 mesures des repères évalués par Blender, à 120 Hz. Dérive maximale entre deux mesures d’un même contact : 0,287 mm ; pénétration minimale de la semelle : 0,222 mm. Ces valeurs incluent l’interpolation et restent sous le seuil de 1 mm utilisé pour ce brouillon. Elles ne constituent pas une validation artistique, ni une garantie de conservation des appuis dans un futur résultat généré.

Chromium : 36 images chargées, lecture/pause/ralenti, étiquettes talon/pointe, vidéo 640 × 960 de 4,8 s et affichage mobile vérifiés ; aucune erreur JavaScript ni requête échouée. Captures `review_preview.png` et `review_passing.png` inspectées. Aucun changement de gameplay ni intégration dans le personnage principal.

## Reproduire le rendu

Depuis la racine, avec Blender installé :

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background art/source/blender/passe_rive_walk_v2/passe_rive_walk_v2_contacts.blend --python tools/passe_rive_motion/render_blender_walk.py
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background art/source/blender/passe_rive_walk_v2/passe_rive_walk_v2_contacts.blend --python tools/passe_rive_motion/inspect_native_walk.py
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python tools/passe_rive_motion/encode_reference_video.py
Copy-Item tools/passe_rive_motion/walk_v2_review.html artifacts/spine_trial/passe_rive_walk_v2/review.html
node tools/passe_rive_motion/verify_walk_v2.mjs
```

Le code de construction est dans `tools/passe_rive_motion/build_blender_walk.py` ; il protège les fichiers existants. Le modèle mathématique est dans `walk_model.py`. `refine_contact_keys.py` ajoute les clés fractionnaires à la version refined et produit la version contacts. Lire les journaux Blender : ce programme peut quitter avec le code 0 malgré une exception Python.

## Transfert d’apparence : prochaine étape préparée

Connecteur disponible : Higgsfield Genjutsu `hf_mult_motion_control`, piloté par la vidéo Blender entière et l’image de référence. Une génération gratuite 720p est disponible selon la consultation du connecteur pendant cette session. Une question explicite sur son utilisation a été adressée à l’utilisateur ; pas de réponse reçue au moment de cette fiche. Aucun job de génération ni achat n’a été lancé.

L’image jointe par l’utilisateur a été transférée avec succès : média `532d1c23-780e-47ca-87d1-1ad6e13fe3fd`. Une place d’envoi vidéo `b3ccd97b-5c92-4740-9f02-00a4fcad6635` a été réservée mais n’a pas reçu de données ; ne pas la considérer comme confirmée. Ne pas enregistrer son URL signée dans Git.

Après accord : envoyer `motion_reference.mp4`, lancer exactement un essai gratuit avec `use_free_gens:true`, comparer les pieds, la silhouette, les armes et le raccord de boucle au mannequin. Rejeter ou retoucher un transfert qui glisse, même si son illustration est séduisante. L’idle et les autres directions restent hors de ce test.

## Références de méthode

- [Jason Martinsen / Animation Mentor : marche humaine](https://www.animationmentor.com/blog/tutorial-animating-human-walk-cycle/) : contacts, passage, déplacement et appuis.
- [Thomas Vasseur : pipeline de Dead Cells](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-) : animation 3D éditable et sortie en images ; échelle graphique différente de Passe-rive.
- [Mariel Cartwright, GDC 2014](https://media.gdcvault.com/GDC2014/Presentations/Cartwright_Muriel_Animation_Bootcamp_Fluid.pdf) : tester le mouvement brut avant les finitions.
- [Blender 5.0, API Python](https://developer.blender.org/docs/release_notes/5.0/python_api/) : `image_settings.media_type = 'VIDEO'` avant le format `FFMPEG`.
