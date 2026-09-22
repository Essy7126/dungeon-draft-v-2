# Run Cartes — audit chiffré des sorts, boss et décisions tactiques

Recherche du 22 septembre 2026. Code examiné à partir de `9af4a96a`. Complément technique aux audits précédents, dont les descriptions de principes ne suffisent pas à évaluer l'équilibrage. Périmètre : run Cartes ; aucune modification de gameplay.

## 1. Comment lire les chiffres

- **Code** : valeur et règle retrouvées dans le projet. **Calcul** : résultat analytique de ces règles, sans prétendre avoir exécuté le combat. **Référence** : relevé externe, avec sa variante. **Proposition** : modification à tester, jamais présentée comme existante.
- Dofus : PA, PM, PO en cases ; résistances dans l'ordre **neutre / terre / feu / eau / air**. Un grade de monstre n'est pas un niveau de difficulté universel. Les dommages approximatifs des guides ne sont pas les dommages de base des sorts.
- BG3 : distances en mètres ; une action et une action bonus ne sont pas deux PA interchangeables. Les moyennes des dés précèdent sauvegarde, résistance, réduction et vulnérabilité.
- DOS2 : armure physique, armure magique et vitalité sont distinctes. Comparer seulement les PV masque le coût d'ouverture des contrôles.
- **NR** signifie non renseigné de manière suffisamment fiable. Les pages consultées ne certifient pas toutes le patch live de septembre 2026. Les valeurs contradictoires restent séparées. Aucun chiffre manquant n'a été remplacé par une estimation présentée comme exacte.

## 2. Notre jeu : valeurs finales et conséquences mesurables

### 2.1 Pâris : une rencontre de 860 PV initiaux, avec une transition évitable

La ressource de base ne suffit pas : la fabrique de rencontre remplace ses valeurs. En difficulté normale : **Pâris 560 PV, 4 PA, 3 PM ; deux spectres de 150 PV, 2 PA, 3 PM chacun**, attaque de contact de 70 dégâts physiques. Distance initiale par chemin : 5–8 cases ; trois ennemis vivants maximum. [Fabrique de rencontre](../../core/expedition/catabase_monster_encounter_catalog.gd#L639).

| Sort de Pâris | PA | PO | Dégâts directs normaux | Autre effet / contrainte |
|---|---:|---:|---:|---|
| Flèche des ombres | 2 | 2–7 | 80 ombre | Ligne de vue ; pas de relance ; répétition autorisée |
| Flèche incendiaire | 2 | 2–6 | 65 feu | Relance 2 ; brûlure 12 ; surface feu 20, durée 2 rounds |
| Flèche du Cocyte | 2 | 2–6 | 55 glace | Relance 2 ; −1 PM à la prochaine activation ; surface glace |
| Flèche du vortex | 2 | 2–5 | 45 ombre | Relance 2 ; attire d'une case |
| Pas du vortex | 2 | 2–4 | — | Téléportation sur case libre, sans ligne de vue ; relance 3 ; deux formes |
| Fouet du Tartare | 2 | 1–3 | 100 feu | Une fois par activation |
| Couronne de braises | 2 | 1–3 | 75 feu | Croix de rayon 1 ; relance 2 ; surface feu |
| Étreinte du Tartare | 2 | 2–4 | 60 feu | Relance 2 ; attire d'une case |

Sources : [ressources des sorts](../../data/spells/enemies/paris/), [réglage final des dégâts](../../core/expedition/catabase_monster_encounter_catalog.gd), [forme infernale](../../data/characters/paris/infernal_form.tres). Les dégâts de surface et de brûlure ne s'ajoutent pas automatiquement à chaque impact : leur déclenchement et leur durée doivent être comptés séparément.

**Budget d'action.** Deux flèches spectrales permettent 160 dégâts directs pour 4 PA si portée et ligne de vue conviennent. Téléportation + flèche : 80 dégâts et repositionnement. En forme infernale, fouet + balayage permettent 175 dégâts directs si les deux sorts sont disponibles et atteignent la cible ; deux fouets sont interdits. Ces séquences sont légales sur le papier, pas une garantie de choix de l'IA.

**Transition exacte.** Le test est strictement sous 20 % des PV de référence et exige que Pâris soit encore vivant. À 112 PV, il reste archer ; à 111 PV, il change de forme, récupère ses PV et gagne 30 de bouclier. Une capacité différée en attente est annulée. Les PA/PM restants ne sont pas rechargés par ce changement. [Résolution](../../units/unit.gd#L1806).

**Calcul discriminant, sans mitigation ni soin empêché :** depuis 112 PV, 112 dégâts nets tuent ; 111 dégâts nets laissent 1 PV, puis déclenchent 560 PV + 30 bouclier. Si l'on franchit le seuil à 111 PV, le travail total sur le boss devient `449 + 560 + 30 = 1 039`, contre 560 avec exécution directe. Avec les spectres, cela représente respectivement 1 339 et 860 points à retirer. Ce ne sont pas des durées de combat : défense, surfaces et main disponible changent le nombre de tours.

**Diagnostic.** Il existe déjà une vraie décision de préparation d'exécution. Mais sa sanction est extrêmement discontinue. La barre de vie doit annoncer le seuil, le soin complet et le contournement par coup fatal. Il faut également vérifier en jeu si le deck permet de conserver ou retrouver les dégâts nécessaires au bon moment. Un seuil invisible transforme une décision stratégique en piège de connaissance.

### 2.2 Profondeur 10 : lire les PA avant de compter les attaques

En normal, le catalogue fixe la référence à `[350, 57]`, avec un poids de pack de 6,8. Les deux rôles pèsent chacun 3,4 : `round(57 × 6,8 / 2) = 194 PV` chacun. La puissance d'attaque devient 35 pour le Rabatteur, 42 pour l'Exécuteur. Au grade 2 : 5 PA chacun ; Rabatteur 3 PM, Exécuteur 2 PM ; armure 30 chacun. [Rencontres](../../core/expedition/catabase_monster_encounter_catalog.gd), [évolution](../../core/expedition/catabase_monster_evolution_catalog.gd).

| Porteur / sort | PA | PO | Calcul avant défense | Restrictions importantes |
|---|---:|---:|---:|---|
| Rabatteur — Fracture | 3 | 1 | `round(35 × 0,85) = 30` | −15 armure, 2 activations |
| Rabatteur — Grand Revers | 3 | Soi, croix 1 | `round(35 × 0,9) = 32` | Relance 2 ; une fois par activation |
| Rabatteur — Chaîne | 2 | 2–4 | `35 × 0,2 = 7` | Attraction 2 ; relance 3 ; indisponible initialement 1 activation |
| Exécuteur — Massue | 3 | 1 | 42 | Une fois par activation |
| Exécuteur — Sentence | 3 | 1 | `round(42 × 1,8) = 76` | Résolution différée ; relance 3, initiale 1 ; résolution consomme l'activation |

**Ce qui est effectivement combinable :** Chaîne + Fracture coûte 5 PA ; Fracture + Revers en coûte 6 et n'est donc pas un tour normal légal. Massue + Sentence n'est pas légal non plus. La Sentence suit une cible avec le type de résolution `RANGED_STRIKE`, puis revalide sa position avec `is_valid_target` à la résolution. Quitter la case initiale ne suffit donc pas ; sortir de la portée effective ou rendre la cible invalide bloque la frappe. Les PA/PM de l'Exécuteur sont mis à zéro avant cette validation : même une cible échappée lui fait perdre cette activation. [Résolution différée](../../core/spell_caster.gd#L580). Le déroulement visuel et l'ordre complet des interruptions restent à éprouver en runtime.

**Comparaison utile avec Dofus.** L'équivalent de « ce monstre attire puis frappe » doit être traduit en chaîne de 5 PA et en distance d'arrivée. Le joueur peut alors calculer s'il reste hors de portée de Chaîne, bloque sa ligne de vue, ou accepte 7 dégâts pour éviter l'exposition suivante. Compter chaque sort comme une menace indépendante surestime la pression ennemie.

### 2.3 Profondeur 12, Airain : combien vaut réellement couper le soin ?

Pack : Collecteur + deux Porteurs + Brute. Budget de PV : `68 × 6,6 = 448,8`. Poids respectifs : `1,8 / 1,2 / 1,2 / 3`, total 7,2. Après arrondi : **112 / 75 / 75 / 187 PV**. Le Styx et le Léthé remplacent la Brute par d'autres rôles : il ne faut pas leur recopier ces quatre résultats.

| Élément | Valeur finale / règle |
|---|---|
| Collecteur | 112 PV, 5 PA, 3 PM ; résistance magique 10 ; seuil de soin IA 75 % |
| Obole de vie | 3 PA, PO 0–4, ligne de vue, relance 2, trois utilisations maximum |
| Montant de soin | Base 16 pour 44 PV ; `round(16 × 112 / 44) = 41` |
| Condition d'Obole | Au moins un Porteur allié vivant à distance Manhattan ≤2 du Collecteur |
| Voile des défunts | 3 PA, PO 0–4 ; bouclier `round(0,2 × 112) = 22`, 2 activations ; relance 3 ; trois utilisations |
| Porteur | 75 PV, 4 PA, 3 PM ; puissance 25 |
| Braise | 4 PA, PO 2–5, ligne de vue, 25 dégâts avant défense |
| Tribut | 3 PA, adjacent, allié ; une utilisation ; bouclier `round(0,45 × 75) = 34`, 2 activations |

Sources : [catalogue d'évolution](../../core/expedition/catabase_monster_evolution_catalog.gd), [condition de soutien réellement contrôlée au lancement](../../core/ai/catabase_monster_support_rules.gd), [résolution du scaling](../../core/spell_scaling_resolver.gd). La présence d'un scaling remplace les dégâts historiques ; elle ne s'y additionne pas.

**Décisions calculables :** tuer les deux Porteurs coûte 150 PV bruts à retirer et coupe durablement cette condition de soin. Sortir tous les Porteurs du rayon peut annuler une occasion de soin de 41 pour le coût d'un déplacement forcé. En éloigner un seul ne suffit pas si l'autre reste à deux cases. Le plafond théorique est 123 PV rendus en trois soins, mais les PV manquants, la survie et les relances limitent la valeur réellement obtenue. Le Porteur ne peut pas faire Tribut + Braise avec ses 4 PA.

**Conclusion locale.** Ce pack possède déjà une interaction positionnelle plus intéressante qu'un soigneur générique. Son analyse doit mesurer : soins effectivement empêchés, coût en cartes/PA des déplacements, vitesse à laquelle le Porteur revient, présence de deux liaisons de soutien. Le nom du rôle ne suffit pas à conclure à sa profondeur.

### 2.4 Cartes et personnages : vérifier que préparer rapporte quelque chose

Relevé du [catalogue de cartes](../../core/expedition/card_ecosystem_catalog.gd), puissance illustrative **P = 40**, cartes de rang 0 non améliorées, sans défense, critique, passif ni équipement. Les cartes avancées multiplient leurs coefficients par `1 + 0,1 × rang` ; les cartes d'initiation restent à multiplicateur 1. [Construction des sorts](../../core/expedition/class_card_catalog.gd#L178).

| Carte | PA / PO | Valeur à P=40 |
|---|---|---|
| Frappe / Trait novice | 2 ; 1 ou 1–3 selon classe | 26 dégâts |
| Repérer une faille | 1 ; 1–2 | 4 dégâts + marque |
| Saisir la faille | 2 ; portée novice | 14 dégâts, +8 sur cible marquée |
| Garde fragile | 1 ; soi | 10 bouclier |
| Bousculade | 2 ; 1 | 10 dégâts + poussée 1 |
| Chaînes du Tartare, Gardien | 2 ; 2–4 | 32 dégâts + attraction 3 |
| Prime de la traque, Arpenteur | 3 ; 2–6 | 44 dégâts, +44 sur cible marquée |

**Problème précis d'initiation.** Marque + Saisir donne `4 + 14 + 8 = 26` dégâts pour 3 PA et deux cartes ; Frappe donne 26 pour 2 PA et une carte. Même avec deux Saisir, `4 + 22 + 22 = 48` pour 5 PA et trois cartes, contre deux Frappes à 52 pour 4 PA et deux cartes. Cela ne prouve pas que la marque est globalement inutile : persistance, passifs et autres consommateurs peuvent la rentabiliser. Cela prouve que le petit combo pédagogique n'est pas récompensé dans ce scénario.

À l'inverse, marque + Prime donne `4 + 88 = 92` pour 4 PA. L'augmentation du coefficient conditionnel de 0,2P à 1,1P change réellement l'intérêt de préparer. **Proposition à évaluer :** choisir explicitement si la marque d'initiation doit payer sur un consommateur, deux consommateurs ou plusieurs tours, puis régler autour de cette cible. Ne pas corriger seulement le texte ou ajouter davantage de cartes marquées.

**Les passifs modifient ce résultat.** En règles de classes révision 3, sans spécialisation, le premier déclenchement éligible de l'activation donne : Assassin +20 % des dégâts de base sur une cible isolée au contact ; Arpenteur +20 % à distance ≥3 ; Thaumaturge +20 % sur une attaque magique contre une cible marquée ou portant précisément `class_slow` ; Gardien +20 % du bouclier du sort de garde. À P=40, Frappe à 26 gagne donc 5, Garde fragile à 10 gagne 2. Le bonus conditionnel de Saisir reste calculé à part : le passif ne multiplie pas toute la somme. [Modificateur](../../core/expedition/class_card_modifier.gd). Cela justifie de comparer des séquences de classe complètes après le calcul neutre, pas d'assimiler les quatre classes.

**Contrôle précis.** Sommeil de l'oubli et Sablier brisé coûtent 3 PA et exigent une cible marquée ; ils bloquent normalement une activation, mais n'enlèvent que 1 PA à Pâris. Ils ajoutent une protection contre la stase de durée 3. [Effet](../../core/expedition/card_ecosystem_effects.gd). Passer Pâris de 4 à 3 PA peut néanmoins lui retirer un deuxième sort à 2 PA : l'effet réel dépasse potentiellement le quart de son tour. Il faut vérifier ses choix IA et ses autres modificateurs avant d'affirmer une réduction systématique de moitié.

Pour différencier les personnages, comparer leur séquence complète sur trois problèmes : finir Pâris au seuil, isoler le Collecteur, éviter Chaîne + Fracture. Ce dossier ne remplace pas un audit exhaustif de tous les équipements et passifs.

### 2.5 Élites : distinguer le champion historique du pack de la route actuelle

Le catalogue contient un « Champion de la dernière obole » à 6 PA, avec chaîne, fracture, revers et égide personnelle. Mais la table des rencontres fixes de la route révision 6 ne sélectionne pas ce rôle : son élite de profondeur 15 est **Porte-Égide + Guetteur + Déplaceur + Protecteur**. Il serait incorrect d'utiliser la fiche du champion historique pour décrire cette étape actuelle. [Table des rôles](../../core/expedition/catabase_monster_encounter_catalog.gd), [kit du champion](../../core/expedition/catabase_monster_evolution_catalog.gd).

Calcul normal à profondeur 15 : budget `100 × 8,4 = 840 PV`, poids total `3 + 1,2 + 2,4 + 1,8 = 8,4`.

| Rôle actuel | PV | Puissance | Protection calculée |
|---|---:|---:|---|
| Porte-Égide | 300 | 48 | Égide à 16 % des PV : 48 bouclier par cible couverte |
| Guetteur | 120 | 60 | Dépend des deux soutiens et de leur position |
| Déplaceur | 240 | 60 | Dépend des deux soutiens et de leur position |
| Protecteur | 180 | 36 | Voile à 28 % : 50 ; égide à 14 % : 25 |

Égide coûte **3 PA**, portée 0, croix de rayon 1 autour du lanceur ; Voile coûte **3 PA**, PO 0–4. Les deux durent deux activations, ont une relance de trois et trois utilisations maximum par sort. [Égide](../../data/spells/enemies/catabase_egide.tres), [Voile](../../data/spells/enemies/catabase_protection.tres).

**Décision de cible.** Les 120 PV du Guetteur ne décrivent pas sa durabilité s'il bénéficie de protections. Déplacer un soutien peut retirer plusieurs bénéficiaires d'une prochaine égide, tandis que tuer le Protecteur supprime deux outils de défense. Ne pas additionner les deux égides sans vérifier les règles de cumul et l'ordre des activations. Pour cette élite, la profondeur vient de la formation et du calendrier de protection ; elle ne nécessite pas d'ajouter un boss à phases à chaque salle.

## 3. Dofus : statistiques et règles de lancement

### 3.1 Kabahal : pression de salle, puis arbitrage entre lignes de dégâts

Relevé : niveau 220, **14 000 PV, 20 PA, 6 PM**, initiative 3 200 ; résistances **50/50/50/50/50**. Coûts : Ratafia **4 PA, PO 4–12** ; Offrande **5 PA, PO 1** ; Paume **3 PA, PO 1–6** ; Œil **5 PA, PO 1**. [Doflex](https://doflex.fr/fr/encyclopedia/monsters/4358-kabahal), [Huzounet](https://huzounet.fr/monsters/6654).

| Règle / sort | Effet opérationnel relevé |
|---|---|
| Alternance | Tours impairs : +30 % dégâts à distance ; pairs : +30 % mêlée |
| Paume | Environ 500 feu volés, cercle 3 ; deux lancers/tour ; −25 % critique pendant 1 tour |
| Ratafia | Environ 500 air en poison, 2 tours ; soins reçus −50 %, désenvoûtable |
| Œil | Cône ; −6 PO et −30 esquive PM, 1 tour ; disponible T2, relance 3 |
| Instabilité | Chaque ligne : −5 points de résistance dans l'élément frappé, compensation dans un autre axe |
| Bras | Cinq emplacements ; runes des tours pairs annoncent les apparitions suivantes ; cinq bras provoquent Ch'Tyx |
| Mort près du rituel | Le sacrifice peut donner au boss 10 PM, 500 puissance et 550 bouclier pendant 2 tours |

[Mécaniques et dommages approximatifs : Rituel de Kabahal](https://www.dofuspourlesnoobs.com/rituel-de-kabahal.html).

**Calcul et méthode.** À résistance initiale 50 %, retirer cinq points fait passer une future frappe brute de 100 de 50 à 55 dégâts, soit +10 % relativement au premier résultat. Répéter les lignes d'un même élément prépare les frappes suivantes, mais augmente d'autres défenses ; il faut planifier l'ordre des attaquants. Les joueurs contrôlent aussi les emplacements de bras plutôt que de tuer indistinctement tout ce qui apparaît. Le risque dépend du prochain tour pair et de la case libérée par une mort.

**Chez nous.** Une carte à plusieurs impacts et une carte à impact unique ne peuvent rester de simples variantes de dégâts si l'on introduit ce type de résistance réactive. Il faut définir si l'effet se déclenche par impact, par carte ou par cible, et si un impact à zéro compte. La salle doit exposer ses cases de naissance et son compte à rebours ; notre soin à rayon 2 offre déjà un précédent beaucoup plus simple à enseigner.

### 3.2 Koutoulou : la cible attaquée détermine aussi le déplacement

Relevé : niveau 220, **18 000 PV, 20 PA, 6 PM**, résistances **16/22/17/17/28** ; esquives PA/PM 100/100. Les 26 000 PV d'autres relevés ne doivent pas être fusionnés avec ce bloc. [Huzounet](https://huzounet.fr/monsters/4453).

Permutation coûte **2 PA, PO 1–6** ; Frappe koutonienne **4 PA, contact**. Le boss n'attaque pas au premier tour. À partir du suivant, la permutation fonctionne sans ligne de vue, au maximum deux fois/tour et une fois/cible. Les dégâts directs déclenchent un échange avec l'entité la plus proche ; répéter l'interaction entre monstres peut les rendre invulnérables. La Folie ajoute des contraintes : palier 2, propagation en rayon 2 ; palier 4, soins réduits ; palier 10, mort. Le Klutiste donne en rayon 3 **2 PM, 200 puissance et 25 % vitalité**, pendant un tour, désenvoûtable. [Temple de Koutoulou](https://www.dofuspourlesnoobs.com/temple-de-koutoulou.html).

**Méthode.** Avant une attaque, déterminer l'entité la plus proche, le point d'arrivée du déplacement et la proximité des autres personnages après échange. Un poison ou un déplacement préparatoire peut être préférable à un impact direct. La carte « frapper » devient simultanément une commande de placement : l'interface doit prévisualiser les deux.

**Chez nous.** Une adaptation solo demande des ancres de salle ou des invocations manipulables ; supprimer les partenaires sans remplacer leurs positions détruirait la mécanique. Une limite de Folie n'est intéressante que si une action accessible permet de la gérer. Ne pas importer une exigence de composition multijoueur dans un deck aléatoire de dix cartes.

### 3.3 Les quatre Cavaliers : budgets et transitions différents

| Boss / variante relevée | PV | PA / PM | Résistances N/T/F/E/A | Source |
|---|---:|---:|---|---|
| Guerre, grade 1, niveau 220 | 22 000 | 12 / 6 | 30/35/35/25/25 | [Fashionista](https://dofusfashionista.gg/encyclopedia/monster/6014-guerre/) |
| Servitude, fiche Dofuthèque | 26 000 | 11 / 7 | 20/15/30/25/25 | [Fers de la tyrannie](https://www.dofutheque.com/fers-de-la-tyrannie) |
| Misère, grade 2 | 20 000 | 20 / 6 | 9/32/19/12/28 | [Doflex](https://www.doflex.fr/fr/encyclopedia/monsters/3783-misere?grade=2&spell=11860) |
| Corruption, niveau 220 | 21 000 | 20 / 4 | 22/16/5/11/25 | [Huzounet](https://huzounet.fr/monsters/6026) |

Ce tableau décrit quatre fiches identifiées, pas un unique mode de butin harmonisé. Par exemple, Servitude grade 4 est affichée à 29 000 PV ailleurs ; une Corruption à 110 000 PV correspond à une autre variante, exclue ici.

**Guerre.** Bravoure : 3 PA, PO 1–3 ; Impact : 5 PA, PO 1–3, base feu 71–85, érosion 20 % ; Lynchage : 3 PA, contact, base feu 71–85 ; Magmaléfice : 5 PA, PO 1–6, base feu 61–70. [Données des sorts](https://dofusfashionista.gg/encyclopedia/monster/6014-guerre/). Bravoure dure deux tours, relance trois, ignore la ligne de vue et désigne un combattant avec contraintes spécifiques. Aux seuils **80/60/40/20 %**, les dégâts sont arrêtés et une arme apparaît ; dans le relevé à 22 000 PV, l'arme possède 5 500 PV. La tuer avant que le boss en tire profit évite la conséquence associée. [Trône de sang](https://www.dofuspourlesnoobs.com/trone-de-sang.html).

**Calcul.** Avec 18 000 PV restants, un impact de 1 000 atteint le premier seuil à 17 600 : seulement 400 servent immédiatement au boss. La question devient « ai-je encore les actions permettant de gérer l'arme ? ». Cela s'oppose au cas de Pâris, où le coup fatal permet justement de sauter la transition. Ces deux règles doivent être distinguées dans nos données et dans les prévisions de dégâts.

**Servitude.** Asservissement : **2 PA, PO 2–10**, attraction de 9 cases en ligne ; Joug : **3 PA, PO 1–5**, environ 700 eau, donne au proche allié 1 000 bouclier et 1 PM ; Tyrannie : **5 PA, cercle 2**, environ 900 eau et −1 PA. Le passage sous 50 % ramène les positions au début du combat et soigne 25 % des PV : 6 500 sur la fiche à 26 000. Insoignable répond à ce soin. Traître renvoie 200 % des dégâts directs ; les poisons évitent cette interaction. [Sorts : Doflex](https://doflex.fr/fr/encyclopedia/monsters/3748-servitude?grade=4&spell=11653), [règles et approximations : guide](https://www.dofuspourlesnoobs.com/fers-de-la-tyrannie.html).

**Méthode.** Conserver une réponse au soin et anticiper la position de retour avant de franchir le seuil ; ne pas déclencher un renvoi avec une grosse attaque directe simplement parce que sa valeur affichée est supérieure. Pour notre run, une carte de saignement peut acquérir une vraie niche contre le renvoi, à condition que le moteur distingue explicitement dégâts directs et périodiques.

**Misère.** Urubu : **4 PA, PO 1–2**, environ 500 neutre, poussée 6, −150 résistance poussée pendant 2 tours, relance 2. Barchan : **3 PA, PO 1–6**, environ 600 eau, −100 soins et −50 % soins reçus pour 1 tour. Dakhma : **4 PA, PO 1–2**, environ 600 feu, immobilisation et invulnérabilité temporaires ; un allié peut libérer la cible en la frappant. L'attraction liée aux lignes de dégâts augmente avec les tranches de PV : 1, 2, 3 puis 4 cases. Sous 50 %, transition avec invulnérabilité temporaire et +4 PM. La relance de Funérailles diverge entre texte et mise à jour du guide : **NR** ici. [Coûts](https://www.doflex.fr/fr/encyclopedia/monsters/3783-misere?grade=2&spell=11860), [mécaniques](https://www.dofuspourlesnoobs.com/sentence-de-la-balance.html).

**Méthode.** Un enchaînement de petites frappes peut rapprocher de plusieurs cases, puis exposer à la poussée. Dans notre jeu solo, une prison libérable seulement par un allié serait sans solution générique : il faudrait une interaction de salle, un objet ou une règle de durée adaptée.

**Corruption.** Bêche : **4 PA, PO 1–2 en ligne**, base 34–46 feu, retrait PA ; Incubation : **6 PA, PO 2–14**, base 48–56 eau ; Convalescence : **2 PA, PO 1–10**, base 28–35 air, pousse 2 ; Liquéfaction : **1 PA, PO 2–14**, base 17–24 eau et échange de position. [Données](https://www.dofutheque.com/arbre-de-mort). Bombe donne 660 bouclier puis explose en fin de tour de la cible, environ 550 terre en rayon 3, avec maladie. Sa portée dépend de la forme : 6–20 montée, jusqu'à 6 démontée. Kissiphrot punit chaque ligne avec un poison ; soigner au contact d'un ennemi permet de le retirer. Peau pourrissante coûte 10 % des PV actuels en fin de tour et trois soins la retirent. [Guide](https://www.dofuspourlesnoobs.com/arbre-de-mort.html).

**Méthode.** Compter les événements de soin et les lignes d'attaque, pas seulement leurs montants. Une petite source de soin répétable peut valoir davantage qu'un gros soin unique. Chez nous, cela ouvrirait une différence intéressante entre relique, consommable et carte de soin ; elle doit rester visible dans les descriptions d'états.

### 3.4 Otomaï : cinq façons différentes de fabriquer une fenêtre d'attaque

| Boss / relevé | PV | PA / PM | Résistances N/T/F/E/A |
|---|---:|---:|---|
| Corailleur magistral, grade 1, niveau 50 | 2 000 | 8 / 3 | 23/−6/13/18/−7 |
| Gourlo, grade 1, niveau 70 | 1 900 | 10 / 5 | 200/200/200/200/200 |
| Silf, grade 2, niveau 110 | 7 800 | 8 / 5 | 200/200/200/200/200 |
| Tynril perfide, grade 1, niveau 140 | 3 800 | 10 / 2 | 200/200/0/200/200 |
| Kimbo, fiche niveau 160 | 6 900 | 10 / 7 | 400/400/400/400/400 |

Sources des blocs : [Corailleur](https://doflex.fr/fr/encyclopedia/monsters/582-corailleur-magistral?grade=1&spell=827), [Gourlo](https://doflex.fr/fr/encyclopedia/monsters/595-gourlo-le-terrible?grade=1&spell=743), [Silf](https://www.doflex.fr/fr/encyclopedia/monsters/615-silf-le-rasboul-majeur?grade=2&spell=853), [Tynril](https://www.doflex.fr/fr/encyclopedia/monsters/627-tynril-perfide?grade=1&spell=858), [Kimbo](https://www.dofutheque.com/canopee-du-kimbo). Les 100 % de certains anciens guides Gourlo ne remplacent pas silencieusement les 200 % de cette fiche.

**Corailleur : changer le budget d'actions.** Coraillement coûte **2 PA**, donne **12 PA et 400 puissance pendant 4 tours**, retire **3 PM en fin de tour**, relance 5. Lancer de corail coûte **6 PA, PO 1–5** ; Frappe de corail coûte **16 PA au contact** et constitue une attaque mortelle. [Grotte Hesque](https://www.dofuspourlesnoobs.com/grotte-hesque.html). Calcul : `8 − 2 + 12 = 18 PA`, donc Frappe devient payable immédiatement. La perte de PM en fin de tour ne garantit pas la sécurité pendant l'activation où le buff est lancé. Contre-jeu : contrôler la distance avant cette activation, puis exploiter l'immobilité. Chez nous, annoncer uniquement « gagne de la puissance » manquerait l'essentiel : l'accès à un nouveau sort.

**Gourlo : utiliser une invocation comme outil élémentaire.** Invocation de tonneau : **1 PA, PO 6–12**, case libre, une fois/tour ; Bombarde : **3 PA au contact** ; Gros Boulet : **3 PA, PO 4–8**. [Fiche des sorts](https://doflex.fr/fr/encyclopedia/monsters/595-gourlo-le-terrible?grade=1&spell=743). La stratégie consiste à charger un tonneau dans l'élément voulu, le placer au contact du boss et exploiter sa réduction de résistance. [Arche d'Otomaï](https://www.dofuspourlesnoobs.com/arche-dotomaiuml.html). Dans notre hybride, un objet neutre de salle peut fournir cette réponse sans exiger que le joueur ait drafté une carte précise ; une carte d'attraction accélère alors la résolution au lieu de la rendre possible à elle seule.

**Silf : donner la ressource qui ouvre la faiblesse.** Hololole coûte **14 PA**, au-dessus des 8 PA naturels ; Rasage coûte 1, Modération 4 à PO 1–6 avec vol de vie et échange, Recrutement 1 à exactement 8 PO. [Sorts](https://www.doflex.fr/fr/encyclopedia/monsters/615-silf-le-rasboul-majeur?grade=2&spell=853). Les tentatives de retrait PA lui font au contraire gagner des PA ; sous Hololole, frapper un élément diminue sa résistance de 50 points et augmente les autres. [Guide Rasboul](https://www.millenium.org/guide/420377.html). Depuis 200 %, trois déclenchements conduisent à 50 %, quatre à 0 %. Ce calcul décrit les résistances après déclenchement, sans supposer que l'impact déclencheur bénéficie déjà de la baisse. Chez nous, transformer un contrôle en outil d'ouverture exige une exception affichée ; sinon le joueur croit son sort défectueux.

**Tynrils : limiter le choix de cible par élément et position.** Sur le Perfide : Hiffe **1 PA, PO 1–63**, jusqu'à deux lancers/tour, −2 000 % résistance feu pour 1 tour ; Helse **5 PA au contact** ; Forque **2 PA, PO 1–63**, échange ; Bisouille **5 PA au contact**, soin massif. [Fiche](https://www.doflex.fr/fr/encyclopedia/monsters/627-tynril-perfide?grade=1&spell=858). La stratégie sépare les monstres pour empêcher leurs soins mutuels et évite le contact du personnage fragilisé. Transposer leurs immunités élémentaires intégrales à un deck solo peut rendre une run insoluble. Une vulnérabilité déplaçable par la salle serait plus compatible avec notre draft.

**Kimbo : l'élément choisit une géométrie.** Air/feu déclenchent une parité, eau/terre l'autre ; les glyphes du Disciple rendent le début de tour sur la mauvaise case mortel. Le joueur prépare le damier et le déplacement du boss avant de déclencher. [Canopée](https://www.dofuspourlesnoobs.com/canopeacutee-du-kimbo.html). Le Disciple possède sur sa fiche **190 PV, 8 PA, 0 PM et 800 % de résistances**, glyphes à 3 PA. [Dafous](https://dafous.app/bestiaire/1088/disciple-du-kimbo). Chez nous, l'aperçu d'une carte élémentaire devrait montrer le futur damier avant paiement ; il faut distinguer « entrer sur une case » et « commencer son activation dessus ».

**Les monstres de salle modifient le puzzle du Kimbo.** Le Bitouf aérien échange les positions à **PO 2–10 sans ligne de vue** et pousse de **3 cases au contact**. Le Kaskargo pose deux glyphes par tour, tue au début du tour sur le glyphe, et échange jusqu'à **8 PO sans ligne de vue**, relance **3** ; la note de correction du guide interdit cet échange au premier tour. [Bestiaire de la Canopée](https://www.dofuspourlesnoobs.com/canopeacutee-du-kimbo.html). La paire crée une menace que les deux fiches prises séparément ne montrent pas : un déplacement forcé devient létal s'il précède immédiatement l'activation de la victime. Chez nous, donner au héros une seule activation entre déplacement et exécution est une règle d'équité à fixer explicitement.

### 3.5 Moon, Meulou, Kralamoure, Protozorreur et Songes

**Moon.** Fiche niveau 100 : **3 700 PV, 12 PA, 5 PM, 200 % dans les cinq résistances**. Marteau : **3 PA, portée maximale 8**, base neutre 31–35, retrait 3 PA/3 PM/1 PO ; Choc : **3 PA au contact**, base neutre 26–30 et téléportation symétrique ; Face cachée : **1 PA, portée maximale 3**, Darkli Moon. [Dofuthèque](https://www.dofutheque.com/arbre-de-moon). Les fiches d'expédition à 20 000 PV ne décrivent pas cette variante. La présence d'une invocation servant à la résolution doit être analysée avec ses cases accessibles, pas seulement comme « un add à tuer » ; la vérification actuelle complète de son rituel reste à faire avant toute reproduction exacte.

**Meulou.** Relevé grade 1 historique : **5 500 PV, 10 PA, 7 PM**, résistances 20/30/−5/40/40 ; Étripage **3 PA au contact**, base neutre 51–60 volée ; Invocation de Milimeulou **4 PA, PO 1** ; Rage reconstituante **5 PA sur soi**. [Fiche](https://dofusfashionista.gg/encyclopedia/monster/232-meulou/). La mise à jour 3.6 réduit ses PV et remplace l'invulnérabilité initiale de Fureur par une réduction de 50 %, avec durée ramenée de quatre à trois tours. Le nombre 5 500 ne doit donc pas être présenté comme PV live certifié. [Changements 3.6](https://www.dofuspourlesnoobs.com/mise-a-jour-306.html). Pour notre audit, cela illustre une différence mesurable : une réduction à 50 % laisse convertir deux fois plus de dégâts bruts en progression, alors qu'une invulnérabilité refuse entièrement cet axe de jeu.

**Kralamoure.** Grade 1, niveau 640 : **3 700 PV, 18 PA, PM −1** dans la donnée. Kracheau : **3 PA, PO 2–22** ; invocations de tentacules **1 PA, PO 4–12**. [Doflex](https://doflex.fr/fr/encyclopedia/monsters/242-kralamoure-geant?grade=1&spell=981). Les tentacules sont déclenchés par les éléments : air, terre, feu, eau pour les quatre types ; leur séquence ouvre une fenêtre de vulnérabilité d'un tour. [Guide](https://www.dofuspourlesnoobs.com/antre-du-kralamoure-geacuteant.html). La faible vitalité seule ne signifie donc pas faible difficulté. Chez nous, l'indicateur pertinent serait le nombre d'actions de préparation avant la fenêtre et les dégâts conservables en main pour cette fenêtre. La chorégraphie complète n'est pas certifiée ici à la version actuelle.

**Protozorreur.** Fiche niveau 220 : **1 000 PV, 20 PA, 5 PM, résistances nulles**. Jet : **4 PA, PO 1–10**, base air 41–50 et attraction 10 ; Électrocution : **4 PA, portée maximale 2**, base feu 81–100 ; Infection : **4 PA sur soi**, avec effets dépendant de l'état infecté. [Dofuthèque](https://www.dofutheque.com/ventre-de-la-baleine). La rencontre se gagne par résolution des Krobes et de leurs états, pas par ces 1 000 PV : la Malamibe impose une échéance de deux tours et le processus comporte plusieurs étapes. [Analyse JOL](https://dofus.jeuxonline.info/article/14644/ventre-baleine). Pour notre jeu, dissocier une attaque normale d'une version conditionnée par infection évite d'additionner tous les effets comme s'ils étaient permanents. Une adaptation exacte demanderait encore une table exhaustive des cinq Krobes et de leurs transitions.

**Songes.** Les valeurs doivent appartenir à une version de système. La refonte 3.5 distingue les longueurs de Rêve, Paradoxe et Cauchemar et modifie le combat final ; le dossier précédent documente cette rupture. [Historique documenté](run_cartes_boss_profondeur_2026-09-22.md). Pour la run Cartes, l'analyse pertinente est une matrice `boss × modificateur × géométrie × deck`, avec tests de compatibilité. Ajouter 30 % de PV à un boss et lui ajouter une contrainte qui condamne sa seule case sûre ne sont pas deux augmentations de difficulté équivalentes. Les valeurs live complètes des Songes ne sont pas certifiées dans ce complément.

## 4. Baldur's Gate 3 : action, réaction et décor

### 4.1 Statistiques à difficulté identifiée

| Boss | PV Équilibré / Tacticien | CA Équilibré / Tacticien | Mobilité | Particularité utile |
|---|---:|---:|---:|---|
| Grym | 300 / 450 | 18 / 18 | 11 m | Vulnérabilité conditionnée par Surchauffe |
| Ansur | 400 / 600 | 19 / 19 | 12 m | Immunité foudre et poison |
| Raphaël | 666 / 666 | 21 de base | 12 m | Les piliers peuvent porter la CA à 27 |
| Avatar de Myrkul | 245 / 390 | 19 / 20 | 0 m | Résistances froid/nécrotique, immunité poison |
| Matriarche araignée | 125 / 162 | 16 / 17 | 9 m | Immunité poison |
| Netherbrain | 300 / 450 | 15 / 15 | 0 m | Destruction de plateformes |
| Dragon rouge dominé | 400 / 520 | 19 / 19 | Vol disponible | Immunité feu ; réduction fixe 2 / 4 |

Sources : [Grym](https://bg3.wiki/wiki/Grym), [Ansur](https://bg3.wiki/wiki/Ansur/Combat), [Raphaël](https://bg3.wiki/wiki/Raphael/Combat), [Myrkul](https://bg3.wiki/wiki/Apostle_of_Myrkul), [Matriarche](https://bg3.wiki/wiki/Phase_Spider_Matriarch), [Netherbrain](https://bg3.wiki/wiki/The_Netherbrain/Combat), [Dragon](https://bg3.wiki/wiki/Dominated_Red_Dragon). Les règles Honneur ci-dessous ne sont pas intégrées subrepticement à la colonne Équilibré.

### 4.2 Fiches d'actions et solutions

**Grym.** La lave applique Surchauffe, qui permet de l'endommager et expose notamment au contondant. Le marteau de forge inflige **12d8 contondants** ; il faut gérer la position, la lave et la désignation de sa cible. [Grym](https://bg3.wiki/wiki/Grym). Calcul : moyenne 54, soit 108 sous vulnérabilité ; trois coups font en moyenne 324, cinq 540. Ce sont des moyennes, pas des garanties de tuer 300/450 PV. La stratégie au marteau exige de recréer les conditions entre frappes ; une équipe à armes contondantes peut exploiter la même faiblesse autrement. **Chez nous :** un mécanisme de salle doit avoir ses propres conditions et dégâts affichés, mais les cartes doivent pouvoir profiter de l'ouverture sans être réduites à actionner le mécanisme.

**Ansur.** Souffle de foudre : **action, 12d6, portée 60 m**, sauvegarde de Dextérité ; Nova : **18d10 foudre**, précédée d'une charge ; Claquement : **6d8+7**, portée 4 m ; vol : **action bonus, 30 m**. En Honneur, une survie à 1 PV avec 100 PV temporaires accompagne une dernière séquence de Nova. [Combat d'Ansur](https://bg3.wiki/wiki/Ansur/Combat). Moyennes respectives : 42, 99 et 34. **Méthode :** garder mouvement et protection pour la charge, puis revenir attaquer ; ne pas engager toutes ses ressources offensives juste avant la zone dangereuse. Chez nous, la carte de mobilité a ici une valeur mesurable en dégâts évités, même sans bonus offensif.

**Raphaël.** Consume Souls : **action bonus**, une âme par pilier à portée 30 m ; Incinerate : **action, deux âmes, 8d8 feu**, sauvegarde Dextérité ; Infernal Salve : **action bonus, une âme, soin 3d6 à 18 m** ; Eternal Debt : **action bonus, une âme**, invocation. En ascension, Ravaging Inferno atteint **20d6 feu** pour deux âmes. [Kit](https://bg3.wiki/wiki/Raphael/Combat). Les piliers alimentent le boss ; leur destruction déclenche aussi une réaction de son système d'âmes. [Piliers](https://bg3.wiki/wiki/Pillar_of_Souls).

**Calcul.** Avec bonus d'attaque +8, toucher CA 27 exige 19–20 : 10 % ; CA 21 exige 13–20 : 40 %, sans avantage. Pour une frappe de valeur nominale 20, l'espérance simple hors supplément critique passe de 2 à 8. Détruire l'infrastructure vaut donc davantage que retirer ses seuls PV. **Chez nous :** le Porteur qui autorise 41 de soin est déjà une infrastructure ; évaluer sa destruction uniquement par ses 75 PV ignore son effet sur tout le combat.

**Myrkul.** Reaper's Scythe : **action, 2d12+7 tranchants +3d6 nécrotiques**, pousse 4 m ; Cold Embrace : **action, 2d8+7 tranchants +4d6 froid**, portée 4 m ; Gaze of the Dead : **4d8 + modificateur**, nécrotique, peur, portée 30 m. Consommer un nécromite donne accès à Finger of Death et, en Tacticien, soigne **8d8**. [Myrkul](https://bg3.wiki/wiki/Apostle_of_Myrkul). Moyennes : 30,5 ; 30 ; soin 36. **Méthode :** couper les arrivées de nécromites, distribuer les positions autour de la plateforme, tenir compte des réactions du mode choisi. Chez nous, le coût de tuer un soutien doit être comparé au soin et à l'attaque spéciale qu'il autorise, pas seulement à son attaque propre.

**Matriarche.** Ethereal Jaunt : **action bonus, 22 m** ; Matriarch's Call : **action**, fait éclore les œufs proches ; Poisonous Discharge : **action, 4d6+5 poison dans le relevé du kit**, portée 20 m, sauvegarde Constitution. Détruire les toiles quand elle s'y trouve provoque une chute ; éliminer les œufs avant leur activation réduit les renforts. [Matriarche](https://bg3.wiki/wiki/Phase_Spider_Matriarch). Moyenne du jet indiqué : 19, avant sauvegarde. **Chez nous :** une case peut porter un ennemi tout en étant une cible destructible. Il faut alors que l'IA et la prévision sachent comparer attaquer le monstre et attaquer son support.

**Netherbrain.** Orb of Negation : **action, portée 30 m**, condamne les plateformes et les détruit à la fin du round suivant. Brainquake : **réaction, 10d6 psychiques**, portée 30 m, sauvegarde Intelligence. En Honneur, Aegis impose d'alterner les types de dégâts selon ceux du round précédent. La réussite préalable du jet spécial peut réduire ses PV de 20 % : 240/360 au lieu de 300/450. [Combat](https://bg3.wiki/wiki/The_Netherbrain/Combat). **Méthode :** répartir les dégâts et les positions avant la perte d'une plateforme ; ne pas investir toute une rotation dans un type bientôt interdit. Dans notre run, une carte d'élément secondaire devient une assurance contre cette règle, mais il faut annoncer le boss assez tôt pour permettre une adaptation du deck.

**Dragon rouge dominé.** Souffle : **action, 14d6 feu, 30 m**, sauvegarde Dextérité ; attaque multiple : **4d8+8 contondants +3d8+8 perforants +4d6 feu**, portée 4 m ; vol **action bonus, 30 m**. En Tacticien, Draconic Fury ajoute une réaction de souffle une fois par round. [Dragon](https://bg3.wiki/wiki/Dominated_Red_Dragon). Moyennes : 49 et 61,5. **Méthode :** l'ordre des attaques doit prendre en compte le souffle de réaction ; déclencher la réaction depuis une position maîtrisée peut protéger les autres actions du round. Notre affichage d'intention ne doit pas masquer les réactions derrière la seule attaque du prochain tour.

## 5. Divinity: Original Sin 2 : seuils d'armure et séquence d'initiative

### 5.1 Fiches, avec limites de difficulté explicites

| Boss / variante | Vitalité | Armure physique | Armure magique | Initiative / autres paramètres |
|---|---:|---:|---:|---|
| Alice Alisceon, Classique, niveau 15 | 1 603 | 550 | 1 032 | Intelligence 33 ; feu 160 %, poison 200 %, eau −50 %, air 50 % |
| Docteur, relevé guide Definitive Edition, difficulté non certifiée | 7 073 | 11 120 | 13 436 | Initiative 37 ; feu/eau 50 %, air/poison 20 % |
| Dévoreur, même guide | 12 846 | 7 413 | 6 255 | Initiative 18 ; eau −10 %, feu/terre 30 %, air 10 %, poison 200 % |
| Braccus, fiche niveau 20, difficulté non certifiée | 9 313 | 6 603 | 6 623 | 8 PA, initiative 32 ; intelligence 48 |

Sources : [Alice](https://www.divinitywiki.com/index.php/DOS2%3AAlice_Alisceon), [guide Docteur/Dévoreur](https://gamefaqs.gamespot.com/ps4/236378-divinity-original-sin-ii-definitive-edition/faqs/81674/chapter-6-the-hunt-for-dallis), [Braccus](https://divinity.fandom.com/wiki/Braccus_Rex). Ne pas employer ce tableau pour déduire un multiplicateur unique Classique→Tacticien : les variantes ne sont pas toutes renseignées.

### 5.2 Alice : une défense faible n'est pas forcément la meilleure route de mise à mort

Son aura de douleur peut être retirée avec Bénédiction ; cela ne signifie pas que Rétribution disparaît également. [Alice](https://www.divinitywiki.com/index.php/DOS2%3AAlice_Alisceon). Bénédiction coûte **1 PA et 1 point de Source**, relance **3**, portée **13 m**. [Sort](https://divinity.fandom.com/wiki/Bless_(Original_Sin_2)). Chloroforme coûte **1 PA**, portée **13 m**, relance **3** ; il attaque l'armure magique et peut endormir après sa suppression. [Sort](https://divinity.fandom.com/wiki/Chloroform).

**Calcul illustratif**, à dégâts bruts comparables et sans autre réduction : ouvrir un contrôle physique exige 550 ; ouvrir l'armure magique avec de l'eau exige `1 032 / 1,5 = 688`. Le physique ouvre donc plus vite cette fenêtre. Mais retirer armure + vie exige `550 + 1 603 = 2 153` physiques contre `(1 032 + 1 603) / 1,5 ≈ 1 757` eau. Le chemin le plus court vers le contrôle et celui vers la mort diffèrent. La réflexion et l'ordre d'initiative peuvent encore changer le choix réel.

**Chez nous.** Une résistance magique et une armure ne doivent pas seulement multiplier deux familles de dégâts : si elles ouvrent des contrôles différents, elles créent une décision de cible. Copier toutes les immunités de DOS2 sans son système d'armures enlèverait cette décision.

### 5.3 Docteur : préparation hors combat et concentration du soutien

Le relevé donne des infirmières à **2 453 vitalité, 0 armure physique, 1 158 magique**, initiative 29. La préparation par les bougies réduit fortement le Docteur ; le guide indique −50 % de vitalité/armures et −50 points de résistance. [Guide DE](https://gamefaqs.gamespot.com/ps4/236378-divinity-original-sin-ii-definitive-edition/faqs/81674/chapter-6-the-hunt-for-dallis).

**Calcul sans affaiblissement.** Route physique théorique du Docteur : `11 120 + 7 073 = 18 193`. Route magique : `13 436 + 7 073 = 20 509`, soit 41 018 dégâts bruts de feu contre sa résistance 50 %, avant autres effets. Une infirmière sans armure physique peut être contrôlée immédiatement par une capacité appropriée, contrairement au boss. La stratégie peut donc neutraliser le soutien pendant que la préparation réduit le mur principal.

**Chez nous.** Les embranchements de run, drops et objets peuvent préparer un boss : par exemple obtenir un consommable qui coupe une source de soin. Il faut comparer cet investissement à une amélioration offensive générique en nombre de tours économisés. Les coûts exacts de tous les sorts du Docteur ne sont pas établis ici ; aucune valeur de sort joueur n'est automatiquement attribuée à sa version de boss.

### 5.4 Dévoreur : contrôler le moment où la phase suivante peut jouer

Un guide Tacticien décrit une phase enchaînée, puis une libération au tour de l'Archéologue au round 3, à la mort des deux auxiliaires, ou à l'épuisement d'une armure. Une libération avant sa place dans l'initiative lui permet d'agir pendant ce même round. Les cages y sont relevées à **501 vitalité**. [Guide Tacticien](https://www.scribd.com/document/815447116/D-OS2-de-Tactician-v1-00).

**Séquence tactique.** Préparer la réduction d'armure et les auxiliaires sans déclencher trop tôt ; attendre son créneau du round précédent, puis libérer quand les alliés disposent encore de leurs actions. Avec les valeurs du tableau, ouvrir la voie magique par l'eau exige environ `6 255 / 1,1 = 5 686` dégâts bruts, contre 7 413 physiques. Ce choix ne garantit pas le contrôle suivant : ses immunités temporaires doivent être respectées.

**Correction de certitude.** Les guides décrivent une immunité temporaire après certains contrôles, mais ne concordent pas assez sur son instant exact de déclenchement pour affirmer ici « deux tours à partir de l'application » plutôt qu'« après libération ». Le dossier précédent doit être lu avec cette réserve. Chez nous, le moment de décrément d'une immunité doit appartenir à la règle formelle d'activation, pas à une description ambiguë.

### 5.5 Braccus : le kit de sorts n'est qu'une partie du combat final

Le répertoire relevé inclut Void Glide, Staff of Magus, Fireball, Spontaneous Combustion, Fire Whip et Searing Daggers. [Braccus](https://divinity.fandom.com/wiki/Braccus_Rex). Le combat final ajoute une transition et des invocations ; une fiche « mage feu à 9 313 PV » ne décrit donc pas la pression réelle de la salle. Les coûts exacts des versions boss et la variante de difficulté de ce bloc ne sont pas certifiés. Il serait trompeur de remplir ces cellules avec les coûts des sorts du joueur.

**Chez nous.** Le même problème existe entre la ressource de Pâris et sa fabrique : le bon objet d'audit est la rencontre instanciée, comprenant accompagnateurs, phases et ressources, et non le fichier d'unité isolé.

## 6. Wakfu et deckbuilding : deux comparaisons chiffrées complémentaires

### 6.1 Serre d'Acier : attribuer les ressources de stabilisation

Le guide décrit **80 000 PV**, seuils **68 000 / 40 000 / 16 000**. Au premier tour : **9 Corbacs à 3 072 PV**. Chaque mort donne −1 PM ; trois charges stabilisent contre les vents. Fulguro Serres pousse **4 cases**. Les pièges frappent en **3×3** et retirent 100 PM ; la bordure tue les personnages, pas les oiseaux. En phase terrestre, dépasser **3 500 dégâts à distance** déclenche un saut punitif ; en dernière phase, soins annulés et **50 % vol de vie** pour le boss. [MethodWakfu](https://methodwakfu.com/pvm/boss-ultimes/plateau-des-hauts-vents/).

**Calcul de rôle.** Neuf victimes pour trois charges permettent de stabiliser trois personnages. La question est de savoir qui reçoit les derniers coups, en tenant compte des classes qui savent déjà se stabiliser. Ce n'est donc pas seulement un objectif « tuer les adds ». Pour notre solo, la ressource devrait devenir un choix de transformation du héros ou d'une invocation : stabilisation contre perte de mobilité, avec seuils visibles. Copier l'allocation entre six joueurs n'aurait pas de sens.

### 6.2 Waven : un exemple de personnage, sorts et équipement réellement liés

Dans le build Hioplite décrit par Guidactik : appliquer Astral déclenche **140 % de l'attaque** ; Maître Hioplite permet une nouvelle attaque après consommation d'Astral, **une fois/tour**. Bond téléporte à **3 cases** et inflige **25 % de l'attaque** autour de l'arrivée. Touche Astrale inflige **50 %**, puis donne **100 % de l'attaque en armure** si la cible est Astrale. Le Brassard Huilé applique l'état lors de l'attaque ; Appel Paladir convertit un état élémentaire en Astral. La Championne du Blasphème gagne **150 % de dégâts** contre une cible Éventée ; Épinette défausse la main puis pioche **3 sorts**. [Guide du Hioplite](https://guidactik.com/waven/guide-et-build-du-iop-paladir-hioplite-sur-waven/).

**Lecture de la séquence.** L'équipement prépare l'état, le passif convertit cette préparation en dégâts, un sort ou compagnon consomme l'état, puis une attaque supplémentaire exploite l'ouverture. Ce sont quatre fonctions différentes. Chez nous, Repérer une faille et Prime remplissent déjà préparation/consommation conditionnelle, mais il faut évaluer séparément l'accès par équipement et la récompense de classe. Une seule attaque rejouée par tour borne la boucle ; un bonus multiplicatif sans limite ne le ferait pas.

**Divergence concrète de données.** Le même guide décrit l'Index de Toross comme +5 % attaque par jauge dépensée, plafond +100 %. Waven Tools décrit cet objet comme ajoutant Flux de Toross à la main initiale, avec une compétence à 5 % d'invocation sur coup de grâce. [Fiche de l'objet](https://www.waven.tools/items/index-de-toross-282). Ces deux descriptions ne sont pas fusionnées en un objet imaginaire : le build sert de référence documentée de fonctionnement, pas de validation du patch live.

Les recherches n'ont pas produit de fiches de boss Waven suffisamment fiables pour publier leurs PA/PV actuels. Aucun chiffre Dofus ou Wakfu n'est attribué à Waven par ressemblance de nom.

### 6.3 Slay the Spire 1 : combien coûte une conversion de défense en dégâts ?

| Carte | Coût normal → amélioré | Transformation |
|---|---|---|
| Body Slam | 1 → 0 énergie | Dégâts égaux au blocage actuel |
| Entrench | 2 → 1 | Double le blocage actuel |
| Barricade | 3 → 2 | Le blocage n'est plus retiré au début du tour |

Sources : [Body Slam](https://slay-the-spire.fandom.com/wiki/Body_Slam), [Entrench](https://slaythespire.wiki.gg/wiki/Entrench), [Barricade](https://slaythespire.wiki.gg/wiki/Barricade). Il s'agit bien de **Slay the Spire 1**, pas d'un mélange avec le second jeu.

**Séquence chiffrée.** Avec 20 blocage déjà acquis, Entrench + Body Slam donnent 40 blocage et 40 dégâts pour 3 énergies ; les deux améliorées ne coûtent plus qu'une énergie. Avec Barricade déjà active, le reliquat après les attaques adverses devient le capital du tour suivant. Barricade jouée seule n'apporte pas de blocage immédiat : elle a un coût de mise en place et demande de survivre à cette mise en place.

**Comparaison locale vérifiée.** Garde fragile donne 10 bouclier pour 1 PA à P=40, avant passif. Sentence du rempart, 3 PA, PO 1–2, inflige 1,1P et ajoute 1P si `current_shield > 0` : 44 + 40 = 84 au rang 0. Le résultat est identique avec 1 ou 100 bouclier. [Condition réelle](../../core/expedition/class_card_modifier.gd#L47). Notre attaque récompense donc la présence de garde, tandis que Body Slam convertit sa quantité. Ajouter plus de bouclier augmente ici la survie, pas les dégâts de Sentence. Cette distinction indique précisément ce qu'une nouvelle relique ou carte de conversion pourrait apporter.

**Équipement, reliques et montée en niveau.** Pour chacun de ces apports, calculer son effet sur une séquence réelle : change-t-il le nombre de cartes nécessaire pour atteindre les 112 dégâts nets de Pâris ? Permet-il de supprimer un Porteur avant son prochain soutien ? Fait-il passer une rotation de 6 à 5 PA ? Un bonus qui ne franchit aucun seuil peut rester utile en moyenne, mais n'a pas le même effet qu'un bonus qui supprime une activation ennemie entière. Les comparaisons doivent conserver le même niveau, les mêmes résistances et la même main initiale.

### 6.4 Monster Train 1 : améliorer l'accès à la bonne carte

Emberstone réduit le coût d'un sort de **1 énergie** ; Freezestone lui donne Permafrost ; Keepstone lui donne Holdover. Hoarfrost Effigy coûte **3 énergies** et peut exploiter ces améliorations pour préparer ou répéter sa multiplication de Frostbite. [Améliorations](https://monster-train.fandom.com/wiki/Upgrades), [Hoarfrost Effigy](https://monster-train.fandom.com/wiki/Hoarfrost_Effigy).

**Application chiffrée à notre problème.** Pour un sort coûtant 3 sur un tour à 4 PA, une réduction à 2 change une rotation avec un autre sort à 2 de « impossible » à « possible ». Pour l'exécution de Pâris, garder une carte pour le seuil et la retrouver régulièrement répondent à deux besoins distincts. Une amélioration de dégâts de 10 % peut ne résoudre aucun des deux. Le draft doit donc être évalué aussi par la disponibilité de ses réponses au bon tour, en conservant le coût d'opportunité des emplacements d'amélioration.

## 7. Ce que ces chiffres changent dans les priorités de la run Cartes

| Priorité | Constat établi | Travail concret proposé | Mesure attendue |
|---|---|---|---|
| 1 | La fabrique modifie PV et dégâts après lecture des ressources | Exporter la fiche finale de chaque rencontre, avec profondeur, variante et difficulté | Aucun PV/dégât de base pris pour une valeur instanciée |
| 1 | Pâris peut presque doubler sa réserve selon le franchissement du seuil | Afficher seuil, retour à pleine vie et exception coup fatal ; éprouver plusieurs decks | Taux de transition voulue/subie, dégâts nets disponibles au seuil |
| 1 | Le petit combo marque coûte plus pour les mêmes dégâts immédiats | Fixer son horizon de rentabilité puis régler le coefficient ou le coût | Rendement à 1, 2 et 3 consommateurs, PA et cartes dépensés |
| 1 | Obole dépend d'une liaison spatiale réelle | Afficher les Porteurs qui autorisent le soin et sa valeur finale | Soins empêchés par déplacement contre élimination |
| 2 | Les menaces ne s'additionnent pas librement | Prévisualiser les séquences légales de PA et les réactions | Aucun tour annoncé comme possible au-delà du budget |
| 2 | Les références utilisent des moments de déclenchement différents | Formaliser entrée de case, début/fin d'activation, impact, mort et changement de phase | Résolution prévisible avant paiement de carte |
| 2 | Une mécanique multijoueur peut devenir insoluble en solo | Donner une réponse de salle aux contraintes obligatoires, une meilleure réponse via deck | Victoire possible sans carte nommée obligatoire |
| 3 | Les objets peuvent changer un seuil plutôt qu'un simple DPS | Comparer équipements et reliques sur les trois rencontres locales de référence | Actions/tours gagnés, pas seulement pourcentage de dégâts |

### Vérifications à exécuter avant de déclarer les changements jouables

Ce sont des **scénarios proposés**, pas des tests déjà passés :

1. Pâris à 112 PV : dégâts nets 111, 112 et 113 ; vérifier forme, survie, bouclier et événement d'annulation.
2. Même transition avec soin empêché ou modifié ; vérifier le résultat réel du retour à pleine vie.
3. Collecteur : Porteur à distance 2 puis 3 ; deuxième Porteur présent/absent ; mesurer refus de lancement et soin réel.
4. Exécuteur : préparer Sentence, déplacer la cible, interrompre, changer la portée ; vérifier résolution et activation consommée.
5. Même main et mêmes équipements : marque + Saisir contre Frappe ; puis marque + Prime ; vérifier les arrondis et défenses.
6. Trois archétypes offensifs et un défensif sur ces rencontres : mesurer la durée, les dégâts subis et les solutions réellement employées.

### Limites de ce complément

Le dossier fournit des fiches chiffrées et des calculs nouveaux ; il ne constitue pas une extraction exhaustive de tous les sorts, grades et monstres de chaque jeu. Les lacunes sont nommées : Waven, rituel actuel complet Moon/Kralamoure, table complète des Krobes, coûts des versions boss de plusieurs sorts DOS2, certaines divergences de patch Dofus. Les calculs locaux reposent sur lecture du code, pas sur des combats rejoués. Aucun test moteur nouveau n'a été exécuté pour cette modification documentaire.
