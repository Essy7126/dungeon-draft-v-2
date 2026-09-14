# Passe-rive : réparer un défaut sans refaire toute l'animation

11 septembre 2026. **Marche seule**. Les pistes ci-dessous ne valent pas résultat validé sur Passe-rive. Aucun autre sort ne doit être produit pendant ce contrôle.

## Ce que les derniers essais montrent

La planche E de douze dessins conserve des poses trop semblables. Une correction du demi-cycle change aussi le masque, la cape et la taille du bouclier. Quatre poses clés, puis huit intermédiaires, clarifient les recouvrements des cuisses mais conservent des variations d'habillage. Une consigne textuelle « garde le reste identique » n'est donc pas une protection suffisante. Les quatre caméras du mannequin sont exactes ; leur imitation par les dessins ne l'est pas automatiquement.

Le détourage effaçait des parties fines des lances. Ce défaut d'affichage a été traité séparément : restauration depuis les pixels d'origine, contrôle du bord sur fond sombre. Ne pas le confondre avec une correction du mouvement.

## Traitement ciblé proposé

| Défaut observé | Intervention précise | Limite et preuve nécessaire |
| --- | --- | --- |
| Une jambe ne passe pas devant l'autre | Transfert d'une vidéo de marche, ou poses articulaires explicites dans un modèle conditionné par pose. Conserver l'identité gauche/droite jusqu'aux pieds. | La fluidité vidéo ne prouve pas le contact au sol. Revoir chaque croisement de jambes. |
| Le masque, le torse ou le bouclier changent alors qu'on retouche un pied | Masquer uniquement la zone à réparer ; composer le résultat sur les pixels originaux hors masque. | Un masque souple dans le générateur seul peut encore modifier le reste : vérifier la différence de pixels hors zone avant d'accepter. |
| Une correction locale fonctionne sur un dessin mais pas ses voisins | Ajouter une pose clé de correction puis la propager sur une piste séparée. Commencer par un court intervalle sans changement d'occlusion. | Le suivi ne peut pas inventer correctement une surface devenue visible. Ajouter une autre pose lors de l'occlusion. |
| Pied posé qui glisse | Suivre un repère du pied peint, mesurer son déplacement relatif au bassin, puis régler la distance parcourue par cycle dans Godot. | Ne pas déduire les contacts peints des chiffres du mannequin. Un suivi automatique perdu doit être signalé, pas présenté comme une mesure valide. |
| Lance qui raccourcit ou se courbe | Garder une pièce dessinée rigide distincte, attachée à la main ; gérer son passage devant/derrière séparément. | Réserve pour les actions : la prise de main et l'occlusion doivent rester exactes. Ce n'est pas un rig complet du personnage. |
| Taille ou position instable sur la planche | Recaler les images sur un repère du bassin ou du torse, avec une échelle unique ; conserver la trajectoire des appuis. | Éviter de centrer indépendamment chaque pied ou de changer l'échelle à chaque image. |

## Sources primaires relues

- [EbSynth, recommandations officielles](https://ebsynth.com/) : choisir des poses clés lisibles, faire correspondre leurs formes à la vidéo, séparer les zones indépendantes en pistes et utiliser des clés avec alpha pour une retouche locale. Le mouvement rapide, les surfaces plates et les changements de forme compliquent la propagation. La formule gratuite produit du MP4 720p ; l'export PNG avec alpha est annoncé dans Pro. **Piste de correction locale, pas preuve de résolution de la marche.**
- [ComfyUI, Wan 2.2 Animate](https://docs.comfy.org/tutorials/video/wan/wan2-2-animate) : le mode Move transfère le mouvement d'une vidéo à une image. La chaîne utilise DWPose et peut prendre des signaux de pose et de visage. Idée à tester : fournir directement les articulations du guide pour éviter qu'une détection redéduise les jambes cachées par la cape. Cette substitution n'est pas encore implémentée ou validée ici.
- [Wan-Animate, auteurs](https://humanaigc.github.io/wan-animate/) : conditionnement par squelette aligné et référence d'apparence. Il s'agit de génération vidéo ; ni atlas ni conservation parfaite des armes ne sont garantis.
- [Kling Motion Control, documentation Scenario](https://help.scenario.com/articles/2242372122-kling-v3-motion-control-the-essentials) : image de personnage et vidéo de mouvement sont des entrées distinctes. Candidat comparable au transfert Genjutsu, sans résultat Passe-rive mesuré.
- [OpenCV, suivi optique](https://docs.opencv.org/4.13.0/d4/dee/tutorial_optical_flow.html) : suivi de repères entre images et statut de perte de suivi. Les changements d'apparence et les occlusions fragilisent la mesure ; vérifier le retour avant/arrière et le chevauchement des jambes.
- [ComfyUI, retouche masquée contrôlée](https://docs.comfy.org/built-in-nodes/ControlNetInpaintingAliMamaApply) : combine image, masque et conditionnement ControlNet. Capacité documentée ; aucun modèle de retouche différent d'ImageGen n'a été exécuté sur nos sprites.

## Essai concret préparé

Un outil de mesure a déjà été installé et essayé, sans retoucher les images : OpenCV 5.0.0, installé dans un dossier isolé. Sur les images E 1 à 4, quatre repères du même pied donnent un déplacement horizontal d'environ -41,6 pixels source, mais seulement +0,7 verticalement ; le déplacement isométrique du personnage demande aussi une compensation verticale. La dérive du repère atteint 7,25 pixels à l'échelle du jeu ; un ajustement de vitesse seul laisse 6,81 pixels. Le suivi est perdu à l'image 5, donc le résultat reste **partiel**. Il mesure une zone de chaussure, pas une force d'appui ou automatiquement le point talon/pointe. [Rapport](../../../artifacts/spine_trial/passe_rive_walk_iso_v1/foot_tracking_report.json).

La page de revue affiche maintenant les quatre vues et les défauts connus ; le navigateur charge 48 images, ses commandes de lecture et de pas d'image sont vérifiées. Le test natif Godot utilise le vrai terrain et la projection forêt. Ces succès d'affichage ne débloquent pas la validation artistique de la marche.

`art/source/characters/achilles/passe_rive_walk_iso_v1/transfer_trial/` contient une vidéo inspectée de 4,8 s, à 30 images/s, quatre cycles de 1,2 s, une image Passe-rive cadrée en entier et le prompt exact. Vue E uniquement. Comparer jambe d'appui, continuité, costume, lance, fermeture de boucle avant toute généralisation.

Le connecteur Higgsfield est déjà disponible et expose `hf_mult_motion_control` (Genjutsu). Consultation du compte : zéro crédit payant, un essai gratuit 480p/720p jusqu'à 30 s. Aucun job soumis à ce stade ; le connecteur exige un choix utilisateur explicite pour consommer l'essai. Pas d'achat ni d'entraînement lancé.

Conserver seulement les méthodes qui réussissent ce petit test et réduisent réellement le nombre de corrections. Lire de nouvelles références enrichit cette mémoire externe ; cela n'entraîne pas les poids de l'assistant.

## Sources de l'itération peinte en cours

Génération via ImageGen intégré, montage et détourage logiciels autorisés. Originaux préservés sous `art/source/characters/achilles/passe_rive_walk_iso_v1/` : `E_keys.png`, `E_inbet.png`, `S_v1.png`, `N_v1.png`, `W_v1.png`. Prompts exacts voisins : `E_keys_prompt.txt`, `E_inbet_prompt.txt`, `S_v1_prompt.txt`, `N_v1_prompt.txt`, `W_v1_prompt.txt`. Les versions E précédentes sont conservées comme contre-exemples, pas comme clips approuvés.
