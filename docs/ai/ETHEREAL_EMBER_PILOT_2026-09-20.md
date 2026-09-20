# Pilote Éclat de braise — DA C

Demande : essayer un sort animé avec la DA C explicitement choisie (transparence, lumière, volutes).

Décision : prototype autonome dans `tools/labs/ethereal_ember_study/`, rendu Godot par champs de flux animés, filaments lumineux, braises et fumée translucide. Le décor et le personnage sont ceux du dépôt. Aucune modification du routeur commun ni du catalogue en cours de modification par d'autres tâches.

Réalisé : scène rejouable avec pause, retour image par image, ralenti, comparaison avec/sans effet ; trois vues (agrandissement, fond clair, fond sombre). Deux itérations après inspection : suppression d'un aspect trop électrique, correction des régions de décor, élargissement et adoucissement des voiles. Neuf braises déterministes, extinction à 1,9 s, boucle d'atelier 2,4 s. Les captures proviennent réellement de Godot, sans image générée ni retouche du rendu.

Vérification moteur : capture native Godot 4.7.1 Compatibility/OpenGL sur RTX 4070 Laptop, 72 images 1360×860 ; dernière exécution de capture terminée avec code 0 et sans diagnostic d'erreur dans `artifacts/dev/ethereal_ember_study/godot.log`. Première tentative sandbox refusait cache/certificats ; reprise native autorisée réussie. Scripts formatés individuellement via `dev.ps1`, puis vérification sans modification réussie. Inspection des images au pic, pendant les volutes et la dissipation. Encodage terminé avec code 0 : GIF normal de 2,4 s et ralenti de 4,8 s, 72 images chacun, 30 images actives successives distinctes et retour exact du décor à son état sans effet. Preuve : `artifacts/dev/ethereal_ember_study/encode_report.json`, avec empreintes des sources.

Présentation : GIF normal ouvert dans Codex ; scène interactive lancée via `preview.ps1`, log de lancement séparé sans diagnostic moteur (`interactive.log`).

Limites : laboratoire autonome avec acteur fixe, pas une validation en combat. Échelle à régler à la caméra réelle ; renderer Forward+ et impacts multi-cibles non vérifiés. Aucun changement au routeur ni aux règles. Pas de nouveau test unitaire pour cette étude visuelle ; vérification par rendu et capture. La charte de référence est `docs/design/achilles/vfx_art_direction_proposal_2026-09-20.md`.

Suite : recueillir l'avis artistique sur cet essai avant toute intégration ou déclinaison. Le guide est `tools/labs/ethereal_ember_study/README.md`.
