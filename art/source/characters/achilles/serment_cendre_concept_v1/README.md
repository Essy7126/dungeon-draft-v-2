# Achille — Veilleur d’airain, concept original V1

12 septembre 2026. Création demandée à partir du dossier de faisabilité Ankama.
Le dossier garde le nom technique de la première exploration ; la proposition
recommandée est **C, Veilleur d’airain**, nom de travail pour une nouvelle
incarnation d’Achille. L’utilisateur n’a pas encore accepté ce design.

## Dessin proposé

Le modèle de référence est `candidate_c.png`, PNG RGBA de 1254 × 1254 pixels.
Son dessin occupe environ 514 × 1168 pixels. L’original généré, sans vraie
transparence, reste dans `candidate_c_raw.png`. A et B sont conservés comme
comparaisons, trop anatomiques et élancées pour la cible choisie.

**Fichier natif : `veilleur_concept.kra`**, exporté par Krita 5.3.3 depuis la
source à deux calques. Son image fusionnée est identique pixel par pixel au
PNG de référence. Ce document reste un concept peint, pas un rig complet.

- Adulte funéraire : visage ivoire anguleux, regard jade étroit, bouche sévère.
- Petit casque de bronze ouvert sur le visage, relief central, sans panache.
- Corps compact stylisé, davantage adapté à la lecture en jeu que les deux
  autres propositions. Le casque augmente la masse de tête ; le ratio apparent
  n’est pas une mesure anatomique précise de 5,5 têtes.
- Tunique pétrole, grand panneau ivoire, ceinture sombre, bord inférieur ivoire.
- Un seul tissu jade court ; broche sur l’épaule **droite anatomique**, proche
  du spectateur dans la vue principale. Le pan reste du même côté.
- Genoux et coudes lisibles, gants sombres, poignets et chevilles ivoire.
- Bottes opaques fermées avec semelles bronze ; les pieds restent physiques.
- La palette du dossier guide les couleurs. Ce n’est pas une quantification
  exacte du dessin généré ; les nuances peintes ne sont pas réduites à quatre codes.

Le caractère grec et spectral repose sur le visage et le bronze. Le volume du
casque et les grandes bottes sont des choix à examiner, pas une perfection acquise.
Les tests emploient les vrais décors du projet ; le modèle précédent n’a servi
ni de base dessinée, ni de squelette, ni de calque de départ.

## Études de construction

`construction_sheet_raw.png` contient trois dessins indépendants : genou levé,
bras levé et torsion. Les fichiers `pose_1.png`, `pose_2.png`, `pose_3.png` sont
des extractions sans changement du dessin. La torsion initiale ouvrait aussi
les deux pieds et n’isolait donc pas bien le haut du corps.

`pose_3_v2_raw.png` / `pose_3_v2.png` reprennent cette seule pose. Les deux bottes
sont orientées dans le même sens et le visage se présente un peu davantage de
face. La rotation obtenue est modeste. La planche révisée applique une seule
échelle uniforme consignée dans le constructeur ; elle ne sert pas de séquence
d’animation. Une main ouverte réclame une substitution de dessin par rapport
au gant de repos. Le dos et les côtés opposés restent à définir.

## Circuit de correction vérifié

Le test isole la broche dans un patch de 82 × 79 pixels, à l’origine (541,363).
Les deux calques sont `body_reference` et `brooch_patch`. Le patch contient un
peu de tissu voisin : **ce n’est pas encore une pièce articulée indépendante**.
Le corps conserve son canevas et ses coordonnées d’origine.

La retouche de la surface de broche a été produite avec ImageGen à partir du
petit extrait. Seule sa face intérieure est reportée sur la copie d’essai ;
le contour original est conservé. `correction_before.ora` reconstruit exactement
le modèle initial. `correction_after.ora` remplace cette surface par du jade.
La broche principale du personnage reste bronze.

Le lecteur relit réellement les images de calques et leurs positions **depuis
le fichier ORA donné en entrée**. Il ne pointe pas vers les PNG d’une ancienne
version. Trois images de contrôle avec décalages connus ont chacune 1795 pixels
modifiés dans le patch et zéro pixel modifié ailleurs. Ces images déplacées
sont des fixtures techniques, pas une marche ni un idle.

Le rapport `artifacts/spine_trial/serment_cendre_concept_v1/correction/report.json`
fait foi pour la preuve et le contrôle de l’aller-retour Krita. Ce premier
circuit porte sur un patch et un montage de concept, pas sur un rig entier.

Aller-retour réel vérifié : ORA → Krita 5.3.3 → KRA → ORA → lecteur local.
Les deux noms de calques et leur rendu sont conservés ; zéro pixel de
différence dans le rendu reconstitué et dans l’export PNG direct de Krita.
Krita recadre le calque du corps avec un décalage enregistré ; le lecteur
réapplique ce décalage et retrouve exactement le canevas initial.

## Comparaison aux décors

La revue propose A/B/C sur trois fonds, à 96, 112 et 128 pixels de hauteur.
Les deux arènes sont des captures de la vraie campagne enregistrées le
5 septembre 2026. Leur liaison aux sources actuelles a été relue ; elles n’ont
pas été recapturées pour ce concept. Le troisième fond est la peinture du
sanctuaire émeraude ; son échelle est indicative.

Ces compositions sont des comparaisons statiques. Le nouveau personnage n’est
pas intégré à la campagne : caméra en mouvement, tri, occultations, collisions
et événements de combat n’ont pas été testés. Le repère elliptique de la revue
est un indicateur de position, pas une ombre définitive ni une validation d’appui.

## Provenance et conservation

Six créations/retouches avec **l’outil ImageGen intégré**, sans API de génération
de secours. Prompts exacts : `prompt_a.txt`, `prompt_b.txt`, `prompt_c.txt`,
`prompt_poses.txt`, `prompt_brooch_trial.txt`, `prompt_twist_correction.txt`.
Toutes les sorties brutes sont conservées dans ce dossier.

Références de style, observées avant génération :

- `assets/catabase/title/underworld_gate_mythology_v3.png` ;
- `asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png`.

Les générations sont RGB avec damier peint. Détourage logiciel explicitement
autorisé dans la conversation : rembg / birefnet-general-lite local, CPU,
décontamination des bords et retrait des fragments de fond détachés. Les
rapports de matte conservent dimensions, cadrages et empreintes des fichiers.

## Prochaine unité de travail

Choisir artistiquement la silhouette, éprouver les appuis et les volumes dans
une ébauche de marche principale. Le découpage définitif découlera de ces poses.
Compléter cette marche dans les trois autres vues avant idle, transitions et
action. Préserver les anciennes versions Passe-rive ; aucun asset public n’a
été remplacé par ce concept.

Outils ciblés : `tools/character_concept/prepare_cutouts.py`,
`build_review_assets.py`, `ora_export.py`, `verify_review.mjs`.
Le lecteur ORA accepte volontairement seulement des calques simples, visibles,
en mode normal à pleine opacité ; les autres constructions sont refusées.
