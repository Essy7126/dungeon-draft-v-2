# Coup de talon — animatique B / S24

**Choix courant de Paolo : coup de pied haut.** Après comparaison en jeu, le 27 septembre 2026, la demande « je préfère le coup de pied haut » rétablit l'atlas initial. Les améliorations de pivot, d'échelle et le petit accent physique sont conservés, avec l'accent replacé au talon haut. La source basse et ses preuves restent archivées. Ne pas rebaisser le geste automatiquement pour s'adapter à la petite cible du banc d'essai.

Paolo a validé la mise en place du chassé de profil le 27 septembre 2026, après les trois propositions dessinées. Étape actuelle : huit poses dans une direction SE à valider, avant production des intervalles et orientations supplémentaires.

## Essai

Depuis la racine du jeu :

```powershell
./tools/class_card_vfx/passe_rive_s24/play.ps1
```

Boutons « Jouer le coup de talon » et « Vitesse ×1 / ×0,5 ». Le lanceur isole les sauvegardes et respecte le verrou moteur. La scène utilise la vraie demande de carte, le vrai coût, les dégâts et la poussée ; l'IA est en pause dans la configuration Studio. La cible et les PA sont réinitialisés entre essais.

Le geste haut est maintenant pris en charge par le backend de production pour les cartes de poussée n04/g03/g06 en SE ainsi que l'ancien Coup de talon. `kick_backend.gd` est un simple alias de compatibilité. La scène historique garde sa carte `class_a_push` ; le banc `../play_passe_rive_assignments.ps1` teste les vraies cartes actuelles `cc2_*`. Les autres orientations du coup restent à dessiner. Voir `docs/ai/PASSE_RIVE_CARD_ASSIGNMENTS_2026-09-27.md` pour la liaison actuelle et ses preuves.

## Fabrication

- Source : outil imagegen intégré, dessin référencé sur le prototype B approuvé et le repos natif SE. Huit poses transparentes, pas d'animation préfabriquée.
- `assets/kick_b.png` : source haute initiale `animatic_b.png` copiée à l'identique ; SHA-256 `5cf34d3bf662489c6efe183bedec695604174909c0d5790613376c302eb35d02`, également dans `metadata.json`. Variante basse `animatic_b_v02.png`, prompts et références archivés dans le dossier de tâche `outputs/passe_rive_coup_de_talon_S24`.
- `build_metadata.py` mesure les régions et semelles, ainsi que cinq familles de couleurs via le calibrage S23. Ne modifie aucun pixel.
- Échelle unique `214 / hauteur de la pose neutre`, multipliée par le profil natif. Pivot de chaque pose sur la semelle d'appui ; raccord au point d'appui du repos SE. Pas de redimensionnement par pose et pas de fondu de deux silhouettes.
- Durées : 80/80/100/50/70/80/90/100 ms. Contact au début de la pose 4, à 310 ms ; total 650 ms.
- La première capture a motivé un essai bas pour viser la petite cible. Paolo préfère le geste haut ; cette intention est rétablie. La scène garde un petit accent au talon à la place du grand souffle qui masquait la jambe. La résolution des règles reste indépendante du VFX.

## Vérification et limites

Validation haute actuelle : 3 tests / 45 assertions PASS dans `artifacts/dev/20260927-133406-test-test_unit_test_passe_rive_s24.gd-0430f9a6`. Le banc des cartes actuelles passe 14 lancers / 274 contrôles avec 125 captures dans `artifacts/dev/passe-rive-assignments-20260927-133519`. Les rapports ci-dessous concernent la précédente variante basse et restent historiques.

Tests ciblés : `./dev.ps1 test test/unit/test_passe_rive_s24.gd` — 3 tests, 45 assertions PASS, y compris contact exact sous retard d'image, annulation et isolement des autres gestes. Dernier rapport : `artifacts/dev/20260927-123430-test-test_unit_test_passe_rive_s24.gd-f9a99d00/`.

Suite Cartes après les changements : `./dev.ps1 test cards` — **190 tests, 14 625 assertions PASS**, aucune erreur, rapport `artifacts/dev/20260927-123637-test-cards-8bb10cc1/`. Formatage ciblé des quatre GDScript vérifié. Aucun moteur commun ni catalogue de règles modifié.

Capture : `./tools/class_card_vfx/passe_rive_s24/play.ps1 -Capture` — PASS dans `artifacts/dev/passe-rive-s24-20260927-123524/`, 24 contrôles de scénario et 84 captures sauvegardées, sans erreur moteur. Dégâts constatés : 5 pour les statistiques de cet essai ; coût 1 PA, poussée d'une case, lanceur immobile, repos natif à la fin. Le test ne transforme pas 5 dégâts en constante de la carte.

Première capture `passe-rive-s24-20260927-123039` conservée comme échec : son assert de rapport employait un mauvais défaut pour le champ `failed`, ensuite corrigé. Ne pas l'utiliser comme résultat final.

Inspection visuelle : capture avant/coup/retour à zoom constant. Le coup bas traverse désormais le haut de la silhouette de la petite cible ; le souffle ne cache plus l'action. C'est une animatique à poses tenues : elle ne valide ni la fluidité finale, ni un contact anatomique universel sur toutes tailles de cibles, ni une identité parfaite pixel par pixel entre deux atlas. Les intervalles fins et autres orientations attendent la validation du geste.

`build_review.py CAPTURE OUTPUT` assemble uniquement les captures Godot pour le GIF et la planche comparative, en préservant leur cadrage commun. Il refuse un rapport en échec.
