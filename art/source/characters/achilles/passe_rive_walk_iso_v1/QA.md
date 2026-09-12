# Marche : candidat refusé pour fluidité et qualité visuelle

Une seule animation active, dans quatre angles. Les sorts et l'idle attendent.

Dernier retour utilisateur : « la marche n'est pas fluide, ça n'est pas beau ». Candidat conservé pour comparaison. La [recherche Dofus](../../../../../docs/design/achilles/dofus_animation_method_2026-09-11.md) propose de reprendre une source 2D éditable avec pièces stables et dessins de remplacement ; elle ne constitue pas une correction déjà livrée.

## Contrôles effectués

- Même action Blender projetée depuis quatre caméras orthographiques ; pas de miroir des membres. 48 images de guide produites. Cadrage agrandi à 2,52 m pour que les lances des vues S/W ne soient plus coupées.
- E_v1 : 12 dessins, alpha présent après détourage, aucun bord de cellule touché, échelle unique. **Rejet mécanique** : les poses 7 à 10 répètent visuellement un pied arrière relevé au lieu d'établir clairement l'appui opposé. Le demi-cycle droit est repris isolément.
- Registre d'apparence préparé mais Passe-rive retiré du menu public jusqu'à validation du kit. Test de lancement Catabase : 2 tests, 82 assertions, aucune erreur (rapport dans artifacts/dev/20260911-221652-test-test_unit_test_catabase_selection_launch.gd-b4a1dd0c/).

## À mesurer sur les dessins retenus

- Identité anatomique des deux pieds sur toute la boucle, contact talon/pointe, continuité du passage.
- Déplacement du pied d'appui relativement au bassin ; en déduire la distance parcourue par cycle et la cadence sur carte. La règle générique « un demi-cycle par case » ne suffit pas à calibrer ce nouveau dessin.
- Taille, angle, visage, drapé, prise de lance et bouclier, occlusion des vues de dos.
- Raccord 12 → 1, arrêt/reprise et changement de direction à la même phase ; contours sur fonds clair et sombre.

Génération : ImageGen intégré. Détourage Birefnet local autorisé. Les chiffres du mannequin ne sont pas des mesures des appuis peints.

## Revue approfondie et aide extérieure

- Les quatre vues E/S/N/W ont leurs douze images et ont été examinées en planches de silhouette et de pieds. Les lances effacées par Birefnet sont restaurées depuis les originaux ; bord contrôlé sur fond sombre. Les vues ne sont pas approuvées artistiquement.
- E : le montage E_v1 + E_half est écarté de la revue active. Nouvelle construction par `E_keys.png` (quatre poses) et `E_inbet.png` (huit intermédiaires). Les cuisses ont une alternance plus lisible, mais le raccord de silhouette et la trajectoire verticale restent insuffisants.
- **Mesure partielle sur les pixels peints** : OpenCV 5.0.0, quatre repères de la même chaussure, images E 1 à 4, vérification aller/retour < 0,54 pixel source. Sous la distance provisoire (160,80) par cycle, déplacement résiduel du repère de 7,25 pixels à l'échelle d'affichage 0,35. Le meilleur ajustement de vitesse seul laisse 6,81 pixels. Il faut corriger la trajectoire/projection, pas simplement changer la cadence. Une chaussure qui roule n'est pas un contact au sol immuable ; cette mesure reste un diagnostic local.
- Suivi perdu à l'image 5 lors du croisement des membres : **pas de mesure extrapolée** aux autres images ou angles. Rapport et planche : `artifacts/spine_trial/passe_rive_walk_iso_v1/foot_tracking_report.json` et `tracked_shoe_review.jpg`.
- Laboratoire Godot `tools/passe_rive_iso/WalkReview.tscn` : marche seule, vraie projection forêt, vrais GridData/Pathfinder, aucune variante de campagne exposée. Première passe native : 75 contrôles avec captures, pause/reprise synchronisées, arrivée sur les cases et refus des obstacles/hors-grille. Cela ne prouve pas la qualité artistique.
- Recherche ciblée et essai de transfert vidéo dans `docs/design/achilles/passe_rive_partial_repairs_2026-09-11.md`. Test E de 4,8 s préparé, pas encore soumis ; choix sur l'essai gratuit Genjutsu demandé via le connecteur.

**Verrou : rester sur la marche.** À traiter : trajectoire verticale du pied E, raccords de volume entre planches et mesures des trois autres vues. Ni idle ni sorts tant que ces défauts persistent.
