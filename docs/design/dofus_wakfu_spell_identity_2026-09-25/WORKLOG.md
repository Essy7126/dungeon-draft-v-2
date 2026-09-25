# Étude précise DOFUS / WAKFU — suivi

Date de lecture : 25 septembre 2026. Base Git : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`.

## Mission

Comprendre les sorts comme des contrats complets : coûts, cibles, ordre, mémoire, déclencheurs, restrictions, rôle dans le kit, contre-jeu et leviers d'équilibrage. Livrer des analyses réutilisables dans le dépôt, sans modifier le gameplay.

## Livraison

- 36 sorts DOFUS : 22 Xélor, 8 Pandawa, 6 Féca. Base communautaire étiquetée 3.6.9.9 ; toutes les variantes non couvertes.
- 55 sorts/passifs WAKFU : 21 élémentaires/actifs Xélor, 20 passifs Xélor, 8 Pandawa, 6 Féca ; niveau 245. Critiques des 15 élémentaires Xélor lus.
- Sept documents Markdown, deux programmes de calcul/vérification, un résultat JSON réutilisable. Point d'entrée : [README](README.md).
- Sources, limites, contre-jeux et implications pour les cartes consommables séparés. Aucun fichier de gameplay modifié.
- Corrections de version identifiées : Tempus fugit, Aiguille et Connaissance du passé. Distorsion, certains états/coefficients et plusieurs branches Pandawa restent non certifiés.
- Notes officielles 1.92 inaccessibles en direct ; lien trouvé dans l'annonce Steam et texte détaillé retrouvé dans l'index du wiki. Annonces Steam 1.92/1.93 effectivement lues.

## Vérifications exécutées

- `node docs/design/dofus_wakfu_spell_identity_2026-09-25/calculs.mjs` : succès ; 14 cas, 15 groupes de contrôles, couverture 36 + 55.
- `node docs/design/dofus_wakfu_spell_identity_2026-09-25/verifier_dossier.mjs` : succès ; tableaux, liens locaux, syntaxe des URL et 91 sources de fiches distinctes. Rapport détaillé dans `artifacts/dev/dofus_wakfu_spell_identity_2026-09-25/validation.json`.
- Le premier contrôle ponctuel des liens avait une erreur de syntaxe ; remplacé par le vérificateur conservé et exécuté avec succès. Ce premier essai n'est pas compté comme validation.
- Aucun client Ankama ni runtime Godot exécuté. Les 16 scénarios de l'étude sont un protocole proposé, pas des tests passés.

## Reprise

Les inconnues sont dans [SOURCES_ET_VERSIONS](SOURCES_ET_VERSIONS.md), les scénarios dans [IDENTITE_ET_EQUILIBRAGE](IDENTITE_ET_EQUILIBRAGE.md). Les modèles ne doivent pas être promus en simulateur fidèle sans résoudre ces points. Préserver les autres études non suivies dans Git. Aucun commit ni push effectué : synchronisation sur un autre ordinateur non réalisée.
