# Restauration — directions S31

Seconde aurore (i01) et Grâce du bronze (l02), normales et améliorées : huit vues dessinées, sans miroir. L'ouverture ample garde les douze poses S30, 1,12 s et résolution à 450 ms ; la version brève reprend neuf poses, 0,82 s et résolution à 250 ms. Les poses hautes sont réservées à Seconde aurore.

Le SE et les VFX approuvés restent ceux de S30. Les sept autres vues sont dessinées d'après les repos natifs. Sources retenues : E_W_v02, NE_NW_v02, S_N_v01, SW_v01. Les versions précédentes et prompts sont conservés : correction d'une ouverture trop haute au contact court W et du bras levé NW. Aucun raster n'a été transformé par un script.

La stature est calibrée à 214 unités source, avec une échelle fixe par vue, des appuis enregistrés et deux repères de paumes par pose. La palette est rapprochée du repos natif. Le raccord utilise le repos natif de la direction ; l'ancien remplacement par l'incantation t_mark a été retiré.

Les deux lumières ascendantes suivent les paumes. Leurs pointes sont ajustées au dessin, leur largeur reste indépendante de la hauteur de l'atlas. Les facettes de bronze conservent la disposition approuvée autour du personnage. L'accent lumineux exige un soin effectif ; les facettes exigent un gain de garde effectif. Aucun effet supplémentaire ne prétend restaurer des PV déjà pleins ou dépasser le plafond de garde. La fin d'activation de Seconde aurore attend le retour au repos.

Reproduction : `tools/class_card_vfx/passe_rive_renew_directions/build_metadata.py`, `capture_poses.ps1`, `play.ps1 -Capture`, puis `build_review.py <captures_poses> <captures_combat>`. Le banc suspend l'IA et prépare les cartes sans écrire la sauvegarde du joueur. Il ne remplace pas une run complète. La grille montre successivement les deux variantes avec une confirmation synthétique ; le banc de combat vérifie les gains réels.

Les vues dessinées gardent de petites différences de contour et de plis. La calibration supprime le redimensionnement selon la pose ; elle ne rend pas les pixels de dessins distincts identiques. Voir VALIDATION.md pour les preuves et la revue finale.
