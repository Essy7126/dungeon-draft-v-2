# Passe-Rive — intégration des sprites S18 et VFX S19

État historique S19. La correction des directions est décrite dans
[S20](../passe_rive_s20/README.md), qui remplace la limite « une vue et son miroir »
ci-dessous dans les combats Cartes actuels.

Les neuf planches du personnage acceptées sont conservées à l'identique. Les cinq
planches VFX sont également copiées sans retouche, dans
`assets/characters/PasseRive/sprites_s19/`. `integrity.json` donne leurs empreintes.
`body_preservation.json`, `generated_sources.json` et `CONCEPTS.md` conservent
la provenance du lot artistique. Aucun personnage ni asset Dofus n'est distribué.

## Périmètre en jeu

La variante Passe-Rive utilise ce lecteur dans les combats **Cartes**. Les autres
apparences et le mode Classique conservent leur lecteur. Le Seuil, les haltes et
les portraits conservent leurs assets existants.

| Carte | Geste | Résolution depuis le début du geste |
|---|---|---|
| Lames croisées | Deux coupes | 550 ms, une seule application des dégâts |
| Attaque oblique | Feinte et estocade | 595 ms |
| Dague lancée | Armé et lancer | 570 ms |
| Trait tendu | Tension et décoche | 780 ms |
| Volée croisée | Visée haute et volée | 830 ms |
| Éclat de braise | Projection de feu | 810 ms |
| Sceau d'ombre | Geste vertical et sceau | 870 ms |

Les cinq cartes d'initiation correspondantes réutilisent le même geste et le même
impact, avec leurs propres règles et valeurs. Les autres cartes emploient un geste
de famille et leurs VFX existants : elles n'ont pas reçu une animation dédiée.

L'horloge et les signaux d'action existants pilotent anticipation, résolution et
récupération. Le lecteur ne change ni les dégâts, ni les coûts, ni le déplacement.
Les impacts ne reçoivent que les contacts confirmés par SpellCaster. Le sceau
utilise le registre des états du routeur, jusqu'à expiration, retrait ou décès.
Sa provenance vient du compte rendu du sort, car l'état Marqué ne stocke pas
obligatoirement de lanceur. Les anciens projectiles ne doublent pas ces impacts.

## Limites artistiques explicites

- Une vue dessinée et son miroir horizontal ; pas huit directions dessinées.
- Les petits projectiles déjà peints dans les poses sont préservés : leur trajet
  local n'est pas recalculé vers chaque cellule. Le contact cible, lui, est réel.
- Les pivots et découpes sont ceux de S18, y compris la dague qui déborde d'une case.
- Aucune nouvelle pose de blessure ou de mort : teinte brève et disparition du
  personnage en attendant des dessins dédiés.
- La garde conserve l'arc du dessin S18, y compris après un autre type de sort.

## Essai reproductible

Depuis la racine du projet :

```powershell
./tools/class_card_vfx/play_passe_rive_s19.ps1
./tools/class_card_vfx/play_passe_rive_s19.ps1 -Capture
./dev.ps1 test cards
./dev.ps1 test test/unit/test_passe_rive_autosprite.gd
```

L'arène est la scène de combat du jeu, pilotée par les mêmes requêtes de sort.
L'IA est suspendue et la main, les positions et les ressources sont préparées pour
l'essai. Ce n'est pas un test de difficulté. Les données utilisateur sont isolées
dans le dossier du lancement ; les sauvegardes personnelles ne sont pas utilisées.
Les boutons permettent de rejouer, inverser la direction, ralentir et retirer le sceau.
La capture automatique vérifie aussi les cinq initiations et le retour en garde.

Les JSON du pack sont la source des métadonnées. Après une modification volontaire,
`python tools/class_card_vfx/build_s19_data.py` régénère le script de données UTF-8
et ses dépendances de textures explicites pour l'export Godot.
