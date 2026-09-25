# Passe-Rive — gestes, cartes et VFX · S19

Décisions du 24 septembre 2026 : conserver les animations S18 que l’utilisateur trouve « pas trop mal » ; prendre le Sram de Dofus 1.29 comme référence supplémentaire. Aucun dessin, pivot, ordre de pose ou timing corporel S18 n’est remplacé. Les 11 clips d’origine restent accessibles dans `original.html`.

## Direction de cette passe

Un verbe par carte, une forme par effet. La palette du personnage reste pétrole, jade, ivoire et or ; le feu porte son orange propre. Les effets dessinés sont des couches indépendantes, actives seulement au moment utile. Le geste se lit avant le VFX et reste visible pendant l’impact.

Référence de rythme demandée : Sram 1.29. Une [vidéo de gameplay Dofus Rétro aux dagues](https://www.youtube.com/watch?v=qq3Lh67nBg4&t=537s) a été consultée dans le lecteur, avec avancée image par image autour de 8:57–9:00. Elle montre l’emploi des dagues au contact ; le haut des personnages est parfois masqué par l’interface. Cette observation reste partielle : elle ne fournit ni courbes originales ni mesure fiable des durées 1.29. Les durées ci-dessous viennent des dessins S18, pas d’une mesure revendiquée de Dofus.

L’adaptation proposée retient l’armé haut déjà présent, un accent bref de coupe et une fin de geste lisible. Nous ne rajoutons ni squelette Sram, ni invisibilité, ni piège à une carte qui ne possède pas cet effet. Le choix cel du projet, consigné le 22 septembre dans `docs/design/achilles/cards_vfx_cel_2026-09-22.md`, guide les aplats et les silhouettes.

## Contrat commun

- La règle vient de `core/expedition/class_card_catalog.gd` du jeu, lue le 24 septembre. Les identifiants, coûts, portées et effets sont vérifiés automatiquement contre ses lignes.
- La préparation et le mouvement appartiennent au lanceur. Le contact sur une cible attend un fait confirmé.
- Dans le lecteur, le fait est simulé au repère choisi du geste. Dans le jeu, il devra provenir du routeur de combat : ne pas ajouter un délai de vol après des dégâts déjà résolus.
- Une croix touche seulement les cibles confirmées ; la case alliée et la case vide du lecteur restent sans impact.
- Deux coupes dessinées ne signifient pas deux résolutions de dégâts.
- La marque reste liée à l’état. Le bouton de retrait simule sa suppression ; aucune durée artistique en secondes ne consomme une activation.
- Les projections et le talisman déjà peints dans les sprites S18 sont conservés. Cette passe ajoute leurs contacts sur les cibles ; elle ne prétend pas avoir extrait ces éléments du corps.

## Sept fiches
### Lames croisées · `a_sweep`

**Intention : Deux coupes ferment la sortie.**

- Geste conservé : `PR_BLADES`.
- Règle : Frappe physique en croix de rayon 1 ; ennemis seulement.
- Concept : Armé haut conservé, coupe descendante puis contre-coupe. Deux accents visuels forment un X ; un seul événement de résolution.
- VFX : Deux croissants ivoire et jade se croisent, puis se déchirent en éclats.
- Garde-fou de sens : Pas de deuxième application de dégâts, pas de saignement inventé.
- Repère de confirmation : début du dessin 7. La valeur exacte en millisecondes est exportée dans `cards.json`.

### Attaque oblique · `a_ambush`

**Intention : Éviter l’axe, trouver le flanc.**

- Geste conservé : `PR_RIPOSTE`.
- Règle : Frappe physique ; bonus de 40 % de Prouesse après 2 cases déjà parcourues ce tour.
- Concept : Le pas de traverse existant devient une feinte locale suivie d’une estocade de biais. Il ne déplace pas l’unité sur la grille.
- VFX : Un seul croissant décentré accompagne la main avant ; trois éclats marquent le contact.
- Garde-fou de sens : Ni esquive garantie, ni téléportation, ni bonus affiché sans confirmation du jeu.
- Repère de confirmation : début du dessin 7. La valeur exacte en millisecondes est exportée dans `cards.json`.

### Dague lancée · `a_dagger`

**Intention : Un lancer bref, une seule cible.**

- Geste conservé : `PR_DAGGER`.
- Règle : Frappe physique monocible à 2–3 cases.
- Concept : L’armé près de l’épaule et le lâcher existants portent le mouvement. La lame déjà dessinée reste visible.
- VFX : Impact fin dirigé vers la cible, sillage bref ; aucun effet durable.
- Garde-fou de sens : Pas d’explosion, pas de seconde dague superposée, pas de dégâts retardés après confirmation.
- Repère de confirmation : début du dessin 7. La valeur exacte en millisecondes est exportée dans `cards.json`.

### Trait tendu · `r_shot`

**Intention : Concentrer la tension dans un trait.**

- Geste conservé : `PR_SHOT`.
- Règle : Frappe physique monocible à 2–4 cases.
- Concept : Appui arrière et tension conservés. L’accent visuel arrive exactement à la décoche, avec un contact plus étiré que celui de la dague.
- VFX : Pointe ivoire horizontale et éclats étroits sur la cible.
- Garde-fou de sens : Pas de recul forcé de la cible : cette carte ne pousse pas.
- Repère de confirmation : début du dessin 8. La valeur exacte en millisecondes est exportée dans `cards.json`.

### Volée croisée · `r_fan`

**Intention : Couvrir plusieurs adversaires.**

- Geste conservé : `PR_VOLLEY`.
- Règle : Frappe physique en croix de rayon 1 ; ennemis seulement, portée 2–4.
- Concept : La visée haute et les trois flèches existantes donnent l’ampleur. Les contacts sont placés sur les cibles réelles de la croix.
- VFX : Accents de flèches obliques descendants, un par ennemi touché ; dissipation courte.
- Garde-fou de sens : Pas de pluie couvrant une aire arbitraire ; pas de délai balistique ajouté aux règles.
- Repère de confirmation : début du dessin 8. La valeur exacte en millisecondes est exportée dans `cards.json`.

### Éclat de braise · `t_fire`

**Intention : Comprimer, projeter, éclater.**

- Geste conservé : `PR_EMBER`.
- Règle : Dégâts magiques de feu en croix de rayon 1 ; ennemis seulement.
- Concept : La petite flamme tenue puis projetée reste celle du sprite. Son énergie se déploie sur les victimes en trois langues ascendantes.
- VFX : Noyau chaud, gerbe découpée, braises ascendantes et extinction.
- Garde-fou de sens : Ni brûlure périodique ni terrain en feu : ils appartiennent à d’autres cartes.
- Repère de confirmation : début du dessin 8. La valeur exacte en millisecondes est exportée dans `cards.json`.

### Sceau d’ombre · `t_mark`

**Intention : Désigner une faille pour la suite.**

- Geste conservé : `PR_SEAL`.
- Règle : Faibles dégâts magiques et état Marqué pendant 1 activation de la cible.
- Concept : Le geste vertical et le talisman existants désignent l’adversaire. Le sceau se referme au contact puis devient un signe discret.
- VFX : Fragments or et pétrole convergents ; petit marqueur maintenu au-dessus de la cible.
- Garde-fou de sens : Pas de portail, d’invocation ou d’explosion ; maintien lié à l’état, pas à un nombre de secondes.
- Repère de confirmation : début du dessin 8. La valeur exacte en millisecondes est exportée dans `cards.json`.

## Suite de production

Cette livraison couvre les sept gestes de sorts disponibles. La marche et la garde restent disponibles sans association forcée à des cartes. Les autres cartes du catalogue nécessitent leurs propres fiches ; elles ne sont pas déclarées couvertes par ces sept clips.

Avant intégration : relier les repères aux événements de combat, placer les contacts à la position capturée avant déplacement éventuel, brancher la marque sur les applications/retraits réels de statut, vérifier les directions supplémentaires et l’échelle sur l’arène actuelle. Les coefficients de dégâts restent exclusivement dans le jeu.

La référence Sram pourra justifier ensuite un réglage de durée ou de pose proposé en variante. Cette passe préserve volontairement la base S18 demandée et n’annonce pas une nouvelle chorégraphie corporelle.

