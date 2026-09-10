PASSE-RIVE — SIX GESTES / ESSAI JOUABLE V1

Dans Godot 4.7.1 : importer godot/project.godot puis F6/F5.
Dans le dépôt principal : tools/labs/passe_rive_spells_v1/PasseRiveSpellsLab.tscn, F6.
Toucher 1–6 ou cliquer un bouton ; flèches/ZQSD déplacer, R replacer, V effets, T ralenti, Espace pause.

6 animations de sorts, 4 dessins chacune. PNG RGBA dans frames/, atlas par sort, SpriteFrames Godot et manifest.json contenant durées, pivot et instant de déclenchement. Cellules 768x768 ; pivot (320,662). Les grandes cellules incluent les marges pour la lance, elles ne représentent pas 768 px de hauteur de personnage. Feuilles sources natives 1254x1254, aucun upscale IA.

Les durées SpriteFrames sont exprimées en millisecondes avec speed=1000. Les événements d'impact sont dans le manifeste, pas intégrés au SpriteFrames. Les scripts de laboratoire montrent comment les synchroniser et ne changent aucune règle de campagne.

Quatre familles canoniques : Frappe, Percée, Tir, Garde. Moisson/Heurt sont deux propositions visuelles. Tir teste une projection de lance ; dessin et effets à valider artistiquement. Une seule direction fixe, pas de miroir. L'idle est une pose de récupération ; la marche vient de V3. Graphismes et armes restent à examiner au ralenti.

Génération : outil ImageGen intégré, six appels + correction ciblée de la Garde. Détourage logiciel autorisé. Prompts et coordonnées sources conservés dans le dépôt. Aucune animation 3D ni interpolation artificielle des membres.
