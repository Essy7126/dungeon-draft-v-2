# Passe-Rive — Passage spectral S29
Historique SE : les huit corps directionnels et la validation actuelle sont dans [S31](../passe_rive_s31/spectral/VALIDATION.md).
Prototype approuvé puis intégré le 28 septembre 2026.

## Résultat
Bond spectral (`cc2_a05`), Au-delà du front (`cc2_r05`) et Permutation (`cc2_r08`), normaux et améliorés, utilisent la famille Passage spectral.

- 12 poses corporelles dessinées SE ; atlas séparé de huit dessins du voile.
- Durée 0,86 s ; résolution à 310 ms, corps invisible à ce marqueur.
- Pivot du buste, effacement, réapparition après changement de position, retour au repos natif.
- Les sept autres vues conservent le corps natif de leur direction, avec le même voile, la même disparition et la même horloge. Le pivot n'y est **pas encore dessiné**.
- Permutation conserve ses effets dédiés aux deux sites. Le voile remplace les anciens portails génériques de Bond spectral et Au-delà du front pour ce backend seulement.
- Les téléportations cc2 sans chemin requis changent instantanément la position visuelle ; les ruées gardent leur interpolation et leur réception. Aucune règle, portée, coût ni quantité de cartes n'a été modifiée.

## Calibration
Référence canonique : stature 214 px. Atlas corps original 1448 × 1086, cellules 362 × 362. Stature de référence mesurée 345 px ; projection de largeur fixe 0,85. Hauteurs des douze dessins : 345, 346, 346, 346, 344, 345, 345, 345, 346, 346, 344, 343 px.

Les pieds sont calés par métadonnées ; aucune normalisation d'échelle par image. Les couleurs passent par la calibration commune par matière. Le premier et le dernier instant visibles emploient le repos natif, avec un court fondu de raccord. Les contours de capuche et le style de trait des dessins générés restent légèrement différents : identité pixel à pixel non revendiquée.

Les fichiers PNG générés n'ont pas été redessinés, redimensionnés ou recolorés hors moteur. `build_metadata.py` mesure les sources et écrit uniquement le JSON de calibration. Les dessins ont été produits avec **imagegen intégré**.

## Synchronisation et nettoyage
Le backend observe le déplacement effectif du UnitView après émission du marqueur. Une pose ne peut pas confirmer à elle seule une téléportation. En cas de déplacement absent, la séquence revient au repos sur place sans effet de réapparition confirmé. L'annulation, la mort, la désactivation et l'arrêt du backend restaurent la visibilité.

L'arrivée instantanée publiée par Battle est différée jusqu'après l'enregistrement du rapport VFX, et protégée par la génération de mouvement contre une annulation. Elle ne déclenche pas la réception d'une ruée et ne coupe pas le geste.

## Vérification visuelle et vrais lancers
[Animation capturée dans Godot](review/passage_spectral_en_jeu.gif) · [Planche de raccord](review/raccord_en_jeu.png) · [Provenance et faits des six lancers](review/provenance.json).

Capture finale : `artifacts/dev/passe-rive-spectral-20260928-203312/`.
**Six lancers réels, 201 contrôles, succès** : trois cartes × base/améliorée. Contrôles du marqueur invisible, absence de déplacement anticipé, case d'arrivée, absence de trajet interpolé, retour natif, PA et copie consommée. Bond spectral et Au-delà du front franchissent une case réellement bloquante dans la fixture. Une destination occupée est refusée sans consommation ni départ. Pas de portails génériques en doublon.

La scène emploie le vrai Battle et le profil public. Main préparée, IA suspendue, caméra rapprochée ×2,4. Ce n'est pas une validation de toutes les salles ou d'une run complète. Le champ historique `card_count` du rapport de base ne représente pas le nombre de cartes vérifiées : il y a bien six lancers S29.

La première capture mécanique réussie (`passe-rive-spectral-20260928-202854`, 702 contrôles) a révélé les portails superposés. Elle est conservée comme étape de diagnostic, pas comme rendu retenu.

## Sources, prompts et reproduction
- Sources conservées : `passage_sequence_v01.png`, `passage_vfx_v01.png`, `passage_storyboard_v01.png`.
- Prompts : `prompt_sequence_v01.txt` et `prompt_vfx_v01.txt` ; prompts du prototype également conservés.
- Runtime : `assets/characters/PasseRive/sprites_s29/{passage.png,veil.png,passage.json}`.
- Lecteur : `characters/achilles/2d/passe_rive_spectral_body.gd` et backend public S19.
- Mesures : `tools/class_card_vfx/passe_rive_s29/build_metadata.py`.
- Essai manuel : `pwsh -File tools/class_card_vfx/passe_rive_s29/play.ps1`.
- Capture reproductible : même commande avec `-Capture`.
- Suite : `./dev.ps1 test passe-rive`, complétée par les suites de mouvement, récupération, Permutation, autosprite et VFX communs.
- Résultats définitifs : [VALIDATION.md](VALIDATION.md).

Les travaux parallèles de Convergence, Contre et de l'interface Cartes ont été préservés. Le routeur partagé reçoit seulement le test de propriété du voile S29 et sa fonction d'accès au backend.

