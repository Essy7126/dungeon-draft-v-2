PASSE-RIVE — DIX GESTES / ESSAI JOUABLE V1

Dans Godot 4.7.1 : importer godot/project.godot puis F6/F5.
Dans le dépôt principal : tools/labs/passe_rive_spells_v1/PasseRiveSpellsLab.tscn, F6.
Toucher 1–9 et 0 ou cliquer un bouton ; flèches/ZQSD déplacer, R replacer, V effets, T ralenti, Espace pause.

10 animations de sorts : 4 dessins pour chacun des six gestes initiaux, 6 dessins pour chacun des deux tirs à l’arc et Moisson vitale, 8 dessins pour Fauche. PNG RGBA dans frames/, atlas par sort, SpriteFrames Godot et manifest.json contenant durées, pivot et instant de déclenchement. Cellules 768x768 ; pivot (320,662). Fauche utilise 1152x768 et le pivot (576,662) pour préserver le cadrage de la lance. Les grandes cellules incluent les marges pour les armes. Feuilles sources natives 1254x1254 pour les gestes initiaux et 1024x1536 pour le tir à l'arc, aucun upscale IA.

Les durées SpriteFrames sont exprimées en millisecondes avec speed=1000. Les événements d'impact sont dans le manifeste, pas intégrés au SpriteFrames. Les scripts de laboratoire montrent comment les synchroniser et ne changent aucune règle de campagne.

Quatre familles canoniques : Frappe, Percée, Tir, Garde. Moisson/Heurt sont deux propositions visuelles. Tir teste une projection de lance ; Tir céleste ajoute un arc et une flèche en trajectoire courbe. Une seule direction fixe, pas de miroir. L'idle est une pose de récupération ; la marche vient de V3. Les deux tirs conservent leur arc au repos ; changement d'équipement instantané vers les autres gestes dans cet atelier. Graphismes et armes restent à examiner au ralenti.

Trait d’ivoire (8) : décoche à 1620 ms, durée 1925 ms, pleine charge 1000 ms. Arc épaissi et ivoire, jambe arrière fléchie, jambe avant tendue, bras de traction renforcé. Tremblement local calculé par le shader charge_tremor.gdshader et le laboratoire navigateur ; PNG/APNG/GIF exposent les poses peintes sans ce tremblement. Les pieds et la main porteuse ne sont pas déplacés par le tremblement.

Moisson vitale (9) : 6 poses sans arme, émission du torse à 620 ms, durée 1200 ms ; lévitation jusqu’à environ 20 pixels dans le terrain de jeu, paumes vertes, petite explosion et traînée rouge vers la cible. La lévitation et les effets sont pilotés par les scripts du laboratoire et vital_effect_layer.gd ; les dessins seuls exposent les poses et les paumes peintes.

Fauche (0) : 8 poses, impact à 300 ms, durée 800 ms ; main droite près du talon, balancier du bassin, genoux fléchis. Traînée calculée depuis les pointes peintes, deux couches devant/derrière le corps via fauche_effect_layer.gd. Bouclier conservé dans le dos.

Génération : outil ImageGen intégré, six appels + correction ciblée de la Garde, puis une feuille de six poses d'arc et une correction de cadrage, puis six poses de charge ivoire et une correction de l’appui arrière, puis une feuille de six poses sans arme pour Moisson vitale, puis huit poses de Fauche et une correction du balayage. Détourage logiciel autorisé. Prompts et coordonnées sources conservés dans le dépôt. Aucune animation 3D ni interpolation artificielle des membres.
