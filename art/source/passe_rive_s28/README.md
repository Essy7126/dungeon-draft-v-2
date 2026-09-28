# Passe-Rive S28 — Prélèvement

La carte `cc2_t07` joue un geste dédié : viser, saisir, ramener vers le sternum et relâcher. Le même bras reste actif. Ce binding s'applique à la version de base et à l'amélioration.

## Production

- **imagegen intégré**, avec les références locales du prototype accepté et du repos natif. [Prompt initial](prompt_sequence_v01.txt), [correction des intervalles](prompt_sequence_v02.txt), [correction retenue](prompt_sequence_v03.txt).
- [Atlas retenu](prelevement_sequence_v03.png), RGBA 1448×1086 ; copie runtime strictement identique dans `assets/characters/PasseRive/sprites_s28/drain.png`. SHA-256 : `56a27eaaa2d3cfc860605191a25ea6c4bb003d4251bace8ce148f7f929a0c6f1`.
- 12 positions temporelles, 11 dessins distincts. Séquence zéro-indexée : `0,1,2,3,4,5,6,7,8,1,10,11`. La cellule 9 est rejetée pour changement de bras ; la pose basse correcte sert au relâchement. Les essais rejetés restent dans le dossier de travail S28.
- 940 ms ; résolution à 330 ms, pose de saisie 5. Une seule horloge pour corps et filament.
- Appui au pied enregistré par pose, hauteur source 343 px, hauteur canonique 214 px multipliée par le profil de salle. Largeur constante ×0,84, ajustée après comparaison au repos natif. Palette par matière via le shader partagé ; aucune retouche des pixels par script.

## Effets et règles

Le rapport réel de `SpellCaster` confirme le filament violet uniquement si des PV ont été retirés. La cible est mémorisée en coordonnées mondiales, puis le filament rejoint la main enregistrée à chaque pose. Les particules vont de la cible vers Passe-Rive. L'éclat ivoire/sauge apparaît seulement si `healing_total > 0`. Il remplace le grand pulse générique pour ce soin précis ; les nombres de PV restent ceux du combat.

Le soin et les dégâts restent calculés ensemble par les règles existantes. Le retour visuel n'ajoute aucun soin et ne déplace pas la résolution. Cas de base : 0,75 P magiques puis 50 % des PV retirés ; amélioration : 0,9 P. Les modificateurs de soin et le plafond de PV restent applicables.

Annulation, changement de mode et arrêt du rendu coupent l'effet. Une confirmation ne peut pas être réutilisée au lancer suivant.

## Périmètre

Le nouveau dessin est **SE uniquement**. Les sept autres directions gardent leur geste directionnel existant (`t_mark`) et les VFX usuels. Aucun dessin SE plaqué sur une autre orientation. Repos, marche, ruée, autres cartes et règles de jeu conservés.

Les différences de trait entre sprite natif et peinture générée restent visibles en gros plan : taille et palette calibrées ne signifient pas identité parfaite du costume au pixel près.

## Vérification

Tests : `./dev.ps1 test passe-rive -TimeoutSeconds 180`. S28 couvre carte/amélioration, libération unique avec saut de temps, appui/main/échelle sur trois profils, sept directions de repli, annulation, absence de flux sans dégâts, absence d'éclat sans soin et nettoyage.

Capture réelle : `./tools/class_card_vfx/passe_rive_s28/play.ps1 -Capture`. Cinq lancers : base blessé, amélioré blessé, PV pleins, absorption totale par bouclier, cible à un PV. La fixture utilise le backend public et la vraie carte ; elle prépare la main/PV, suspend l'IA et agrandit la caméra ×2,4. La transition de victoire est différée uniquement pour vérifier le retour du coup fatal sans récompense de fin de combat interférente.

Relecture visuelle : `build_review.py <capture> <sortie>` assemble les captures du moteur à leurs durées réelles et vérifie le hash de l'atlas, la séquence et la calibration constante. Résultats finaux consignés dans la fiche `docs/ai/PASSE_RIVE_S28_2026-09-27.md`.

[Animation capturée en jeu](review/prelevement_en_jeu.gif) · [raccord au repos](review/raccord_en_jeu.png) · [provenance](review/provenance.json).

Capture finale du 28 septembre : **234 contrôles PASS**, cinq lancers, aucun `ERROR`/`SCRIPT ERROR` ni avertissement dans le journal. Base : 14 PV retirés / 7 soignés ; amélioration : 16 / 8 ; PV pleins : 14 / 0 ; bouclier intégral : 0 / 0 ; coup fatal sur un PV : 1 / 1 (arrondi des règles). Dossier `artifacts/dev/passe-rive-prelevement-20260928-080707`.

Suite Passe-Rive finale : **39 tests / 4 292 assertions PASS**, rapport `artifacts/dev/20260928-080914-test-passe-rive-ceac3b6c/gut-strict-report.json`.

Régression du routeur partagé : **34 tests / 3 551 assertions PASS**, rapport `artifacts/dev/20260928-081016-test-test_unit_test_class_card_vfx.gd-3f33acb2/gut-strict-report.json`. Les autres soins et VFX restent couverts par leurs tests existants. Vérification de format des sept scripts ciblés et `git diff --check` réussis.

Essai interactif : `./tools/class_card_vfx/passe_rive_s28/play.ps1`, puis « Jouer la carte ». Le bouton vitesse permet une lecture à ×0,5.
