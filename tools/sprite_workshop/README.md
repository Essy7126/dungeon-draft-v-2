# Atelier de production des sprites

L'atelier prépare et compare des **dessins existants**. Il permet de sélectionner
les poses, corriger leur placement et leur rythme, puis livrer un clip traçable.
Il ne produit pas automatiquement de nouvelles poses crédibles.

Pour la production courante, lire la [mémoire courte d'animation](../../docs/ai/animation_memory.md)
et le [comparatif des méthodes et générateurs](../../docs/design/achilles/sprite_generation_research_2026-09-10.md).
Ils distinguent les progrès d'appui de Passe-rive V2, les résultats peints encore
à obtenir et le prochain essai destiné à mesurer le temps de correction.

Le [pilote de Sentinelle](../../docs/tools/sentinelle_attack_pilot_2026-09-09.md)
a produit des variantes et un comparatif animé, puis a été rejeté en revue
artistique : coordination du corps et directions insuffisantes. Le
[catalogue de références de mouvement](../../docs/tools/sprite_motion_references_2026-09-09.md)
définit le prochain essai et le panneau de référence animée encore à ajouter.

Le [dossier Spine](../../docs/spine/README.md) est le point d'entrée pour reprendre
les recherches, le choix du connecteur et les essais d'animation dans une autre tâche locale.

## Ouvrir

```powershell
./tools/sprite_workshop/workshop.ps1 open
```

Ou ouvrir `tools/sprite_workshop/SpriteWorkshop.tscn` puis **F6** dans Godot.
Le menu **Projet > Outils > Dungeon Draft : ouvrir l'atelier de sprites (F6)**
ouvre cette scène quand le plugin Studio a été rechargé.

Les deux documents d'exemple sont versionnés dans `art/source/sprite_workshop/` :

- `achille_dash_e.json` conserve la ruée appréciée, avec ses quatre dessins et
  une attente d'arrivée. Elle reste une référence, sans nouvelle génération.
- `sentinelle_attack_e.json` importe l'attaque actuelle à huit dessins. Son statut
  artistique est **à examiner**, pas « nouvelle animation finale ».

L'original reste dans le document. **Copie…** crée une variante indépendante.
Les PNG sources ne sont jamais écrasés par l'atelier. Une confirmation protège
les modifications non enregistrées avant un changement de document ou la fermeture.

## Production d'une action

1. **Référence.** Reprendre le dessin canonique de chaque direction : silhouette,
   proportions, palette, équipement et main porteuse. Ne pas retourner les sprites
   pour fabriquer les directions opposées. Inscrire l'intention du clip et ses
   difficultés dans `intent` et `open_questions` du JSON.
2. **Poses décisives.** Préparation, engagement, contact ou release, récupération.
   Vérifier d'abord ces poses à taille jeu ; décider ensuite des intermédiaires.
   Le nombre de dessins dépend du geste. Ni « huit dessins » ni « 60 fps » ne
   constituent un objectif artistique.
3. **Candidats.** Dessiner ou générer les nouvelles poses à partir des références
   visuelles, puis conserver seulement celles qui conviennent. Réutiliser les
   découpeurs/assembleurs Achille et monstres pour obtenir des PNG normalisés.
   Pas de redimensionnement automatique par pose : une flexion ne doit pas
   agrandir le personnage. Conserver les sources, prompts et motifs de sélection.
4. **Montage.** Dans une copie du clip, remplacer les dessins défectueux par des
   PNG transparents du même canevas, réordonner, régler les durées et décalages.
   Examiner les images voisines en transparence et comparer original/candidat.
   Annuler/rétablir conserve les identifiants des poses et leurs événements.
5. **Revue.** Regarder à vitesse normale et à taille jeu, puis au ralenti : identité,
   anatomie, équipement, lisibilité de l'action, appuis et transitions. L'ancre
   commune est un repère ; ses coordonnées seules ne prouvent pas un bon appui.
   Documenter l'auteur et ses observations avant **Valider le visuel**.
6. **Livraison technique.** Exporter la revue ; vérifier le rapport. Les fichiers
   prêts à retoucher sont dans `frames/`, avec `reference.png`. L'atlas est assemblé
   par copie des pixels. Le SpriteFrames est relu et comparé aux images attendues.
7. **Intégration et combat.** Reporter uniquement le clip retenu dans l'assembleur
   de sa famille. Adapter les paramètres du profil et vérifier la scène de combat
   correspondante. Revoir départ, release/impact, déplacement, réception,
   interruption et retour au repos. Valider les autres directions après le pilote.

Les services de cet atelier sont dans le Studio et sont partagés entre l'interface
et la commande. Les assembleurs existants restent responsables des ressources
complètes des personnages ; leurs autres animations sont conservées.

## Commandes pour une personne ou un agent

```powershell
# Idempotent : crée seulement les exemples manquants, conserve ceux déjà édités.
./tools/sprite_workshop/workshop.ps1 seed

./tools/sprite_workshop/workshop.ps1 check -Clip res://art/source/sprite_workshop/sentinelle_attack_e.json
./tools/sprite_workshop/workshop.ps1 export -Clip res://art/source/sprite_workshop/sentinelle_attack_e.json
./tools/sprite_workshop/workshop.ps1 capture

# Nouveau document : PNG ou AtlasTexture avec marges, directions N/E/S/W.
./tools/sprite_workshop/workshop.ps1 import `
  -Resource res://assets/characters/catabase_monsters/sentinelle_airain/sprite_frames.tres `
  -Animation cast_E `
  -Profile res://data/visuals/catabase_monsters/sentinelle_airain_sprite_profile.tres `
  -Clip res://art/source/sprite_workshop/sentinelle_cast_e.json

# Nouvelle action depuis des PNG transparents normalisés, sans SpriteFrames préalable.
# Remplacer ces exemples de chemins par les dessins présents dans le projet.
./tools/sprite_workshop/workshop.ps1 new `
  -Frames @('res://art/source/mon_action/pose_01.png', 'res://art/source/mon_action/pose_02.png') `
  -Reference res://art/source/mon_action/repos_E.png `
  -Animation attack_E -Clip res://art/source/sprite_workshop/mon_action_e.json

./dev.ps1 test test/unit/test_sprite_clip_workshop.gd
```

L'import refuse d'écraser un document. `-Profile` importe l'échelle et l'ancre
lorsqu'elles existent. La durée de chaque dessin provient du SpriteFrames ; les
événements et règles particulières d'un nouveau personnage doivent être explicités.
Le backend peut ignorer la vitesse du SpriteFrames : vérifier son contrat avant
de considérer cette durée comme la durée effective en jeu.

`new` exige une référence explicite et initialise chaque pose à 100 ms, l'échelle
à 0,35 et l'ancre au centre horizontal, à 5/6 de la hauteur. Ce sont des valeurs
de départ à revoir. Le clip et la référence doivent partager le même canevas.

Chaque commande moteur utilise le harnais existant : résolution du moteur,
verrou commun, délai maximal, logs et rapport unique dans `artifacts/dev/`.
Une sortie sans rapport ou comportant une erreur moteur est un échec.
`open` lance une application interactive, sans déclarer de validation.

Les scripts agents peuvent éditer le JSON, appeler `check`, puis `export`.
Pour économiser le contexte, lire d'abord erreurs/avertissements et les seuls
dessins modifiés. Consulter les sources et logs détaillés lorsque nécessaire.
Aucune économie chiffrée de tokens n'a encore été mesurée.

## Document et livrables

Le JSON contient le canevas, l'ancre, l'échelle d'affichage, les durées en ms,
la direction, les régions des PNG, leurs placements et empreintes SHA256,
les événements, l'original, les questions ouvertes et la revue visuelle.
Les événements désignent des identifiants stables de dessins, pas leurs indices.
Ils sont positionnés au début de la pose ; un événement entre deux poses nécessite
de diviser une tenue. Le schéma accepte 1 à 64 poses, canevas maximal 1024 × 1024.

Export dans `artifacts/sprite_workshop/<id>/<empreinte>/` :

| Fichier | Usage |
| --- | --- |
| `frames/000.png`, etc. | PNG transparents normalisés, destinés aux retouches |
| `reference.png` | Repos canonique, si disponible à l'import |
| `atlas.png` | Planche à quatre colonnes maximum et gouttières transparentes |
| `clip.res` | SpriteFrames avec texture embarquée, relisible même dans un dossier ignoré par l'import |
| `clip.json` | Copie exacte du document exporté |
| `timing.json` | Ancre, échelle, règles de lecture et événements |
| `report.json` | Résultat des contrôles, empreintes et limites |

Une modification de dessin, ordre, durée ou référence rend la revue visuelle
périmée. Une simple sauvegarde/relecture ne la périme pas. Une source modifiée
sur disque bloque la validation : examiner la différence puis faire un nouvel
import ou sélectionner explicitement le nouveau PNG. Ne pas actualiser ses
empreintes automatiquement pour contourner le contrôle.

### Cas particulier de la ruée

Dans le jeu, la release arrive à 100 ms, la pose 2 attend le contrôleur, puis la
réception dure 80 ms. L'atelier utilise une arrivée simulée, réglable ; original
et candidat partagent ce scénario d'arrivée pour permettre la comparaison.
Le champ durée de la pose maintenue sert de durée nominale d'export ; la lecture
de revue la remplace par l'attente du scénario.

**AnimatedSprite2D seul ne consomme pas `timing.json`.** Ses événements et
l'attente d'arrivée nécessitent le contrôleur. L'export n'écrase ni les profils
ni les SpriteFrames utilisés par le jeu. Les contrôles de l'atelier ne remplacent
pas les tests existants du backend d'Achille ou des monstres.

## Points encore à éprouver

- **Qualité du dessin :** pour l'estoc de la Sentinelle, comparer une correction
  des poses existantes à quelques poses clés redessinées. Garder la même référence,
  direction, taille et durée totale pour juger les dessins. Tester le rythme
  séparément. Si deux essais ciblés stagnent, signaler le blocage et changer
  d'approche ; ce seuil est une règle de travail ajustable, pas une garantie.
- **Fluidité et complexité :** on n'a pas encore produit une nouvelle attaque
  finale avec cet atelier. Pas de promesse sur les rotations prononcées, parties
  cachées ou grands changements de perspective.
- **Retouche :** l'atelier assemble et compare ; il ne remplace pas une brosse.
  Krita pour les sources peintes ou Aseprite pour des retouches adaptées peuvent
  être évalués sur une pose problématique. Aucun achat/installation requis ici.
- **Passage à l'échelle :** les directions se traitent en clips séparés. Pas de
  diffusion automatique d'une correction sur tout le personnage ou sur un rig.
- **Intégration :** livraison vers les assembleurs de familles puis essais réels.
  Pas de bouton qui déclare « production finale » à partir d'un contrôle alpha.

La recherche et ses sources primaires sont conservées dans
`docs/tools/sprite_motion_workshop_proposal_2026-09-09.md`.

Le [bilan de livraison du 9 septembre](../../docs/tools/sprite_workshop_implementation_2026-09-09.md)
donne les commandes vérifiées, les rapports et les échecs observés dans la suite
générale du Studio. Un rapport technique valide ne constitue pas une approbation
artistique du clip.
