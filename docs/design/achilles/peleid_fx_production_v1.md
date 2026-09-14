# Frappe du Péléide — Éclat de fresque

12 septembre 2026 — **proposition artistique, pic statique et source en calques ; animation et intégration à faire**. Contexte Git : `0bdfd5bf`, dépôt comportant d'autres travaux en cours. Cette recherche répond au retour utilisateur sur le manque de cohérence artistique des effets précédents. La garde d'airain ne sert plus de modèle pour ce pilote.

## Intention et lecture

Un estoc imprime brièvement une forme de peinture ivoire, bordée de bronze et d'ombre pétrole. Au contact, trois petits éclats plats se détachent, avec un revers terre cuite. L'image évoque une fresque qui s'écaille sous la force du coup. Les fragments expriment l'impulsion ; ils ne racontent ni un projectile de pierre ni des dégâts de feu.

Sort existant : `data/spells/achilles/peleid_strike.tres`, `achilles_peleid_strike`, 3 PA, portée 1, dégâts physiques à 55 % de Prouesse. Le joueur doit comprendre immédiatement la direction du coup et la cible touchée. La silhouette, le visage, les dégâts affichés et les cases doivent rester lisibles. Aucun effet persistant n'est ajouté au sens du sort.

## Direction artistique

Référence canonique : [Catabase — direction artistique peinte](catabase_direction_artistique_v1.md). Références locales examinées :

- `art/source/catabase/painted/references/inventory_icons.png` : matières peintes, rehauts contrôlés et contours colorés.
- `asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png` : ombres pétrole et hiérarchie du contraste.
- `asset/ui/character_hud/generated/spell_icon_r02_c02.png` : vocabulaire de la lance et de la terre cuite.
- `art/source/characters/catabase_monsters/rejeton_braise/base_frame_E.png` : cible réelle des montages, sans redéfinir le héros actuellement en recherche.

| Couleur de référence | Rôle |
| --- | --- |
| Ivoire `#DDD7BD` | Surface de contact, bref accent de valeur claire |
| Bronze patiné `#B48A4E` | Matière et transition vers les ombres |
| Terre cuite `#B5503F` | Revers des éclats, identité physique du Péléide |
| Pétrole `#24565A` | Contour coloré qui résiste sur pierre claire |

Ces couleurs dirigent la peinture ; le candidat comporte des nuances et des rehauts plus clairs. Éviter de transformer ces derniers en halo permanent. Les détails intérieurs doivent pouvoir disparaître à petite taille sans perdre la silhouette.

La première génération a été écartée car trop proche d'un projectile rocheux. La V2 allège les fragments et conserve une empreinte anguleuse. À 72 pixels de largeur totale, le contact est visible sur fond sombre, pierre claire et décor existant ; le visage reste dégagé dans le montage. Ce contrôle visuel statique ne démontre pas la lecture temporelle, la visibilité du HUD ou le rendu en combat.

## Source réellement produite

Dans `art/source/vfx/peleid_fresco_v1/` : prompts exacts, deux recherches brutes, `peak_rgba.png`, quatre PNG de calques et `peleid_contact_master.ora`. Le fichier OpenRaster contient l'empreinte et les trois éclats séparés. Il s'agit de peinture raster éditable, sans animation ni squelette caché. L'image a été créée avec l'outil imagegen ; ce n'est pas un asset Ankama.

La transparence est extraite d'un fond magenta : **elle n'est pas native**. Le traitement reprend les équations de détourage de la préparation painted-G du dépôt. Les quatre formes sont isolées par connexité, sans supprimer de pixels. Une première découpe rectangulaire emportait la pointe basse de l'empreinte : la séparation par formes connexes corrige ce défaut. L'assemblage des calques restitue exactement les octets RGBA après détourage.

`tools/peleid_fx_direction/build.cjs` reconstruit ces exports, l'archive et la planche `artifacts/dev/peleid_fx_direction_v1/proposal.png`. Le manifeste contient le hash de source, les dimensions, les limites des calques et les vérifications. Archive réouverte, mimetype et image fusionnée contrôlés ; ouverture dans un éditeur natif **non testée**. Structure suivie : [spécification OpenRaster](https://www.openraster.org/baseline/file-layout-spec.html).

## Pipeline du pilote et critères de passage

1. **Intention et pic — étape actuelle.** Fixer le sens du sort, la palette, l'échelle et le point de contact. Examiner la même forme sur trois fonds avec une cible du jeu. Livrer le maître en calques. Critère : le coup physique et sa direction se lisent ; il appartient aux matières du jeu. La proposition reste à apprécier artistiquement.
2. **Mouvement du contact seul.** Construire 6 à 8 dessins de silhouette depuis le maître, avec correction possible de chaque pose. Fourchette initiale : 240 à 320 ms au total, pic dans les 40 à 60 premières ms. Commencer par l'empreinte : compression, ouverture brève, rupture, disparition. Un agrandissement de l'image fixe ne suffit pas. Contrôler au ralenti puis à vitesse réelle, taille de jeu, avant d'ajouter les éclats.
3. **Secondaires.** Déplacer et faire pivoter les trois éclats existants sur une courte trajectoire, puis les dissiper. La poussière mate est optionnelle et nécessitera un dessin supplémentaire ; elle n'est pas produite. Critère : les secondaires soutiennent le point d'impact sans devenir le sujet principal. Vérifier aussi une variante simplifiée.
4. **Export et Studio existant.** Préserver un pivot de contact commun par pose ; exporter atlas, durées, emplacements et provenance. Réutiliser les ressources `vfx/data/vfx_flipbook_module_data.gd` et le compositeur `addons/dungeon_draft_arena_studio/vfx/ui/vfx_composer.gd`, en examinant leurs services avant toute modification. Partir d'une composition alpha normale ; aucun shader personnalisé n'est nécessaire pour prouver ce pilote. Toute dissolution ultérieure devra justifier son apport visuel.
5. **Combat réel.** Brancher sur l'impact résolu du sort. Le chemin strike dans `core/vfx_manager.gd` émet actuellement son burst d'impact sur les cibles résolues non vides. Vérifier le profil réellement associé avant intégration. Conserver les règles et le timing des dégâts. Contrôler absence de doublon, orientation vers la cible dans les directions pertinentes, ancrage, fonds clairs/sombres, lisibilité des nombres et des cases, interruption et nettoyage, animations réduites, absence d'impact sur une cible non touchée. Les contrôles d'import et tests ciblés du moteur deviennent nécessaires à cette étape.
6. **Standardisation.** Seulement après un pilote convaincant en combat, transformer ses dimensions, règles de palette, durées et contrôles en recette réutilisable. Chaque nouveau sort garde sa silhouette et son rythme propres.

## Reprise

Travail suivant : revoir ce pic puis fabriquer **uniquement les poses du contact**. Ne pas relancer une génération de planche entière pour corriger une pose. Ne pas annoncer la pipeline complète ou l'effet intégré : les livrables actuels couvrent la direction, la préparation du maître et la revue statique. Aucun code de combat ni profil VFX de production n'a été modifié par ce lot.
