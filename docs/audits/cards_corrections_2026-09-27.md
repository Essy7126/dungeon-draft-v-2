# Corrections du réaudit Cartes

Les quatre défauts du [réaudit](cards_reaudit_2026-09-27.md) sont corrigés dans la Battle de la run existante. Les décors, le déploiement, la grille, la file de tours, les mouvements et les fenêtres de Catabase restent ceux du parcours public. Aucune aventure parallèle n'est ajoutée.

## Corrections

| Défaut | Comportement ajouté ou corrigé |
|---|---|
| Mécanismes absents | `consumable_room_rules.gd` est installé par l'adaptateur de la vraie Battle. Presse, sablier, jardin, convoi et réservoirs sont actifs dans les six rencontres prévues. Commandes dans la main ; intentions et mécanismes projetés sur les polygones de la grille actuelle. |
| Formation sans porteur au combat 7 | Attribution explicite d'un porteur par identité tactique, archétype puis emplacement stable. Les variantes de soutien, parade et exécution utilisent aussi ce raccordement. La protection de formation est de 14 points à P=57 ; elle disparaît à l'activation suivante si le héros est adjacent. |
| Pression absorbée par la garde | Seul le contexte de pression du profil Cartes contourne l'absorption dans `Unit`. Les événements de dégâts, la mort et la résolution de Battle restent communs. À 110 PV maximum, après le tour 9 : 3 PV perdus et les 18 points de garde conservés. Résistance et Édit ne l'annulent pas. |
| Pâris reste en phase 1 après brûlure | Actualisation sur les pertes de PV et avant la décision ennemie. À 340/724 PV, la phase est 2 ; une intention déjà annoncée reste à résoudre. Ni soin ni second pool de PV n'est introduit. |

Les contrôles occupent des cases de sol reliées dans les cartes actuelles : les coordonnées 1/3/5 des petites grilles de référence deviennent trois rails distribués sur la hauteur réelle. Les repères A/B des réservoirs n'impliquent pas une orientation visuelle fixe. Les commandes exigent la proximité et leurs PA ; une seule est permise par tour. La hauteur du HUD suit le contenu, notamment l'alerte de pression et les commandes.

Le jardin et la décharge des réservoirs suivent le premier ennemi vivant par ordre de spawn, y compris après mort et reprise. Les deux porteurs du convoi respectent Stase et les coûts de déplacement natifs. Leurs sacrifices sont enregistrés avant la mort : chacun donne au chef `arrondi(0,8 P)` PV maximum/actuels et `arrondi(0,02 PVbase)` ATK, sans verser son butin. Pour P=68 et PVbase=420, deux livraisons donnent **+108 PV maximum et +16 ATK**. Recharger ne réapplique pas ces bonus sur des statistiques déjà augmentées.

## Reprise et contrôles

Le checkpoint intégré passe en version 2 et conserve état de salle, dettes du sablier, réserves, commande déjà payée, sacrifices et éligibilité du butin. La version 1 intégrée reste acceptée : le mécanisme s'initialise à la décision reprise, sans changer main, copies consommées, garde ou PA. La validation des versions accepte les entiers représentés comme flottants par JSON. Un checkpoint malformé est rejeté avant le remplacement de la session ; une erreur d'écriture bloque les intentions jusqu'à une nouvelle tentative réussie.

Les fixtures montent les scènes `RegisteredTerrainBattle.tscn`. Elles accélèrent la progression entre les rencontres et imposent certains placements pour tester les règles ; elles ne constituent pas des parties gagnées ni une mesure d'équilibrage.

## Résultats vérifiés

Référence Git au début et à la fin de l'implémentation : `c6ab5a72c1789e4cc285300c9bbae9c78524fa05`. Le répertoire contient des travaux concurrents ; les résultats ci-dessous portent sur cet état local, sans commit ni publication.

| Contrôle | Résultat et preuve |
|---|---|
| Suite Cartes intermédiaire | **201 tests / 16 195 assertions réussis**, sans erreur moteur : `artifacts/dev/20260927-141028-test-cards-5976198c/summary.json`. Les contrôles ci-dessous couvrent les derniers ajustements. |
| Scénarios intégrés finaux | **8 tests / 785 assertions réussis** dans le JUnit global : six commandes de salle, effets réels, reprise JSON, rejet atomique d'une sauvegarde invalide, retry d'écriture, convoi/Stase/butin, cible survivante, formation et phase du boss. |
| Réaudit des vraies scènes | **12 rencontres contrôlées dans chacune des deux résolutions**, zéro défaut signalé, zéro erreur moteur. Sept captures par résolution ; commandes et garde de secours lisibles, PA du réservoir cohérents. `artifacts/dev/20260927-191415-cards-corrections-final-checks-1dd8205e/report.json` et sous-dossiers `1280x720/`, `1600x900/`. |
| Ressources et outillage | Sept tests Python de l'audit de contenu réussis. **12 368 fichiers, zéro référence externe manquante** dans `artifacts/dev/cards-corrections-gates-20260927/resources-final.json`. Contrôle du diff et versions produit/plugin réussis. |
| Suite globale stricte | **ÉCHEC** : 3 224 tests, 3 045 réussis, 171 échoués, 8 pending/risky ; 266 872 assertions réussies sur 267 629. Les 166 échecs de référence persistent ; cinq identités supplémentaires sont détaillées ci-dessous. Le processus crashe à la fermeture (`-1073741819`), comme la référence. `artifacts/dev/20260927-144950-cards-corrections-all-4a582337/summary.json` et `gut.junit.xml`. |
| Contrats Studio | 522 tests du manifeste exact exécutés dans la suite globale, 30 échecs, contre 28 dans la référence. `artifacts/dev/cards-corrections-gates-20260927/studio-subset.json`. |
| Smokes partagés | Rencontre réussit. Objets échoue sur une conversion en `Dictionary`. Terrain headless ne fournit pas d'image de viewport ; le secours GL produit les captures mais garde des fuites à la fermeture. Ces deux smokes restent en échec strict, comme lors du réaudit préalable. Rapport dans le dossier des captures finales. |

La comparaison détaillée est conservée dans `artifacts/dev/cards-corrections-gates-20260927/global-comparison.json`. Le sous-ensemble Cartes du global comprend **231 tests**, avec deux échecs provenant des nouvelles fixtures Orage : le héros était déplacé vers la case encore occupée par sa cible, et le test du routeur ne liait pas de session Catabase. Les fixtures sont corrigées sans changer les dégâts ni élargir le domaine du routeur VFX. **La relance Orage réussit : 20 tests, 437 assertions, zéro erreur moteur**, rapport `artifacts/dev/20260927-193131-cf-4a492da0/summary.json`. Le global n'est pas présenté rétroactivement comme réussi après cette relance.

Les trois autres écarts ont été examinés séparément :

- **Studio Rencontre** : le test de nettoyage de transaction réussit avec un chemin court (7 assertions), alors que le passage global laisse des manifestes à 269 caractères. Cela étaye un problème de longueur de chemin Windows, sans constituer une validation de tout le Studio. Sa suite ciblée reste rouge : 15 tests réussis sur 32, avec des erreurs de récupération/persistence. Preuve : `artifacts/dev/20260927-193225-cf-deae9f43/gut.junit.xml`.
- **Studio Terrain** : la récupération UI supplémentaire réussit isolément avec un chemin court, **1 test / 31 assertions**, sortie 0 et zéro erreur moteur. Preuve : `artifacts/dev/20260927-193358-ci-c638d5a9/gut.junit.xml`. Les fichiers Studio concernés sont inchangés par cette correction ; la réussite isolée ne supprime pas l'échec constaté dans le global.
- **Déplacement** : les assertions arrivaient avant la fin de l'animation, parce que le timer GUT et la présentation utilisent des horloges différentes. Les trois attentes concernées observent désormais la fin effective avec une limite de deux ou trois secondes. Aucun déplacement de production ni assertion n'est modifié. **17 tests / 101 assertions réussissent**, mais la suite reste en échec strict pour 14 ressources non libérées à la fermeture. Preuve : `artifacts/dev/20260927-193756-cf-movement-39e1d53d/summary.json`.

La gate CI d'allowlist reste **rouge** : elle attend huit échecs, le dépôt en présente davantage et le marqueur de sortie manque après le crash. La gate de portabilité détecte **17 chemins de machine préexistants** dans `vfx/class_cards/cel/art/provenance.json`, identique à HEAD. Aucun seuil ni allowlist n'est assoupli. Les empreintes avant/après la suite sont conservées ; elles montrent notamment deux fichiers générés suivis sous `artifacts/arena_studio/arena_studio_test/` et des modifications concurrentes. Ce passage ne certifie donc pas non plus un worktree inchangé.

Ces validations confirment les comportements corrigés dans les scènes publiques. Elles ne constituent pas un feu vert de la CI complète ni une mesure d'équilibrage des parties.

## Limites de portée

Les valeurs des archétypes et les différences de roster mesurées dans le réaudit ne sont pas rééquilibrées par cette correction. Les variantes obligatoires sont désormais garanties, même si le nom du monstre ne correspond pas à l'archétype du catalogue. L'équilibrage des quatre classes, de toutes les routes et des nouveaux VFX demande encore des parties et des observations dédiées. Les travaux concurrents sur sprites, effets, Studio et haltes sont conservés.
