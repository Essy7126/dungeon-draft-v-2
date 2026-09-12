# Veilleur d’airain — marche E, premier essai

**Essai rejeté par l’utilisateur le 12 septembre : jambes différentes du modèle,
disproportion flagrante.** Voir `../veilleur_proportions_v1/README.md` pour la
correction à partir des pixels et dimensions du dessin d’origine.

12 septembre 2026. Suite au « Ok continue » de l’utilisateur : la proposition C
sert de base de travail. Une seule marche, une seule vue trois-quarts E, sans
équipement. **Ébauche à corriger, pas marche approuvée.**

Revue : <http://127.0.0.1:8734/files/veilleur_walk_E_v1/review.html>.
Le dessin nettoyé est affiché par défaut ; le menu Version montre sa construction.

## Ce qui existe

- Douze dessins, deux pas en 1,1 seconde, PNG RGBA, atlas et APNG/WebP animés.
- Les cellules originales font **362 × 362** ; le cadre exporté de 512 × 512
  est un agrandissement uniforme. Pas de remise à l’échelle séparée par pose.
- Calques éditables `painted_frames.kra`, un calque nommé `pose_00` à `pose_11`
  par dessin, disposés sur une planche de 1448 × 1086. Ce n’est pas encore
  une timeline d’animation Krita ni un rig à pièces pour la version redessinée.
- `painted_frames.ora` est l’entrée réelle de `tools/veilleur_walk/export_painted.py`.
  Le script conserve les positions et relit chaque calque. Après une retouche KRA,
  exporter dans **ce fichier ORA**, puis relancer l’export. Ne pas remplacer les
  positions des calques par un recadrage automatique autour de chaque personnage.
- Référence de mouvement à 48 étapes : `source_parts.ora` et `.kra`,
  `parts_layout.json`, `motion.json`, et `tools/veilleur_walk/render_walk.py`.
  Ce montage rough est une aide à la pose, pas un rig universel figé.
- Revue avec ralenti, pause, scrubbing, pas précédent/suivant, vue agrandie,
  référence à 112 pixels debout et photomontage sur trois décors du projet.
  Les deux combats sont des captures du 5 septembre 2026. Le sanctuaire est
  une peinture du projet. Aucune capture nouvelle du personnage dans le jeu.

## Origine et choix

Quatre appels au générateur d’image intégré, sans autre fournisseur :

1. `prompt_walk_12.txt` → `rejected_sheet_01.png` : premier cycle généré,
   alternance insuffisante, écarté.
2. `prompt_guided_12.txt` + `guide_sheet.png` → `rejected_sheet_02.png` :
   les poses abstraites ne suffisent pas ; même jambe dominante répétée, écarté.
3. `prompt_parts.txt` → `parts_raw.png` : pièces 2D et quatre dessins de bottes
   par côté. Détourage logiciel autorisé, montage avec appuis annotés. Le visage
   et le centre du costume du guide proviennent du concept C. Raccords trop visibles.
4. `prompt_cleanup.txt` + `cleanup_guide.png` → `cleanup_sheet_raw.png` :
   nettoyage des douze poses déjà habillées, puis détourage Birefnet local.

Les essais rejetés sont conservés. Le guide de poses habillé transmet mieux
l’alternance dans cet essai que la description ou le squelette abstrait. Ce constat
local ne démontre pas la fiabilité générale de la méthode.

## Limites constatées

- Démarche encore trop fléchie. Il faut relever les poses d’appui et reprendre
  leur déroulement avant de chercher davantage de détails ou de directions.
- Les bottes varient légèrement de volume et le raccord fin/début mérite
  correction. Le nettoyage améliore les raccords ; il ne résout pas la mécanique.
- Les 48 images du guide sont des échantillons de pièces transformées.
  Les 12 dessins nettoyés sont une autre sortie, avec une fidélité imparfaite.
- `geometry_report.json` suit les points de semelle annotés sur le **guide**.
  Il ne mesure pas les appuis du dessin repeint. Ne pas présenter cette mesure
  comme une preuve d’absence de glissement dans la marche nettoyée.
- Pas d’idle, transitions, autres directions, équipement ou intégration campagne.
  Ne pas étendre le lot avant correction et revue de cette direction.

## Contrôles

Rapports dans `artifacts/spine_trial/veilleur_walk_E_v1/` :

- `painted_export_report.json` : douze PNG non vides/non coupés, dimensions,
  séquence APNG/WebP de douze images, durée de 1100 ms et empreinte de la source.
- `native_source_report.json` : vrai aller-retour Krita 5.3.3
  ORA → KRA → ORA ; douze calques, **zéro pixel modifié** par calque,
  en tenant compte des décalages. Fusion KRA également identique.
- `verification.json` : contrôle navigateur de la lecture, des deux versions,
  du déplacement, des décors, des contrôles et des liens. Lire son état courant ;
  ce contrôle ne juge pas la beauté du mouvement.
- Les captures ordinateur/mobile, les douze étapes de la revue et le détourage
  sur fond clair/foncé sont conservés pour inspection.

Aucun code du parcours public n’est modifié. Les tests du moteur commun n’ont
pas été relancés pour ce laboratoire d’images ; aucun nouveau test natif Godot
n’est revendiqué. Les validations antérieures d’autres personnages ne comptent
pas comme preuve pour ce Veilleur.

## Reprise

Ne pas poursuivre ces proportions. Repartir des jambes et bottes du canon dans
`veilleur_proportions_v1`, puis corriger le mouvement sur cette base. Les sources
de cet essai restent conservées pour expliquer et comparer la dérive.
