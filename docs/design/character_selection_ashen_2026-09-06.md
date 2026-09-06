# Sélection : noir et brun cendré

Cette passe remplace les surfaces bleu vert et les tuiles ivoire de la [sélection v2](character_selection_quality_2026-09-06.md) par du charbon chaud, du cuir noirci et du bronze patiné. Elle concerne les fenêtres, cartes, boutons, statistiques, bandeaux et textes de cet écran.

## Fabrication

Une texture originale de grain cendré est générée avec l’outil intégré `image_gen`, puis livrée dans [`asset/ui/character_selection/materials/ash_leather_v1.png`](../../asset/ui/character_selection/materials/ash_leather_v1.png). Le [prompt exact et la provenance](../../art/source/character_selection/ashen_material_v1_prompt.md) sont conservés avec les sources artistiques.

La matière ne contient aucun texte, cadre ou bouton peint. `SelectionAshenSurface` l’échantillonne à une densité constante ; un shader ajoute les arêtes, les ombres des joints, les reflets discrets et les filets de la fenêtre. Le grain est plus calme sur les grands panneaux et bénéficie de mipmaps pour les petites tailles. La forme des cadres reste calculée à la résolution réelle, sans étirement d’une image de bouton.

Les surfaces sont des enfants décoratifs placés derrière leurs contrôles natifs. Elles ignorent souris et clavier. Les textes, les portraits, les icônes, les zones cliquables et le cadre de focus restent indépendants. Le shader respecte la modulation du parent, notamment le fondu d’apparition.

## Finitions

- Fenêtres et bandeaux : noir brun, grain fin, double filet gravé.
- Boutons : surface mate, arête supérieure claire, joint intérieur sombre, reflet renforcé au survol et assombri à la pression.
- Sélection : filet bronze clair persistant, distinct du contour de focus clavier. Le liseré propre à chaque héros conserve sa couleur.
- Action principale : bronze bruni, bordure biseautée, inscription ivoire.
- Statistiques : tuiles sombres, chiffres clairs en Cinzel, libellés gris chaud.
- Typographie : titres Cinzel de graisse 600 avec ombre courte, textes fonctionnels Atkinson Hyperlegible, couleurs ivoire, cendre et bronze clair. Les écritures sont des fontes, jamais des images raster.

Les états repos, survol, pression, sélection avec survol, indisponibilité et focus sont explicitement pris en charge. Désactiver un contrôle pendant sa pression efface l’état enfoncé ; le réactiver ne le restaure pas artificiellement.

## Périmètre et contrôle

La composition, les cinq aventures, les données des personnages et les animations disponibles conservent le parcours existant. La texture ne s’applique pas aux portraits ou aux icônes. Les matériaux du codex lui-même et du combat ne sont pas remplacés par cette passe.

Le nouveau runner `tools/character_selection/selection_ashen_review.gd` produit les vues de sélection en 720p et 1080p, le Mage, l’Épreuve, le codex, le retour du focus et une galerie de boutons. Les gros plans de chaque état sont capturés séparément, au moyen de véritables événements de souris et de focus, sans lancement d’aventure.

Après fermeture du codex ouvert par un clic sur « Explorer les maîtrises », le focus revient au bouton qui l’a ouvert. Une ouverture programmée depuis une technique garde le comportement déjà testé pour cette technique.

La suite ciblée finale passe : **38 tests, 1 854 assertions** sur six fichiers. Elle reprend les 33 tests existants et ajoute cinq contrôles des couches et des événements réels, exécutés dans un SubViewport isolé pour éviter que l’interface du runner GUT ne capte les entrées. Aucun échec de script ou de chargement dans le journal final. Les avertissements connus de ressources/ObjectDB à la fermeture de Godot restent présents ; cette validation est ciblée et ne certifie pas la suite globale.

La revue finale passe : **14 captures, 59 vérifications**, dont les six gros plans des états. Les coordonnées effectives du TextServer confirment l’axe OpenType `wght` à 600 ; la ressource utilise son identifiant numérique pour éviter une variation ignorée. Les vues complètes 720p et les détails de boutons ont été inspectés visuellement.

Résultats et captures : `artifacts/character_selection_ashen/` (`tests.log`, `review.json`, `review.log`, `review.err`).

```powershell
godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tools/character_selection/selection_ashen_review.gd
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://test/unit/test_character_selection_screen.gd,res://test/unit/test_philosopher_selection_layout.gd,res://test/unit/test_selection_quality_v2.gd,res://test/unit/test_character_preview_showcase.gd,res://test/unit/test_achilles_sprite_preview.gd,res://test/unit/test_selection_ashen_skin.gd -gexit
```
