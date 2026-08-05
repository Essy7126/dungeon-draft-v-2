# Guide de calibration par ancres

Une ancre associe une cellule logique connue à son centre mesuré dans l'image
native. Trois ancres non colinéaires sont le minimum ; cinq à huit ancres
réparties près des coins et du centre donnent un meilleur diagnostic.

Dans l'outil Ancres, cliquez une cellule pour ajouter une mesure, glissez une
ancre pour corriger son pixel et utilisez le clic droit pour la supprimer.
L'auto-fit résout simultanément O, U et V par moindres carrés. L'opération est
déterministe et forme une seule action Undo.

La qualité est centralisée dans `GridTransformService` : RMS jusqu'à 1 px
« excellente », jusqu'à 3 px « acceptable », au-delà « à vérifier ». L'erreur
maximale et chaque résidu restent visibles. L'ajustement refuse les cellules
dupliquées, hors grille, colinéaires ou trop mal conditionnées. Il ne modifie
jamais la topologie.

Avant d'accepter le résultat, contrôlez les trois maps types, les extrémités de
la grille et l'inversion cellule → image → cellule. Une grille partiellement
hors image produit un avertissement ; aucune correction automatique ne déplace
les cellules logiques.
