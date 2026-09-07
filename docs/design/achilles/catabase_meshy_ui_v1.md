# Catabase — assets et interface Meshy, passe 1

Cette passe complète l'habillage de la run existante à partir des deux références
Higgsfield approuvées : icônes d'inventaire et bibliothèque engloutie. Les images
sont produites avec **Nano Banana Pro via le plugin Meshy**, puis découpées en PNG
et raccordées aux objets, techniques et contrôles réels de Catabase.

## Production

| Famille | Nouveaux exports |
| --- | ---: |
| Techniques : Braise, Givre, Foudre, deux Serments et Tempête | 6 |
| Équipements : six armes, trois protections, trois accessoires | 12 |
| Statistiques | 9 |
| Emblèmes des cinq doctrines et d'Achille | 6 |
| Ressources et résultats | 6 |
| Marqueurs de route | 12 |
| Navigation | 12 |
| Boutons et onglets | 6 |
| Panneaux et cadres | 8 |
| Fonds : interface, arbre, parchemin | 3 |
| **Total** | **80** |

Les 16 maîtres d'icônes déjà produits avec Higgsfield restent utilisés. Leur fond
navy a été retiré mécaniquement des exports pour éviter les carrés dans l'arbre,
en conservant les sources, les pixels opaques et une recomposition exacte sur le
fond initial. Le reçu `art/source/catabase/painted/icon_matte_cleanup.json`
enregistre les empreintes avant et après cette opération. Les six
nouvelles silhouettes complètent la couverture des **46 identifiants de sorts**,
avec réemploi d'un même maître pour les variantes d'une technique. Les douze
équipements ont chacun leur image propre.

La production comporte 15 requêtes facturées 9 crédits chacune, soit **135 crédits
Meshy**. Solde constaté : **1 396 → 1 261**. Ce montant comprend une reprise de
l'icône de déplacement, dont la première image comportait une dalle indésirable.
Le comparatif antérieur Higgsfield/Meshy a coûté 30 crédits supplémentaires et
constitue une opération distincte.

Les icônes sont livrées en RGBA 256 × 256, les cadres en 128 × 128. Les panneaux
mesurent jusqu'à 448 px et les fonds jusqu'à 1 376 × 768 ou 896 × 1 200. Les
dimensions réelles et empreintes de chaque fichier figurent dans le reçu.

## Intégration

- Carte : marqueurs peints, parchemin, destination courante identifiable et
  traitement explicite des destinations encore inconnues.
- Arbre : emblèmes, glyphes de statistiques, techniques illustrées, cartes plus
  grandes, sélection et disponibilité distinctes, adaptation à la largeur.
- Équipement : visuels des objets dans les choix, les emplacements, l'inventaire
  et les récompenses ; kit de sorts illustré.
- Interface : thème bronze et bleu pétrole, boutons et onglets peints,
  panneaux, cadres, navigation et compteurs cohérents.
- Pause et inventaire : application du thème uniquement pendant Catabase,
  restauration du thème d'origine pour les autres aventures ; actions
  Équiper/Retirer/Utiliser dans un pied fixe, descriptions et statistiques
  défilantes.
- Interactions : retour lumineux au survol, au focus et au clic sans déplacer
  les zones cliquables ; apparition des pages en 160 ms, sans retarder les
  actions. La réduction des animations désactive ces transitions.
- HUD : glyphes de déplacement et navigation, affichage adapté aux kits de
  quatre à six sorts ; conservation des effets et raccourcis existants.
- Fin de run : emblème de victoire ou de défaite, thème et fond Catabase.
- Haltes : habillage des libellés ; peintures Higgsfield, cibles et transactions
  existantes conservées.

Les images ne portent aucun texte fonctionnel : noms, valeurs, états et actions
restent rendus par Godot. Les styles découpés en neuf zones adaptent les bordures
aux contrôles. Les marqueurs `event` et `cache` sont disponibles pour le résolveur,
mais la génération actuelle de la route n'émet pas de destinations de ces types.

## Sources et reproductibilité

- `meshy_output/catabase_ui_production_plan.json` : prompts exacts, modèle,
  références et cibles d'export.
- `meshy_output/catabase_ui_production_receipt.json` : tâches, statuts et crédits
  réels, sans clé API.
- `meshy_output/20260907_*_catabase-ui-*/` : sources immuables et réponses Meshy.
- `art/source/catabase/meshy_ui/exports.json` : 80 fichiers, coordonnées de
  découpe, SHA-256, provenance et état de validation.
- `tools/catabase_art_pipeline/export_meshy_ui.py` : extraction mécanique,
  suppression du fond uni et redimensionnement uniforme. La quatrième rangée
  de boutons fournie en surplus par le modèle est ignorée après inspection.
- `meshy_output/review/` : planches de vérification avec miniatures des icônes
  à 64, 48 et 34 px.

La clé Meshy a été injectée dans le processus de génération uniquement ; la
session authentifiée est fermée. Les données d'origine du comparatif et de la
production Higgsfield sont conservées.

## Validation

Validation exécutée sous Godot **4.7.1 stable**, Windows, rendu OpenGL
Compatibility. L'import final ne signale aucune erreur de script.

| Vérification exécutée | Résultat |
| --- | --- |
| GUT : assets, inventaire et thèmes | 49/49 tests, 7 417 assertions |
| GUT : sélection, Achille, progression et isolation | 118/118 tests, 3 866 assertions |
| GUT : HUD, raccourcis et objets | 32/32 tests, 579 assertions |
| Interface, clics réels et absence de chevauchements | 302 contrôles par résolution, aucun échec |
| Écrans de victoire/défaite | 17 contrôles par résolution, aucun échec |
| Deux haltes peintes et transactions | 320 contrôles par résolution, aucun échec |
| Route | 12 785 contrôles, 3 456 chemins complets |
| Build et sauvegarde de session | 1 000 + 301 contrôles |
| Dix arènes supplémentaires | 4 439 contrôles |
| Combat réel d'ouverture | Victoire, achat de Crochet, remplacement de Garde et retour carte |

Les captures **1280 × 720 et 1920 × 1080** ont été inspectées. Les 21 vues du
probe principal par résolution couvrent le HUD à quatre et six sorts, la pause,
la carte en consultation, les récompenses, l'inventaire, le kit et les cinq
doctrines. Les clics moteur vérifient le réglage d'animations réduites et
l'équipement d'un objet ; les tests comparent aussi les rectangles des sorts,
de Déplacer, de Fin de tour et des boutons de navigation.

Les commandes exactes et les résultats sont conservés dans
`art/source/catabase/meshy_ui/validation.json`. Les tests et probes sont décrits
dans `tests/expedition/README.md` ; les captures réelles et journaux restent dans
`artifacts/meshy_ui/` et `artifacts/catabase_painted_art/`.

Les scénarios contenant du combat signalent encore des objets/ressources retenus
à l'arrêt du moteur : notamment 1 143 objets et 339 ressources pour le probe UI.
Leurs assertions passent, mais leur fermeture n'est pas qualifiée de propre.
Le probe de cartes signale aussi l'annulation d'un rafraîchissement suspendu lors
d'un rechargement de script. La suite globale et son contrôle des échecs
historiques sont exécutés séparément avant la publication finale.

## Limites de cette passe

L'habillage couvre les contrôles et contenus de la run actuelle. Les nouvelles
peintures d'arènes, les quinze autres décors de halte, les animations, VFX et
assets 3D restent pour une passe ultérieure. Les images existantes appréciées par
l'utilisateur restent la référence pour ces décors plus contextuels.

Les probes de présentation utilisent des découvertes, objets et victoires
intermédiaires préparés pour visiter les états de l'interface. Ils ne mesurent ni
la difficulté ni le plaisir de jeu d'une run complète.
