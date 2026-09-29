# Sceau de parade — directions S31

Garde brève (n02), Contre préparé (g05) et garde de secours (fallback_guard). Durée 720 ms, paume levée et résolution à 240 ms, pose 5. Douze dessins par orientation ; SE approuvé conservé, sept nouvelles vues, aucun miroir.

Les quatre atlas et prompts dans `sources/` ont été produits avec imagegen intégré à partir des repos natifs correspondants. Silhouettes mesurées sans repeindre les pixels ; échelle fixe, pied d'appui enregistré, point de paume par dessin et palette par matière.

L'arc de bronze reste une forme procédurale existante, attachée à la paume. Sa transformation compense la résolution de chaque atlas pour garder la taille SE approuvée, puis l'oriente selon la direction. Pour n02 et la garde de secours, la confirmation du bouclier reste obligatoire. Il disparaît après 240 ms ; annulation et changement de mode remettent sa confirmation à zéro. Contre préparé utilise son effet dédié : armement, jeton puis riposte au coup reçu ; aucun second arc de garde n'est ajouté.

Outils : `tools/class_card_vfx/passe_rive_guard_directions/`. `capture_poses.ps1` montre huit vues à échelle doublée avec un repère orange de main (absent en jeu). `play.ps1 -Capture` exerce 40 cas : deux cartes normales/améliorées et la garde de secours, dans huit orientations. Comme ces sorts se lancent sur soi, le banc garde un attaquant adjacent pour vérifier le contre tout en faisant varier l'orientation de Passe-Rive.

La lecture accepte les occlusions normales des bras dans les vues de dos. Des différences de contour subsistent entre dessins et repos ; les fondus sont visibles au ralenti. Ce banc prépare le combat et suspend l'IA, il n'est pas une run complète.
