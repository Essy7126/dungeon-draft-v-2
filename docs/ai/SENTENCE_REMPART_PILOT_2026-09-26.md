# Sentence du rempart — pilote Blender / Godot

Demande du 26 septembre : commencer le pilote après ouverture de Blender.
Décision : modèle original d'airain, mouvement éditable, couches de contact séparées,
comparaison V1/V2 dans Godot, raccord limité à la run Cartes.

État initial : Blender 5.1.2, scène de démarrage non modifiée. Le connecteur fonctionne
avec son protocole de repli. Nombreuses modifications étrangères sur Passe-rive,
la sélection, le routeur et les tests : les préserver.

Travail en cours : source dans `tools/class_card_vfx/sentence/`, modèle dans
`art/source/vfx/sentence_rempart/`, runtime dans `vfx/class_cards/sentence/`.
Vérifications prévues : rendu et mouvement Blender, comparaison Godot, annulation,
contact et isolation Cartes, suite cards et suites communes si concernées.

Point à résoudre : l'anticipation doit précéder la résolution réelle ; ne pas
retarder les chiffres après un dégât déjà présenté par les autres systèmes.

14:20 UTC : modèle 26 objets et 48 poses rendu/assemblé. Cadre élargi après
détection d'une coupe du manche ; marge de toutes les poses vérifiée par pack.py.
Sources et PNG préservés. Raccord avant begin_cast dans battle.gd ; confirmation
par le routeur existant. Les appels directs commencent au contact. Son original
sur le bus SFX. Laboratoire interactif/capture et export de clip via Studio ajoutés.

Premier test sandbox : échec import (certificats/dépendances Windows + préchargement
PNG trop tôt). Chargement de texture différé corrigé. Test hors sandbox en cours :
`artifacts/dev/20260926-141725-test-cards-a0827ff3/`. Import réussi ; GUT démarré.
Suite à faire : relire résultat, contrôle visuel du laboratoire, corrections,
tests supplémentaires d'annulation si nécessaire, audio et validations communes.

## Point de reprise après intégration

- Source Blender sauvegardée et toujours ouverte, scène dédiée de 26 objets,
  48 poses à 30 images/s, contact image 16. Les autres scènes sont conservées.
- Atlas transparent 3072 × 2304 ; rendu du volume, traînée, éclat et six débris
  composés séparément. Le retrait Godot dégage la cible entre 0,63 et 0,99 s.
- Préparation de 0,5 s avant le `begin_cast` réel. Revalidation des PA à cet
  instant ; annulation si fermeture, mort, échec ou remplacement de séquence.
  Un report direct démarre au contact, sans armement tardif.
- Son original sur le bus SFX, limité au coup confirmé. La V1 des autres cartes
  et le mode Classique sont conservés. Aucune modification de règles du sort.
- Le laboratoire `tools/class_card_vfx/sentence/run.ps1` permet V1/V2 et deux
  distances de caméra. `-Capture` utilise de vraies unités et SpellCaster, puis
  contrôle le chemin Battle, le son, le bilan, la sauvegarde et la reprise.
- Export du marteau par le service Studio : 48 poses, pixels et durées identiques,
  événement contact à 500 ms. Document `art/source/sprite_workshop/sentence_rempart.json`.
  Sa direction E est un champ imposé par Studio, pas une série de vues du VFX.

Preuves au 26 septembre vers 14:40, heure locale :

- `artifacts/dev/20260926-141725-test-cards-a0827ff3/` : 108 tests,
  11 119 assertions, PASS avant les derniers contrôles d'annulation.
- Exécution parallèle `20260926-142932-test-cards-ad9054d9/` : 110/111 tests,
  seul échec sur l'apparence Passe-rive S19. Les six tests Sentence passent.
  Cette exécution précède l'ajout du contrôle d'ancien report dupliqué.
- `artifacts/dev/class_card_vfx/sentence/combat/report.json` : 180 contrôles,
  126 captures, PASS ; 20 dégâts et 3 PA dans les deux variantes. Dernière
  exécution complète 12:37:43–12:38:33 UTC, code moteur 0, sans erreur moteur.
  La victoire du contrôle de reprise est une fixture, pas une partie jouée.
- `artifacts/dev/class_card_vfx/sentence/combat/workshop.log` : export Studio OK,
  `pixel_roundtrip=true`, contact 500 ms. Aucune approbation artistique simulée.
- `artifacts/dev/20260926-143508-selftest--7f671bfa/` : harnais et analyseur strict OK.
- Images de contact/retrait, caméra normale, reprise et vue Blender inspectées.
  GIF natifs encodés ; leur palette seule est quantifiée, sans son.
- Reconstruction dans un Blender séparé avec le script courant : pose de contact
  identique pixel par pixel, même pivot. `artifacts/dev/class_card_vfx/sentence/rebuild_report.json`.
- Audit des ressources : aucun lien externe manquant sur 12 095 fichiers inventoriés
  (`artifacts/dev/class_card_vfx/sentence/resources.json`).

## Livraison vérifiée vers 15:10, heure locale

- Suite globale complète : `artifacts/dev/20260926-143856-test-all-75883e11/`.
  309 scripts, 3 101 tests, 2 924 réussis, 169 échecs, 8 risqués/en attente.
  261 110 / 261 859 assertions. Durée GUT 1 451 s, sans timeout ; crash moteur
  après écriture du JUnit (code -1073741819). Verdict strict FAIL, avec des
  erreurs de contrats 3D, Studio et contenu. Ce résultat ne certifie pas le jeu entier.
- Dans ce JUnit, les sept suites Cartes totalisent 111 tests sans échec. Passent
  aussi réaction/arrivée (7), feedback commun (6), audio de combat (3),
  dédoublonnage (2), grille (3) et récupération visuelle des sorts (6).
- Après la dernière correction de traînée, test isolé du pilote :
  `artifacts/dev/20260926-150857-test-test_unit_test_sentence_rempart_vfx.gd-35a0168e/`.
  Import et verdict strict PASS, 6 tests / 35 assertions, aucune erreur.
- Capture finale 13:07:43–13:08:37 UTC : 184 contrôles, 126 vues, code moteur 0,
  aucune erreur. Inclut destruction de la scène pendant l'armement : aucun
  paiement, dégât ou son résiduel, marteau libéré. Les sources sélectionnées
  restent identiques pendant la capture (`capture_manifest.json`).
- Traînée amincie et placée derrière le marteau ; contact conservé devant.
  Caméra normale, contact, chute et retrait réinspectés. GIF V1/V2 réencodés.
  SHA256 V2 : `09d6e6b1438c3b733fd4776839b2f343705e579060c3af716d2c197bd554e715`.
- Les cinq nouveaux scripts GDScript passent le formatage ; diff sans erreur
  d'espacement sur les fichiers partagés modifiés.
- Comparatif interactif lancé et laissé ouvert pour l'utilisateur (session
  d'exécution 36499). Son lancement automatique a effectué le vrai coup de 20
  dégâts, sans erreur dans `combat/interactive.log`. Fermer cette fenêtre Godot
  quand la revue est terminée ; le processus est conservé volontairement.

Une capture intermédiaire a croisé des erreurs de typage dans le nouveau module
`consumable_card_terrain.gd`, modifié par une autre tâche. Ces erreurs ont été
corrigées par cette tâche avant la reprise ; nous n'avons pas édité ce module.
La capture finale et l'import du test isolé ci-dessus sont postérieurs et propres.

Suite artistique proposée : juger ce pilote en comparatif, puis travailler la
variante renforcée par la garde et les pilotes Bastion/Braise. Aucun autre sort
n'a été refait dans ce lot. Le document Studio est un outil de revue ; modifier
ses durées ne reprogramme pas automatiquement le lecteur du pilote.

Limites : pilote d'un seul sort, rythme et dessin encore à juger par l'utilisateur.
Pas de mesure GPU ni de test matériel modeste. Écoute artistique du son à faire
dans le laboratoire ; le contrôle automatique vérifie son déclenchement.
Le dessin n'accentue pas encore la variante renforcée par la garde du Gardien :
ce sera une comparaison utile après jugement du mouvement de base. La règle de
bonus de Prouesse reste celle du catalogue, sans changement par ce pilote.
Le workspace évolue aussi sur Passe-rive et la sélection : relire Git et la
fraîcheur des rapports avant de reprendre, sans écraser ces travaux.

## Retouche impact et couleurs — livrée vers 15:41

Demande : consolider ce pilote pour la V1. Périmètre strict `g_crash`, run Cartes.
Les 48 poses, les règles, le déclenchement à 500 ms et le son sont conservés.

- Sauvegarde de comparaison avant retouche :
  `artifacts/dev/class_card_vfx/sentence/polish_before/`.
- Palette `bronze-contact-02` dans le script, les matériaux Blender et le manifeste.
  Neuf teintes : bronze chaud, ombres brunes, manche bleu et sceau turquoise.
- Shader : illumination brève des seules faces chaudes claires ; les contours et
  l'émail ne deviennent plus blancs. Intensité du flash objet réduite de 0,65 à 0,38.
- Contact comprimé asymétrique, accents au sol, deux poussières basses et six éclats
  à facettes avec rebond. Tout dépend encore du report de coup confirmé.
- Fichiers de comportement commun non édités pour cette passe. Modifications
  concentrées dans `tools/class_card_vfx/sentence/build_hammer.py`, les matériaux
  du `.blend`, les exports et `vfx/class_cards/sentence/hammer_player.gd/.gdshader`.
- Rendu des 48 images terminé. Reconstruction du contact par le script dans un
  Blender séparé : pixels identiques, pivot conservé. `rebuild_report.json`.
- Suite `cards` : `artifacts/dev/20260926-153224-test-cards-124df1f6/`,
  PASS strict, 13 scripts, 138 tests, 12 012 assertions, code moteur 0.
- Capture finale 13:38:53–13:39:48 UTC : 184 contrôles, 126 images, PASS,
  code moteur 0, sources sélectionnées stables et aucune erreur moteur.
  Même dépense de 3 PA et mêmes 20 dégâts dans les deux présentations.
  Inclut les limites du lancer et le bilan/reprise par fixture déjà documentés.
- Export Studio après cette capture : 48 images, restitution des pixels exacte,
  contact à 500 ms. Empreinte `2b8cdf7de053ff8f3df544d9a03cc869007512dc6b501f565dcb8da98835fc5d`.
  Le lanceur rejette désormais aussi les erreurs de script au démarrage de cet
  export, même si le moteur termine avec un code 0.
- GIF régénéré en 63 images / 2,1 s. SHA256 de `combat/sentence_v2.gif` :
  `a8d1aad87a94682a1e16d64a833204d848cb64e4c5de73b1db66688f93b8a17d`.
  Inspection du contact, de l'armement, du rebond, du retrait et de la caméra normale.
- Ancienne fenêtre du comparatif remplacée par la retouche (session 82485),
  nouveau lancer réel réussi et journal sans erreur. L'éditeur Godot et les autres
  travaux restent ouverts. Source Blender recolorée sauvegardée, scène de 26 objets.

La capture intermédiaire de 13:36:21–13:37:17 UTC était invalide malgré ses
assertions réussies : un nouveau type `ConsumableCardItemDefinition`, ajouté
en parallèle, n'était pas encore connu au lancement. Son import partagé a été
actualisé vers 15:37:51. Les logs intermédiaires sont gardés dans
`artifacts/dev/class_card_vfx/sentence/polish_import_stale/`. La capture et l'export
finaux ci-dessus sont postérieurs et propres. Aucun fichier de ce module n'a été
édité pour résoudre le problème. La tentative de test isolé `153812-…-12f4b1d8`
a rencontré le verrou d'une autre validation et n'a exécuté aucun test ; elle
ne constitue pas une preuve de succès.

Cette passe ne certifie pas la suite globale ni les performances GPU. Les six
éclats et les deux poussières sont volontaires et brefs ; le ressenti et les
couleurs restent à juger en replay. La variante renforcée par la garde et les
autres pilotes n'ont pas été étendus dans cette retouche.
