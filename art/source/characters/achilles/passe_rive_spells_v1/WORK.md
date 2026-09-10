# Passe-rive — palette de sorts, livraison V1

10 septembre 2026. Six actions peintes, une direction trois-quarts droite. Quatre sorts canoniques (Frappe, Percée, Tir, Garde), deux propositions visuelles (Moisson des rives, Heurt du passeur). Tir proposé sous forme de projection de lance, variante visuelle à valider.

Sources : canon Passe-rive V1, marche peinte V3. ImageGen intégré, quatre poses fortes par sort ; prompts exacts dans `tools/passe_rive_spells/specs.json`. Détourage logiciel déjà autorisé. Conserver les feuilles RGB originales et les coordonnées de chaque pose. Aucun rig 3D requis pour ces six gestes.

Objectif : PNG RGBA / atlas / chronologie d'événements + laboratoire jouable, temps de préparation distincts, impact unique et récupération. Règles de combat existantes inchangées ; laboratoire de sensation visuelle, pas équilibrage final.

Livré : six actions / 24 poses, atlas RGBA, SpriteFrames, APNG/GIF, laboratoire navigateur ouvert et projet Godot autonome. Détourage final Birefnet : le seuil de blanc a été rejeté après inspection, car il abîmait les zones ivoire. Garde corrigée par ImageGen, raccord pose/impact corrigé dans le lecteur.

Vérifié : atlas exacts, marges, 37 images chargées, six entrées, impacts uniques, coup hors de portée, ruée bloquée devant cible, file d'entrée, réinitialisation, ralenti/fonds/effets, largeur mobile 390, import Godot 4.7.1 et six exécutions natives. Scripts Godot formatés. Rapports et limites dans README.md. La validation technique ne vaut pas approbation artistique ; suite : retour utilisateur sur sensations et raccords.
