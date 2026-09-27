# Orage du passage — production du 27 septembre 2026

Demande : « créé orage du passage de la manière possible, on veut des belles
couleurs, de beaux effets ». Référence H du lot 2 approuvée.

Périmètre : `cc2_l01`, catalogue public Cartes consommables. Rayon de Manhattan
2, 1,1 P magiques (1,25 P amélioré), ennemis seuls, instantané sans terrain.
Les anciens pilotes et modifications concurrentes restent conservés.

Direction : couronne basse bleu nuit/turquoise en anticipation, foudre épaisse
à cœur ivoire et contact cel simultané par ennemi réellement touché, fragments
qui se résorbent. Aucun éclair sur allié/case vide, aucune persistance.
Production : dessins de géométrie simple originaux dans Blender, exports RGBA,
service Studio, lecteur Godot dédié et capture dans la vraie run.

Production : quatre scènes Blender et 66 poses exportées ; seconde passe avec
foudre épaissie, couronne dentelée et arcs de contact brisés. Sources dans
`art/source/vfx/orage_passage/`, générateurs et revue dans
`tools/class_card_vfx/orage/`, lecteur et atlas dans `vfx/class_cards/orage/`.
Le routage est réservé à `cc2_l01`. Le modifier existant capture les cibles avant
leur mort via l'observateur existant ; aucun second modifier ni changement de
dégâts. Les autres travaux présents dans le routeur sont conservés.

Vérifié : 66/66 images identiques au rerendu du .blend ; quatre exports par le
service Sprite Clip du Studio inchangé avec aller-retour RGBA exact.
Rapports : `artifacts/dev/class_card_vfx/orage/source_verification.json` et
`workshop_report.json`.

La validation moteur utilise une copie isolée sous
`artifacts/dev/class_card_vfx/orage/project_snapshot` pour ne pas interrompre les
validations concurrentes. Un premier import frais a expiré à 240 s ; le suivant
a terminé sans modification de l'UI. Test ciblé : PASS, 20 tests (dont 10 hérités),
437 assertions, rapport `project_snapshot/artifacts/dev/20260927-192747-test-test_unit_test_consumable_cards_orage_vfx.gd-07097632/summary.json`.
Un dossier output copié par erreur a été retiré uniquement de cette copie après
audit de chacun des 79 520 fichiers ; origine intacte, preuves dans
`temporary_copy_audit.json` et `temporary_copy_cleanup.json`.

Capture finale exécutée dans le projet courant après disponibilité du moteur :
PASS, 84 images à 30 poses/s, 229 contrôles, trois cibles réelles dans les deux
vues. `artifacts/dev/class_card_vfx/orage/combat/report.json`, `godot.log`,
`capture_process.json` et `capture_manifest.json`. Aucun diagnostic moteur dans
ce dernier lancement ; les sources sélectionnées restent identiques après
capture. Inspection native de l'anticipation, du contact, des fragments et de la
fin aux deux échelles. Aucun effet restant à 0,93 s. L'export animé alterne
détail et caméra normale : `combat/orage_du_passage.gif`, 2,8 s, sans retouche.

Parcours vérifié via les services existants : préparation, entrée du troisième
combat, commande publique (3 PA et une copie), sauvegarde effective sur disque,
remontage de la Battle avec PV/PA/case exacts et cible morte conservée dans le
checkpoint, aucun éclair rejoué, bilan puis sauvegarde/reprise de ce bilan.
Les victoires précédentes et la victoire de bilan sont explicitement des
fixtures ; la revue visuelle augmente les PV et repositionne les trois ennemis.
Le contrôle de commande publique repart de PV normaux. Pas de test d'équilibrage.

Corrections du banc pendant la validation : démarrage complet du runtime Cartes,
attente de la bannière de tour, profil utilisateur neuf, relecture du checkpoint
disque (le getter public refuse volontairement un combat en cours), limite de
frames moteur adaptée. Une déconnexion WASAPI a invalidé un essai ; la dernière
capture utilise le pilote audio Dummy, sans changer l'audio du jeu interactif.
Les scènes finales sont chargées dans Blender sous « Orage final - … » et
inspectées, scènes précédentes conservées.

Suite Cartes finale dans le projet courant : PASS, 231 tests, 17 240 assertions,
24 scripts, zéro échec ni diagnostic moteur. Rapport complet :
`artifacts/dev/20260927-194229-test-cards-6a60846a/gut-strict-report.json` et
`summary.json`. Les cinq scripts propres au pilote passent le formatteur ;
`git diff --check` du routeur passe. Aucun changement de source runtime depuis
la capture finale.

État final : produit, intégré au catalogue public Cartes, contrôlé en jeu et
aperçu GIF ouvert dans Codex. Le jugement esthétique reste à valider par le
joueur. Les propositions E/F/G restent en attente de choix, sans production.
