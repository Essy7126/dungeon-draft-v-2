# Musique de l’écran titre — sélection du 12 septembre 2026

Panneau : [title_music_panel.html](title_music_panel.html).
Huit morceaux complets en streaming depuis les sources des compositeurs,
avec volume initial à 25 %, favoris locaux, parcours de 40 s par titre,
boucle et aperçu avec le décor du titre. Ce panneau de comparaison reste disponible.

Les huit titres sont désormais intégrés au jeu en Ogg Vorbis local, sans achat,
dans `assets/audio/title/`. Le titre propose un sélecteur, un volume mémorisé,
des transitions en fondu et les crédits. Passage of Time est le choix initial.
Le lecteur appartient au menu et s’arrête lorsqu’on le quitte.
Les fichiers ont un niveau abaissé (RMS cible -24 dBFS, limité par la crête),
avec un volume initial de 50 % en jeu. Le manifeste conserve les mesures et SHA256.
Reconstruction : `build_title_music.py` (NumPy et SoundFile). En cas de certificat
non reconnu par Python, télécharger la source officielle avec le magasin de
certificats Windows dans `artifacts/audio/title_music_import/sources/`, sans désactiver TLS.

Ouvrir le fichier HTML dans un navigateur, ou lancer depuis la racine :

```powershell
python tools/audio_workshop/serve_title_panel.py
```

Puis ouvrir <http://127.0.0.1:8796>. Le serveur est limité à l’interface locale
et ne sert que les fichiers du panneau et le décor déjà présent dans le projet.
Une connexion Internet est nécessaire pour écouter les morceaux.

## Sources et droits

Les pages ci-dessous ont été consultées le 12 septembre 2026. Chacune propose
le morceau sous **Creative Commons Attribution 4.0 International**. Pour une
intégration : conserver titre, auteur, lien source, lien vers la licence
et indiquer les adaptations éventuelles. Le paiement affiché par certains sites
correspond à une option sans attribution ; la sélection utilise l’option gratuite.

| Morceau | Auteur | Fiche et licence |
| --- | --- | --- |
| Passage of Time | Scott Buckley | https://www.scottbuckley.com.au/library/passage-of-time/ |
| Memories Of Stone | Scott Buckley | https://www.scottbuckley.com.au/library/memories-of-stone/ |
| Nomadic Dawn | Alexander Nakarada | https://creatorchords.com/music/nomadic-dawn/ |
| Temple of the Manes | Kevin MacLeod | https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1100053 |
| Hiraeth | Scott Buckley | https://www.scottbuckley.com.au/library/hiraeth/ |
| Winter Night | Alexander Nakarada | https://creatorchords.com/music/winter-night/ |
| Titan | Scott Buckley | https://www.scottbuckley.com.au/library/titan/ |
| The Summoning | Scott Buckley | https://www.scottbuckley.com.au/library/the-summoning/ |

Licence : https://creativecommons.org/licenses/by/4.0/
Métadonnées complémentaires du morceau de Kevin MacLeod :
https://incompetech.com/music/royalty-free/pieces.json (ISRC USUAN1100053).
Le repère 2:45 de Passage of Time figure aussi dans l’annonce du compositeur :
https://www.scottbuckley.com.au/tag/scott-buckley/page/10/

Les descriptions instrumentales viennent des fiches des auteurs ; le classement
et les rapprochements artistiques sont une proposition pour Catabase, à confirmer
par l’écoute de l’utilisateur. Les références retenues sont surtout Divinity:
Original Sin 2 et Baldur’s Gate 3. Aucune de leurs bandes originales n’est copiée
ou présentée comme disponible pour notre jeu.

## Validation

Intégration Godot : **4 tests, 64 assertions**, puis **88 contrôles WASAPI** du
titre au premier combat. Huit signaux musicaux mesurés, volume zéro silencieux,
lecteur du titre libéré en quittant la scène, quatre sorts et effets contextuels
toujours audibles. Le scénario déclenche la sélection par le signal du popup ;
les crédits et le parcours suivant utilisent le pointeur. Captures du titre et
des crédits inspectées.
Rapports : `artifacts/dev/20260912-100955-test-test_unit_test_title_music.gd-ed7b62f6/`
et `artifacts/dev/20260912-101310-production-audio-e2949c95/`.

Panneau navigateur initial :

- Syntaxe JavaScript : `node --check` sur le catalogue et le contrôleur.
- Vérification navigateur avec agent-browser : les huit fichiers se décodent,
  ont une durée valide et leur lecture avance, sans erreur média.
- Onze contrôles d’interface réussis : lecteur unique, favoris, filtres, volume,
  saut à 2:45, boucle, changement automatique, arrêt, précédent.
- Captures inspectées, aucune erreur JavaScript rapportée par le navigateur.
- Preuves : `artifacts/audio/title_music_panel_v1/playback-report.json`,
  `controls-report.json`, `panel.png` et `panel-full.png`.

Ces contrôles attestent du fonctionnement de la lecture, pas d’une appréciation
auditive des morceaux. Le panneau garde les versions originales et ne prétend
pas égaliser leur volume perçu. Cette validation concerne le panneau initial ;
l’intégration locale au titre et ses contrôles Godot sont décrits plus haut.
