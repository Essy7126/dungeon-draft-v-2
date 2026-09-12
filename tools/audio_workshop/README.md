# Atelier audio — essai gratuit

## Sélection pour l’écran titre — 12 septembre 2026

[Panneau d’écoute : huit musiques](title_music_panel.html), avec les sources,
favoris et comparaison sur le décor du titre. [Droits, lancement et contrôles](TITLE_MUSIC_SELECTION.md).
Les huit titres sont intégrés à l’écran titre en fichiers locaux : choix et volume
mémorisés, fondus, boucle et crédits accessibles. Reconstruction : `build_title_music.py`.
Tests : `./dev.ps1 test test/unit/test_title_music.gd`, puis
`./tools/audio_workshop/verify_production.ps1` pour la lecture WASAPI des huit titres
par le sélecteur et le parcours normal jusqu’aux sorts du premier combat.

## Extension contextuelle — 12 septembre 2026

Intégrée aux ressources de production, sans achat : 14 retours construits avec
les matières acceptées et trois variantes de pas Kenney déjà approuvées.
Recettes et niveaux : `build_context_sounds.py`,
`assets/audio/catabase/feedback/manifest.json` ; crédits dans le dossier parent.

- Combat : pas après chaque déplacement visuel validé, attaques physiques et
  magiques sans signature existante (ennemis compris), soins effectifs, boucliers
  accordés/absorbés, esquives, chute d'une unité et début du tour du héros.
- Interface : ouverture/fermeture du sac et du grimoire, sélection, équipement,
  acquisition de maîtrise, choix et confirmation de récompense, navigation du
  parcours, interactions des haltes et passage de la porte après succès.
- Remplacement du triangle aigu des écrans de victoire, récompense et évolution.
  Les confirmations utilisent le bronze amorti ; les refus un frottement discret.

`core/audio/feedback_player.gd` limite la polyphonie à quatre voix et les répétitions
d'un même retour à 140 ms. Les variantes ne consomment aucun aléa de combat.
L'interface utilise un lecteur persistant compatible avec la pause. Le combat
possède son propre lecteur et déconnecte événements et grille à la sortie.
Les faits sont dédupliqués et les ticks périodiques restent silencieux ; les quatre
techniques initiales conservent leur signature sans deuxième impact générique.

Validation GUT : `./dev.ps1 test audio`, 13 suites, 96 tests et 1 265 assertions
réussis, sans erreur moteur. Rapport :
`artifacts/dev/20260912-080748-test-audio-d72e475a/gut-strict-report.json`.
Parcours `./tools/audio_workshop/verify_production.ps1` : 52 contrôles réussis,
sans erreur moteur. Douze pas, quatre débuts de tour et l'impact du Trait d'ombre
ennemi détectés ; quatre techniques mesurées sur SFX (crêtes 0,180 à 0,358),
harpe sur Music (0,043). Rapport :
`artifacts/dev/20260912-081645-production-audio-20e8c02b/summary.json` ;
capture `06-production-audio.png` inspectée. Ne pas présenter les imports
échoués comme des tests : les nouveaux sons ont d'abord nécessité leur import,
et un export WebP d'animation en cours a momentanément échoué au décodage.
Le test des faits a également nécessité une assertion immédiatement après chaque
émission (GUT compare la dernière), puis le nettoyage du graphe unité/grille de
sa fixture via le service de test existant. Les rapports échoués sont conservés.
Le scénario normal attend désormais un impact ennemi après les quatre techniques,
en gardant le héros immobile : le poursuivre en mêlée déclenchait systématiquement
son repli et ne permettait pas de vérifier son tir. Aucun changement de l'IA.

## Intégration dans le jeu — 11 septembre 2026

Le retour « après relance, aucun sort et ancienne musique » venait du périmètre
des versions précédentes : seul le laboratoire injectait l'audio. Désormais
`data/rooms/maps/painted_battle.tscn` possède `CombatAudio`, avec
`battle/audio/catabase_battle_audio.gd` et les cinq ressources importées de
`assets/audio/catabase/`. Aucun chargement depuis `artifacts/` en production.
Les quatre techniques de départ sont reliées aux rapports réels de SpellCaster,
filtrés sur les unités de cette rencontre. La musique remplace l'ancien autoplay
et passe par Music à -6 dB ; les effets passent par SFX à 90 %.
Le composant s'arrête et déconnecte son écouteur quand sa scène disparaît.

Le laboratoire reste disponible et désactive le composant de production dans
son seul processus afin d'éviter deux lectures superposées. Les sections qui
suivent conservent l'historique des essais, pas le périmètre actuel du jeu.

Contrôles : `./dev.ps1 test test/unit/test_catabase_battle_audio.gd` et
`./tools/audio_workshop/verify_production.ps1`. Ce dernier reprend le parcours
réel du menu jusqu'à la porte, puis joue les quatre techniques par les intentions
du combat. Il mesure Music et SFX avec WASAPI sans ajouter de lecteur de son.
Validation finale : 50 contrôles du parcours normal réussis, les quatre effets
mesurés sur SFX et la harpe mesurée sur Music. Rapport :
`artifacts/dev/20260911-220808-production-audio-f78d3b64/summary.json`.
Capture `06-production-audio.png` inspectée. Trois tests GUT / 20 assertions
réussis, dont sortie de scène avec lectures actives et absence d'écouteur restant :
`artifacts/dev/20260911-221005-test-test_unit_test_catabase_battle_audio.gd-5bf28e3a/gut-strict-report.json`.
Aucune erreur moteur dans ces validations finales. Les contrôles précédemment
échoués restent conservés (types du test, attente du mixeur, puis menu bloqué).
Le parcours a nécessité de préciser `bool` pour `painted` et `passe_rive` dans
`ui/selection/character_selection_catalog.gd` ; autres modifications d'apparences
préservées. Aucun changement aux règles du combat ni aux exigences de la CI.

`build_free_starter.py` prépare une sélection et des assemblages de banques
Kenney CC0, sans modifier les scènes ni les sons de production. Les sources,
licences et résultats sont conservés dans `artifacts/audio/free_starter_v1/`.

## Reproduire

Python avec NumPy et SoundFile 0.13.1. Le script accepte le décodeur installé
localement dans `artifacts/audio/python/` (aucune installation système nécessaire).

Télécharger les trois archives aux URL du `PACKS` du script, dans `sources/`,
sous les noms `interface.zip`, `impact.zip`, `rpg.zip`, puis lancer :

```powershell
python tools/audio_workshop/build_free_starter.py
```

Écouter `ecoute_catabase.wav`, puis les variantes liées dans `ECOUTER.md`.
Le manifeste conserve la provenance et les recettes. `validation.json` vérifie
le décodage, la fréquence, les échantillons finis, les crêtes et les extrémités.
Ces contrôles ne remplacent pas l'écoute, le mixage et la synchronisation en jeu.

## État du 11 septembre 2026

- Retour utilisateur : les pas sont corrects ; le reste du premier essai est
  rejeté car trop électronique ou artificiel. Ne pas intégrer ces autres sons.
  Prochaine direction : enregistrements naturels de matières, sans ponctuations
  musicales ni couches synthétiques. Les pas restent seulement des candidats.
- Choix : un essai isolé à coût nul, matières Kenney CC0, aucun crédit d'IA.
- Fichiers de cette tâche : ce dossier, `artifacts/audio/` et rapports dans
  `artifacts/dev/*-audio-combat-trial-*`.
- Aucune modification du moteur commun ou des scènes : pas de validation Godot
  revendiquée. Les fichiers WAV sont des candidats, pas une livraison intégrée.
- Essai 2 : `build_natural_trial.py`, sorties dans `artifacts/audio/natural_v2/`.
  Quatre matières Double Trouble Audio du bundle Sonniss GDC 2017 ; noms
  recoupés avec la liste officielle. Licence Sonniss, pas CC0. Aucun achat.
  Montage de 6,64 s, quatre exports et montage vérifiés techniquement.
  Aucune couche ajoutée ni modification de hauteur/vitesse. Retour utilisateur :
  mieux, mais il manque un peu de fantaisie. Garder cette base naturelle.
- Essai 3 : `build_mythic_trial.py`, sorties dans `artifacts/audio/mythic_v3/`.
  Trois paires naturel/fantaisie ; contact naturel conservé, résonance de métal
  discrète et souffle tiré du cuir enregistré. Aucun achat ni génération payante.
- Retour essai 3 : direction acceptée pour essai, éviter les aigus stridents ;
  les sons doivent rester satisfaisants et agréables à entendre régulièrement.
- Essai 4 : `build_soft_trial.py` réduit les aigus, raccourcit les queues et
  prépare quatre sons : frappe, garde, impact du tir, déplacement sans impact.
  Sortie `artifacts/audio/soft_v4/` avec vérification spectrale et crêtes.
- Suite : écouter dans le premier combat. Ambiances, ennemis, voix et musique
  demandent une passe distincte.

## Essayer dans le premier combat

```powershell
python tools/audio_workshop/build_soft_trial.py
python tools/audio_workshop/build_mysterious_music.py
./tools/audio_workshop/try_combat.ps1
```

Le lanceur reprend les services de l'explorateur pour préparer le premier combat
canonique dans un processus à sauvegardes isolées. Il ajoute les sons aux quatre
sorts de départ via leurs rapports réels de résolution. Les scènes de production
et le moteur de combat ne sont pas modifiés. Ne pas lancer cette scène par F6 :
le contrôle d'isolation impose le lanceur PowerShell.

La barre **Sons doux** permet de couper les sons d'essai et de régler leur volume.
Les quatre boutons permettent de les écouter sans dépenser de PA. **F8** ferme.
Les sons sont préchargés, au maximum trois voix jouent simultanément ; un délai
minimal de 90 ms évite les rafales. Aucun impact sur tir manqué ou cast échoué.
La piste du premier combat est remplacée dans l'essai par la harpe ci-dessous.
Une seconde barre règle la musique indépendamment des effets ; zéro la coupe.

`./tools/audio_workshop/try_combat.ps1 -Verify` vérifie l'import, charge le vrai
premier combat, lance réellement Garde via SpellCaster, contrôle le déclenchement,
les refus, le mute, les quatre lectures et l'arrêt, puis capture et ferme. Le pilote
audio de ce contrôle est muet : il ne prouve pas le confort d'écoute ni un parcours
complet des quatre sorts depuis le HUD. Rapports dans `artifacts/dev/`.

Validation du 11 septembre : import réussi, 16 contrôles réussis, zéro erreur
moteur dans le contrôle final, capture du combat inspectée. Rapport :
`artifacts/dev/20260911-212141-audio-combat-trial-0b3ea057/summary.json`.
Le premier contrôle avait omis de déployer Achille ; son échec reste conservé.
Les scripts GDScript ajoutés sont formatés. Aucun test global du moteur n'est
revendiqué pour cet outil isolé ; la CI et ses suites ne sont pas modifiées.

Les WAV sous licence Sonniss restent des fichiers de travail locaux dans
`artifacts/`, non des ressources à publier dans un dépôt source public.

## Diagnostic de sortie audio

Retour utilisateur : ni les sorts ni les boutons n'étaient audibles dans la
première fenêtre. Les contrôles initiaux utilisaient Dummy : ils ne prouvaient
pas une sortie audio. La fenêtre d'origine a été fermée avant la lecture de son
état Windows ; sa cause exacte n'est donc pas établie. Une autre session du jeu
ouverte depuis l'éditeur était muette dans le mélangeur Windows (non modifiée).

Le lanceur jouable sélectionne maintenant explicitement WASAPI. La barre affiche
un indicateur de lecture ; `audio-output.json` et les lignes `AUDIO_PLAY` mesurent
le PCM du bus SFX, le pilote, la pause et les volumes. Les mesures attendent les
échantillons du pilote, pas un nombre de frames d'affichage trop court.

`./tools/audio_workshop/try_combat.ps1 -Verify -RealAudio` ajoute la mesure réelle
des quatre sons. Validation finale : 22 contrôles passés, aucune erreur moteur,
dans `artifacts/dev/20260911-213734-audio-combat-trial-f41c3adc/summary.json`.
Cela prouve un signal mixé par Godot, pas l'écoute physique par l'utilisateur.

`probe_audio_output.gd` isole décodage et mixage sur Master ;
`inspect_windows_audio.ps1` lit le volume principal et les sessions du mélangeur
Windows sans modifier leurs réglages. Ne pas couper l'autre session du jeu.

## Mixage 5 — harpe mystérieuse

Retour utilisateur : les effets sont audibles mais trop faibles ; musique trop
forte et à remplacer. Direction retenue : mythologique et mystérieuse, cordes
pincées, notes espacées et fond discret.

Le lecteur de `painted_battle.tscn` utilise Master à 0 dB. Dans ce laboratoire,
son flux est remplacé directement et routé vers Music : aucune superposition
avec l'ancienne piste. Les fichiers `soft_v5/` gagnent 6 dB sans changer leur
filtrage ; le réglage initial passe de 65 à 90 %, soit environ +8,8 dB au total.
Le premier essai `soft_v4/` est conservé dans les artifacts.

Musique candidate : **Soft Mysterious Harp Loop**, **VWolfdog / Jordy Hake**.
Source : https://opengameart.org/content/soft-mysterious-harp-loop
Licence : **CC BY 3.0**, https://creativecommons.org/licenses/by/3.0/
Téléchargement source : https://opengameart.org/sites/default/files/Harp.ogg
Placer ce fichier dans `artifacts/audio/music_mystery_v1/sources/Harp.ogg`.
Le script prépare un WAV de 61 s à 90 % de la vitesse originale (hauteur également
abaissée), atténue les aigus, applique des fondus de 100 ms aux extrémités et ajuste
le niveau. Crête exportée : -18 dBFS ; RMS : -32 dBFS. Lecture initiale à 50 %,
soit -6 dB supplémentaires. Composition existante adaptée, aucune génération IA.
Crédit visible dans l'essai ; provenance, empreinte et adaptations consignées dans
`manifest.json` et `CREDITS.txt`. Gratuit avec attribution, pas CC0.

Les modifications restent dans le laboratoire. L'écoute de la nouvelle musique
et de son équilibre reste à apprécier en combat par l'utilisateur.

Validation du mixage 5 : exports WAV vérifiés, import Godot réussi et 28 contrôles
réussis avec WASAPI, dont remplacement de la piste, bus Music, coupure/reprise,
passage de boucle et signal musical faible mais non nul. Rapport :
`artifacts/dev/20260911-214707-audio-combat-trial-ad77d7f9/summary.json`.
L'encodeur Ogg local a échoué pendant l'export : livraison en PCM WAV, décodée
et vérifiée avec succès. L'Ogg d'origine téléchargé reste la source.
