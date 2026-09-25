# DOFUS — les 16 classes supplémentaires

Lecture du 25 septembre 2026. **80 fiches individuelles**, cinq par classe. Xélor, Pandawa et Féca figurent dans le [premier dossier](../DOFUS.md). Ce complément couvre toutes les classes restantes du catalogue consulté, pas tous leurs sorts, variantes, invocations et builds.

Les valeurs viennent du dernier grade affiché dans DOFUSDB.com, qui indique 3.6.9.9. Ce n'est pas une certification du client live. PA = coût de lancement ; PO = intervalle affiché ; t = tour ; N = niveau du personnage. Dégâts de base hors critique, avant caractéristiques/résistances. Une restriction non écrite ici n'est pas déclarée absente. Les champs « 0 lancer/tour » sont incomplets et ne sont jamais traduits par « illimité ». Les portées à 63 sont souvent des ciblages d'entités de classe, pas des tirs libres.

Chaque dernier paragraphe est une **analyse de conception** : boucle suggérée par ces cinq fiches, dépendances et leviers. Ce n'est ni un classement PvM/PvP ni un build optimal vérifié.

## Crâ — construire et conserver sa distance

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Flèche de Recul](https://dofusdb.com/sorts/fleche-de-recul-32426) | 3 PA, PO 1–6 ; Air 25–28 ; pousse ; 3/t | Défense et attaque ensemble ; distance de poussée non décodée. |
| [Balise de Survie](https://dofusdb.com/sorts/balise-de-survie-32474) | 2 PA, PO 1–4 ; soigne 7 % PV max des alliés en vue au début de son tour ; échange avec le Crâ qui l'attaque en vue ; disparaît après deux tours | Préparer une sortie et des soins futurs ; il faut préserver l'ancrage. |
| [Flèche Punitive](https://dofusdb.com/sorts/fleche-punitive-32456) | 4 PA, PO 4–10 ; Terre 30–34 ; érosion 15 %, 2 t ; 1/t ; charge des utilisations suivantes | La cible trop proche devient inaccessible ; progression de charge non chiffrée. |
| [Flèche d'Expiation](https://dofusdb.com/sorts/fleche-d-expiation-32438) | 4 PA, PO 6–12 ; Eau 35–37 ; soins reçus ×0,5 ; charge ultérieure | Forte zone morte ; durée exacte de l'anti-soin et montée en puissance à compléter. |
| [Acuité Absolue](https://dofusdb.com/sorts/acuite-absolue-32469) | 2 PA, soi ; +15 points de critique pendant 1 t ; supprime la ligne de vue des sorts en augmentant la portée minimale des offensifs | Acheter l'accès derrière obstacle contre l'accès aux adversaires proches ; hausse minimale non décodée. |

La portée minimale est un budget d'équilibrage à part entière. Le build distance organise une zone de travail avec Recul et Balise ; un ennemi qui y entre impose un coût de réparation. Acuité ne devrait pas être réduite à « ignore les murs » dans notre adaptation. Conserver son prix spatial évite de rendre obsolètes mobilité et obstacles.

## Ecaflip — main, hasard et dette temporelle

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Bonne Pioche](https://dofusdb.com/sorts/bonne-pioche-12843) | 1 PA rendu ; pioche aléatoire ; joue d'abord une main pleine ; 3/t | Gratuit net, mais exige le PA initial ; contenu du Poker non étudié intégralement. |
| [Roulette](https://dofusdb.com/sorts/roulette-12840) | 1 PA rendu ; 1/t ; un effet aléatoire collectif : PA, PM, portée, caractéristiques, érosion, etc. | Ne pas additionner toutes les issues ; l'adversaire peut bénéficier du tirage. |
| [Odorat](https://dofusdb.com/sorts/odorat-12854) | 3 PA, PO 0–2 ; maintenant −3 PA/+2 PM, puis −2 PM/+3 PA ; le lanceur évite le retrait PA initial ; joue la main | Financer un tour futur exige de pouvoir le jouer à bonne distance. |
| [Seconde Chance](https://dofusdb.com/sorts/seconde-chance-12842) | 2 PA, PO 0–6 ; dégâts reçus alliés ×0,5 puis ×1,5 ; manipulation main/table | Protection déplacée dans le temps, pas réduction permanente ; table vide = exception de défausse. |
| [Bluff](https://dofusdb.com/sorts/bluff-29785) | 3 PA, PO 1–7, 1/t ; dégâts selon la main ; main vide : quatre cartes tirées avant résolution | Les lignes 4–56 affichées ne prouvent pas quatre impacts simultanés. |

Trois axes distincts : contrôle de la main, exploitation d'un tirage, transfert de puissance entre tours. Leur intérêt vient du droit de réagir à l'information. Dans un système consommable, faire payer une copie rare avant de révéler un résultat incontrôlable augmente fortement la réticence à jouer. Un coût net nul en PA reste coûteux en carte.

## Eliotrope — exploiter un réseau, puis en fermer les accès

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Portail](https://dofusdb.com/sorts/portail-14574) | 1 PA, PO 1–6, 2/t ; transporte/projette ; projection : +2 % dommages/soins finaux, 3 t, cumul 10 ; traversée ennemie interdite T1 | Chemins et coefficient général du réseau restent à documenter. |
| [Neutral](https://dofusdb.com/sorts/neutral-14582) | 1 PA rendu ; PO 0–8, 2/t ; portail désactivé 1 t | Fermer après avoir exploité le trajet ; dépense de commande malgré coût net nul. |
| [Distribution](https://dofusdb.com/sorts/distribution-14577) | 2 PA, PO 0–6 ; alliés proches de la cible soignés à hauteur de 25 % des dégâts infligés | La position des bénéficiaires est une partie de la puissance. |
| [Entraide](https://dofusdb.com/sorts/entraide-14596) | 2 PA, soi ; traversée → +1 PA au lanceur et soin 3 % PV max près de lui | Plafond et restrictions de répétition non certifiés : aucune boucle infinie supposée. |
| [Rayon de Wakfu](https://dofusdb.com/sorts/rayon-de-wakfu-14579) | 3 PA, PO 1–5, 2/t ; Feu 26–28 ennemis, soin alliés dans la zone | Un placement peut produire simultanément pression et soutien. |

Le réseau doit rester un objet risqué : accès, sortie, orientation, fermeture. Un build de projection et un build de soutien n'utilisent pas forcément les mêmes positions. Pour nos cartes, la structure pourrait durer plusieurs tours après consommation de la carte de pose ; chaque commande ultérieure doit alors être comparée au capital déjà investi.

## Eniripsa — soutien distribué et limites de cumul

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Mot d'Amitié](https://dofusdb.com/sorts/mot-d-amitie-25795) | 3 PA, PO 1–3 ; Lapino contrôlé, soin/bouclier ; relance sur lui : déplacement et immobilisation ; mort : glyphe, recharge 2 | Le kit de l'invocation et ses transformations demandent des fiches supplémentaires. |
| [Mot Stimulant](https://dofusdb.com/sorts/mot-stimulant-25742) | 2 PA, PO 0–5, 1/t ; +2 PA, 2 t, Encouragé ; case libre : Fée | Plafond partagé des encouragements ; éviter les additions naïves. |
| [Mot de Jouvence](https://dofusdb.com/sorts/mot-de-jouvence-25743) | 2 PA, PO 0–5, 1/t ; réduit les effets d'un tour ; soin 10 % PV max puis au début du tour ; Encouragé ; case vide : Fée | Nettoyage, soin et concurrence avec d'autres encouragements. |
| [Mot de Reconstitution](https://dofusdb.com/sorts/mot-de-reconstitution-13187) | 5 PA, PO 0–8 ; soin 100 % PV max ; Insoignable | Le verrou de soin est essentiel ; durée absente de la lecture exploitable. |
| [Peinture de Guerre](https://dofusdb.com/sorts/peinture-de-guerre-25868) | 2 PA, PO 0–7, 2/t ; Terre 9–11 contre ennemi ; peinture alliée soigne, peinture ennemie affaiblit la résistance poussée | Les branches allié/ennemi ne sont pas deux dommages. |

Identité : acheter le bon avenir d'un allié, avec plusieurs canaux de soutien qui ne se cumulent pas librement. Le soin maximal théorique ne suffit pas à comparer Reconstitution et Jouvence : débuff, échéance, plafond partagé et interdiction future comptent. En solo, ces interactions ont besoin de bénéficiaires ou d'objets réellement utiles ; copier des outils d'équipe tels quels produirait des cartes mortes.

## Enutrof — rediriger, immobiliser, faire payer après

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Sac Animé](https://dofusdb.com/sorts/sac-anime-13328) | 2 PA, PO 1–5 ; invocation contrôlée interceptant la zone initiale pendant 3 t ; allié qui frappe le sac se soigne | Déplacement de risque vers une entité destructible. |
| [Maladresse](https://dofusdb.com/sorts/maladresse-13337) | 1 PA, PO 1–12, 4/t ; −2 PM, 1 t | Puissance dépend du seuil de déplacement, pas seulement du nombre retiré. |
| [Corruption](https://dofusdb.com/sorts/corruption-13346) | 5 PA, PO 4–8 ; ennemi Pacifiste + Invulnérable ; allié Pacifiste + soin 40 % PV max | Ce n'est pas un tour gratuit pour frapper la victime. |
| [Retraite Anticipée](https://dofusdb.com/sorts/retraite-anticipee-13349) | 4 PA ; −100 PM et Pesanteur aux autres ; lanceur immobilisé au tour suivant | Contrôle collectif à dette personnelle. |
| [Coffre Animé](https://dofusdb.com/sorts/coffre-anime-13347) | 3 PA, PO 1–3 ; tacle, dégâts Eau, révèle ; allié qui le frappe se soigne | Aucun bonus de drop lu dans cette fiche. |

Le build contrôle convertit l'espace en tours disponibles ; le build soutien transforme des objets en points d'appui. Un ennemi déjà hors portée rend un retrait de PM inutile, tandis qu'un seul PM retiré peut supprimer son attaque entière. Notre économie doit mesurer les cartes économisées par ce contrôle, tout en évitant un combat prolongeable indéfiniment pour se régénérer.

## Forgelance — changer l'origine d'un sort

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Épilogue](https://dofusdb.com/sorts/epilogue-23801) | 1 PA, PO 1–8, 1/t ; pose/rappelle la Lance ; sans vue si Désarmé | Préparation spatiale et changement d'état. |
| [Phalange](https://dofusdb.com/sorts/phalange-23330) | 3 PA ; bouclier 300 % N, 2 t, zone ; résistance poussée ; Désarmé : cible Lance | Le bandeau « soi » ne décrit pas les deux modes de ciblage. |
| [Muspel](https://dofusdb.com/sorts/muspel-23750) | 4 PA, PO 1–63 affichée ; Feu 28–32 en zone croissante ; Désarmé : Lance seulement, rappel | Le nombre 63 ne signifie pas liberté totale. |
| [Terre du Milieu](https://dofusdb.com/sorts/terre-du-milieu-23738) | 3 PA, 1/t ; Terre 30–34 en zone ; +50 Puissance par ennemi, 2 t ; origine Lance si Désarmé | Grouper les ennemis accroît plusieurs rendements. |
| [Chevalerie](https://dofusdb.com/sorts/chevalerie-23826) | 2 PA ; soin 7 % PV max en zone, +2 PM, rappel de Lance si Désarmé | Retour offensif, défensif ou repositionnement. |

Le même sort peut exprimer un build de proximité ou d'artillerie selon l'emplacement de la Lance. L'ancrage évite de multiplier les boutons tout en créant une géométrie différente. Équilibrer séparément coût de pose, coût de rappel, occupation de case et pertes de tour si le dispositif n'est plus accessible.

## Huppermage — coder une situation avec les éléments

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Runification](https://dofusdb.com/sorts/runification-13670) | 2 PA, PO 0–8, 2/t ; rune occupée : vol de vie 15 ennemi ou soin 6 % PV max allié ; +50 caractéristique, 3 t ; soi : ensemble des runes occupées | Les quatre éléments sont des branches, pas quatre frappes garanties. |
| [Cycle Élémentaire](https://dofusdb.com/sorts/cycle-elementaire-13722) | 1 PA, PO 1–8, 4/t ; Terre→Eau→Feu→Air→Terre ; premier changement sur une cible remboursé | Préparer l'effet voulu sans refaire tout le cycle offensif. |
| [Contribution](https://dofusdb.com/sorts/contribution-13701) | 2 PA, PO 0–7 ; consomme états ennemis ; Terre→PM, Feu→bouclier 200 % N, Eau→150 Puissance, Air→PA ; 2 t | Consommation d'une réserve distribuée ; caps à compléter. |
| [Polarité](https://dofusdb.com/sorts/polarite-13696) | 1 PA, PO 1–4, 2/t ; Terre pousse, Feu échange, Eau attire, Air symétrie du lanceur ; consomme l'état | Une même commande donne plusieurs mouvements selon la préparation. |
| [Propagation](https://dofusdb.com/sorts/propagation-13695) | 1 PA, PO 1–8, 2/t ; propage ; malus associés : résistance poussée, critique −15, fuite −20, tacle −20 | La combinaison élémentaire complète n'est pas chiffrée ici. |

Le multiélément n'est pas seulement une couverture de résistances : c'est un langage de commandes. Il faut distinguer état sur cible, rune sur case et dernière action. Pour notre Thaumaturge, deux conversions lisibles d'un état seraient plus structurantes que quatre copies de la même attaque avec une couleur différente.

## Iop — engager, maintenir, décaisser

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Bond](https://dofusdb.com/sorts/bond-13107) | 4 PA, PO 1–5, 1/t ; téléportation ; dégâts reçus ennemis voisins ×1,15 | Coût d'accès élevé, rentabilisé par la suite de la séquence. |
| [Friction](https://dofusdb.com/sorts/friction-13113) | 2 PA, PO 0–6 ; ennemi touché attiré vers son attaquant ; sur allié : attire ses attaquants ennemis | Déplacement conditionné par l'attaque ; distance exacte inconnue. |
| [Précipitation](https://dofusdb.com/sorts/precipitation-13114) | 2 PA, PO 0–6 ; +5 PA puis −3 PA ; allié Affaibli sauf lanceur | Gain immédiat net +3, dette future −3 : transfert temporel. |
| [Épée du Destin](https://dofusdb.com/sorts/epee-du-destin-13111) | 4 PA, PO 1–6 ; Feu 38–42 ; bonus après récupération | Relance et coefficient de charge non certifiés. |
| [Fureur](https://dofusdb.com/sorts/fureur-13156) | 3 PA, contact, 1/t ; Terre 28–32 ; gagne en puissance si répétée, perd du bonus si abandonnée | Récompense la continuité ; punie par déplacement ou invulnérabilité. |

Deux rythmes se distinguent : conserver l'engagement ou préparer une échéance explosive. Copier une attaque qui exige des lancements réguliers dans un deck à usage unique nécessite de garantir des copies ou de stocker sa charge hors de la carte. Sinon, l'aléatoire casse l'identité avant même que le combat commence.

## Osamodas — commander un partenaire mobile

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Tofu](https://dofusdb.com/sorts/tofu-31115) | 3 PA, PO 1–2 ; invocation contrôlable : Air, soin, retrait tacle, poussée | Les coefficients de ses propres sorts ne sont pas lus. |
| [Fouet](https://dofusdb.com/sorts/fouet-31114) | 2 PA, PO 1–5, 3/t ; meilleur élément 15–17, pousse ; invocation alliée +1 PM | Un outil partagé entre pilotage et attaque. |
| [Piqûre Motivante](https://dofusdb.com/sorts/piqure-motivante-31120) | 2 PA, PO 0–5 ; +1 PA/+1 PM pendant 3 t ; branche invocation +2/+2 | Ne pas additionner les branches en +3/+3. |
| [Discipline](https://dofusdb.com/sorts/discipline-31125) | 2 PA, PO 1–5, 2/t ; meilleur élément 19–22, −2 PM, attire | Remettre une cible dans le périmètre des invocations. |
| [Laisse Spirituelle](https://dofusdb.com/sorts/laisse-spirituelle-31152) | 2 PA, PO 0–5 ; cible suit les déplacements PM ; soi : toutes les invocations ; déplacement forcé rompt le lien | **La fiche lue décrit un suivi, pas l'ancienne résurrection.** |

L'efficacité vient des tours rendus utiles aux invocations. Comparer Tofu à une attaque immédiate exige d'intégrer survie, accès à la cible, coût de commande et temps d'animation. Pour une run solo, limiter le nombre d'unités commandées est aussi un budget de durée des combats, pas seulement de puissance.

## Ouginak — poursuivre sans perdre sa réserve

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Proie](https://dofusdb.com/sorts/proie-13748) | 1 PA, PO 1–6 ; attaquer la proie soigne ; sa mort réinitialise la relance | Fraction de soin non lisible ; choix de cible collectif. |
| [Molosse](https://dofusdb.com/sorts/molosse-13756) | 3 PA, PO 1–2, 3/t ; Terre 31–34 ; dégâts reçus lanceur ×0,9 ; gain de Rage sur cible | La résistance accompagne l'exposition au contact. |
| [Apaisement](https://dofusdb.com/sorts/apaisement-13769) | 3 PA, PO 0–4 ; soin 15 % PV max ; consomme Rage/retire forme bestiale | Sauvetage contre perte de puissance préparée. |
| [Flair](https://dofusdb.com/sorts/flair-13749) | 3 PA ; rejoint la Proie ; destination adjacente ; requiert/consomme Rage | Accès conditionnel, pas téléportation libre PO 63. |
| [Appel de la Meute](https://dofusdb.com/sorts/appel-de-la-meute-14357) | 2 PA, PO 0–6 ; rassemble alliés ; sur Proie : attraction renforcée, érosion 10 % ; réduit relance Lance-roquet | Effets liés à des bénéficiaires et à une invocation. |

Poursuite, soin et maintien de forme se disputent la même préparation. Cette concurrence est fertile pour un consommable : une carte utilitaire peut sacrifier la ressource de burst, plutôt que d'être simplement moins rentable en dégâts. Il faudra toutefois définir la Rage indépendamment du hasard de pioche.

## Roublard — investir, déplacer, liquider

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Explobombe](https://dofusdb.com/sorts/explobombe-13444) | 2 PA initiaux, PO 1–6, 2/t ; pose ou explosion directe ; +1 PA de coût par Explobombe personnelle déjà présente ; sur bombe : combo +1 et explosion | Inflation du coût de déploiement ; pas un coût fixe de 2. |
| [Détonateur](https://dofusdb.com/sorts/detonateur-13432) | 1 PA, PO 1–8, 2/t ; combo +1 ; PA rendu **avant** explosion | Ordre important si l'explosion crée d'autres événements. |
| [Aimantation](https://dofusdb.com/sorts/aimantation-13437) | 2 PA, PO 0–7, 2/t ; regroupe bombes ; combo +1 si réellement déplacée, une fois/bombe/t ; autres cibles attirées d'une case | Déplacer une bombe bloquée ne doit pas compter comme une réussite. |
| [Poudre](https://dofusdb.com/sorts/poudre-13441) | 1 PA, PO 1–8, 1/t ; immobilise bombe ; +2 combo sur destruction/branche de retrait ; explosion normale retire l'état | Branches exactes à tester, pas bonus inconditionnel. |
| [Kaboom](https://dofusdb.com/sorts/kaboom-13450) | 3 PA, PO 0–5 ; état allié de zone ; bombes personnelles +1 combo | L'état Kaboom n'est pas décodé : ne pas lui attribuer un ancien effet. |

Trois valeurs d'une bombe : menace future, obstacle présent, capital convertible. Sa destruction peut être un choix. Pour notre jeu, payer une carte de pose unique peut ouvrir plusieurs commandes ; l'équilibrage doit compter les copies de toute la chaîne et la probabilité de perdre l'investissement avant déclenchement.

## Sacrieur — transformer sa vulnérabilité sans confondre les PV

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Mutilation](https://dofusdb.com/sorts/mutilation-12737) | 2 PA, soi, 1/t ; perd 10 % PV au départ puis par début de tour ; +150 Puissance ; arrêt : bouclier 15/25 % PV max selon stade | Choix du moment de conversion ; les deux boucliers sont alternatifs. |
| [Transposition](https://dofusdb.com/sorts/transposition-12736) | 3 PA, PO 1–9 ; échange ; +4 PO maximale à Souffrance ≥6 | La vulnérabilité personnelle améliore aussi l'accès. |
| [Sacrifice](https://dofusdb.com/sorts/sacrifice-12739) | 2 PA, PO 0–5 ; intercepte pour les alliés ; détruit ses épées et transfère 50 % de leurs PV restants | Valorise la réserve vivante, pas uniquement le PV maximal. |
| [Berserk](https://dofusdb.com/sorts/berserk-12743) | 2 PA, soi ; perte 70 % PV ; +10 % dégâts sorts, intaclable, soins reçus ×0,3 ; cesse à Souffrance ≤5/recast | Base actuelle/maximale de la perte non certifiée. |
| [Punition](https://dofusdb.com/sorts/punition-12741) | 4 PA, contact ; 31–35 meilleur élément +35 % des **PV érodés** en Neutre | PV érodés ≠ PV simplement manquants. |

Le build berserk ne se résume pas à une courbe « moins de vie = plus de dégâts ». Il modifie mobilité, soins, protection et choix des bénéficiaires. Une statistique doit préciser sa référence : PV actuels, max de combat, max après érosion, ou réserve de départ. Toute formule qui mélange ces valeurs peut inverser le risque réel.

## Sadida — réseau vivant, propagation puis récolte

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Arbre](https://dofusdb.com/sorts/arbre-13519) | 2 PA, PO 1–8, 2/t ; feuillu après 1 t ; six par équipe ; le septième supprime le premier | Temps de croissance et capacité partagée. |
| [La Folle](https://dofusdb.com/sorts/la-folle-13564) | 2 PA, PO 1–63, 1/t ; transforme un arbre en poupée contrôlée ; infection/poison Air ; mort restitue l'arbre et son état feuillu | Transformer conserve une partie du capital de terrain. |
| [Contagion](https://dofusdb.com/sorts/contagion-13575) | 4 PA, PO 1–7, 2/t ; Air 35–39, −2 PM ; relais sur infectés et propagation près de la cible | La préparation augmente le nombre de bénéficiaires ennemis. |
| [Inoculation](https://dofusdb.com/sorts/inoculation-13569) | 5 PA, PO 1–6, 2/t ; Air 39–43, bonus selon infectés ; consomme les infections **autour de la cible** | Portée locale de consommation à distinguer du relais global. |
| [Don Naturel](https://dofusdb.com/sorts/don-naturel-13532) | 2 PA ; sacrifie arbre feuillu/poupée ; partage de dégâts entre alliés et soin de zone 30–35 | Invocations statiques exclues du partage. |

L'alternative centrale est maintenir le réseau pour plusieurs tours ou le sacrifier pour survivre/finir. Une carte « infection » n'a donc pas une valeur fixe : elle vaut davantage quand beaucoup de tours et de cibles restent. Dans une run, l'attrition doit empêcher de reconstituer gratuitement et éternellement le réseau hors danger.

## Sram — programmer un trajet et une position de retour

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Invisibilité](https://dofusdb.com/sorts/invisibilite-12913) | 2 PA, PO 0–6 ; invisible 1 t ; allié +2 PM, 2 t ; élimination par le Sram réinitialise la relance | Récompense la sortie réussie, pas uniquement la fuite. |
| [Double](https://dofusdb.com/sorts/double-12915) | 3 PA, PO 1–3 ; mêmes caractéristiques, contrôlé, sans attaque ; mort et échange en fin de son deuxième tour ; +2 PM au Sram | Horloge spatiale ; importance du moment de jeu du Double. |
| [Piège Répulsif](https://dofusdb.com/sorts/piege-repulsif-12914) | 2 PA, PO 1–7, 2/t ; pousse depuis le centre ; Air ennemi | Dégâts et dimensions exactes non décodés. |
| [Peur](https://dofusdb.com/sorts/peur-12908) | 2 PA, PO 2–8, 3/t ; pousse jusqu'à la case choisie | Contrôle du point d'arrêt, distinct d'une poussée fixe. |
| [Concentration de Chakra](https://dofusdb.com/sorts/concentration-de-chakra-12903) | 3 PA, PO 1–6 ; chaque dommage de piège déclenche vol de vie 12 meilleur élément pendant 1 t ; révèle le Sram | Multiplie la valeur des déclenchements ; coût d'exposition. |

Un réseau de pièges est une séquence, pas une collection de zones. Le design doit définir si un déplacement déclenché interrompt le trajet précédent et si une case peut redéclencher le même piège. Le Double apporte une identité très transférable : conserver une position de retour dont l'échéance est visible.

## Steamer — choisir sa structure et désigner sa cible

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Harponneuse](https://dofusdb.com/sorts/harponneuse-13829) | 2 PA, PO 1–7, 1/t ; tourelle offensive, vol de vie meilleur élément | Autonomie réelle et sélection de cibles à étudier séparément. |
| [Évolution](https://dofusdb.com/sorts/evolution-13832) | 1 PA, PO 1–7, 1/t ; monte la tourelle, soigne 50/25 % max selon branche ; allié +100 Puissance, 2 t | Les lignes de soin ne se cumulent pas automatiquement. |
| [Tactirelle](https://dofusdb.com/sorts/tactirelle-13831) | 2 PA, PO 1–7, 1/t ; tourelle de poussée | Construction d'un déplacement futur. |
| [Foène](https://dofusdb.com/sorts/foene-13824) | 3 PA, PO 1–6, 2/t ; **Air 28–32 et poussée de zone** | Ne pas importer l'ancien poison Terre de mémoire. |
| [Secourisme](https://dofusdb.com/sorts/secourisme-13836) | 3 PA, PO 1–6, 2/t ; soin 25–29 meilleur élément ; déclenche les spéciaux des tourelles défensives sur l'allié | Désignation de cible rentabilisant l'infrastructure. |

Le build dépend du dispositif que l'on améliore et des commandes que l'on lui donne. Évaluer Évolution seule manquerait l'essentiel : la valeur vient de ses activations ultérieures et de sa survie. Notre adaptation doit pouvoir afficher « cet objet jouera encore deux fois » pour rendre l'investissement compréhensible.

## Zobal — posture et conversion de risque en protection

| Sort et source | Contrat utile lu | Décision / limite |
|---|---|---|
| [Masque de l'Intrépide](https://dofusdb.com/sorts/masque-de-l-intrepide-13386) | 1 PA ; +1 PA au porteur tant qu'actif ; alliés non-Zobal de proximité +1 PA, 2 t ; attraction | Posture et aura, règles distinctes pour soi/autrui. |
| [Masque du Pleutre](https://dofusdb.com/sorts/masque-du-pleutre-13387) | 1 PA ; +1 PM/+40 fuite ; porteur continu, alliés non-Zobal 2 t | Évasion contre abandon d'une autre posture. |
| [Masque du Psychopathe](https://dofusdb.com/sorts/masque-du-psychopathe-13388) | 1 PA ; +10 % mêlée/+20 tacle ; mêmes distinctions de durée | Exposition choisie ; pas un bonus permanent cumulable aux autres masques. |
| [Plastron](https://dofusdb.com/sorts/plastron-13397) | 4 PA ; bouclier 600 % N, 2 t ; 300 % N pour invocations | Protection de groupe et coefficient spécifique aux invocations. |
| [Transe](https://dofusdb.com/sorts/transe-13399) | 3 PA, PO 0–1 ; perte 70 % PV, 2 t ; bouclier 450 % N, moitié pour invocations | Ne pas calculer un gain net de survie avant de résoudre la base de perte PV. |

Une posture change ce que la classe accepte de risquer. Plastron et Transe ne sont pas deux boucliers interchangeables : l'un coûte davantage d'actions, l'autre expose les PV. Dans notre run, distinguer garde expirante, réduction de PV réversible et perte permanente évite de vendre au joueur une fausse protection.
