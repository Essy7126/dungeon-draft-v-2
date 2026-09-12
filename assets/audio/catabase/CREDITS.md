# Catabase — sons intégrés

## Musique

**Soft Mysterious Harp Loop**, **VWolfdog (Jordy Hake)**.
Source : https://opengameart.org/content/soft-mysterious-harp-loop
Licence : **CC BY 3.0**, https://creativecommons.org/licenses/by/3.0/

Adaptation pour Catabase : vitesse et hauteur à 90 %, atténuation douce des aigus,
fondus de 100 ms aux extrémités, ajustement de niveau et export WAV 48 kHz.
L'auteur ne cautionne pas cette adaptation. Conserver ces crédits avec toute
distribution du jeu.

## Effets

**Double Trouble Audio — Medieval Armor and Impacts**, bundle **Sonniss GDC 2017**.
Licence Sonniss #GameAudioGDC, version 2.0 du 27 août 2026 :
https://sonniss.com/gdc-bundle-license/

Enregistrements sources : LeatherArmor_Rustle_03.wav, Chainmail_Impact_Hard_03.wav,
Plate_Impact_Hard_02.wav et Weapon_Impact_Parry_01.wav. Recoupes, assemblages de
matières, résonances abaissées, filtrage des aigus et gain. Pas de génération IA.

Ces fichiers sont des ressources du jeu, pas une banque de sons libre. Leur usage
dans le jeu et le partage avec l'équipe sont autorisés ; ne pas les republier
comme effets séparés, banque d'assets ou modèle de projet public.

Recettes : `tools/audio_workshop/build_mythic_trial.py`, `build_soft_trial.py`
et `build_mysterious_music.py`. Les fichiers de production sont copiés depuis
les sorties validées `soft_v5/` et `music_mystery_v1/`.

## Retours contextuels — 12 septembre 2026

`feedback/` : nouveaux assemblages des mêmes matières Sonniss, filtrés et adoucis,
produits par `tools/audio_workshop/build_context_sounds.py`. Le manifeste décrit
chaque source, vitesse, gain et recoupe. Aucune source de l'essai électronique
rejeté n'a été reprise pour ces retours.

Exception : `step_1.wav` à `step_3.wav` sont les pas sur pierre du premier essai
acceptés par l'utilisateur, sans modification. Sources **Kenney Impact Sounds**,
`footstep_concrete_000.ogg` à `footstep_concrete_002.ogg`, **CC0** :
https://kenney.nl/assets/impact-sounds
https://creativecommons.org/publicdomain/zero/1.0/
