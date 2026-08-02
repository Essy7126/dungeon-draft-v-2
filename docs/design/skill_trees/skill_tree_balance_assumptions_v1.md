# Hypothèses d’équilibrage V1 des arbres de compétences

Date de référence : 2026-08-02  
Sources : `res://asset/ui/dungeon_draft/arbre_compétences/preview.html` et `res://docs/audits/skill_trees_preview_gap_audit.md`.

Ce document ne remplace pas la preview. Il consigne seulement les décisions nécessaires lorsque la preview ne fixe pas une valeur ou une règle de résolution. Les noms, descriptions et valeurs explicitement présents dans la preview sont sérialisés tels quels dans les ressources d’arbres.

## Hypothèses et conventions

| Personnage | Arbre / nœud | Information absente ou ambiguë | Valeur ou règle V1 retenue | Justification | Alternative | Risque |
|---|---|---|---|---|---|---|
| Elfe | Mage / racine Boule de feu | Toutes les valeurs de base sont « à normaliser ». | Conservation provisoire du sort actif : coût par défaut 1 PA, portée 14, croix de rayon 2, 400 dégâts, lave de 3 tours infligeant 15 dégâts à l’entrée. | Priorité 2 : mêmes sort et systèmes, aucune énergie. Aucun chiffre de remplacement n’existe dans la preview. | Rebaser le sort sur une échelle commune aux trois héros lors d’une passe d’équilibrage. | Critique : les 400 dégâts rendent les bonus plats peu significatifs. |
| Mage | Pyromancie / racine Boule de feu | Toutes les valeurs de base sont « à normaliser ». | Conservation provisoire du sort actif avec les mêmes valeurs que la Boule de feu de l’Elfe. | Priorité 2 et maintien du gameplay existant. | Créer deux bases chiffrées distinctes après arbitrage design. | Critique : les deux sorts restent mécaniquement très proches. |
| Mage | Cryomancie / racine Mur de glace | Forme, longueur et durée de la zone de base non précisées. | Conservation de la croix de rayon 3 et de la durée 3 de la ressource `glace`; portée 6 et aucun dégât direct conformément à la preview. | Priorité 2 : le sort existant exprime déjà la création de glace. | Mur linéaire orienté, si la direction artistique le confirme. | Élevé : « mur » peut impliquer une forme différente. |
| Tous | Statuts périodiques | Règle de cumul et de rafraîchissement non définie. | Un même `status_id` ne s’empile pas ; la durée la plus longue et la version la plus forte gagnent, puis une nouvelle application rafraîchit le statut. | Réutilise le contrat de `Unit.apply_status` et évite les cumuls non bornés. | Additionner les charges ou les dégâts. | Moyen. |
| Elfe / Guerrier | Soigneur et Rempart / boucliers | Cumul ou remplacement non défini. | Les bonus du même cast sont additionnés avant application ; le bouclier final remplace seulement un bouclier existant plus faible. | Réutilise le contrat global actuel des boucliers. | Boucliers cumulables ou durée limitée. | Moyen. |
| Elfe | Soigneur / Floraison | Arrondi de 50 % non défini. | Arrondi inférieur (`floor`) du soin réel reçu par la cible principale, après plafond de PV. | Conservateur et impossible à exploiter par sursoin. | Arrondi au plus proche ou calcul sur le soin théorique. | Faible. |
| Elfe / Guerrier | Assassin et Brutalité / Coup fatal | « Le seuil passe à 50 % » ne précise pas le comportement sous l’ancien seuil de 40 %. | Le seuil est remplacé : le bonus reste +4 sous 50 % et ne se double pas sous 40 %. | Respecte le verbe « passe » et évite un bonus caché. | Cumuler les deux bonus sous 40 %. | Faible. |
| Mage | Foudromancie / Arc secondaire et Orage conducteur | Aucun ordre de sélection de la cible adjacente n’est donné. | Le premier ennemi adjacent à la cible dans l’ordre Nord, Est, Sud, Ouest reçoit 3 dégâts de foudre magiques. L’arc consomme la même charge que le bonus principal. | Résolution déterministe, data-driven et indépendante de l’interface. | Choix manuel, cible aux PV les plus faibles ou aléatoire. | Moyen. |
| Guerrier | Assaut / Charge et Intercepteur | Trajet, traversée d’unités et case d’arrivée non détaillés. | Ciblage cardinal avec ligne de vue existante ; contre une unité, arrivée sur la case libre immédiatement devant elle ; vers une case libre, arrivée sur cette case. Aucun franchissement d’obstacle. | Réutilise la grille et le ciblage existants sans second moteur de déplacement. | Parcours case par case avec interruptions et réactions. | Moyen. |
| Tous | Terrain | Rafraîchissement d’un terrain identique déjà présent non défini. | Les deltas d’arbre s’appliquent à la nouvelle pose. Une pose ultérieure sur un terrain identique suit le contrat actuel de `TerrainEffects` et ne le remplace pas. | Aucun changement global de gameplay hors arbres. | Rafraîchir systématiquement la durée. | Moyen. |
| Tous | Iconographie des nœuds sans asset dédié | La preview indique une sémantique visuelle mais pas un fichier d’asset par nœud. | Réemploi du catalogue actuel : dégâts, portée, poussée, collision, mouvement, statut, terrain, soin et défense. Les racines réutilisent les icônes de sorts. | Respecte la direction artistique existante et évite 216 assets fictifs. | Production d’icônes dédiées lors d’une passe artistique. | Faible, visuel uniquement. |
| Guerrier | Quatre racines | Aucun nouveau set d’animations ou d’icônes n’est fourni. | Réemploi des quatre animations et icônes Guerrier existantes les plus proches, remappées aux nouveaux `spell_id`. | Les mécaniques et identifiants restent indépendants des assets. | Produire quatre animations et quatre icônes dédiées. | Moyen, visuel uniquement. |

## Conventions mécaniques communes

- Les bonus formulés avec « + » sont additifs le long d’un chemin valide.
- Les formulations « passe à » utilisent une valeur finale ou un delta calculé pour atteindre cette valeur, sans double application cachée.
- Les vulnérabilités et ordres d’attaque sont des statuts à charges ; une attaque esquivée ne consomme pas la charge.
- Les effets de zone sont résolus avant les dégâts, statuts et terrains afin que tous les modificateurs lisent la même liste de cellules.
- Les deltas de terrain sont appliqués à une copie runtime de `TerrainEffectData`; la ressource partagée reste immuable.
- Les choix de R2 à R5 restent définitifs pendant une run. La reconstruction depuis snapshot rejoue les choix dans l’ordre des rangs.
- Aucun nœud n’utilise un modificateur de coût en PA, une attraction ou un critique : ces effets ne figurent dans aucun choix de la preview. Les coûts des douze racines sont testés dans le pipeline existant.

## Arbitrages encore attendus

Avant une passe d’équilibrage finale, le design doit fixer en priorité les deux Boules de feu, puis la forme exacte du Mur de glace. Les autres hypothèses concernent surtout des conventions de cumul, d’arrondi ou de sélection déterministe et ne bloquent pas l’utilisation des arbres.
