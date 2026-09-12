# Achille — prompts AutoSprite

Préparé le 12 septembre 2026 pour le personnage déjà utilisé dans AutoSprite. **Prompts proposés, non testés par une génération AutoSprite. Aucun crédit consommé pour cette préparation.** Les animations idle, marche, course et attaque simple à l’arc sont déjà disponibles d’après le joueur.

## Le point de départ

Conserver la référence AutoSprite qui a servi aux animations réussies. La capuche, la peau du revenant, les proportions adultes et le dessin simple sont portés par cette image. Ne pas redemander « style Dofus », « plus mort » ou une nouvelle tenue dans chaque action : cela mélange mouvement et modification du personnage.

**Choix artistique confirmé par le joueur :** une lame courte de rôdeur pour la mêlée, et une garde avec les avant-bras, sans bouclier matériel. Les prompts de tir emploient l’arc déjà validé. Cette proposition ne modifie ni les règles des sorts ni le jeu.

La première pose doit déjà présenter l’arme nécessaire. Pour l’arc, reprendre une pose de l’animation de tir réussie, avec arc, main de corde et flèche lisibles. Pour la mêlée, préparer une pose avec la lame ; éviter de faire apparaître une nouvelle arme au milieu du mouvement. Les gestes à mains libres utilisent leur propre pose de départ.

## Ce que la recherche permet de recommander

- **Décrire une action concrète et sa direction.** AutoSprite conseille de préciser le mouvement des membres plutôt que d’écrire seulement le nom d’une attaque. Son assistant permet aussi de choisir les poses de début et de fin. [Documentation officielle](https://www.autosprite.io/docs/guide-advanced-creation).
- **Laisser l’image porter l’apparence.** Le guide Runway image vers vidéo recommande de concentrer le texte sur le mouvement et son déroulement. C’est un principe général transposé ici, pas une preuve qu’AutoSprite utilise Runway. [Guide officiel Runway](https://help.runwayml.com/hc/en-us/articles/48324313115155-Image-to-Video-Prompting-Guide).
- **Une durée supérieure ne signifie pas une animation plus fluide.** AutoSprite distingue la longueur du mouvement du nombre d’images extraites ; un clip long avec trop peu d’images devient saccadé. Conserver d’abord les réglages qui ont réussi sur ton personnage. [FAQ](https://www.autosprite.io/docs/faq).
- **Conserver PNG et JSON ensemble.** L’atlas fournit les dimensions, positions et informations de lecture. Si tu allonges un clip à 4–6 secondes, la documentation recommande 64 images ou MAX pour l’échantillonner. Cela ne constitue pas une recommandation de rallonger tous les sorts. [Export](https://www.autosprite.io/docs/reference-export-formats).
- **Vérifier dans l’aperçu avant d’exporter.** AutoSprite permet de revoir le mouvement et de rogner sa plage. Une récupération excessive peut parfois être raccourcie sans nouvelle génération. [Workflow officiel](https://www.autosprite.io/blog/autosprite-full-workflow).

Aucune source consultée ne démontre qu’une langue est systématiquement meilleure dans AutoSprite. Les prompts sont donc fournis en français, directement utilisables dans ton interface. Ce sont des propositions adaptées au projet, pas des « meilleurs prompts » validés par un comparatif de générations.

## Réglages et méthode pour tes actions

1. Choisir la même perspective que les animations existantes. Une marche de profil et un tir de trois quarts ne s’assemblent pas proprement par une simple phrase dans le prompt.
2. Dans **Action**, coller un seul bloc ci-dessous. Chaque bloc contient sa consigne de cadrage et fait moins de 330 caractères ; rien à concaténer.
3. **Animation en boucle : désactivée** pour les sorts, impacts et défaite. Un coup unique peut néanmoins finir dans la même garde que le repos. Le réglage de lecture en boucle dans Godot reste indépendant.
4. Les prompts décrivent déjà préparation → action → récupération. Sur ta capture, « Amélioration grâce à l’IA » annonce qu’elle développe cette séquence. Commencer avec le texte fourni ; si tu utilises ce bouton, relire le résultat et retirer les combos, mouvements de caméra ou effets ajoutés qui changent le geste voulu.
5. Si le début ou la fin dérivent, utiliser le contrôle des poses : départ depuis la garde validée, arrivée vers cette même garde après récupération. Pour la défaite, choisir au contraire une pose finale au sol. AutoSprite propose plusieurs modes de poses ; l’image de fin doit être cohérente avec le mouvement demandé, et une pose de « pic d’attaque » ne convient pas à un clip censé inclure le retour au repos. [Guide des animations](https://www.autosprite.io/docs/guide-advanced-creation).
6. Revoir d’abord une seule direction à vitesse normale puis au ralenti. Modifier seulement le défaut observé à la tentative suivante. Ne multiplier les directions qu’une fois le geste convaincant.

Pour les déplacements, le sprite contient l’impulsion et la réception ; le jeu gère le trajet entre les cases. « Sur place » évite de cumuler le déplacement dans l’image avec celui du personnage dans le moteur. Les phases de départ, déplacement et réception doivent rester repérables : une durée précise ou un contact exact ne sont pas garantis par le texte seul.

## Ordre conseillé pour limiter les générations

Pour ta branche d’archer, commencer par **G06 Tir de rupture, G07 Tir de précision, G08 Tir puissant, G09 Percée et G14 Garde**. Ajouter ensuite **G15 Second souffle**.

Pour élargir à toutes les branches : G01 Frappe, G02 Crochet, G03 Balayage, G11 Bond et G13 Heurt. Les variantes G04, G05, G10, G12, G16 et G17 sont des enrichissements possibles : leurs réemplois économiques sont indiqués dans la correspondance des sorts. G18–G20 servent aux réactions de combat.

**Il n’est pas nécessaire de générer les vingt clips maintenant.** Le tir simple peut déjà servir à Tir du Pélion, Tir de guet, Trait de braise et Entrave de givre ; la marche sert aussi à Marche du survivant et Marche purificatrice.

## Prompts du personnage

### G01 — Frappe courte

Mêlée · Socle. Lame courte déjà présente sur la pose de départ.

```text
Le personnage arme sa lame courte près de la hanche, tourne brièvement le buste puis porte une seule taille diagonale devant lui. Il freine le geste et revient à sa garde initiale, pieds ancrés. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Instant où la lame atteint son extension maximale.

### G02 — Crochet et rappel

Briseur · Variante. Main libre visible ; le lien et le crochet spectral seront des effets séparés.

```text
Le personnage abaisse son centre de gravité, projette sa main libre devant lui puis referme les doigts et ramène vivement le coude vers sa hanche, comme pour attirer une prise. Son poids passe sur la jambe arrière, puis il reprend sa garde. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Extension de la main pour le départ ; rappel du coude pour l’attraction.

### G03 — Balayage circulaire

Zone de mêlée · Socle. Lame courte déjà visible ; place autour du corps.

```text
Le personnage fléchit les genoux, arme sa lame courte sur le côté puis exécute un seul large balayage horizontal en tournant le buste. Il freine sa lame, stabilise ses appuis et retrouve sa garde initiale. La cape suit avec un léger retard. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Passage de la lame devant le corps ; effets de zone autour du lanceur traités séparément.

### G04 — Entaille sacrificielle

Sang héroïque · Variante. Lame courte déjà visible ; le sacrifice est montré par un effet discret séparé.

```text
Le personnage pose brièvement sa main libre sur sa poitrine et se contracte, puis porte une seule taille diagonale sèche avec sa lame courte. Il accuse un léger effort, expire et retrouve sa garde. Le visage reste visible. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Extension de la lame ; prix du sacrifice juste avant, sans blessure dessinée.

### G05 — Moisson vitale

Sang héroïque · Variante. Lame courte ; flux de soin séparé.

```text
Le personnage porte une seule taille courte de sa lame, puis ouvre sa main libre vers l'avant et la ramène lentement contre sa poitrine, comme s'il recueillait un souffle. Ses épaules se redressent et il retrouve sa garde. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Contact du coup ; le soin suit seulement un impact réussi.

### G06 — Tir de rupture

Chasseur · Priorité arc. Réutiliser une pose avec exactement l’arc du tir déjà validé.

```text
Le personnage élargit ses appuis, tend fermement son arc et pousse l'épaule d'arc vers l'avant en libérant une seule flèche horizontale. Son buste accuse un bref recul maîtrisé, puis il abaisse légèrement l'arc et retrouve sa garde. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Lâcher unique de la corde.

### G07 — Tir de précision

Chasseur / Givre · Priorité arc. Arc identique ; flèche et main de corde bien séparées.

```text
Le personnage abaisse son centre de gravité, lève son arc, tire la corde jusqu'à sa joue et marque un court arrêt de visée. Il libère une seule flèche droit devant lui, conserve un instant son bras tendu puis reprend sa garde. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Lâcher après l’arrêt de visée.

### G08 — Tir puissant

Chasseur / Foudre · Priorité arc. Arc identique ; ampleur de l’armé compatible avec son dessin.

```text
Le personnage plante solidement ses pieds et arme lentement son arc, coude de corde bien en arrière. Après une courte tension immobile, il décoche une seule flèche avec un lâcher sec. La cape réagit brièvement et il reprend sa garde. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Lâcher unique, plus marqué que le tir normal.

### G09 — Percée sur place

Déplacement · Priorité arc. Le jeu déplacera le personnage entre les cases.

```text
Le personnage se tasse, incline son buste vers l'avant puis exécute deux appuis de course explosifs sur place. Il freine par un appui bas et retrouve sa garde. Son bassin reste horizontalement centré ; la cape suit l'accélération puis retombe. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Repérer départ, phase de déplacement et réception séparément.

### G10 — Feinte d'appui

Danseur · Variante. Direction de déplacement donnée par le jeu ; pas de saut périlleux.

```text
Le personnage fléchit les genoux et décale brièvement son buste pour feinter, puis change vivement d'appui sans avancer dans l'image. Il stabilise ses pieds et retrouve sa garde, regard toujours vers l'avant. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Impulsion du changement d’appui.

### G11 — Bond du sillage

Danseur · Socle. Mains libres ou arme tenue comme sur la pose de référence.

```text
Le personnage se ramasse, prend une impulsion nette et effectue un seul bond bas sur place, genoux légèrement repliés. Il réceptionne sur ses deux jambes fléchies puis reprend sa garde. La cape se soulève et retombe après l'atterrissage. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Décollage et réception ; translation horizontale assurée par le jeu.

### G12 — Contretemps

Danseur · Variante. Lame courte ; la téléportation sera séparée du sprite du corps.

```text
Le personnage esquive légèrement du buste, porte une unique taille courte en revers puis ramène sa lame près de lui. Il termine ramassé sur ses appuis, prêt à repartir, dans la même orientation qu'au début. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Contact du revers ; repositionnement après le coup si la case est libre.

### G13 — Heurt d'airain

Airain · Socle. Garde avec les avant-bras ; pas de bouclier physique ajouté.

```text
L
```

Repère de synchronisation : Extension maximale de l’avant-bras.

### G14 — Garde du revenant

Airain / Serment · Priorité arc. Mains libres ; protection surnaturelle ajoutée séparément.

```text
Le personnage plante ses pieds, fléchit les genoux et croise fermement ses avant-bras devant le torse. Il tient brièvement cette posture protectrice puis desserre sa garde et retrouve son repos de combat. La cape se stabilise derrière lui. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Avant-bras verrouillés ; naissance de la protection à cet instant.

### G15 — Second souffle

Endurance · Socle. Mains et visage dégagés ; effet de soin séparé.

```text
Le personnage porte une main à sa poitrine, baisse légèrement la tête et inspire lentement. Son torse se redresse, ses épaules se relâchent à l'expiration, puis il reprend sa garde initiale. Les pieds restent fixes. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Redressement et expiration ; soin seulement lorsqu’il est effectivement reçu.

### G16 — Tir de zone

Feu · Variante. Arc identique ; une flèche vers la zone, explosion séparée.

```text
Le personnage lève son arc légèrement au-dessus de l'horizontale, arme sa corde puis décoche une seule flèche vers l'avant. Son buste accompagne le lâcher, puis il baisse l'arc et reprend sa garde. La trajectoire reste devant lui. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Lâcher ; éclatement en croix à l’arrivée, jamais trois flèches inventées.

### G17 — Serment du brasier

Serment · Variante. Mains libres ; zone de feu séparée.

```text
Le personnage ramène ses deux mains près du sternum, se contracte brièvement puis ouvre vivement ses avant-bras vers l'extérieur en expirant. Il tient un court instant cette posture, puis revient à sa garde, pieds solidement ancrés. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Ouverture des bras ; impulsion du sort autour du lanceur.

### G18 — Impact reçu

Réaction · Complément. Conserver l’arme présente ; ne pas la faire disparaître.

```text
Le personnage reçoit un seul choc de face : le haut du corps recule brièvement, les genoux absorbent l'impact puis il se rétablit dans sa garde. Les pieds restent près de leurs appuis de départ et la cape réagit avec un léger retard. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Recul maximal du torse.

### G19 — Esquive courte

Réaction · Complément. Conserver les appuis et l’arme de référence.

```text
Le personnage fléchit légèrement les genoux, retire vivement le buste en arrière pour éviter un coup puis revient aussitôt à sa garde. Ses pieds restent au sol et sa tête conserve son orientation. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Point maximal d’évitement ; seulement sur une esquive confirmée.

### G20 — Défaite du revenant

Réaction · Complément. Fin différente du repos ; boucle désactivée.

```text
Le personnage vacille, abaisse les bras puis tombe sur un genou. Il s'affaisse ensuite au sol, la cape retombant autour de lui. Il reste immobile dans sa pose finale, corps entier visible. Caméra fixe, corps entier, même orientation et apparence. Une seule action.
```

Repère de synchronisation : Dernière pose tenue ; ne pas revenir au repos.

## Correspondance avec l’arbre actuellement utilisé

Source directe : [ExpeditionBuildCatalog](../../../core/expedition/expedition_build_catalog.gd), instancié par [ExpeditionBuildState](../../../core/expedition/expedition_build_state.gd) et [ExpeditionSession](../../../core/expedition/expedition_session.gd). Le catalogue comporte **55 nœuds : 41 donnant une racine, un apprentissage ou une forme de sort, et 14 passifs**. Les quatre sorts de départ et Tempête du Péléide complètent la liste à **46 identifiants de sorts**, dont 42 `exp_*`. Tous ne sont pas équipables simultanément ; ce tableau couvre les options du catalogue, pas un build unique.

L’ancien catalogue de 36 maîtrises est une autre version. Il contient notamment Volée du centaure et Rempart des Myrmidons : ils ne sont pas ajoutés à cette liste de production. La suppression du prototype de deck n’a pas supprimé l’arbre `ExpeditionBuildState`, encore présent dans le code actuel.

Les gestes ci-dessous sont des **propositions pour les nouveaux sprites AutoSprite**. Le mapping du renderer existant réutilise parfois davantage d’animations ; ce document ne revendique aucune intégration de ces nouveaux gestes.

| Branche | Sort | Geste à utiliser | Effet et lecture du sort |
|---|---|---|---|
| Départ | Frappe du Péléide | G01 | Contact physique ivoire / bronze, sans feu. |
| Départ | Percée fulgurante | G09 | Traînée de pas légère ; aucun dégât de base. |
| Départ | Tir du Pélion | DÉJÀ : tir à l’arc | Projectile et contact physiques. |
| Départ | Garde d'airain | G14 | Protection personnelle à la pose de garde. |
| Racines | Frappe d'ouverture | G01 | Même coup, marque d’armure réduite sur la cible. |
| Racines | Tir de guet | DÉJÀ : tir à l’arc | Même tir, impact renforcé si sa condition de distance est remplie. |
| Racines | Garde d'Éaque | G14 | Même garde, protection personnelle renforcée. |
| Briseur | Crochet | G02 | Lien / crochet vers la cible ; attraction réelle de 1 case. |
| Briseur | Fauchage | G03 | Impacts sur les ennemis de la croix adjacente. |
| Briseur | Harpon du Péléide | G02 | Lien plus long ; attraction réelle de 2 cases. |
| Briseur | Fracas circulaire | G03 | Croix adjacente ; impacts puis poussées de 1 case. |
| Briseur | Hameçon du destin | G02 | Attraction de 2 cases et signe de perte de PA sur la cible. |
| Sang héroïque | Entaille sacrificielle | G04 (ou G01) | Accent bref sur le lanceur au sacrifice, puis contact physique. |
| Sang héroïque | Moisson vitale | G05 (ou G01) | Flux de soin vers le lanceur après les PV effectivement retirés. |
| Sang héroïque | Veine ouverte | G04 (ou G01) | Même geste ; sacrifice et impact plus marqués. |
| Sang héroïque | Moisson de guerre | G03 | Impacts sur la croix, puis flux de soin confirmés. |
| Sang héroïque | Serment du talon | G04 (ou G01) | Même entaille ; accent de sacrifice. Le nom n’impose pas de frapper le talon. |
| Chasseur | Trait de rupture | G06 | Flèche lourde ; poussée à l’impact, jamais Achille qui recule d’une case. |
| Chasseur | Marque du chasseur | G07 (ou tir existant) | Marque discrète sur la cible après le tir. |
| Chasseur | Tir de traverse | G07 | Projectile linéaire traversant les ennemis ; aucune poussée. |
| Chasseur | Sentence du guetteur | G07 | Même visée ; marque préparant deux prochains impacts, pas deux flèches. |
| Chasseur | Horizon percé | G08 | Une trajectoire physique puissante en ligne ; aucun rayon magique imposé. |
| Danseur | Feinte latérale | G10 (ou G09) | Déplacement réel cardinal ; bref signe d’esquive accrue, pas d’invulnérabilité. |
| Danseur | Contretemps | G12 (ou G01) | Coup, puis repositionnement derrière la cible seulement si libre. |
| Danseur | Pas sans retour | G09 | Déplacement simple ; perd le bonus temporaire d’esquive. |
| Danseur | Revers du Danseur | G12 (ou G01) | Revers, perte de PA puis repositionnement conditionnel. |
| Danseur | Sillage trompeur | G11 | Bond franchissant les obstacles vers une case libre ; traînée séparée. |
| Airain | Heurt d'airain | G13 | Contact bronze et poussée réelle de 1 case ; pas de charge. |
| Airain | Posture d'airain | G14 | Protection personnelle et armure ; aucun déplacement. |
| Airain | Bélier d'airain | G13 | Heurt, poussée de 2 cases ; effet de collision seulement si elle a lieu. |
| Airain | Bastion mobile | G14 | Posture personnelle, bouclier et armure ; pas de malus PM, pas de charge. |
| Airain | Cercle de bronze | G03 | Impulsion bronze sur la croix adjacente, poussées de 2 cases. |
| Endurance | Second souffle | G15 | Souffle de soin sobre après soin confirmé. |
| Endurance | Marche du survivant | DÉJÀ : marche / course | Déplacement puis soin à l’arrivée. |
| Endurance | Souffle retenu | G15 | Même soin, intensité moindre. |
| Endurance | Marche purificatrice | DÉJÀ : marche / course | Déplacement, soin et purification des entraves à l’arrivée. |
| Endurance | Serment de survie | G15 | Même souffle, suivi d’une protection personnelle. |
| Éléments | Trait de braise | DÉJÀ : tir à l’arc | Flèche de feu, impact puis braise persistante sur la cellule. |
| Éléments | Entrave de givre | DÉJÀ : tir à l’arc | Flèche de givre, impact et entrave de PM ; pas de prison complète. |
| Éléments | Ligne fulgurante | G08 | Une ligne électrique vers l’avant, perte de PA aux cibles touchées. |
| Éléments | Brasier cruciforme | G16 | Un tir vers la cible ; explosion et terrain en croix de cinq cellules. |
| Éléments | Verrou de givre | G07 | Même tir ciblé ; entrave renforcée, sans perforation ni gel total inventés. |
| Éléments | Couronne de braise | G16 | Même croix au point ciblé, feu renforcé ; pas un cercle autour d’Achille. |
| Serments | Serment du rempart | G14 | Prix en vitalité puis protection personnelle ; pas de mur de terrain. |
| Serments | Serment du brasier | G17 (ou G03) | Prix en vitalité puis feu sur la croix adjacente au lanceur. |
| Choix de parcours | Tempête du Péléide | G03 | Impacts physiques sur la croix adjacente ; aucun orage élémentaire. |

### Les quatorze passifs

Aucune nouvelle feuille du personnage n’est nécessaire pour ces changements de caractéristiques. Une icône ou un retour d’interface suffit ; un bonus acquis ne signifie pas qu’un effet vient de se déclencher.

| Branche | Passifs |
|---|---|
| Briseur | Levier ; Élan brutal |
| Sang héroïque | Sang dense ; Prix du courage |
| Chasseur | Lecture du terrain ; Œil du Pélion |
| Danseur | Appuis légers ; Angle mort |
| Airain | Bronze épais ; Bronze gravé |
| Endurance | Réserve du héros ; Souffle profond |
| Éléments | Accord des éléments ; Conduction |

### Les confusions à éviter

- **Bastion mobile** actuel améliore une posture personnelle. Le mouvement offensif appelé ainsi dans l’ancien arbre ne décrit pas cette version.
- **Brasier cruciforme** et **Couronne de braise** créent une croix autour du point ciblé. Ils ne demandent pas une pluie de flèches ni un anneau autour du héros.
- **Cercle de bronze** et **Tempête du Péléide** touchent une croix adjacente au lanceur. Une animation ample reste possible, mais l’effet au sol doit respecter les cellules réellement affectées.
- **Sentence du guetteur** prépare les deux prochains impacts physiques. Elle ne lance pas deux flèches lors du cast.
- **Contretemps** frappe avant son repositionnement, et ne passe derrière la cible que si la case est libre.
- **Trait de rupture** pousse ; **Tir de traverse** et **Horizon percé** remplacent cette poussée par une ligne traversante.
- **Verrou de givre** retire des PM. Un personnage entièrement congelé donnerait une lecture plus forte que sa règle réelle.
- **Marche purificatrice** soigne et retire certaines entraves à l’arrivée ; le soin ne doit pas se produire au départ de la marche.

## Effets visuels : même geste, identité différente

Notre direction récente reste celle de grandes formes peintes, peu nombreuses, qui laissent le visage, les mains et les cases lisibles. Pour le physique : ivoire, bronze patiné et revers terre cuite. Pour le revenant et les soins : pétrole, sauge et ivoire. Réserver feu, givre et foudre aux sorts réellement élémentaires.

Je recommande de garder hors de la feuille du personnage les trajectoires longues, les marques sur la cible, les impacts, les boucliers persistants et les zones de terrain. On peut alors réemployer les tirs existants sans repeindre Achille à chaque élément. Une légère réaction du personnage au lâcher est intégrée au mouvement ; la cible reste gérée par le combat.

Pour une création ultérieure d’effets seuls dans le mode approprié d’AutoSprite, ces descriptions de mouvement peuvent servir de points de départ. Elles supposent une référence propre de l’effet : elles ne sont pas à coller sur la fiche d’Achille en espérant qu’il disparaisse.

| Effet | Description de mouvement proposée |
|---|---|
| Contact physique | Une petite empreinte anguleuse ivoire et bronze se comprime, éclate en trois larges fragments puis disparaît rapidement. Point de contact fixe, silhouette simple, aucune flamme. |
| Protection personnelle | Un arc épais de bronze patiné se dessine brièvement du bas vers le haut, se stabilise en rempart courbe puis s’efface. Centre fixe et espace central dégagé. |
| Soin | Deux larges rubans sauge et ivoire se rapprochent doucement d’un centre vide, produisent une impulsion claire puis se dissipent. Mouvement court et calme, sans pluie de particules. |
| Impact feu | Une petite flamme terre cuite s’écrase au point de contact, s’ouvre en trois lobes puis laisse une braise basse. Les contours restent nets, le centre demeure fixe. |
| Impact givre | Trois formes de givre ivoire et bleu froid poussent brièvement depuis un point de contact bas, se cassent en larges morceaux puis s’effacent. Pas de bloc emprisonnant une silhouette entière. |
| Impact foudre | Un trait anguleux ivoire et or pâle se contracte en un éclair sec, bifurque une seule fois puis disparaît. Peu de branches, aucune saturation blanche de tout le cadre. |
| Marque du chasseur | Deux traits de bronze se rejoignent autour d’un centre vide pour former un chevron simple ; il pulse une fois puis reste calme. Pas de silhouette de cible générée. |

Ces descriptions sont aussi non testées. Les motifs persistants doivent être exportés séparément de leur apparition ; la durée de vie et les cellules couvertes viennent du jeu, pas d’un nombre de tours écrit dans le prompt.

## Contrôle avant de conserver une génération

- Reconnaît-on le même personnage, avec les mêmes mains et la même arme ?
- Le mouvement comporte-t-il un seul lâcher, contact ou geste central ?
- Le pic est-il lisible à la taille de jeu, sans effet qui cache le corps ?
- Le début et la récupération se raccordent-ils au repos validé ?
- Le cadrage, l’échelle et l’ancre des pieds restent-ils utilisables ?
- Les déplacements, zones et réactions restent-ils compatibles avec les règles du sort ?

En cas de mouvement correct mais trop lent, essayer d’abord le rognage et le réglage de lecture de l’aperçu. En cas de mauvaise arme ou mauvaise posture, corriger la pose de référence. En cas de combo ajouté, raccourcir la description à une seule action. Aucun prompt ne garantit à lui seul une boucle parfaite ou une identité sans dérive.

## Sources et traçabilité

Recherche consultée le 12 septembre 2026 ; les interfaces évoluent et certaines pages anciennes d’AutoSprite décrivent un assistant antérieur à ta capture. Les réglages visibles sur ta capture sont prioritaires pour nommer les commandes. Le texte « Enhance » de cette capture indique préparation/action/récupération et gratuité ; je n’ai pas utilisé cette fonction.

- [Animations personnalisées : gestes, poses et début/fin](https://www.autosprite.io/docs/guide-advanced-creation)
- [FAQ : durée, détails et échantillonnage](https://www.autosprite.io/docs/faq)
- [Formats d’export : PNG, atlas et nombre d’images](https://www.autosprite.io/docs/reference-export-formats)
- [Workflow AutoSprite : poses, prévisualisation et découpe](https://www.autosprite.io/blog/autosprite-full-workflow)
- [Guide Runway image vers vidéo : mouvement et progression temporelle](https://help.runwayml.com/hc/en-us/articles/48324313115155-Image-to-Video-Prompting-Guide)

Sources projet :

- [Catalogue réel des sorts et nœuds](../../../core/expedition/expedition_build_catalog.gd).
- [Initialisation du kit et progression](../../../core/expedition/expedition_build_state.gd).
- [Session qui emploie cet arbre](../../../core/expedition/expedition_session.gd).
- [Table de présentation des 42 formes](../../../data/visuals/achilles/achilles_expedition_spell_presentation.gd).
- [Direction des effets physiques du Péléide](peleid_fx_production_v1.md).
- [Description structurée des prompts et des 46 correspondances](../../../artifacts/dev/autosprite_prompts_20260912/catalog.json).

Vérification de cette livraison : contrôle statique de couverture des 42 identifiants exp_* de la table de présentation, des 4 sorts de base, de l’unicité des 46 correspondances et de la longueur des 20 prompts. Aucun test moteur ni rendu AutoSprite exécuté ; aucun gameplay modifié.
