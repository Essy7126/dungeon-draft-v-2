# Passe-Rive S22 — 2026-09-26, intégration terminée et vérifiée

Demande : marche de l'exploration, taille cohérente, ruée en combat Cartes.
Runtime : backend S19 alterne AnimatedSprite2D natif pour repos/marche/course/réactions/ruée, painter pour les sept attaques S19/S20. S21 n'est plus sélectionné. Même stride physique et mêmes frames que l'exploration ; cadence adaptée à la longueur réelle de la case (cycle .72 s / .60 s).
Taille : référence native 214 × profile.display_scale (94.16), correction de stance constante par geste, pas de rescale par frame. PNG préservés. Sceau : fragments interlignes E/SE attribués à la main et non aux pieds ; recalage des premiers appuis SE.
Ruée : cartes dont l'effet est move, départ 0/1, trajet 2..13, réception 14..24 à l'arrivée. Blink reste distinct. Le banc Studio doit connecter unit_pushed comme le démarrage normal de Battle. Percée n'autorise que les quatre axes de la grille ; test unitaire des huit vues.

Preuves : test ciblé initial 8/8, 2146 assertions. Première capture interrompue par budget de frames ; deux captures ont révélé des erreurs du banc (trajets non permis, startup Studio partiel, clé failed absente sur succès). Rapport complet valide à artifacts/dev/passe-rive-s22-20260926-133204 (616 contrôles / 11 casts), antérieur au dernier correctif de cadence. Nouvelle capture en cours, puis suite Cards, non-régression native, flow IA victoire reprise.
Fichiers : s19_backend/body, passe_rive_autosprite_view, s22_registration, build_s20_data + métadonnées, tests S19, arène S19, arène S22, lanceur et lecteur de captures.
Limite graphique constatée : les sources d'attaque peintes gardent leur modelé et proportions de vêtement différents du rendu natif. Ne pas présenter la calibration comme un nouveau dessin uniformisé.
Préserver modifications concurrentes. Les scripts tools/implement_s22.py, finish_s22_runtime.py, build_s22_audit.py du workspace sont des étapes historiques : ne pas les rejouer sur le résultat final.

Validation finale : 103 tests Cartes + 13 tests natifs PASS ; audit 133701 PASS ; flow réel 134325 PASS, victoire et reprise disque. Voir VALIDATION.md pour les limites et preuves. Nouvelle arène interactive à lancer pour la revue utilisateur.

Arène interactive S22 ouverte et prête : session exec 93767, dossier artifacts/dev/passe-rive-s22-20260926-134520. Ce processus utilise encore le verrou engine.lock ; fermer cette fenêtre d’essai avant de relancer les commandes de tests. Les fenêtres de l’utilisateur n’ont pas été fermées.
