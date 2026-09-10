# Achille des Enfers — deux propositions

10 septembre 2026, base Git `2473c335`. Retour ultérieur : l'utilisateur préfère clairement l'Écho de bronze et demande des skins dans cette DA. Voir [les quatre propositions](../echo_skins_v1/README.md). Ce choix de direction ne constitue pas une livraison de personnage animé.

## Dernier retour utilisateur

La simplicité de `graphic_v1` est jugée clairement meilleure, mais le personnage
reste trop enfantin et éloigné de la DA des maps Émeraude et de l'écran titre.
Achille est mort et se trouve aux Enfers ; explorer un aspect fantôme et une
direction artistique plus libre. Garder la bonne résolution et le faible niveau
de détail demandés précédemment.

## Sources créées avec ImageGen intégré

- [A — Revenant](achille_revenant_v1.png) : adulte cendré, petit regard jade,
  bronze assourdi, tunique ivoire et bleu sombre, marque au talon.
  [Prompt exécuté](revenant_text_prompt.txt).
- [B — Écho de bronze](achille_echo_v1.png) : effigie funéraire habitée,
  visage d'ivoire fendu, corps sombre, bronze et drapé clair.
  [Prompt exécuté](echo_prompt.txt).

Les deux sources sont des PNG RGBA natifs 1024 × 1536, copiés sans modification
des résultats ImageGen. Dimensions, alpha et SHA-256 dans `manifest.json`.
Les originaux générés sont respectivement `exec-924aeafe-d7dc-4926-a552-c8eab8425466.png`
et `exec-76bd651f-c540-467c-a931-0f5b58fb486a.png`.

## Références réellement consultées

- `asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png` : salle active.
- `assets/catabase/title/underworld_gate_emerald_v1.png` : variante active du titre.
- Les prompts de ces deux décors, la définition de la salle et le suivi du menu.

Ces deux images ont été inspectées visuellement. L'appel qui tentait de les
transmettre directement comme références a échoué avant génération :
`apply deny-read ACLs`. `revenant_prompt.txt` conserve cet essai échoué.
Les deux images effectivement produites reposent sur des prompts textuels
décrivant les caractéristiques observées. Aucune transmission réussie des
références visuelles au générateur n'est revendiquée ; aucune API alternative.

## Revue et limites

[Comparaison locale](http://127.0.0.1:8734/files/achille_enfers_v1/review.html) :
deux propositions, deux décors actifs, taille réglable et miniatures à 130 px.
Montage HTML indicatif, sans intégration ni modification Godot. Appuis, échelle,
caméra et ombres de contact ne sont pas encore calibrés.

Captures `revenant_sanctuaire.jpg` et `echo_titre.jpg` inspectées. Les deux
personnages et décors chargent, le masquage fonctionne, aucune erreur de page.
Rapport et captures : `artifacts/spine_trial/achille_enfers_v1/`.

Jugement de travail : A améliore l'âge apparent et l'ambiance, mais garde trop
de modelé anatomique et de plis. B est une identité plus libre et plus graphique,
avec un risque d'être lu comme un ennemi ou une statue sans humanité. Les jambes
sombres de B devront aussi rester lisibles sur les sols froids. La fidélité au
style des décors n'est pas certifiée. Simplifier encore les plans internes de la
piste retenue plutôt que multiplier les détails.

Suite : revue de la présence du héros et du degré de surnaturel, puis dessin
maître cohérent avant les orientations et animations. Ne pas lancer un nouveau
rig 3D détaillé pour résoudre cette question artistique ; Blender reste un guide
de poses. Les variantes antérieures et les personnages runtime sont conservés.
