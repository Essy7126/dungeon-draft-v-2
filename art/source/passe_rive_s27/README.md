# Passe-Rive — Sceau de parade S27

Intégration du prototype accepté en une séquence de 12 poses SE, 720 ms, déclenchement unique à 240 ms (index de pose 5).

## Attribution explicite

| Action | ID | Geste |
|---|---|---|
| Garde brève, normale et améliorée | `cc2_n02` | Sceau de parade |
| Contre préparé, normal et amélioré | `cc2_g05` | Sceau de parade ; la riposte attend toujours un coup reçu |
| Garde de secours | `cc2_fallback_guard` | Sceau de parade ; ne consomme aucune copie |

Les sept autres directions conservent le repos natif de la direction, avec le même événement à 240 ms. Aucune rotation ou projection forcée du dessin SE sur le dos. Le nouveau geste complet reste à dessiner pour ces directions.

Les autres cartes, dont Garde ferme et Bastion vivant (S26), conservent leurs gestes. Aucun changement des règles de protection, coûts ou riposte.

## Intégration

- Corps : `characters/achilles/2d/passe_rive_guard_body.gd`, activé par le backend public S19 et la liaison sémantique `guard`.
- Atlas : `assets/characters/PasseRive/sprites_s27/guard.png`, source inchangée RGBA 1448 × 1086, grille 4 × 3 ; métadonnées `guard.json`.
- Appui du pied enregistré à chaque pose ; échelle constante, hauteur de référence de 214 pixels × taille du profil. Calibration horizontale **0,93**, fixe sur tout le geste. Palette mesurée sur l’atlas complet puis rapprochée du repos par le shader commun.
- Arc de bronze : `vfx/class_cards/passe_rive_guard_ward.gd`, couche séparée liée à la main. Le routeur VFX le confirme uniquement après un rapport de sort réussi avec un gain de bouclier positif. Durée 240 ms ; annulation et sortie de mode le masquent. Les icônes de statut restent celles du jeu.
- Pas de rendu déformé par interpolation d’images, ni de rééchantillonnage d’échelle entre poses. Le rythme vient des durées différentes des douze dessins.

## Provenance graphique

Généré avec **imagegen intégré**, fond transparent, à partir du prototype S27 v02 et du repos natif SE. [Prompt exact](prompt_atlas_v01.txt).

SHA256 atlas : `07142ab673c0f75bca23a00a77f143e55590f3354e349e335b810568f69b23bf`.

Sources de travail : `C:/Users/paolo/Documents/Codex/2026-09-19/lis-la-conversation-x20/outputs/passe_rive_garde_S27`. `build_metadata.py` lit les pixels pour mesurer les appuis et couleurs ; il ne repeint pas l’image. La planche de concept demeure disponible à côté de l’atlas.

## Validation finale

Capture finale **PASS**, `artifacts/dev/passe-rive-garde-20260927-214503/report.json` : cinq lancers (deux cartes normales, leurs deux améliorations et le secours), **205 contrôles**, 95 captures dont 79 images de film. Import et journal du combat sans `SCRIPT ERROR` ni `ERROR:`.

Les cinq gains de protection de la fixture sont 8 / 16 / 5 / 8 / 21 ; chaque coût correspond à la carte, quatre copies normales/améliorées sont consommées, le secours n’en consomme aucune et ne peut pas être rejoué dans le même tour. Contre préparé inflige 9 dégâts sur le premier impact reçu dans cette fixture ; le second impact ne relance pas la riposte. Ces valeurs dépendent des statistiques de la fixture, pas d’un nouvel équilibrage.

Revue visuelle : pieds et hauteur se raccordent au repos, bras de garde lisible, arc court sans masquer le visage. La projection et le trait peints restent légèrement différents du repos natif ; ce contrôle ne démontre pas une identité parfaite entre les dessins. Les douze poses apparaissent dans le film et l’échelle reste constante. Source PNG inchangée, hash vérifié. GIF assemblé à partir des captures réelles, erreur de quantification temporelle +1 ms hors pause finale.

Livrables de revue : `outputs/passe_rive_garde_S27/integration_review/` dans le dossier de travail Codex (`garde_en_jeu.gif`, `raccord_en_jeu.png`, `provenance.json`).

Premier passage ciblé : 32 tests / 3930 assertions réussis dans `artifacts/dev/20260927-213554-test-passe-rive-da12f195/gut-strict-report.json`. Couvre garde, précédents gestes S19/S24/S25/S26, toutes les orientations de secours, profil à trois tailles, interruption et événement unique même après un grand pas de temps.

La capture initiale `passe-rive-garde-20260927-213758` avait exécuté les cinq lancers et 206 contrôles fonctionnels réussis, mais reste **exclue de la validation finale** : son démarrage contenait une erreur de chargement d’un nouveau fichier d’interface modifié en parallèle (`consumable_combat_card_view.gd`). La réimportation et la nouvelle capture ci-dessus ont réussi. Trois relances de validation n’avaient pas démarré car le verrou moteur était occupé par d’autres travaux ; ce ne sont pas des tests exécutés. Le lanceur attend désormais ce verrou avant import et capture.

Banc : `tools/class_card_vfx/passe_rive_s27/play.ps1`, option `-Capture`. Utilise le véritable combat, le backend public et SpellCaster ; main préparée, acteurs positionnés, caméra agrandie, IA suspendue. Pour Contre préparé, un impact adjacent réel via le résolveur est déclenché après retour au repos pour vérifier une seule riposte. Ce banc ne prétend pas jouer une run complète depuis le menu.
