# Écho de bronze — quatre skins exploratoires

10 septembre 2026, base Git `2473c335`. L'utilisateur préfère explicitement
l'Écho de bronze et demande plusieurs skins créatifs dans cette DA.
Retour ultérieur : Passe-rive est choisi pour le premier essai. Voir [la référence figée](../../passe_rive_v1/README.md). Les autres skins restent des propositions.

## Images et prompts

Quatre appels individuels à l'outil intégré ImageGen, quatre PNG RGBA natifs
1024 × 1536. Copies sans modification, alpha conservé, pas d'agrandissement.

| Proposition | PNG source | Prompt exact exécuté |
|---|---|---|
| Serment pourpre | [Image](serment_pourpre.png) | [Prompt](serment_pourpre_prompt.txt) |
| Passe-rive | [Image](passe_rive.png) | [Prompt](passe_rive_prompt.txt) |
| Cendre vive | [Image](cendre_vive.png) | [Prompt](cendre_vive_prompt.txt) |
| Marbre oublié | [Image](marbre_oublie.png) | [Prompt](marbre_oublie_prompt.txt) |

Serment pourpre explore une silhouette cérémonielle avec laurier brisé et manteau
long ; Passe-rive, un revenant du Styx avec capuche et obole ; Cendre vive, une
palette chaude de cuivre, rouille et charbon ; Marbre oublié, une effigie claire
avec des articulations d'ombre. Le visage adulte, la silhouette mince et les
formes simples restent les repères communs.

## Provenance

L'envoi direct de l'Écho original comme référence a échoué avant génération :
`windows sandbox failed: helper_unknown_error: apply deny-read ACLs`.
Cet essai utilisait la source originale ImageGen `exec-76bd651f-c540-467c-a931-0f5b58fb486a.png`.
Les quatre appels réussis utilisent donc le brief textuel détaillé ; il ne s'agit
pas de retouches contrôlées du même dessin. La constance exacte des proportions
ou du visage n'est pas garantie. Aucun appel API alternatif.

Résultats ImageGen copiés, dans l'ordre du tableau :

- `exec-a1232546-c149-4b64-b125-1687b0293eba.png`
- `exec-486cf106-77f3-4948-b054-61e573b80b21.png`
- `exec-8accb82a-eade-4f6d-8dde-12efc71ef488.png`
- `exec-15ae5ce6-2fa2-434b-bf7f-4bd483f7914b.png`

Dimensions, alpha et empreintes SHA-256 figurent dans `manifest.json`.

## Revue

[Comparer les quatre skins et l'Écho original](http://127.0.0.1:8734/files/echo_skins_v1/review.html)
dans le sanctuaire Émeraude et le décor du titre. La revue comprend les PNG,
des miniatures à 120 px, une taille réglable et une comparaison avec la référence.
Ce sont des montages HTML indicatifs ; caméra, appuis, échelle et ombre de contact
ne sont pas encore calibrés. Aucun personnage runtime n'est modifié.

Galerie et montage du titre inspectés. Les quatre sélections chargent la bonne
image, la référence et le masquage fonctionnent, aucune erreur de page détectée.
Captures et rapport dans `artifacts/spine_trial/echo_skins_v1/`.

Jugement de travail : Serment pourpre a une silhouette héroïque distinctive ;
Cendre vive donne un contraste chaud intéressant dans les décors froids.
Passe-rive pourra manquer de contraste sur certains sols sombres. Marbre oublié
reste trop anatomique par rapport à la simplicité demandée. Les capes, plis et
plans de muscles devront être simplifiés dans le futur dessin maître retenu.

Suite : choix artistique ou combinaison ciblée, puis référence de personnage
cohérente avant rig de poses, directions et animations. Ne pas repartir vers
un habillage 3D détaillé pour résoudre les choix de silhouette.
