# Inventaire local reproductible

Généré par `node docs/design/spell_comparison_2026-09-25/audit_local.mjs`. Lecture statique : rang zéro avant passifs, équipement, résistances et modificateurs. P = Prouesse. Un code d’effet décrit une famille technique, pas une identité de gameplay. Voir la fabrique pour les règles exactes.

| ID | Carte | Classe | PA | Portée | Dégâts / P | Effet | Paramètre | Source |
|---|---|---|---:|---|---:|---|---:|---|
| a_open | Ouvrir la garde | assassin | 1 | 1–3 | 0.35 | mark | 1 | [ligne 66](../../../core/expedition/class_card_catalog.gd#L66) |
| a_finish | Frapper l'ouverture | assassin | 2 | 1–1 | 0.8 | marked | 0.55 | [ligne 67](../../../core/expedition/class_card_catalog.gd#L67) |
| a_cut | Entaille profonde | assassin | 2 | 1–1 | 0.7 | bleed | 0.2 | [ligne 68](../../../core/expedition/class_card_catalog.gd#L68) |
| a_step | Pas de côté | assassin | 1 | 1–2 | 0 | move | 2 | [ligne 69](../../../core/expedition/class_card_catalog.gd#L69) |
| a_parry | Parade courte | assassin | 1 | 0–0 | 0 | guard | 0.35 | [ligne 70](../../../core/expedition/class_card_catalog.gd#L70) |
| a_dagger | Dague lancée | assassin | 1 | 2–3 | 0.55 | hit | 0 | [ligne 71](../../../core/expedition/class_card_catalog.gd#L71) |
| a_ambush | Attaque oblique | assassin | 2 | 1–1 | 1 | moved | 0.4 | [ligne 72](../../../core/expedition/class_card_catalog.gd#L72) |
| a_sweep | Lames croisées | assassin | 3 | 1–1 | 0.95 | cross | 1 | [ligne 73](../../../core/expedition/class_card_catalog.gd#L73) |
| a_hamstring | Couper les appuis | assassin | 2 | 1–1 | 0.65 | slow | 1 | [ligne 74](../../../core/expedition/class_card_catalog.gd#L74) |
| a_push | Coup de talon | assassin | 1 | 1–1 | 0.25 | push | 1 | [ligne 75](../../../core/expedition/class_card_catalog.gd#L75) |
| a_execute | Coup de grâce | assassin | 3 | 1–1 | 1.2 | execute | 0.7 | [ligne 76](../../../core/expedition/class_card_catalog.gd#L76) |
| a_pull | Crochet de lame | assassin | 2 | 2–3 | 0.55 | pull | 1 | [ligne 77](../../../core/expedition/class_card_catalog.gd#L77) |
| a_blind | Poussière noire | assassin | 2 | 1–2 | 0.4 | weaken | 0.2 | [ligne 78](../../../core/expedition/class_card_catalog.gd#L78) |
| a_pierce | Pointe précise | assassin | 2 | 1–1 | 1.1 | hit | 0 | [ligne 79](../../../core/expedition/class_card_catalog.gd#L79) |
| a_escape | Fuite préparée | assassin | 2 | 1–3 | 0 | move | 3 | [ligne 80](../../../core/expedition/class_card_catalog.gd#L80) |
| g_guard | Garde brève | gardien | 2 | 0–0 | 0 | guard | 0.8 | [ligne 81](../../../core/expedition/class_card_catalog.gd#L81) |
| g_push | Repousser | gardien | 2 | 1–1 | 0.75 | push | 1 | [ligne 82](../../../core/expedition/class_card_catalog.gd#L82) |
| g_hit | Heurt d'airain | gardien | 2 | 1–1 | 1 | guarded | 0.3 | [ligne 83](../../../core/expedition/class_card_catalog.gd#L83) |
| g_step | Avancée prudente | gardien | 1 | 1–1 | 0 | move | 1 | [ligne 84](../../../core/expedition/class_card_catalog.gd#L84) |
| g_slow | Briser l'élan | gardien | 2 | 1–2 | 0.65 | slow | 1 | [ligne 85](../../../core/expedition/class_card_catalog.gd#L85) |
| g_pull | Ramener au front | gardien | 2 | 2–3 | 0.5 | pull | 2 | [ligne 86](../../../core/expedition/class_card_catalog.gd#L86) |
| g_wall | Tenir le passage | gardien | 3 | 0–0 | 0 | guard | 1.25 | [ligne 87](../../../core/expedition/class_card_catalog.gd#L87) |
| g_sweep | Balayage de hampe | gardien | 3 | 1–1 | 0.9 | cross | 1 | [ligne 88](../../../core/expedition/class_card_catalog.gd#L88) |
| g_crush | Choc de masse | gardien | 3 | 1–1 | 1.1 | push | 2 | [ligne 89](../../../core/expedition/class_card_catalog.gd#L89) |
| g_mark | Désigner la menace | gardien | 1 | 1–3 | 0.3 | mark | 1 | [ligne 90](../../../core/expedition/class_card_catalog.gd#L90) |
| g_riposte | Rendre le coup | gardien | 2 | 1–1 | 0.8 | wounded | 0.5 | [ligne 91](../../../core/expedition/class_card_catalog.gd#L91) |
| g_shot | Javelot lourd | gardien | 2 | 2–3 | 0.95 | hit | 0 | [ligne 92](../../../core/expedition/class_card_catalog.gd#L92) |
| g_weaken | Casser les armes | gardien | 2 | 1–1 | 0.6 | weaken | 0.25 | [ligne 93](../../../core/expedition/class_card_catalog.gd#L93) |
| g_charge | Percée | gardien | 2 | 1–2 | 0 | move | 2 | [ligne 94](../../../core/expedition/class_card_catalog.gd#L94) |
| g_punish | Punir le recul | gardien | 2 | 1–2 | 0.9 | displaced | 0.5 | [ligne 95](../../../core/expedition/class_card_catalog.gd#L95) |
| r_shot | Trait tendu | arpenteur | 2 | 2–4 | 1 | hit | 0 | [ligne 96](../../../core/expedition/class_card_catalog.gd#L96) |
| r_step | Pas latéral | arpenteur | 1 | 1–2 | 0 | move | 2 | [ligne 97](../../../core/expedition/class_card_catalog.gd#L97) |
| r_slow | Flèche entravante | arpenteur | 2 | 2–4 | 0.65 | slow | 1 | [ligne 98](../../../core/expedition/class_card_catalog.gd#L98) |
| r_push | Trait de recul | arpenteur | 2 | 1–3 | 0.6 | push | 1 | [ligne 99](../../../core/expedition/class_card_catalog.gd#L99) |
| r_guard | Se couvrir | arpenteur | 1 | 0–0 | 0 | guard | 0.35 | [ligne 100](../../../core/expedition/class_card_catalog.gd#L100) |
| r_mark | Visée révélatrice | arpenteur | 1 | 2–5 | 0.25 | mark | 1 | [ligne 101](../../../core/expedition/class_card_catalog.gd#L101) |
| r_hunt | Flèche de chasse | arpenteur | 2 | 2–4 | 0.75 | marked | 0.55 | [ligne 102](../../../core/expedition/class_card_catalog.gd#L102) |
| r_fan | Volée croisée | arpenteur | 3 | 2–4 | 0.75 | cross | 1 | [ligne 103](../../../core/expedition/class_card_catalog.gd#L103) |
| r_close | Coup de crosse | arpenteur | 1 | 1–1 | 0.45 | push | 1 | [ligne 104](../../../core/expedition/class_card_catalog.gd#L104) |
| r_bleed | Flèche barbelée | arpenteur | 2 | 2–4 | 0.65 | bleed | 0.2 | [ligne 105](../../../core/expedition/class_card_catalog.gd#L105) |
| r_long | Tir de longue vue | arpenteur | 3 | 3–6 | 1.45 | hit | 0 | [ligne 106](../../../core/expedition/class_card_catalog.gd#L106) |
| r_move | Tir en mouvement | arpenteur | 2 | 1–3 | 0.8 | moved | 0.4 | [ligne 107](../../../core/expedition/class_card_catalog.gd#L107) |
| r_escape | Traverser la ligne | arpenteur | 2 | 1–3 | 0 | move | 3 | [ligne 108](../../../core/expedition/class_card_catalog.gd#L108) |
| r_pull | Trait harpon | arpenteur | 2 | 2–4 | 0.55 | pull | 1 | [ligne 109](../../../core/expedition/class_card_catalog.gd#L109) |
| r_weak | Tir aux mains | arpenteur | 2 | 2–4 | 0.6 | weaken | 0.2 | [ligne 110](../../../core/expedition/class_card_catalog.gd#L110) |
| t_frost | Trait de givre | thaumaturge | 2 | 1–3 | 0.7 | frost | 1 | [ligne 111](../../../core/expedition/class_card_catalog.gd#L111) |
| t_fire | Éclat de braise | thaumaturge | 3 | 1–3 | 0.8 | fire | 1 | [ligne 112](../../../core/expedition/class_card_catalog.gd#L112) |
| t_mark | Sceau d'ombre | thaumaturge | 1 | 1–3 | 0.3 | mark | 1 | [ligne 113](../../../core/expedition/class_card_catalog.gd#L113) |
| t_guard | Écran de cendre | thaumaturge | 2 | 0–0 | 0 | guard | 0.75 | [ligne 114](../../../core/expedition/class_card_catalog.gd#L114) |
| t_step | Pas de brume | thaumaturge | 1 | 1–2 | 0 | move | 2 | [ligne 115](../../../core/expedition/class_card_catalog.gd#L115) |
| t_bolt | Arc fulgurant | thaumaturge | 2 | 1–4 | 1 | lightning | 0 | [ligne 116](../../../core/expedition/class_card_catalog.gd#L116) |
| t_hex | Morsure du sceau | thaumaturge | 2 | 1–3 | 0.75 | marked | 0.55 | [ligne 117](../../../core/expedition/class_card_catalog.gd#L117) |
| t_weak | Éteindre la force | thaumaturge | 2 | 1–3 | 0.5 | weaken | 0.25 | [ligne 118](../../../core/expedition/class_card_catalog.gd#L118) |
| t_pull | Appel des profondeurs | thaumaturge | 2 | 2–4 | 0.4 | pull | 2 | [ligne 119](../../../core/expedition/class_card_catalog.gd#L119) |
| t_push | Souffle de pierre | thaumaturge | 2 | 1–3 | 0.6 | push | 1 | [ligne 120](../../../core/expedition/class_card_catalog.gd#L120) |
| t_burn | Braise tenace | thaumaturge | 2 | 1–3 | 0.6 | burn | 0.22 | [ligne 121](../../../core/expedition/class_card_catalog.gd#L121) |
| t_ice | Éclats gelés | thaumaturge | 3 | 1–3 | 0.7 | ice_area | 1 | [ligne 122](../../../core/expedition/class_card_catalog.gd#L122) |
| t_storm | Orage concentré | thaumaturge | 3 | 2–4 | 1.5 | lightning | 0 | [ligne 123](../../../core/expedition/class_card_catalog.gd#L123) |
| t_touch | Toucher du Tartare | thaumaturge | 1 | 1–1 | 0.6 | shadow | 0 | [ligne 124](../../../core/expedition/class_card_catalog.gd#L124) |
| t_escape | Traversée de brume | thaumaturge | 2 | 1–3 | 0 | move | 3 | [ligne 125](../../../core/expedition/class_card_catalog.gd#L125) |
| i_a_open | Faille furtive | assassin | 1 | 1–3 | 0.15 | mark | 1 | [ligne 4](../../../core/expedition/class_starter_catalog.gd#L4) |
| i_a_strike | Lame opportuniste | assassin | 2 | 1–1 | 0.45 | marked | 0.35 | [ligne 5](../../../core/expedition/class_starter_catalog.gd#L5) |
| i_a_step | Approche oblique | assassin | 1 | 1–2 | 0 | move | 2 | [ligne 6](../../../core/expedition/class_starter_catalog.gd#L6) |
| i_a_cut | Entaille discrète | assassin | 2 | 1–1 | 0.35 | bleed | 0.18 | [ligne 7](../../../core/expedition/class_starter_catalog.gd#L7) |
| i_a_ambush | Premier guet-apens | assassin | 2 | 1–1 | 0.5 | moved | 0.3 | [ligne 8](../../../core/expedition/class_starter_catalog.gd#L8) |
| i_a_dagger | Dague de diversion | assassin | 1 | 2–3 | 0.4 | hit | 0 | [ligne 9](../../../core/expedition/class_starter_catalog.gd#L9) |
| i_a_escape | Repli dans l'ombre | assassin | 2 | 1–3 | 0 | move | 3 | [ligne 10](../../../core/expedition/class_starter_catalog.gd#L10) |
| i_g_guard | Rempart d'apprenti | gardien | 2 | 0–0 | 0 | guard | 0.75 | [ligne 11](../../../core/expedition/class_starter_catalog.gd#L11) |
| i_g_hit | Heurt sous couvert | gardien | 2 | 1–1 | 0.5 | guarded | 0.35 | [ligne 12](../../../core/expedition/class_starter_catalog.gd#L12) |
| i_g_push | Écarter la menace | gardien | 2 | 1–1 | 0.4 | push | 1 | [ligne 13](../../../core/expedition/class_starter_catalog.gd#L13) |
| i_g_pull | Crochet du rempart | gardien | 2 | 2–3 | 0.25 | pull | 2 | [ligne 14](../../../core/expedition/class_starter_catalog.gd#L14) |
| i_g_weaken | Désarmer l'élan | gardien | 2 | 1–1 | 0.3 | weaken | 0.2 | [ligne 15](../../../core/expedition/class_starter_catalog.gd#L15) |
| i_g_step | Prendre position | gardien | 1 | 1–1 | 0 | move | 1 | [ligne 16](../../../core/expedition/class_starter_catalog.gd#L16) |
| i_g_punish | Punir le déséquilibre | gardien | 2 | 1–2 | 0.45 | displaced | 0.4 | [ligne 17](../../../core/expedition/class_starter_catalog.gd#L17) |
| i_r_shot | Flèche d'éclaireur | arpenteur | 2 | 2–4 | 0.65 | hit | 0 | [ligne 18](../../../core/expedition/class_starter_catalog.gd#L18) |
| i_r_slow | Entraver la poursuite | arpenteur | 2 | 2–4 | 0.4 | slow | 1 | [ligne 19](../../../core/expedition/class_starter_catalog.gd#L19) |
| i_r_push | Flèche de recul | arpenteur | 2 | 1–3 | 0.3 | push | 1 | [ligne 20](../../../core/expedition/class_starter_catalog.gd#L20) |
| i_r_step | Pas d'éclaireur | arpenteur | 1 | 1–2 | 0 | move | 2 | [ligne 21](../../../core/expedition/class_starter_catalog.gd#L21) |
| i_r_move | Tir d'escarmouche | arpenteur | 2 | 1–3 | 0.45 | moved | 0.3 | [ligne 22](../../../core/expedition/class_starter_catalog.gd#L22) |
| i_r_mark | Repérer la proie | arpenteur | 1 | 2–5 | 0.15 | mark | 1 | [ligne 23](../../../core/expedition/class_starter_catalog.gd#L23) |
| i_r_hunt | Suivre la piste | arpenteur | 2 | 2–4 | 0.4 | marked | 0.35 | [ligne 24](../../../core/expedition/class_starter_catalog.gd#L24) |
| i_t_frost | Morsure de givre | thaumaturge | 2 | 1–3 | 0.4 | frost | 1 | [ligne 25](../../../core/expedition/class_starter_catalog.gd#L25) |
| i_t_hex | Réveiller le sceau | thaumaturge | 2 | 1–3 | 0.45 | marked | 0.35 | [ligne 26](../../../core/expedition/class_starter_catalog.gd#L26) |
| i_t_mark | Tracer le sceau | thaumaturge | 1 | 1–3 | 0.15 | mark | 1 | [ligne 27](../../../core/expedition/class_starter_catalog.gd#L27) |
| i_t_fire | Gerbe de cendres | thaumaturge | 3 | 1–3 | 0.5 | fire | 1 | [ligne 28](../../../core/expedition/class_starter_catalog.gd#L28) |
| i_t_burn | Braise couvante | thaumaturge | 2 | 1–3 | 0.3 | burn | 0.18 | [ligne 29](../../../core/expedition/class_starter_catalog.gd#L29) |
| i_t_pull | Rassembler les ombres | thaumaturge | 2 | 2–3 | 0.25 | pull | 2 | [ligne 30](../../../core/expedition/class_starter_catalog.gd#L30) |
| i_t_guard | Voile de suie | thaumaturge | 2 | 0–0 | 0 | guard | 0.55 | [ligne 31](../../../core/expedition/class_starter_catalog.gd#L31) |
| a_venom | Venin du Styx | assassin | 2 | 1–2 | 0.6 | bleed | 0.45 | [ligne 12](../../../core/expedition/card_ecosystem_catalog.gd#L12) |
| a_disarm | Sectionner les tendons | assassin | 2 | 1–2 | 0.6 | disrupt | 1 | [ligne 13](../../../core/expedition/card_ecosystem_catalog.gd#L13) |
| a_lure | Murmure trompeur | assassin | 2 | 2–4 | 0.3 | lure | 2 | [ligne 14](../../../core/expedition/card_ecosystem_catalog.gd#L14) |
| a_stasis | Sommeil de l'oubli | assassin | 3 | 1–2 | 0 | stasis | 1 | [ligne 15](../../../core/expedition/card_ecosystem_catalog.gd#L15) |
| a_reap | Moisson des condamnés | assassin | 3 | 1–2 | 1.1 | execute | 1.2 | [ligne 16](../../../core/expedition/card_ecosystem_catalog.gd#L16) |
| a_phantom | Traversée spectrale | assassin | 2 | 1–4 | 0 | blink | 4 | [ligne 17](../../../core/expedition/card_ecosystem_catalog.gd#L17) |
| g_bastion | Bastion vivant | gardien | 3 | 0–0 | 0 | guard | 1.8 | [ligne 18](../../../core/expedition/card_ecosystem_catalog.gd#L18) |
| g_prison | Entrave de bronze | gardien | 2 | 1–3 | 0.6 | root | 2 | [ligne 19](../../../core/expedition/card_ecosystem_catalog.gd#L19) |
| g_fault | Faille ardente | gardien | 3 | 1–3 | 0.5 | fire_field | 0.45 | [ligne 20](../../../core/expedition/card_ecosystem_catalog.gd#L20) |
| g_crash | Sentence du rempart | gardien | 3 | 1–2 | 1.1 | guarded | 1 | [ligne 21](../../../core/expedition/card_ecosystem_catalog.gd#L21) |
| g_hook | Chaînes du Tartare | gardien | 2 | 2–4 | 0.8 | pull | 3 | [ligne 22](../../../core/expedition/card_ecosystem_catalog.gd#L22) |
| g_silence | Briser l'incantation | gardien | 2 | 1–3 | 0.5 | disrupt | 2 | [ligne 23](../../../core/expedition/card_ecosystem_catalog.gd#L23) |
| r_caltrop | Piège de givre | arpenteur | 2 | 1–4 | 0.25 | ice_field | 1 | [ligne 24](../../../core/expedition/card_ecosystem_catalog.gd#L24) |
| r_embers | Flèche incendiaire | arpenteur | 3 | 2–5 | 0.7 | fire_field | 0.35 | [ligne 25](../../../core/expedition/card_ecosystem_catalog.gd#L25) |
| r_net | Filet du chasseur | arpenteur | 2 | 2–5 | 0.55 | root | 2 | [ligne 26](../../../core/expedition/card_ecosystem_catalog.gd#L26) |
| r_scatter | Volée du crépuscule | arpenteur | 3 | 2–5 | 1.2 | cross | 1 | [ligne 27](../../../core/expedition/card_ecosystem_catalog.gd#L27) |
| r_horizon | Au-delà de la ligne | arpenteur | 2 | 1–4 | 0 | blink | 4 | [ligne 28](../../../core/expedition/card_ecosystem_catalog.gd#L28) |
| r_bounty | Prime de la traque | arpenteur | 3 | 2–6 | 1.1 | marked | 1.1 | [ligne 29](../../../core/expedition/card_ecosystem_catalog.gd#L29) |
| t_flamewall | Bûcher des ombres | thaumaturge | 3 | 1–4 | 0.65 | fire_field | 0.5 | [ligne 30](../../../core/expedition/card_ecosystem_catalog.gd#L30) |
| t_glacier | Jardin de givre | thaumaturge | 3 | 1–4 | 0.45 | ice_field | 2 | [ligne 31](../../../core/expedition/card_ecosystem_catalog.gd#L31) |
| t_charm | Chant du Léthé | thaumaturge | 2 | 2–4 | 0.4 | lure | 2 | [ligne 32](../../../core/expedition/card_ecosystem_catalog.gd#L32) |
| t_hourglass | Sablier brisé | thaumaturge | 3 | 1–3 | 0 | stasis | 1 | [ligne 33](../../../core/expedition/card_ecosystem_catalog.gd#L33) |
| t_disrupt | Dissonance | thaumaturge | 2 | 1–4 | 0.55 | disrupt | 2 | [ligne 34](../../../core/expedition/card_ecosystem_catalog.gd#L34) |
| t_cataclysm | Couronne de cendres | thaumaturge | 3 | 1–4 | 1.35 | fire | 1 | [ligne 35](../../../core/expedition/card_ecosystem_catalog.gd#L35) |

## V1 : les 48 familles

| ID | Carte | PA | Portée | Dégâts / P | Effet | Condition |
|---|---|---:|---|---:|---|---|
| n01 | Estoc | 1 | 1–1 | 0.55 | hit | — |
| n02 | Garde brève | 1 | 0–0 | 0 | guard | — |
| n03 | Pas latéral | 1 | 1–2 | 0 | move | — |
| n04 | Heurt | 1 | 1–1 | 0.25 | push | — |
| n05 | Trait court | 1 | 2–4 | 0.45 | hit | — |
| n06 | Repérage | 1 | 1–4 | 0.2 | mark | — |
| n07 | Entrave légère | 1 | 1–3 | 0.2 | slow | — |
| n08 | Recentrage | 1 | 0–0 | 0 | draw | — |
| a01 | Ouvrir la garde | 1 | 1–2 | 0.35 | mark | — |
| a02 | Frapper la faille | 2 | 1–1 | 0.95 | hit | marked |
| a03 | Entaille tenace | 2 | 1–1 | 0.7 | burn | — |
| a04 | Attaque oblique | 2 | 1–1 | 1.05 | hit | moved |
| g01 | Garde ferme | 2 | 0–0 | 0 | guard | — |
| g02 | Heurt du rempart | 2 | 1–1 | 1 | hit | guarded |
| g03 | Repousser | 2 | 1–1 | 0.8 | push | — |
| g04 | Ramener au front | 1 | 2–3 | 0.2 | pull | — |
| r01 | Trait tendu | 2 | 2–5 | 1 | hit | — |
| r02 | Trait de recul | 2 | 2–4 | 0.7 | push | — |
| r03 | Flèche entravante | 2 | 2–4 | 0.6 | slow | — |
| r04 | Volée croisée | 3 | 2–4 | 0.6 | hit | — |
| t01 | Trait de givre | 2 | 1–4 | 0.65 | slow | — |
| t02 | Braise tenace | 2 | 1–3 | 0.55 | burn | — |
| t03 | Sceau ombreux | 1 | 1–4 | 0.25 | mark | — |
| t04 | Éclat de braise | 3 | 1–3 | 0.65 | hit | — |
| a05 | Bond spectral | 2 | 1–3 | 0 | blink | — |
| a06 | Dernier verdict | 3 | 1–2 | 1.3 | hit | execute |
| a07 | Pointe franche | 2 | 1–3 | 0.9 | hit | — |
| g05 | Contre préparé | 2 | 0–0 | 0 | counter | — |
| g06 | Choc de masse | 2 | 1–1 | 0.9 | push | — |
| g07 | Dette du bronze | 3 | 1–2 | 1.2 | hit | absorbed |
| r05 | Au-delà du front | 2 | 1–4 | 0 | blink | — |
| r06 | Pluie de pointes | 3 | 2–5 | 0.85 | hit | — |
| r07 | Trait harpon | 2 | 2–5 | 0.55 | pull | — |
| t05 | Bûcher des ombres | 2 | 1–4 | 0 | firefield | — |
| t06 | Jardin de givre | 2 | 1–4 | 0 | icefield | — |
| t07 | Prélèvement | 2 | 1–3 | 0.75 | drain | — |
| a08 | Couper le souffle | 2 | 1–3 | 0.7 | disrupt | — |
| a09 | Sommeil marqué | 3 | 1–3 | 0 | stasis | — |
| g08 | Bastion vivant | 3 | 0–0 | 0 | guard | — |
| g09 | Répercussion | 2 | 1–3 | 0.5 | guardburst | — |
| r08 | Permutation | 2 | 1–5 | 0 | swap | — |
| r09 | La longue vue | 3 | 3–6 | 1.75 | hit | — |
| t08 | Convergence | 3 | 1–4 | 0.8 | converge | — |
| t09 | Résonance du sceau | 3 | 1–4 | 0.9 | hit | marked |
| l01 | Orage du passage | 3 | 0–0 | 1.1 | storm | — |
| l02 | Grâce du bronze | 2 | 0–0 | 0 | heal | — |
| d01 | Décret du dernier souffle | 3 | 0–0 | 0 | edict | — |
| i01 | Seconde aurore | 4 | 0–0 | 0 | renew | — |
