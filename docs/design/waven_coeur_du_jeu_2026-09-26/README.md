# WAVEN : enquête sur les mécanismes, l'évolution et les joueurs

26 septembre 2026 — travail documentaire et calculs reproductibles. Comparaison locale à `c6ab5a72c1789e4cc285300c9bbae9c78524fa05`, avec les modifications des autres tâches préservées. Aucun code du jeu changé, aucune partie WAVEN jouée par cet audit.

**Le cœur de WAVEN apparaît dans les conversions entre actions : déplacer devient frapper, soigner devient déclencher une ligne de dégâts, invoquer permet de réactiver des mécanismes, conserver de l'armure produit de l'offensive. La profondeur vient du choix des séquences et des positions qui rendent ces conversions utiles. Le risque vient de séquences répétables qui font simultanément dégâts, défense et économie.**

Ce constat repose ici sur des cartes et passifs réellement ouverts, des notes de correctifs et des descriptions de rencontres. Il dépasse l'analogie générale entre « tactique » et « deckbuilding », mais ne prétend pas fournir une base exhaustive et actuelle de toutes les cartes du jeu.

## Lire le dossier

| Document | Contenu |
|---|---|
| [Kits et combat](KITS_ET_COMBAT.md) | Huit moteurs de héros, 32 options de passifs examinées, deck de 15 sorts, cinq équipements, quatre compagnons, statistiques et calculs de séquences. |
| [Ennemis et rencontres](ENNEMIS_ET_RENCONTRES.md) | Sept ennemis étudiés, reconstruction de La Piscine, conditions de riposte, terrain et objectifs ; limites des statistiques disponibles. |
| [Évolution et joueurs](EVOLUTION_ET_JOUEURS.md) | Correctifs 2023–2025, refonte annoncée, Survie 2026, guides argumentés, témoignages contradictoires et retour d'essai. |
| [Sources et versions](SOURCES.md) | Provenance, dates, contradictions et niveau de preuve. |
| [Calculs exécutables](calculs.mjs) / [résultats](CALCULS.json) | 26 vérifications, dont une énumération des 4 368 mains d'ouverture du modèle Survie. |

## 1. Ce que cette recherche corrige

La précédente étude signalait que le corps de certaines actualités officielles était inaccessible au lecteur web. Le navigateur a permis cette fois de lire les notes complètes et l'annonce Survie 2026. Cette limite technique antérieure est donc levée pour les sources recensées ici ; les anciennes expériences Catabase restent des expériences distinctes.

Deux divergences empêchent de prendre une base de cartes au pied de la lettre : Waven Build affiche 45 % pour Pikuxala et 35 % pour Apostruker, alors que la note 0.17 donne respectivement 60 % et 50 % en PvE. Je date donc les calculs au lieu d'inventer une synthèse « actuelle ». Les icônes PvE/PvP expliquent également plusieurs textes doublés. [Ankama, 0.17](https://forum.waven-game.com/en/44-patchnotes-fr/5428-version-17-fr), [WavenDB](https://wavendb.com/gods), [Waven Build](https://www.waven-build.com/bestiaire/weapons).

Autre précision substantielle : obtenir Poussette avec Maîtrise Pikuxala dépend d'un échange de positions réussi. Un modèle qui récompense la simple tentative surestime la boucle précisément quand le plateau est encombré. [Ankama, 0.20](https://forum.waven-game.com/en/44-patchnotes-fr/6058-version-20-fr).

## 2. Les résultats chiffrés les plus utiles

| Question | Résultat | Portée de la preuve |
|---|---|---|
| Peut-on retrouver les stats d'un build ? | 2 128 PV et 203 ATK reconstruits exactement après arrondi. | Cohérence d'un constructeur et d'un montage donnés. |
| Son curseur 1 représente-t-il un débutant ? | Non : 969 PV et 80 ATK avec les 250 points et les runes conservés. | Observation directe de l'interface. |
| Combien valent deux téléportations ? | 487,2 dégâts bruts si chacune touche deux ennemis, ATK fixe 203, coefficient PvE 0.17. | Scénario géométrique ; hors bonus temporaires et protections. |
| Pourquoi un nerf d'armure peut-il être amplifié ? | Le montage conditionnel étudié passe de 720 à 420 armure, soit −41,67 %. | Hypothèse de quatre bonus additifs ; pas une mesure du DPS total. |
| Que coûte la suite des quatre compagnons ? | 23 jauges imprimées, dont 14 air. | Addition des coûts lus ; pas un calcul de tour d'invocation. |
| Quand voit-on le compagnon de Survie ? | 31,25 % dans cinq cartes parmi seize. | Tirage uniforme, sans mulligan ni tutorat. |
| Deux cartes précises dans cette ouverture ? | 8,33 %. | Vérifié par formule et énumération exhaustive. |
| Les PV supplémentaires règlent-ils Toxique ? | Trois effets à 5 % représentent toujours 15 % des PV max bruts. | Règle communautaire non datée, avant protection. |

Ces résultats ne sont pas un classement de classes. Ils identifient les variables qui doivent être mesurées avant de classer : nombre de déclenchements utiles, position, seuil de mort, ressources disponibles et temps réel.

## 3. Mon appréciation du design de WAVEN

**Sa force : faire varier le sens d'une même action.** Une téléportation peut corriger une erreur de placement, augmenter l'offensive ou redistribuer l'équipe. Une attaque de compagnon peut activer un réseau préparé. Une case change de valeur selon les ennemis et leurs conditions. Les huit kits examinés donnent des raisons différentes de regarder le même plateau.

**Sa fragilité : concentrer plusieurs rendements sur une même boucle.** Quand un geste produit simultanément dégâts, amplification et remboursement, les autres gestes doivent offrir une utilité contextuelle forte pour rester compétitifs. Ajouter des multiplicateurs à tous les niveaux peut réduire la diversité des décisions malgré un grand nombre de combinaisons théoriques.

**Son coût d'apprentissage : des états intermédiaires difficiles à prévoir.** Le succès d'un échange, le moment du soin, le mode PvE/PvP, les ressources réellement dépensées ou une différence entre attaque et dégâts peuvent renverser le résultat. Les corrections d'Ankama montrent que ces détails sont aussi des problèmes de fiabilité du moteur et d'information. [Exemples 0.19](https://forum.waven-game.com/en/44-patchnotes-fr/5880-version-19-fr), [0.20](https://forum.waven-game.com/en/44-patchnotes-fr/6058-version-20-fr).

**La refonte : un déplacement des choix à vérifier.** Le projet de 2025 retire des couches de préparation ; Survie 2026 propose de construire pendant la partie. C'est une réponse plausible à l'apprentissage, mais son succès dépend des choix qui subsistent et de leur variété au fil des vagues. Le témoignage positif d'une démonstration ne suffit pas à établir cette variété à long terme. [Développeurs](https://forum.waven-game.com/en/22-news-fr/6657-community-update-2), [Survie et discussion](https://forum.waven-game.com/en/22-news-fr/6783-ankama-convention-25-ans-waven).

## 4. Ce que je transposerais à Catabase

La [référence produit](../../current/product.md) conserve dix cartes initiales et quatre en main. Le code [CatabaseCards](../../../core/expedition/catabase_cards.gd) renvoie la carte jouée en défausse ; le [modificateur de classe](../../../core/expedition/class_card_modifier.gd) choisit le passif de spécialisation à la place du passif de classe. La [V1 consommable](../consumable_v1/REGLES_V1.md) est un autre contrat : cartes jouées détruites, cinq en main, stock à maintenir sur la run. Ces différences changent le prix d'une boucle.

| Proposition examinée dans les travaux précédents | Avis après lecture des mécanismes WAVEN | Critère de décision |
|---|---|---|
| Tir de relais / ancre de repli | À privilégier parmi les petits prototypes. | L'arrivée doit ouvrir un choix de cible ou de sécurité ; un aller-retour systématique ne doit pas tout financer. |
| Répercussion | Garder l'arbitrage défense conservée / dégâts immédiats explicite. | Afficher garde avant/après, dégâts ajoutés et menace adverse restante. Ne pas équilibrer uniquement le coefficient. |
| Maîtrises qui changent l'usage | Fort potentiel d'identité. | Comparer deux décisions réellement différentes sur trois plateaux, sans empiler automatiquement classe et spécialisation. |
| Pièce persistante / compagnon | Commencer par une seule pièce et un seul déclencheur. | Mesurer durée utile, occupation, activations et investissement perdu à la destruction. |
| Grande main générale | Aucune justification nouvelle suffisante. | Séparer présence du plan, possibilité de le payer et nombre de choix utiles. Le maximum de neuf de Survie n'est pas sa main initiale. |
| Nouvelle réserve globale de PA | À différer. | Vérifier d'abord si les outils existants offrent des séquences concurrentes ; séparer report, génération et remboursement. |
| Achats ciblés de copies dans la V1 | Restent importants pour la continuité du moteur. | Mesurer renouvellement des fonctions et variété du jeu après la halte, pas seulement quantité de butin. |

Les [expériences précédentes](../waven_investigation_2026-09-26/suite_02/README.md) restent leurs propres preuves. Aucune nouvelle série de victoires de bot n'est présentée comme un résultat WAVEN ou comme la validation des propositions ci-dessus.

### Trois idées nouvelles, à tester séparément

**1. Un ennemi de soutien dont la condition est spatiale.** Il protège un allié désigné s'il commence son activation sans héros proche. L'interface annonce le bénéficiaire et la condition. La décision devient frapper, approcher ou déplacer la cible. Prototype utile pour tester si notre mobilité économise des ressources sans ajouter un passif de dégâts gratuit.

**2. Une riposte à charges visibles.** Un ennemi possède deux charges consommées par des actions offensives explicitement définies. Le joueur peut subir le coût, concentrer ses actions, neutraliser l'ennemi ou détourner la riposte par un outil existant. C'est une proposition inspirée de la structure de Kralamar, pas une reprise de ses chiffres. Il faut une réponse accessible à chaque classe et éviter une taxe inévitable sur tout jeu de cartes.

**3. Une maîtrise de déplacement qui rémunère un changement de plan.** Une fois par tour, une arrivée valide ouvre un tir ou une protection conditionnelle ; revenir sur sa case initiale ne multiplie pas les récompenses. Ce prototype remplacerait un bonus, sans s'ajouter gratuitement aux passifs existants. Son intérêt se juge à la diversité des cases d'arrivée et aux cartes économisées, avec un cas encombré et un cas où rester immobile est meilleur.

Ces trois propositions partagent un objectif : augmenter la valeur du plateau et la variété des réponses, avec peu de nouvelles règles. Leurs coefficients restent à choisir ; aucune n'est implémentée ni déclarée équilibrée dans ce dossier.

## 5. Validation et limites

Commande exécutée depuis la racine :

```powershell
node docs/design/waven_coeur_du_jeu_2026-09-26/calculs.mjs
```

Résultat : **26 assertions passées**, 4 368 mains énumérées. Le script enregistre les hypothèses avec chaque résultat. Il contrôle arithmétique et combinatoire, pas la conformité au moteur WAVEN. Le dossier contient un `.gdignore` pour éviter l'import de ses sorties par Godot.

Les inconnues restantes sont concrètes : courbes exactes de statistiques ennemies par niveau, détail complet des nouveaux kits Survie, arrondis et ordre des déclenchements en client, temps de combat et progression réellement observée. Elles sont recensées dans [SOURCES.md](SOURCES.md). Aucun taux de rétention, temps de farm ou taux de victoire global n'a été inventé à partir des discussions.
