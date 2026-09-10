# Achille Passe-rive — référence choisie

10 septembre 2026, base Git `2473c335`. Choix utilisateur : « On va essayé avec passe rive ».

`reference_choisie.png` est une copie exacte du skin retenu, PNG RGBA 1024 × 1536.
SHA-256 : `178409524db1e7bf7dbef01e6ab5f7aee449c26fa1d90853682d509207d61330`.
Le visage adulte d'ivoire fendu, la capuche pétrole, le corps sombre, le drapé
jade, l'obole et les équipements définissent désormais la référence de cet essai.
Les autres skins restent des recherches conservées.

## Premier essai préparé

Une seule pose de contact d'estoc dans la vue trois-quarts actuelle, avant une
séquence entière. Le prompt exact est `contact_prompt.txt`. Garder le personnage
et son style ; vérifier d'abord qu'un changement de pose ne le redessine pas.

Le guide Blender existant a été relu :
`art/source/sprite_workshop/sentinelle_guided_v1/pose_guide.json`.
Il sert uniquement à analyser le transfert de poids et la coordination.
Ses proportions ne sont pas celles de Passe-rive. Le pied avant est stable entre
les poses 13 et 16 ; la lance suit la direction écran bas-droite. Aucun nouveau
rig, habillage 3D ou rendu Blender n'a été construit pendant ce choix.

## État actuel — accès réparé, première pose produite

Le 10 septembre à 18 h 42, le cache corrompu du sandbox a été sauvegardé et mis
de côté ; Codex l'a recréé. La lecture sans élévation, `view_image` puis ImageGen
avec référence fonctionnent. Configuration inchangée, ACL contrôlées identiques,
test d'écriture hors du projet correctement refusé. Voir le
[diagnostic et sa résolution](sandbox_diagnostic_2026-09-10.md).

`contact_estoc_v1.png` est le premier dessin de contact obtenu avec le PNG choisi
comme véritable référence d'édition, par ImageGen intégré et `contact_prompt.txt`.
Source native : `exec-56d1f54b-6154-4db6-9db3-f7d11bc1aeff.png` dans le répertoire
ImageGen de cette tâche. Métadonnées : `contact_estoc_v1_metadata.json`.

Le dessin conserve visuellement le masque, la capuche, la palette et les motifs
principaux. Il reste un essai : appuis très écartés, faible flexion avant,
extrémité arrière de la hampe non visible. La coordination sur une séquence
n'est pas démontrée par ce dessin isolé.

Le PNG est RGB 1536 × 1024 : le damier est peint, sans transparence réelle.
Une correction limitée au détourage a été tentée avec ImageGen, mais le résultat
reste RGB et montre le damier. `alpha_attempt_prompt.txt` conserve le prompt et
`alpha_attempt_metadata.json` son résultat non retenu. Aucun détourage logiciel
substitutif, aucune API externe et aucune intégration Godot n'ont été effectués.

Cet estoc reste un essai historique non détouré. La priorité utilisateur est
ensuite devenue marche et idle, **une direction soignée d'abord**. L'utilisateur
a explicitement autorisé le détourage logiciel pour ces nouveaux dessins.
Lire la [fiche du socle de mouvement](../passe_rive_motion_v1/README.md) pour les
huit poses RGBA, l'idle sur le dessin original, la revue et les défauts restants.
