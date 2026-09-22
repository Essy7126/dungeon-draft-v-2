# VFX Catabase — direction artistique Éthéré

**Historique : remplacé le 22 septembre 2026 par le choix utilisateur
[Animation cel](cards_vfx_cel_2026-09-22.md).** Les prescriptions éthérées
ci-dessous décrivent la décision du 20 septembre et ne sont plus la DA à suivre.

**Suivi de production :** après le pilote Éclat de braise, l’utilisateur a demandé explicitement la reprise de toutes les cartes et des sorts adverses, uniquement en run Cartes. Cette déclinaison est documentée dans la [fiche de reprise éthérée](../../ai/CARDS_ETHEREAL_VFX_2026-09-20.md). Le présent document conserve la recherche et la charte ; son programme initial de trois pilotes décrit l’étape précédente.

Statut : **DIRECTION C CHOISIE PAR L'UTILISATEUR — ÉTHÉRÉ : TRANSPARENCE, LUMIÈRE ET VOLUTES**, le 20 septembre 2026. Le choix porte sur la direction de la planche, pas sur une animation déjà produite. L'utilisateur juge les idées intéressantes mais rejette la réalisation graphique de la première bibliothèque. La couverture technique des 112 cartes reste acquise ; elle ne constitue pas un accord sur leur apparence. Aucun remplacement des effets en jeu dans cette passe.

## Diagnostic

La première passe expose trop directement ses primitives : pointes triangulaires, losanges répétés, rubans réguliers et symétries. Les masses manquent de dessin, de variation d'épaisseur et de hiérarchie lumineuse. Certains effets ont une apparence de découpage posé sur le décor. La déclinaison à tout le catalogue a précédé la validation d'un vrai standard artistique.

La correction doit porter sur les silhouettes, la matière et les poses d'animation. Ajouter du flou, du bloom ou des particules ne corrigerait pas un dessin insuffisant.

## Trois pistes comparables

La [planche](media/vfx_da_comparison_2026-09-20.png) est une image de recherche générée avec l'outil intégré imagegen. Elle compare feu, garde et soin avec un personnage et un contexte similaires. **Ce ne sont ni des captures Godot ni des sprites animés prêts à importer.** Le personnage et le décor ont été réinterprétés pour la comparaison.

| Piste | Intention | Compromis |
| --- | --- | --- |
| A — Animation dessinée | Silhouettes organiques franches, aplats nuancés, pointes effilées, énergie très lisible | Demande des poses réellement dessinées pour éviter le retour au clipart |
| B — Peint mythologique | Matière de pinceau, ombres colorées, accents ivoire et aspect pictural | Le grain et les détails peuvent devenir du bruit à petite taille |
| C — Éthéré | Volutes translucides, lumière diffuse, magie atmosphérique | Risque de perdre les limites et la force des impacts sur le décor |

**C est la référence retenue.** La recommandation initiale A n'est pas la décision : ne pas revenir à des aplats opaques, à des contours dessinés dominants ou à une finition de peinture épaisse. La référence se trouve dans la colonne de droite de la planche.

La planche compare surtout les traitements graphiques. Elle répète trop le croissant entre feu, garde et soin : cette ressemblance ne doit pas devenir la grammaire finale des sorts. La taille montrée est illustrative et doit encore être ajustée en situation de jeu.

## Charte retenue pour la piste C

- Une silhouette dominante portée par le flux : volutes asymétriques, épaisseurs variables, ramifications et déchirures naturelles. Les formes doivent évoluer pendant l'animation.
- Trois couches de lumière : petit cœur clair et précis, corps coloré translucide, enveloppe diffuse. La luminosité maximale reste localisée ; le halo ne doit pas effacer la cible.
- Matière faite de vapeur, d'énergie et de lumière, avec transparences superposées. Quelques détails nets au cœur donnent le point d'attention ; les bords se dissolvent. Éviter les surfaces opaques en aplat, les triangles visibles et les contours épais.
- Palette sémantique : braise vermillon/ocre/ivoire, garde bronze/or pâle, soin jade/céladon, givre bleu pâle, ombre prune/encre. La classe peut ajouter un accent ; elle ne doit pas changer le sens d'un élément.
- Silhouette du personnage, cible et cellules utiles reconnaissables au pic de l'effet. Maintiens de statut beaucoup plus discrets que leur application.
- Particules peu nombreuses, fines et dirigées par le mouvement principal. Le glow est une composante assumée de la DA, mais sa présence doit être locale et mesurée : ni scintillement général ni écran blanc.
- L'accord avec les décors peints vient des couleurs, de la direction de lumière, de la profondeur et de l'ancrage au sol. Il ne faut pas réintroduire un rendu de coup de pinceau opaque pour imiter le décor.

| Pilote | Forme et mouvement propres | À éviter |
| --- | --- | --- |
| Éclat de braise | Noyau incandescent, langues transparentes qui s'enroulent et se séparent, quelques braises entraînées puis une fin de fumée | Cônes, triangles répétés, forme figée qui grossit, fumée opaque |
| Garde brève | Membrane ou voile doré courbe qui enveloppe le buste ; filaments lumineux, traces de laurier suggérées ; maintien discret et onde locale au coup | Cage de losanges, grandes lames solides, croissant d'attaque, bulle de science-fiction |
| Soin du laurier | Courant jade/céladon montant doucement autour du corps, rubans diffus et quelques feuilles translucides ; lumière qui s'éteint progressivement | Entaille verte, cage hélicoïdale régulière, réutilisation du mouvement du feu |

Le rythme fait partie de la DA. La transparence n'impose pas une animation molle : un impact doit avoir une montée courte, un pic clair et une dissipation plus longue ; le soin peut respirer davantage. La garde doit aussi avoir un état calme. Ces rythmes seront évalués sur les animations pilotes, sans ajouter artificiellement de délai aux règles de combat.

## Reprise de production

1. Direction choisie : **C — Éthéré**, sans mélange automatique avec A ou B.
2. Concevoir les poses clés des trois pilotes : naissance, pic et dissipation ; garde avec maintien et rupture supplémentaires.
3. Produire les masques de densité et d'émission, puis leur animation. Blender peut construire volumes, perspectives et trajectoires de volutes ; les textures et matériaux doivent masquer toute impression de primitives. Godot compose transparence, émission et dissipation avec un éclairage local maîtrisé. Une simulation lourde n'est pas un prérequis : juger le résultat, pas l'outil. Les concepts générés ne garantissent pas à eux seuls une animation temporellement cohérente.
4. Montrer les trois effets réellement animés dans Godot, sur le décor du jeu, à taille normale et au ralenti. Vérifier aussi un fond clair, un fond sombre et plusieurs effets simultanés.
5. Décliner le catalogue seulement après accord sur ces trois résultats. Conserver le routeur et les contrôles fonctionnels déjà construits.

Critères d'accord sur les pilotes : correspondance à la colonne C ; effet reconnaissable sans sa légende ; cœur lumineux et cible lisibles au pic ; transparence perceptible ; flux réellement animé ; aucune impression de primitives répétées ; identité distincte entre attaque/protection/soin ; intégration correcte au personnage et au sol. Une belle planche fixe ne remplace pas cette revue en mouvement.

## Références consultées

- [Julien Pingault / Deeamo — FX de Dofus](https://deeamo.fr/dofus-x-deeamo-lanimation-de-fx-dans-le-jeu-dankama/) : exemples de travail FX 2D par classe et importance du métier d'animation. Cette source ne décrit pas toute la pipeline actuelle de Dofus 3.
- [Josh Barnett — Hades 1.0 et travail artistique](https://kirbyufo.com/page/2/) : retour de l'artiste VFX/UI sur la recherche d'un résultat direct, fort et satisfaisant, aidé par des concepts. Référence de démarche, pas une recette technique copiée.
- [Riot — critères VFX 2023](https://www.riotgames.com/en/news/vfx-contest-league-valorant-2023) : teinte, valeur, timing et langage de formes comme critères de cohérence ; articulation lancement, projectile, explosion et sortie. Les contraintes du concours ne sont pas des prescriptions pour Catabase.

Prompt exact de la planche : [vfx_da_comparison_2026-09-20.prompt.txt](media/vfx_da_comparison_2026-09-20.prompt.txt). Génération intégrée, sans appel CLI/API externe. Références locales : `art/source/characters/achilles/passe_rive_v1/reference_choisie.png` (identité du héros) et `artifacts/dev/class_card_vfx/gallery/poster.png` (contexte du jeu et contre-exemple des primitives).
