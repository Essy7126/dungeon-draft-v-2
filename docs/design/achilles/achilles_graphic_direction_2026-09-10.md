# Nouvel Achille — direction graphique à revoir

L'utilisateur demande un personnage neuf : le classique manque de résolution,
et le peint G paraît trop musclé et épais. Une première proposition élancée reste
jugée trop détaillée. La priorité est désormais un dessin simple inspiré de la
lisibilité des personnages Dofus, avec une grande source nette, des aplats et
peu de détails internes. La résolution ne doit pas augmenter le détail anatomique.

Lire la [fiche du candidat graphique](../../../art/source/characters/achilles/concepts/graphic_v1/README.md)
pour le PNG natif, le prompt, les vérifications et le montage dans l'atelier.
Ce candidat attend la revue artistique. Les deux apparences intégrées au jeu
restent conservées. La production d'animations et le guidage des poses par
Blender viendront après le choix d'une direction convaincante.

## Évolution — Achille mort dans les Enfers

Le retour suivant juge la simplicité de `graphic_v1` clairement meilleure, mais
l'allure trop enfantine et la DA éloignée des décors Émeraude et du titre. Le
personnage doit paraître adulte et peut porter les signes de sa mort. Deux
nouvelles propositions explorent un revenant humain et une effigie funéraire
habitée. Lire la [fiche Achille des Enfers](../../../art/source/characters/achilles/concepts/underworld_v1/README.md)
pour les PNG, prompts, références réellement consultées et comparaison dans les
décors. Aucune piste n'est encore validée et aucun changement runtime n'est livré.

## Direction retenue pour l'exploration : Écho de bronze

L'utilisateur préfère clairement l'Écho et demande plusieurs skins créatifs.
Les [quatre skins exploratoires](../../../art/source/characters/achilles/concepts/echo_skins_v1/README.md)
sont Serment pourpre, Passe-rive, Cendre vive et Marbre oublié. La fiche conserve
les sources natives, prompts, limites de génération et revue dans les décors.
Aucun de ces quatre skins n'est encore choisi ; aucun kit animé n'est livré.

## Choix pour le premier essai : Passe-rive

L'utilisateur choisit Passe-rive. La [référence figée et l'essai de contact](../../../art/source/characters/achilles/passe_rive_v1/README.md)
conservent le PNG exact, son empreinte et le prompt du premier estoc. L'appel
avec référence locale est bloqué par `apply deny-read ACLs`. Aucune pose nouvelle
ni animation livrée. La prochaine étape exige une référence image accessible
au générateur ; ne pas repartir d'un personnage seulement décrit par texte.

### Précision du blocage après réattachement

Le PNG réattaché échoue également avant génération. Le diagnostic en lecture
seule trouve `deny_read_acl_state.json` rempli de 22 octets nuls ; le journal
signale précisément son échec de parsing. Voir le
[diagnostic conservé](../../../art/source/characters/achilles/passe_rive_v1/sandbox_diagnostic_2026-09-10.md).
Aucune nouvelle image ni réparation du sandbox livrée ; ne pas redemander le PNG.

### Résolution et premier essai — 10 septembre, 18 h 42

L'incident ci-dessus est résolu. Le cache corrompu a été sauvegardé puis recréé
par Codex ; configuration et ACL contrôlées inchangées, écriture hors projet
refusée. L'édition avec référence a enfin produit `contact_estoc_v1.png` dans
`art/source/characters/achilles/passe_rive_v1/`. Ce dessin conserve les éléments
principaux de Passe-rive mais reste à évaluer pour les appuis et la lance.
Il est RGB avec damier peint ; une correction ImageGen de transparence a échoué.
Pas de kit animé ni d'intégration runtime. La fiche Passe-rive décrit l'état
actuel et les limites, les paragraphes de blocage précédents sont historiques.

## Socle suivant — idle et marche, une direction d'abord

L'utilisateur demande une base soignée avant les actions spectaculaires et
choisit de travailler une seule vue trois-quarts. Il autorise explicitement le
détourage logiciel. La [fiche de mouvement Passe-rive](../../../art/source/characters/achilles/passe_rive_motion_v1/README.md)
documente huit dessins natifs 1024 × 1536, détourés localement, et un idle par
shader sur la référence exacte. La revue compare les dessins au guide d'appui
calculé et au décor Émeraude. Import et exécution du projet Godot autonome
réussis ; aucune intégration dans le combat principal.

La marche n'est pas artistiquement validée : les appuis dessinés ne suivent pas
encore assez le guide et certains accents de chaussure varient. Corriger cette
direction avant d'étendre le kit. Le guide ne constitue pas une preuve de
cohérence physique des images générées.
