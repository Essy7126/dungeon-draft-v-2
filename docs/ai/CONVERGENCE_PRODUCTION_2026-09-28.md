# Convergence — production de la planche J

Autorisation du 28 septembre : « Travails sur convergence ». Planche validée :
`docs/design/vfx_avant_production_lot3_2026-09-27/j_convergence.png`.

État initial Git : uniquement `art/source/passe_rive_s28/review/raccord_en_jeu.png.import`
non suivi ; à préserver. Aucun agent délégué. Production limitée à `cc2_t08`,
normale et améliorée, dans la run Cartes actuelle.

Décisions : quatre pétales indigo/violet/lilas, cœur ivoire ; contraction,
traits sur les déplacements confirmés, ouverture selon les axes réels de grille,
contacts locaux confirmés. Rayon d'attraction Manhattan 2 distinct de la croix
de cinq cases. Pas de terrain durable, ni d'écriture des positions par le VFX.
Le runtime déplace instantanément les ennemis attirés : les traits accompagnent
ce déplacement réel ; aucune interpolation fictive des personnages.

Production terminée : source Blender et quatre atlas, export Studio inchangé,
lecteur dédié et compagnon de faits de présentation. Refus, blocages, mort,
absorption, isolation et nettoyage vérifiés ; rendu à la caméra normale,
commande publique puis sauvegarde/reprise et bilan contrôlés.

Avancement : les 34 poses sont rendues et assemblées sans retouche ; rerendu
du `.blend` égal pixel par pixel (34/34), quatre exports Studio avec roundtrip.
Rapports : `artifacts/dev/class_card_vfx/convergence/source_verification.json`
et `workshop_report.json`. Le premier import a révélé un nom de type incomplet,
corrigé en `DamageResolver.DamageResult`. Les données de zone ne filtrent pas
les murs/alliés dans le moteur : les bras visuels filtrent séparément les murs,
les contacts reposent uniquement sur les résultats de dégâts/absorption.

Des modifications parallèles existent dans le dossier joueur / bilan Cartes ;
ne pas les écraser et ne pas leur attribuer cette passe.

Vérification du 28 septembre : `./dev.ps1 test cards` terminé PASS,
317 tests, 21 298 assertions, aucune erreur. Rapport complet :
`artifacts/dev/20260928-192012-test-cards-9c8cccfc/gut-strict-report.json`.
La suite Convergence compte 17 tests réussis (7 spécifiques et 10 hérités).
Les lecteurs, faits et tests dédiés passent le formateur sans changement.

Première capture : rendu et contacts létaux corrects, mais scénario incomplet
car il réutilisait une vue d'ennemi tué. Logs conservés dans
`artifacts/dev/class_card_vfx/convergence/attempts/01_initial_fixture/`.
Correction : nouvelle salle pour chaque clip ; commande publique de reprise
sur l'ennemi le plus robuste. Capture finale PASS : 90 images natives, 253
contrôles, trois attractions et trois contacts dans chaque clip normal/amélioré.
Commande publique, checkpoint disque, reprise des positions/PV/consommation et
bilan réussis. Sources du runtime et de capture inchangées lors du contrôle final.

Aperçu : `artifacts/dev/class_card_vfx/convergence/combat/convergence.gif`,
90 images, 3 000 ms, SHA256
`25f18515ca170be544b4c0cb40665f14564d924c5e1f0cf9cba29a6cee8ee974`.
Images inspectées : détail 004/011, caméra normale 011/023. Rapport synthétique
avec accès aux preuves : `artifacts/dev/class_card_vfx/convergence/integration_report.json`.
Reste : appréciation artistique de Paolo sur cette V1 ; aucun travail technique
obligatoire laissé ouvert pour cette production. Aucun commit effectué.
