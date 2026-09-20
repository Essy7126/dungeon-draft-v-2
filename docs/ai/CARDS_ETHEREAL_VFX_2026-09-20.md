# Reprise éthérée — run Cartes uniquement

## Complément demandé : états durables et application en combat

Nouvelle demande après livraison : appliquer les effets à toutes les cartes et aux états/effets durables. Implémentation : animation continue du feu maintenu, restauration des états/boucliers déjà présents et des vues créées tardivement, retrait forcé immédiat, nappes éthérées des surfaces dynamiques calées sur les polygones du terrain. Ajout mouillé/poison/choc et correspondance sémantique pour les états d’équipement : **21 familles et 23 statuts explicites**. Les règles restent autoritaires.

La capture dans la scène réelle a révélé les nappes arrière masquées sous les dalles : profondeur corrigée et dessin avant le modèle. Bouclier élargi et marque déplacée au-dessus du corps ; intensité du maintien ajustée sur fond clair. Les surfaces attendent l’insertion des dalles opaques du service terrain avant de se placer au-dessus, dans la même couche de sol. Ni le Z des acteurs ni le moteur des règles ne sont modifiés.

Sonde visuelle native `tools/class_card_vfx/combat_probe.tscn`, sortie isolée `artifacts/dev/class_card_vfx/persistence/`. Scénario contrôlé : vrai combat de départ Cartes, IA suspendue via le Studio, personnages rapprochés, main préparée, huit vrais lancers, caméra native agrandie ×2,4. Soixante images montrent le maintien de six effets (bouclier et cinq états), puis captures des sols feu/givre et du nettoyage. Les réactions sont laissées expirer selon leurs propres durées, jusqu’à huit tours de terrain au maximum.

Galerie recapturée et inspectée : 112 cartes, 48 sorts adverses, 21 familles, deux planches de maintien pour les 23 statuts. Capture native finale **26 contrôles réussis**, 60 images / 2 secondes, Godot Forward+ sans erreur. GIF `artifacts/dev/class_card_vfx/persistence/durable_states.gif`, planche de sols `fire_and_ice_ground.png`, état nettoyé `expired.png`. Les empreintes de `encode_report.json` correspondent aux sources finales ; aucune retouche des captures.

Validation finale à 21:50 : **PASS strict, 20 tests / 1 265 assertions**, import en recovery réussi, aucune erreur ni fuite dans la suite VFX. Rapport `artifacts/dev/20260920-214934-test-test_unit_test_class_card_vfx.gd-7ca5ba5b/gut-strict-report.json`. La première relance avait une attente de taille devenue obsolète après l’agrandissement du bouclier ; elle a été corrigée. Les sept fichiers GDScript modifiés ont passé le formatage ciblé.

Contrôle élargi via `tools/class_card_vfx/validate.ps1` : **64/65 tests**, 3 109/3 110 assertions. Les six suites VFX/combat/isolation passent leurs 58 tests et 3 061 assertions, mais l’ensemble est **FAIL strict** : le test Studio `test_update_real_encounter_candidate_preserves_odyssey_room_without_mutation` échoue sur le snapshot de la salle Odyssée (ligne 143), et l’import éditeur normal / fermeture signalent Spine et des ressources non libérées. Rapport `artifacts/dev/20260920-214349-class-card-vfx-regression-662b3217/gut-strict-report.json`. Aucun correctif Studio/Spine dans cette tâche ; ne pas annoncer de PASS global, ni attribuer ces échecs à une régression sans comparaison de référence. Le harnais habituel `dev.ps1` utilise le recovery mode et donne le PASS VFX isolé ci-dessus.

État : complément livré. Les résultats de la livraison précédente ci-dessous sont historiques. Manifest des preuves courantes : `artifacts/dev/class_card_vfx/persistence/verification.json`.

## Livraison précédente (avant le complément)

Demande explicite : reprendre les effets existants dans la DA C et couvrir chaque carte et chaque sort adverse, exclusivement dans la run Cartes. Cette demande autorise la déclinaison et l’intégration du pilote sans attendre deux pilotes supplémentaires.

Implémenté : 112 cartes + 2 gestes, 48 sorts adverses (dont 10 cartes partagées), 19 familles procédurales, 20 identifiants de statut. Shaders natifs Godot translucides ; feu repris du pilote ; vols, avertissements différés, invocations, états et feedbacks observant les faits réellement appliqués. Activation conditionnée à la session Cartes du combat lié, pas aux seuls identifiants. Les surfaces persistantes gardent leur service existant.

Fichiers : `vfx/class_cards/`, branche dédiée dans `core/vfx_manager.gd`, `tools/class_card_vfx/`, `test/unit/test_class_card_vfx.gd`. Préserver les nombreuses modifications antérieures des autres tâches, notamment drops, catalogues de règles, progression et UI. Aucun changement de coût, portée, dégâts ou rythme des règles.

Vérification finale : `./dev.ps1 test test/unit/test_class_card_vfx.gd` PASS strict, 16 tests / 1 182 assertions. Rapport `artifacts/dev/20260920-201832-test-test_unit_test_class_card_vfx.gd-97244a83/gut-strict-report.json`. Tous les vrais casts du catalogue, formes et invocations incluses, ont passé ; cas particuliers de tir annulé, absorption totale et isolation classique vérifiés.

Galerie GPU créée : 66 frames, 10 pages de cartes, 4 pages d’ennemis, 2 pages de familles, une planche d’états. Première capture inspectée (sélection, deux pages de familles, boss). Dernière recapture effectuée après francisation des labels et correction du sélecteur. Sortie `artifacts/dev/class_card_vfx/ethereal/gallery/` ; sources et instructions dans `tools/class_card_vfx/README.md`.

Régression finale : 10 suites, **125 tests / 7 640 assertions satisfaits**. Sept suites sont en PASS strict, dont VFX Cartes, présentation différée, garde d’Achille, lifecycle, isolation des runs et règles/progression Cartes (25 tests / 4 086 assertions). Paris, kit d’Achille et philosophe échouent au contrôle strict de fermeture pour ressources non libérées, sans assertion en échec ; ne pas présenter l’ensemble comme PASS. Détail et liens vers chaque rapport : `artifacts/dev/class_card_vfx/ethereal/verification.json`. Le comparatif historique `artifacts/dev/class_card_vfx/baseline.log` avait déjà reproduit les fuites Paris/Achille avec le gestionnaire original ; aucun nouveau comparatif du philosophe n’a été exécuté ici.

Capture et encodage finaux terminés le 20 septembre à 20:19, sortie code 0 : Godot 4.7.1 / Forward+ D3D12 / RTX 4070 Laptop, sans erreur de shader ni de capture. Les 112 cartes et 48 sorts sont présents, GIF de 66 frames / 2,2 secondes. Dernières pages familles/boss inspectées, titres et sélecteur vérifiés. Empreintes des sources dans `encode_report.json`. Les huit scripts GDScript propres à la tâche ont passé le formatage ciblé ; aucun formatage global.

État : intégration et livraison visuelle terminées. Restent le jugement artistique de l’utilisateur et les éventuels ajustements demandés. Les fuites de suites communes sont consignées séparément et ne sont pas masquées. Deux tentatives de lancement ont été refusées par le verrou du harnais pendant une autre validation ; la dernière exécution complète ci-dessus les remplace comme preuve.
