# Veilleur — quatre vues de marche, essai en jeu

12 septembre 2026. Demande : décliner la marche E V5 sous E/S/N/W puis essai Godot.
E V5 reste conservée. Trois dessins directionnels propres à créer et contrôler.
Une seule animation : marche ; pas de validation artistique finale implicite.
Mêmes 48 phases / 800 ms, pied d’appui piloté par la distance réelle.
Vues E/S/N/W = bas droite / bas gauche / haut droite / haut gauche. Aucun miroir.
Réutiliser GridData / Pathfinder et la vraie carte forêt pour le laboratoire.
Livraison : trois vues dessinées S/N/W + E V5 conservée, 192 PNG et quatre atlas,
SpriteFrames Godot, lecteur par distance et laboratoire de carte forêt.
Vérifications : 234 contrôles natifs GPU, 46 exports/pixels/appuis, 68 navigateur.
Rapport natif final : artifacts/dev/20260912-152227-veilleur-iso-691273e2/summary.json.
Captures face/dos, contacts, taille carte et interface web inspectées.
Corrections : mauvaise épaule de l’écharpe S, mains trop basses, découpe de pointe
de botte dans W, raccord pantalon/revers. Bottes rigides, pas de miroir.
Avis artistique reçu : REJETÉ, personnage mécanique et sans vie. Reprise de la
méthode demandée. Voir docs/design/achilles/animation_reset_2026-09-12.md.
Pas de vrai idle, virages instantanés, dernier dessin conservé à l'arrêt.
Ne pas lancer une nouvelle variante procédurale de ce cycle.
Les PNG de pièces et JSON d’attaches sont relus à l’export, sans nouvelle génération.
