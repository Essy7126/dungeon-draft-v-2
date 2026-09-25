# Ce que les personnages WAKFU apportent à notre audit

Références locales : [règles consommables V1](../consumable_v1/REGLES_V1.md), [48 familles de cartes](../consumable_v1/content.mjs), [catalogue Godot de classe](../../../core/expedition/class_card_catalog.gd), [dispositifs de salle](../../../core/expedition/card_tactical_room_catalog.gd), [comparaison StS](../slay_the_spire_complete_2026-09-25/APPLICATION_CATABASE.md). La base examinée est `24053adbb4a41f9442f14a6c23ca721b8c413c8b` ; les catalogues et règles de salle cités n'ont pas changé depuis la référence initiale `6a500c5`. La V1 théorique n'est pas présentée comme déjà intégrée à Godot.

## Le manque central : le build doit modifier la décision

La V1 contient déjà marque, garde, surfaces, déplacement, équipements et reliques. Le problème n'est pas une absence de mécanique. Le comptage de l'étude StS montre que **33 des 48 améliorations de famille ne changent que les dégâts**. On peut donc améliorer la spécialisation sans agrandir immédiatement le catalogue : faire varier l'accès, l'échéance ou ce qu'un effet consomme.

| Famille de transformation observée | Exemple WAKFU | Décision nouvelle | Transposition à éprouver |
|---|---|---|---|
| Moment contre fréquence | Maître des boucliers | Répondre maintenant ou garder une meilleure cadence | Une protection immédiate plus limitée que sa variante préparée. |
| Réserve contre action | Tacticien | Dépenser de la maturation pour agir davantage | Consommer une charge de dispositif pour financer une commande, avec plafond porté par le héros. |
| Territoire contre survie | Protection minérale | Détruire un emplacement utile pour tenir le tour | Convertir une surface ou charge locale en garde, avec disparition avant le gain. |
| Angle contre rendement | Virevolte ; Marcher droit | Chercher une position précise plutôt que subir un malus | Changer une contrainte de visée sans rendre simultanément toutes les cibles légales. |
| Investissement contre souplesse | Terrain fertile ; Croissance accélérée | Rester près du centre ou perdre la croissance | Déplacer une installation en abandonnant ses charges. |
| Victime contre relais | Assaut létal | Utiliser une mort pour préparer une autre cible | Transférer une marque existante plutôt que dupliquer sa valeur. |
| Action contre soin | Médecin sans barrière | Préparer le soutien pendant l'attaque | Un état de famille persistant entre deux cartes consommées, à usage borné. |
| Statistique contre spécialisation | Échange asynchrone | Réutiliser un investissement sous une autre contrainte | Conversion plafonnée d'une statistique, explicitement non additive. |

Ces propositions ne sont pas huit nouveaux systèmes adoptés. Elles forment une grille pour remplacer des améliorations redondantes. Les six prototypes définis dans le dossier StS suffisent pour un premier essai ; la présente lecture affine leurs coûts et leurs cas limites.

## Priorités par classe

**Assassin : conserver un plan entre deux exemplaires.** La préparation doit appartenir à la cible ou au héros, jamais à une carte disparue. Un transfert de marque donne une décision de victime sans multiplier les marques. Tester mort de la source, destination illégale, dernière cible vivante et exécution par un dommage indirect.

**Gardien : décider combien engager.** La garde existe déjà et possède un plafond ainsi qu'une expiration. Reprendre le choix de sacrifice de Répercussion plutôt qu'ajouter une seconde réserve défensive. Un gain conditionné à un seuil doit compter un franchissement, pas chaque lecture de PV sous ce seuil.

**Arpenteur : transformer la position en possibilité d'action.** La portée minimale, les couloirs et les obstacles doivent changer la meilleure réponse. Une amélioration peut autoriser une cible plus proche ou remplacer une contrainte de ligne de vue par un alignement. Un +PA gratuit attaché à chaque case parcourue supprimerait le coût recherché ; fixer événement et plafond avant le coefficient.

**Thaumaturge : arbitrer maintien et conversion d'une surface.** Brûlure et terrain peuvent préparer un tour suivant, défendre ou déplacer une menace. Chaque conversion doit retirer la ressource source avant de produire la suivante. Le niveau d'une bombe Roublard illustre le coût d'opportunité ; il ne justifie pas de copier toutes les bombes, murs et modes.

## Garder notre économie de cartes

Le joueur part avec environ quinze normales, prépare au plus trente copies et se ravitaille par les sacs de monstres. Les évolutions de drop restent celles du [laboratoire économique](../card_economy_lab/README.md) et du [contrat V1](../consumable_v1/REGLES_V1.md). Aucun bonus de prospection, de maîtrise ou de relique supplémentaire n'est ajouté implicitement par cette étude.

Pour qu'un moteur de build survive à la consommation, mesurer son **accès fonctionnel** : préparation, convertisseur, sortie défensive et déplacement. Un sac rempli de normales peut être abondant en quantité mais manquer systématiquement de la fonction requise. C'est une métrique à ajouter aux distributions de rareté ; ce n'est pas une raison de remplacer le drop par une sélection automatique de techniques ennemies.

Les fonctions indispensables doivent avoir une version normale. Une rare peut transformer le moment ou la portée de leur conversion. Une légendaire ne doit pas être nécessaire pour que la classe trouve une action satisfaisante pendant les premiers combats. Les améliorations de famille, équipements et reliques maintiennent l'identité malgré la disparition des exemplaires.

Une mort admissible pour une ressource de classe ne l'est pas nécessairement pour le butin. Assimilation rend cela particulièrement clair. Pour Catabase, les ennemis initiaux éligibles restent les seules racines de drop définies par la V1 ; copies, réanimations et invocations ne doivent pas réinitialiser cette éligibilité. Un remboursement de PA ne restitue pas une carte consommée.

## Protocole d'intégration concret

1. Choisir une seule famille existante par classe ; conserver son coût de copie et sa rareté pendant le premier essai.
2. Comparer son amélioration actuelle à une transformation de règle, sur les mêmes graines, stocks et positions.
3. Mesurer : première action utile, tours nécessaires à la préparation, copies dépensées, ressource perdue par plafond, dommage évité réel, actions illégales tentées et dépendance aux rares.
4. Ajouter un adversaire qui perturbe le moteur par position ou timing ; laisser une sortie de secours. Éviter l'immunité totale qui supprime l'essai.
5. Vérifier les compositions : un remboursement par événement/racine, expiration avant déclenchement, morts simultanées, annulation de ciblage, reprise de sauvegarde et inventaire plein après butin.
6. Observer des joueurs avant de conclure sur le plaisir. Demander quel plan ils voyaient, pourquoi ils ont conservé ou consommé une carte, et ce que l'interface leur a réellement permis de prévoir.

Les calculs W01–W15 montrent des enjeux locaux. Ils ne constituent pas ces essais de gameplay. La prochaine modification de moteur devra avoir ses tests de règles, ses scénarios Godot et une observation de combat ; aucun de ces résultats n'est anticipé dans cette livraison.
