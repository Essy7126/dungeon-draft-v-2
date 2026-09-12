# Étude du contact peint

Petit projet Godot autonome consacré à une seule construction VFX. Il réemploie
les quatre calques de `art/source/vfx/peleid_fresco_v1`. La peinture reste candidate.
Ce laboratoire ne remplace pas le Studio, ne publie aucun asset et ne charge pas
les autoloads de Catabase.

Depuis la racine du dépôt, avec le moteur fixé dans `tools/dev/toolchain.json` :

```powershell
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --path tools/labs/peleid_contact_study
```

On peut aussi importer le `project.godot` de ce dossier et lancer son projet.
Ne pas lancer cette scène par F6 depuis le projet parent : ses chemins `res://`
désignent volontairement le petit projet isolé.

- Espace : pause / reprise ; R : rejouer.
- Flèches gauche/droite : avancer ou reculer de 1/60 seconde.
- G : silhouette grise ; M : afficher/masquer les éclats.
- D : comparer l’érosion à une simple baisse d’opacité.

Les trois panneaux du haut comparent les rythmes avec un agrandissement ×3.
Les trois panneaux du bas montrent tous le rythme B à 72 px de largeur de
référence, sur trois fonds. C’est une fixture, pas une capture de combat réel.

`recipe.json` contient les temps, tailles et trajectoires. `study.gd` échantillonne
ces paramètres au temps absolu ; `contact.gdshader` n’utilise pas `TIME`.
La position de contact du maître reste fixée pendant l’ouverture.

## Captures reproductibles

```powershell
& 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe' --path tools/labs/peleid_contact_study --log-file "$PWD/artifacts/dev/peleid_contact_study/engine.log" -- --capture
node tools/labs/peleid_contact_study/assemble.cjs
```

Ces commandes écrivent dans `artifacts/dev/peleid_contact_study/` et remplacent
les captures de ce laboratoire. Ne pas lancer plusieurs captures de ce laboratoire
simultanément. La capture est manuelle et n’acquiert pas le verrou de `dev.ps1`.

La première commande requiert un GPU ; `--headless` ne valide pas ce rendu.
Elle produit 7 PNG temporels, 84 frames à 60 FPS et un rapport avec trois contrôles
sur les pixels des panneaux agrandis. La seconde assemble un GIF de revue sans
modifier les images sources et conserve les checksums des entrées.

`assemble.cjs` utilise Node et Sharp : module local si disponible, puis `SHARP_PATH`,
puis le runtime partagé Codex de ce poste. Aucun téléchargement automatique.
Le GIF sous-échantillonne à environ 30 FPS, réduit la palette et arrondit le temps
à la centiseconde ; les PNG et le rendu interactif restent les références.

## Portée

Le dernier journal GPU Forward+ est propre. Cela ne certifie ni l’import d’un atlas
transparent, ni le gameplay, ni le son, ni les performances sur le matériel cible.
Le projet ne possède pas encore d’export flipbook de production.

La construction, le contrat d’export envisagé et les critères de passage sont dans
[le dossier de construction](../../../docs/design/achilles/vfx_feasible_construction_2026-09-12.md).
