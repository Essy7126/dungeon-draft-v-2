# Premier essai Spine

## Kit courant

**Sentinelle : 24 animations E/S/W/N, révision `sentinelle_kit_v7`.**
Voir [le guide du kit](../../docs/spine/sentinelle_kit.md).
Lancer `./tools/spine_trial/kit.ps1 start`, ou ouvrir `SentinelleKit.tscn` dans Godot.
La documentation ci-dessous décrit le premier contrôle de rig E/N, conservé.

Installation locale du 9 septembre 2026. Choix utilisateur : rester sur la trial.
Le connecteur et le lecteur utilisent Spine **4.2** ; l'éditeur trial installé
est **4.3.26**. Le fichier `toolchain.json` verrouille les sources et archives.

## Ouvrir

```powershell
./tools/spine_trial/spine.ps1 start
```

Dashboard : <http://127.0.0.1:8734/>. Le serveur écoute uniquement sur la boucle
locale et ses fichiers sont limités à `artifacts/spine_trial/`.
La configuration `.codex/config.toml` expose 8 outils sous `spine_trial` après
rechargement MCP. Les 2 commandes nécessitant une licence ne sont pas exposées.
Le serveur est lancé pour cette session Windows ; relancer `start` si nécessaire.

Dans Godot, ouvrir `tools/spine_trial/SpineTrial.tscn`, puis **F6**. Le sélecteur
propose Spineboy et les vues E/N de la Sentinelle ; Pause arrête la lecture.

Dans Spine Trial, **Import Data** puis sélectionner :

- `artifacts/spine_trial/sentinelle/E/sentinelle.json` ;
- ou `artifacts/spine_trial/sentinelle/N/sentinelle.json`.

Les PNG séparés sont dans le sous-dossier `images/`. Conserver l'échelle d'import
à 1 et le dossier d'images `./images/`. L'ouverture/import dans l'éditeur trial
reste à constater manuellement : les lecteurs web et Godot ont été vérifiés.
La trial ne sauvegarde ni n'exporte le travail de l'éditeur ; aucun `.spine`
éditable n'est présenté comme livré. Ne pas confondre la trial 4.3 avec les
données 4.2 ni promettre un aller-retour entre versions.

## Conversion livrée

Chaque vue possède 14 os, 24 régions et ses propres dessins. L'adaptateur
`prepare_sentinelle.py` réutilise `humanoid_parts.build_parts` et `PaintedSkeleton` :
découpes, dessous peints et IK restent ceux du pipeline de monstres.
Les coordonnées Spine sont vérifiées contre les transformations du service,
avec une erreur inférieure à `5e-7` ; les pixels relus de l'atlas sont exacts.

`repos` et `controle_articulations` servent à vérifier le rig. Cette dernière
contient cinq poses du corps avec appuis contraints ; **ce n'est pas une nouvelle
attaque approuvée**. Les essais A/B/B2 rejetés ne sont pas réutilisés. La nouvelle
mécanique de l'estoc doit être conçue et revue avant les détails.

Les sources de production n'ont pas été remplacées. Chaque sortie possède un
`manifest.json` avec provenance et limites. Un second `prepare` refuse d'écraser
un dossier déjà édité. Le lecteur Godot synchronise une copie `.spine-json`,
extension attendue par son chargeur, depuis le JSON de travail à chaque sélection.

## Installation et contrôles

```powershell
./tools/spine_trial/install.ps1
./tools/spine_trial/spine.ps1 prepare  # seulement si les sorties n'existent pas
./tools/spine_trial/spine.ps1 start
node tools/spine_trial/smoke_mcp.mjs
./dev.ps1 test smoke
./tools/spine_trial/verify.ps1
```

Prérequis existants : Node, le Python isolé `artifacts/dev-tools/sprite-python`
avec Pillow/NumPy/SciPy, et Godot configuré par `dev.ps1 doctor`.
Le runtime officiel est dans `addons/spine_godot_trial/`, ignoré par Git,
avec sa licence. Pas d'achat, de publication ni d'intégration au combat.

Preuves de cette livraison sous `artifacts/dev/` :

- `spine-mcp-1788974305451` : 8 contrôles MCP, clés enregistrées sur une copie
  de Spineboy, traversée de chemin refusée et GIF officiel de 8 images.
- `20260909-192237-test-smoke-24b14bd1` : import avec GDExtension, 16 tests et
  215 assertions réussis.
- `20260909-192644-spine-godot-preview-be5734bc` : 3 squelettes animés dans le
  runtime natif, captures enregistrées, aucune erreur moteur ; captures E/N
  examinées. Premier essai précédent en échec sur l'extension JSON, corrigée.
- GIF Sentinelle E/N : 12 images, 1,2 seconde, produits par `preview_gif` dans
  chaque dossier de travail. Ils prouvent la lecture, pas la qualité d'un estoc.

La GDExtension officielle construite pour Godot 4.6.1 fonctionne dans ces essais
sur Godot 4.7.1. Cela ne valide pas les autres plateformes ou une intégration
combat complète. Ne pas intégrer ce runtime d'évaluation à une distribution.

Sources : [connecteur](https://github.com/nihatcagri44/spine-motion-mcp),
[runtime Godot](https://esotericsoftware.com/spine-godot),
[import](https://esotericsoftware.com/spine-import),
[trial](https://esotericsoftware.com/spine-download).
