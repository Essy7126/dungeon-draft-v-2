# Achille — présentation des sorts V3

Contrat du 8 septembre 2026. Cette passe ne modifie aucun coût, dégât, quota, achat ou condition de maîtrise. Le corps retenu est Achille classique, harmonisé sur les dessins de repos originaux de `sprites_cour_des_sources_v1`. Les validations des dessins et des combats accompagnent séparément ce contrat.

## Expédition actuelle

Le parcours Catabase utilise désormais [ExpeditionBuildCatalog](../../../core/expedition/expedition_build_catalog.gd), avec quatre techniques d'entrée et 42 identifiants `exp_*` supplémentaires : racines, cartes apprises, mutations, signatures, légendes et serments. Le profil historique présenté ensuite ne décrit donc pas à lui seul le kit accessible dans cette expédition.

La [table de présentation d'expédition](../../../data/visuals/achilles/achilles_expedition_spell_presentation.gd) couvre explicitement les 42 identifiants. Elle conserve leur `spell_id` de combat/persistance et associe seulement un archétype de corps. Un préfixe `exp_` inconnu ne reçoit pas automatiquement une identité d'Achille. Les nouvelles cartes réemploient des familles de gestes ; aucun dessin unique par identifiant n'est revendiqué.

| Famille / forme réelle | Geste | Effet |
|---|---|---|
| Frappe d'ouverture ; Crochet et ses formes ; Entaille et ses formes ; Moisson simple ; Heurt et Bélier | attack | Impact physique confirmé |
| Fauchage / Fracas ; Moisson de guerre ; Cercle de bronze ; Tempête | sweep | Balayage et impacts sur les seules cellules résolues |
| Tir de guet | bow | arrow / impact |
| Trait de rupture | bow | arrow_heavy / impact_heavy avec poussée prévue par le profil |
| Tir de traverse | bow_piercing | arrow_piercing / impact_piercing |
| Horizon percé | bow_death | arrow_death_line / impact_death_line |
| Marque du chasseur / Sentence du guetteur | bow / bow_piercing | arrow_reach / impact_reach ; cette pose précise ne rend pas le tir perforant |
| Feinte et ses formes ; Marche du survivant / purificatrice | dash | Départ/réception liés au déplacement confirmé ; soin seulement si réellement reçu |
| Contretemps / Revers du Danseur | attack | Frappe puis téléportation conditionnelle autoritaire |
| Garde d'Éaque ; Posture / Bastion mobile ; Serment du rempart | guard | Protection sur création de bouclier confirmée |
| Second souffle / Souffle retenu / Serment de survie | guard | heal du philosophe sur soin confirmé, plus protection si créée |
| Trait de braise | bow | fire / hellfire de l'atlas de Paris |
| Brasier cruciforme / Couronne de braise | volley | fire / hellfire sur la croix réellement résolue |
| Entrave de givre / Verrou de givre | bow / bow_piercing | frost de l'atlas de Paris |
| Ligne fulgurante | bow_death | arrow_lightning / impact_lightning dans l'atlas dédié |
| Serment du brasier | sweep | hellfire sur les cellules de la croix résolue |

Les lignes natives de Traverse, Horizon et Foudre proviennent de `Spell.aoe_shape = LINE`. Elles ne possèdent pas artificiellement le `piercing_enabled` ni le plafond de cibles d'une maîtrise historique. `target_geometry_source = native_spell` et `target_count_policy = native_area` distinguent ces règles.

Les douze tirs de `PROJECTILE_FLIGHT_IDS` disposent d'un délai réel de 0,20 s dans le catalogue : départ au lâcher, vol, puis résolution des PV. Ce réglage du scheduler concerne Tir de guet, Rupture et ses deux formes, Marque et sa signature, Braise et ses deux formes, Givre et sa signature, Foudre. Le renderer ne retarde pas les dégâts de son côté et ne joue pas un vol après leur retrait. Une résolution sans délai reçoit seulement son impact confirmé.

Feu, glace et foudre correspondent ici au véritable `Spell.element`, avec dégâts, terrain et contrôles gérés par le combat. Le corps reste dans sa palette classique. Les capacités de soin exposent `heal_animation` ; seul le rapport réel de soin permet de jouer cet effet. La sélection d'un sort de marque, de sacrifice ou de contrôle n'est jamais assimilée à son activation sur une cible.

## Profil historique Odyssey / maîtrises

Le [profil de progression](../../../data/runs/progression/odyssey/achilles_progression_profile.tres) fournit quatre sorts et quatre emplacements : Frappe du Péléide, Percée fulgurante, Tir du Pélion et Garde d’airain. Le [catalogue](../../../data/characters/achilles/doctrines/achilles_mastery_catalog.tres) contient 36 maîtrises, dont neuf avancées.

Aucun cinquième sort appris n’est branché dans ce profil historique. Fléau, Perforante, Ligne de mort, Volée et Rempart sont des évolutions des quatre sorts ; leurs identifiants de combat restent inchangés. Des gestes dédiés les distinguent sans inventer un nouveau sort disponible dans le codex.

L’[inventaire V2](achilles_spell_animation_inventory_v2.md) donne les 36 identifiants et leurs règles. Son choix de réutiliser un même geste d’arc pour Perforante et Ligne de mort est remplacé ci-dessous. Ses quantités de poses et de salles restent historiques.

## Mapping de présentation

| Technique / évolution | Geste | Projectile | Impact confirmé |
|---|---|---|---|
| Frappe | attack | Aucun | impact |
| Fléau de Troie | sweep | Aucun | sweep puis impacts aux deux cellules réelles |
| Percée | dash | Aucun | dust |
| Bastion mobile | dash | Aucun | guard et impacts après réception et consommation réelle de Garde |
| Tir du Pélion | bow | arrow | impact |
| Allonge du Pélion | bow | arrow_reach | impact_reach |
| Tir rapproché, avec poussée présente dans le profil résolu | bow | arrow_heavy | impact_heavy |
| Flèche perforante | bow_piercing | arrow_piercing | impact_piercing |
| Ligne de mort | bow_death | arrow_death_line | impact_death_line |
| Volée du centaure | volley | arrow_volley | impact_volley |
| Garde / Garde orientée | guard | Aucun | guard |
| Rempart des Myrmidons | guard | Aucun | barrier sur les cellules enregistrées |

Priorité : FAN choisit Volée ; une ligne perforante choisit Perforante ou Ligne de mort selon sa capacité ; sinon `push_distance > 0` dans le profil résolu choisit la flèche lourde ; sinon Allonge choisit la flèche fine de portée ; sinon la flèche de bronze. Les prérequis encore sélectionnés ne remplacent donc pas une nouvelle forme réellement résolue.

Les flèches de ces maîtrises historiques restent physiques. Ce tableau ne couvre pas les cartes élémentaires du catalogue d’expédition décrit plus haut.

## Ce qui conserve le geste

- Fureur lucide, Élan meurtrier, Exécution, Sang pour sang, Colère irrépressible, Œil du centaure et Chasse mobile modifient le rendement sous conditions. Leur achat ne prouve pas qu’un bonus vient d’être appliqué.
- Entaille d’ouverture et Brise-formation conservent les retours de combat sur l’armure, le déplacement et la collision.
- Flèche d’arrêt conserve le projectile de la posture acquise. `stopping_arrow_selected` décrit seulement la capacité sélectionnée et ne choisit jamais à lui seul `arrow_heavy`. Avec Allonge du Pélion, le résultat reste `arrow_reach` ; avec Tir rapproché et sa poussée résolue, il peut être `arrow_heavy`. Aucun effet de gel ou de perte de PM n’est inventé pour une cible sans contrôle confirmé.
- Pas victorieux et Angle impossible utilisent la locomotion après acceptation du déplacement optionnel.
- Garde active, Ancrage, Réplique, Mur aux flèches et Bouclier brisé conservent leurs retours défensifs/offensifs. Le rendu ne consomme pas leurs conditions.
- Les trois sommets, Prédateur, Vengeur d’airain et Le héros invincible conservent le geste de la forme active. Les conversions, restaurations et bonus restent autoritaires.
- Contre d’Éaque, Sentinelle du Pélion et Fléau des Troyens accusent réception du coup automatique déjà résolu : aucun vol tardif, geste manuel supplémentaire, coût ou quota supplémentaire.
- Trait du destin translate l’origine de la flèche depuis la case effectivement choisie. Le corps demeure sur sa case actuelle.

Ces nœuds existent dans le catalogue ; une run fraîche ne les possède pas tous. Les captures avancées utilisent des configurations de validation annoncées, séparées du parcours d’achat normal.

## Contrat technique et art

[AchillesSpellVisualResolver](../../../data/visuals/achilles/achilles_spell_visual_resolver.gd) reste pur. resolve lit le Spell, les maîtrises et éventuellement un profil statique résolu. with_cast_context copie origine, cible, case du corps, distance Manhattan et origine alternative. Aucun événement, indicateur consommé ou mutation de Resource.

Champs ajoutés : presentation_version = 3, gesture_variant, projectile_variant, projectile_animation, impact_animation, projectile_scale, projectile_trail_count/spacing/alpha, push_distance, stopping_arrow_selected, cast_distance et alternate_origin.

Les onze [sources retenues](../../../art/source/characters/achilles/sprites_polish_v3/README.md) fournissent 112 régions source pour 20 clips : marche et quatre gestes d’arc dans les quatre orientations. Les 28 clips hérités, dont repos, réception des coups et Percée, restent inchangés. Le profil de corps fournit le nombre d’images, l’armé, l’image de libération et les origines par direction. bow_piercing et bow_death se replient explicitement vers bow si un ancien profil ne possède pas leurs dessins, puis attack uniquement si ce profil n’a aucun arc. La réception de Percée reste indépendante.

Les quatre arcs S ont été affinés dans une dernière passe depuis la seule image du repos S original ; les anciennes planches ne servaient plus de référence visuelle. Les nouveaux visage, torse et bras se rapprochent ainsi des proportions d'origine. Cette base V6 fournit seulement ses huit poses d'arc : sa marche répétée est exclue. La marche S harmonisée et les 16 autres atlas gardent leurs fichiers vérifiés ; quatre origines S sont remesurées.

Le [renderer VFX](../../../vfx/achilles_kit/achilles_spell_sprite_vfx.gd) utilise `assets/vfx/achilles_polish_v3/effects.tres` et choisit le vrai clip de SpriteFrames. Les 48 dessins neufs forment douze clips de projectile/impact ; sweep, guard, dust et barrier conservent leurs régions V2. Il expose animation, requested_animation et used_animation_fallback. Pour l'expédition, `effects_source` sélectionne aussi les atlas de Paris, du philosophe et de foudre ; `used_source_fallback` indique un emprunt au clip utilitaire canonique. Les champs `heal_animation`/`heal_effects_source` et `aux_burst_animation` décrivent les soins confirmés et l'effet de zone dédié. Le soin lié à Marche attend l'arrivée visuelle et ne se répète pas sur un second signal d'arrivée. L’ancien atlas peut revenir à arrow/impact, mais ce repli reste observable. Les dessins natifs gardent leurs proportions ; projectile_scale sert uniquement au secours ancien.

Une traîne contient au maximum trois échantillons à faible alpha de la même flèche. Ils restent derrière sa tête, entre origine et cible, et disparaissent à la confirmation d’impact. Ils ne créent ni autre flèche active, ni cellule visée. Volée garde exactement une tête par cellule légale.

Le délai de vol reste celui du Spell (0,20 s pour les tirs configurés). La fin du trajet ne déclenche aucun dégât. confirm_impact attend le rapport réel ; un tir manqué/annulé ferme l’effet. Un coup direct ou automatique n’invente pas de vol après la perte de PV.

## Vérification

Les [tests du résolveur](../../../test/unit/test_achilles_spell_visual_resolver.gd) vérifient identités, priorités de forme, gestes spécifiques, postures, conditions non confirmées et absence de mutation.

Les [tests VFX](../../../test/unit/test_achilles_kit_sprite_vfx.gd) vérifient la texture effectivement rendue, les proportions natives, le repli explicite, les traînes derrière leurs têtes, les seules cellules touchées, l’acquittement des dégâts, les contres et l’origine alternative via le vrai VFXManager. Les textures injectées isolent la mécanique ; elles ne remplacent pas la revue des nouveaux dessins et les captures de jeu.

La [preuve des sept cas d'expédition](achilles_expedition_animation_validation_v3.json) conserve les rapports sélectionnés, empreintes, poses, atlas, délais mesurés, dégâts et effets réels. Elle inclut le rerun de Givre après correction de l'assertion sur la source du statut ; elle ne prétend pas valider une run complète.
