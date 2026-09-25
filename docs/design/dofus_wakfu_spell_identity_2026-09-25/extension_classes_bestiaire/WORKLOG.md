# Extension classes et bestiaire — suivi

Lecture commencée le 25 septembre 2026. Git vérifié : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`. Aucun changement suivi existant ; conserver les études non suivies.

Objectif : étudier les classes non couvertes par le premier dossier et les systèmes de rencontres DOFUS/WAKFU, monstres ordinaires compris. Relier les sorts aux contraintes du combat et au projet de cartes consommables.

Périmètre de lecture : les catalogues consultés affichent 19 classes DOFUS et 18 WAKFU. Xélor, Pandawa, Féca déjà couverts partiellement : reste 16 et 15 classes. Lire un noyau de sorts représentatifs par classe sans prétendre épuiser tous les builds. Pour les ennemis, distinguer dégâts observés, coefficients, timing, IA décrite, état de boss et dépendances entre monstres.

État terminé pour cette extension : 80 fiches DOFUS, 75 WAKFU ; cinq par classe restante. Vingt-huit descriptions WAKFU ambiguës relues en complément des panneaux chiffrés. Six rencontres DOFUS / cinq WAKFU, 42 entrées ennemies dont 11 boss. Les guides historiques sont identifiés comme tels ; aucun moteur des jeux exécuté.

## Décisions conservées

- Maintien du drop sur mobs et des sacs ; aucune substitution par un vol automatique de technique.
- Toute clef obligatoire doit disposer d'une voie de salle accessible sans carte précise.
- Distinguer plafond d'ennemis vivants et budget total de renforts/soins ; attacher le butin à une identité initiale.
- Ne pas refaire les cinq salles déjà présentes ; comparer aux règles, à l'IA et à l'économie actuelles.
- Les quatre prototypes proposés sont des spécifications de laboratoire, non implémentées. Les inconnues de sorts ne sont pas des paramètres prêts à importer.

## Fichiers

Neuf documents Markdown dans cette extension : index, deux lectures de classes, deux bestiaires, analyse Catabase, calculs, sources et présent suivi. Deux scripts autonomes et un export des seize modèles. Le README parent pointe vers l'extension ; les autres études non suivies sont conservées.

## Vérifications

- `node docs/design/dofus_wakfu_spell_identity_2026-09-25/extension_classes_bestiaire/calculs.mjs` : 16 cas, 32 assertions réussies. Lors du premier lancement, une fraction attendue incorrecte dans le contrôle de probabilité a été corrigée en `88/203` ; l'exécution complète a ensuite réussi.
- `node docs/design/dofus_wakfu_spell_identity_2026-09-25/extension_classes_bestiaire/verifier_dossier.mjs` : réussite ; couverture 80/75, cinq fiches par classe, onze synthèses, 9 documents, 45 tableaux, 27 liens locaux et syntaxe de 171 URL distinctes. Rapport complet dans `artifacts/dev/dofus_wakfu_spell_identity_2026-09-25/extension_classes_bestiaire/validation.json`.
- Vérificateur du dossier parent relancé après ajout du lien : réussite, 91 sources conservées, 20 liens locaux, aucune erreur. `git diff --check` réussi sur les fichiers suivis ; les documents de cette étude sont non suivis et sont contrôlés par les vérificateurs documentaires, pas par cette commande Git.
- Base Git vérifiée à nouveau en fin de rédaction : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`.
- Aucun changement de gameplay, import moteur, test de combat ou essai humain. Aucun commit/push demandé ni effectué.

## Suite de fond

Avant implémentation : préciser dans le client cible les états/modes signalés incomplets, notamment Roublard et Sacrieur WAKFU 1.93 ; choisir un prototype de rencontre ; mesurer dans Godot son accessibilité spatiale, sa consommation de copies et deux réponses jouables. Pour la run complète, reprendre le laboratoire économique avec les budgets de soins/renforts et les droits au drop proposés ici. Les calculs présents ne valident pas toute la V1.
