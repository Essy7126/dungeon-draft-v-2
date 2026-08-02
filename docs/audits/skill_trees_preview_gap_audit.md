# Audit des arbres de compétences par rapport à la preview

Date : 2026-08-02

HEAD audité : `309a6cda9e00e8db0327ea3188d64a937a9b4673`

Branche : `refactor/project-clean-slate`

Périmètre : lecture seule du gameplay ; seuls ce rapport et son manifeste JSON sont produits.

## Verdict exécutif

`SKILL_TREES_BLOCKED_BY_PREVIEW_GAPS`

Le dépôt n'est pas prêt pour une migration fidèle des douze arbres.

- Le chemin demandé, `res://docs/design/reference/skill_tree_preview.html`, n'existe ni dans le worktree ni dans l'historique Git accessible.
- Une preview candidate suivie par Git existe à l'ancien emplacement `res://asset/ui/dungeon_draft/arbre_compétences/preview.html`. Elle a été analysée afin de ne pas perdre l'information disponible, mais rien ne prouve qu'elle est identique à la référence demandée.
- Cette candidate définit bien 12 arbres, 5 rangs, 18 choix et 16 configurations finales par arbre, soit 216 choix et 228 nœuds en comptant les 12 bases R1.
- Elle affirme que ses identifiants sont stables et « repris dans le fichier JSON joint », mais ce JSON joint est absent. Le seul mapping présent, `res://docs/reference/skill_tree_node_icon_mapping.json`, ne couvre que 24 choix de l'Elfe et utilise une autre famille d'identifiants.
- Elle ne définit aucune icône, aucun asset de nœud, aucun état acquis/disponible/verrouillé/exclu, ni interaction clavier/souris/manette.
- Les valeurs de base des deux Boules de feu sont explicitement « à normaliser avant équilibrage final ».
- Le dépôt ne contient que 11 disciplines pour 12 sorts. Le Guerrier a 4 sorts mais 3 `discipline_id`; Marque de guerre et Exécution de guerre partagent `warrior_executioner`.
- Un arbre actuel est invalide : `warrior_breaker_driving_shove` exclut le nœud inexistant `warrior_breaker_long_hook`. `SkillTreeResolver` refuse donc tout choix de cette discipline avec `INVALID_TREE_DATA`.
- Les quatre arbres Guerrier de la preview — Brutalité/Frappe lourde, Assaut/Charge, Furie/Tourbillon et Rempart/Garde — sont absents. Les trois arbres présents sont des données d'un kit antérieur.
- La suite ciblée de progression exécute 166 tests : 165 passent et 1 échoue. L'échec est le contrat de nettoyage qui attend l'absence de `Gardien.tres`, toujours présent.

## Référence et méthode

### Disponibilité de la référence

| Élément | Résultat |
|---|---|
| Chemin demandé | `res://docs/design/reference/skill_tree_preview.html` — absent |
| Recherche worktree | aucun fichier à ce chemin |
| Recherche `HEAD`, refs et objets Git | aucun objet à ce chemin |
| Candidate trouvée | `res://asset/ui/dungeon_draft/arbre_compétences/preview.html`, 97 314 octets |
| JSON annoncé par la candidate | absent |
| Mapping JSON réellement présent | `res://docs/reference/skill_tree_node_icon_mapping.json`, partiel et non isomorphe |

Toute mention « preview » ci-dessous désigne la candidate. Le décalage de chemin reste un blocage et aucune équivalence n'est supposée.

### Règles globales extraites de la preview candidate

- Un lancement réussi rapporte 1 XP à la discipline du sort.
- R1 : 0 XP, sort de base.
- R2 : 3 XP, choix définitif de la branche principale A ou B.
- R3 : 7 XP, choix d'une des deux sous-spécialisations de la branche retenue.
- R4 : 12 XP, choix d'un des deux perfectionnements sous la sous-spécialisation retenue.
- R5 : 18 XP, choix d'un des deux capstones de la branche principale.
- Un seul nœud est choisi par rang.
- Chaque discipline possède 16 configurations finales : `2 × 2 × 2 × 2`.
- Les valeurs sont qualifiées de « prototype à tester en jeu ».

### Prérequis et exclusions déduits sans invention

La preview ne contient pas de champs `prerequisite_node_ids` ou `excluded_node_ids`. Sa hiérarchie visuelle et sa légende définissent toutefois les relations suivantes :

- un R3 requiert le R2 de la même branche ;
- un R4 requiert le R3 sous lequel il est placé ;
- un R5 requiert la branche R2 correspondante et la résolution préalable du R4 ;
- les deux R2 sont mutuellement exclus définitivement ;
- les candidats concurrents d'un même rang sont exclus par la règle « un seul nœud par rang ».

Aucune autre exclusion ou dépendance n'est définie. Le rapport n'en invente pas.

## Matrice de conformité des douze arbres

Dans « preview complète », « mécanique » porte sur la structure de l'arbre. Toutes les previews restent visuellement incomplètes faute d'assets et d'états. « Modificateurs fonctionnels » distingue le moteur générique des effets réellement présents et testés pour l'arbre.

| Personnage | Sort | Discipline preview | Preview complète ? | Données présentes ? | UI présente ? | Modificateurs fonctionnels ? | Classification | Écarts principaux | Travail nécessaire | Risque |
|---|---|---|---|---|---|---|---|---|---|---|
| Elfe (`elf`) | Tir précis (`elf_precise_shot`) | Archer | Mécanique oui; visuel non | Oui, R1–R5, 18 choix | Oui | Oui, 18 choix testés | PARTIEL | IDs preview/runtime différents; aucun asset dans la preview; UI non identique | Décider l'autorité des IDs, ajouter le contrat visuel et les tests UI | Moyen |
| Elfe (`elf`) | Frappe sournoise (`elf_sneak_strike`) | Assassin | Mécanique oui; visuel non | R1–R2 seulement, 2/18 choix | Oui | Oui pour les 2 choix actuels | PARTIEL | R3–R5 et 16 choix absents; IDs différents | Créer 16 choix et leurs effets, rangs R3–R5, assets et tests | Élevé |
| Elfe (`elf`) | Boule de feu (`elf_fireball`) | Mage | Non : base à normaliser; visuel absent | R1–R2 seulement, 2/18 choix | Oui | Oui pour les 2 choix actuels | AMBIGU DANS LA PREVIEW | Base preview non chiffrée; 16 choix absents; « Braises persistantes » ne décrit pas exactement le même effet | Fixer la base et les règles de terrain, puis compléter R3–R5 | Critique |
| Elfe (`elf`) | Soin sylvestre (`elf_sylvan_heal`) | Soigneur | Mécanique oui; visuel non | R1–R2 seulement, 2/18 choix | Oui | Oui pour les 2 choix actuels | PARTIEL | R3–R5 et 16 choix absents; règles de cumul/remplacement non définies dans la preview | Compléter les choix et formaliser bouclier, régénération, purge | Élevé |
| Mage (`mage`) | Boule de feu (`mage_fireball`) | Pyromancie | Non : base à normaliser; visuel absent | R1 seulement, 0/18 choix | Racine seulement | Sans objet : aucun choix | AMBIGU DANS LA PREVIEW | Base non chiffrée; valeur dépôt 400 non vérifiable; tous les choix absents | Normaliser la base, créer R2–R5 et 18 effets | Critique |
| Mage (`mage`) | Mur de glace (`mage_ice_wall`) | Cryomancie | Mécanique oui; visuel non | R1 seulement, 0/18 choix | Racine seulement | Sans objet : aucun choix | PARTIEL | Tous les choix absents; timings de glace/bouclier non spécifiés | Créer R2–R5, effets et conventions de durée/cumul | Élevé |
| Mage (`mage`) | Tempête orageuse (`mage_thunderstorm`) | Foudromancie | Mécanique oui; visuel non | R1 seulement, 0/18 choix | Racine seulement | Sans objet : aucun choix | PARTIEL | Base correspond; 18 choix absents | Créer R2–R5, statuts, arcs secondaires et tests | Élevé |
| Mage (`mage`) | Onde sismique (`mage_seismic_wave`) | Géomancie | Mécanique oui; visuel non | R1 seulement, 0/18 choix | Racine seulement | Sans objet : aucun choix | PARTIEL | Base correspond; 18 choix absents | Créer R2–R5, vulnérabilité, poussée/collision et tests | Élevé |
| Guerrier (`warrior`) | Frappe lourde | Brutalité | Mécanique oui; visuel non | Non | Non | Non | ABSENT | Dépôt équipé de Bourrade; arbre Briseur obsolète et invalide | Créer sort, discipline R1–R5, 18 choix, effets, icônes et tests | Critique |
| Guerrier (`warrior`) | Charge | Assaut | Mécanique oui; visuel non | Non | Non | Non | ABSENT | Aucun sort ni discipline correspondant | Créer sort, discipline R1–R5, déplacement ciblé, 18 choix et tests | Critique |
| Guerrier (`warrior`) | Tourbillon | Furie | Mécanique oui; visuel non | Non | Non | Non | ABSENT | Dépôt équipé de Piétinement; arbre Saccageur obsolète | Créer sort, discipline R1–R5, zone adjacente, 18 choix et tests | Critique |
| Guerrier (`warrior`) | Garde | Rempart | Mécanique oui; visuel non | Non | Non | Non | ABSENT | Marque et Exécution partagent un arbre Bourreau sans rapport | Créer sort, discipline R1–R5, bouclier/purge, 18 choix et tests | Critique |

Résumé : 0 conforme, 6 partiels, 2 ambigus dans la preview, 4 absents. Les données Guerrier actuelles sont en outre obsolètes par rapport à la candidate.

## Extraction exhaustive de la preview candidate

Format des tableaux : `Rang / XP / identifiant preview / libellé / description`. Les identifiants sont retranscrits tels quels, y compris `cur_...` dans plusieurs IDs. Les colonnes d'icône et d'état ne sont pas répétées sur chaque ligne : elles sont absentes pour tous les nœuds.

### Iconographie, assets et états visuels définis par la preview

- Icônes de personnages, sorts, disciplines ou nœuds : absentes.
- Chemins d'assets : absents.
- États acquis, disponible, verrouillé, exclu, survol, focus ou sélection : absents.
- Interactions clavier, souris ou manette : absentes.
- Détail séparé du nœud : absent; libellé et description sont affichés directement dans chaque carte.
- Couleurs de rang : R1 `#45a7ff`, R2 `#83d94c`, R3 `#a76bf3`, R4 `#f0ad2f`, R5 `#ef4f42`.
- Couleurs personnages : Elfe accent `#7ddc65`, Mage `#66c7ff`, Guerrier `#ff835d`.
- Layout : deux branches à partir de 1201 px, une colonne jusqu'à 1200 px; grilles R3/R4/R5 en une colonne jusqu'à 760 px.

### Elfe — Archer — Tir précis

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `elfe.archer.r1.base` | Tir précis | 2 PA · Portée 7 · 7 dégâts physiques · Cible unique. |
| 2 | 3 | `elfe.archer.r2.a.il_daigle` | Œil d’aigle | +3 dégâts si la cible se trouve à au moins 4 cases. |
| 3 | 7 | `elfe.archer.r3.a.longue_portee` | Longue portée | +2 portée. |
| 4 | 12 | `elfe.archer.r4.a.longue_portee.vue_parfaite` | Vue parfaite | +3 dégâts supplémentaires à partir de 6 cases. |
| 4 | 12 | `elfe.archer.r4.a.longue_portee.stabilisation` | Stabilisation | +2 dégâts sans condition. |
| 3 | 7 | `elfe.archer.r3.a.tir_perforant` | Tir perforant | La cible subit +2 dégâts physiques sur la prochaine attaque reçue. |
| 4 | 12 | `elfe.archer.r4.a.tir_perforant.pointe_barbelee` | Pointe barbelée | Applique Saignement : 2 dégâts pendant 2 tours. |
| 4 | 12 | `elfe.archer.r4.a.tir_perforant.breche_ouverte` | Brèche ouverte | Le bonus de vulnérabilité s’applique aux 2 prochaines attaques physiques. |
| 5 | 18 | `elfe.archer.r5.a.tir_parfait` | Tir parfait | +6 dégâts à partir de 6 cases et +1 portée. |
| 5 | 18 | `elfe.archer.r5.a.trait_transpercant` | Trait transperçant | Le projectile touche aussi le premier ennemi aligné derrière la cible pour 50 % des dégâts. |
| 2 | 3 | `elfe.archer.r2.b.fleche_de_recul` | Flèche de recul | Repousse la cible de 1 case. |
| 3 | 7 | `elfe.archer.r3.b.fleche_entravante` | Flèche entravante | La cible perd 1 PM pendant son prochain tour. |
| 4 | 12 | `elfe.archer.r4.b.fleche_entravante.fleche_clouante` | Flèche clouante | La perte passe à −2 PM pour le prochain tour. |
| 4 | 12 | `elfe.archer.r4.b.fleche_entravante.recul_tactique` | Recul tactique | Après un tir réussi, l’Elfe gagne 1 PM à son prochain tour. |
| 3 | 7 | `elfe.archer.r3.b.trait_dimpact` | Trait d’impact | Une collision inflige 4 dégâts supplémentaires. |
| 4 | 12 | `elfe.archer.r4.b.trait_dimpact.trait_de_siege` | Trait de siège | +1 case de poussée. |
| 4 | 12 | `elfe.archer.r4.b.trait_dimpact.fracas` | Fracas | +4 dégâts de collision supplémentaires. |
| 5 | 18 | `elfe.archer.r5.b.fleche_de_siege` | Flèche de siège | Poussée totale de 3 cases et 8 dégâts de collision. |
| 5 | 18 | `elfe.archer.r5.b.fleche_darret` | Flèche d’arrêt | Inflige −2 PM et +4 dégâts si la cible termine contre un obstacle. |

Comparaison dépôt : les 18 choix, seuils, libellés et effets sont présents et testés. Les IDs runtime sont toutefois tous différents (`elf_archer_*`). Les ressources ajoutent parfois des conventions non dites par la preview, par exemple le rafraîchissement du Saignement.

### Elfe — Assassin — Frappe sournoise

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `elfe.assassin.r1.base` | Frappe sournoise | 2 PA · Portée 1 · 7 dégâts physiques · Corps à corps. |
| 2 | 3 | `elfe.assassin.r2.a.dans_le_dos` | Dans le dos | +4 dégâts lors d’une véritable attaque arrière. |
| 3 | 7 | `elfe.assassin.r3.a.executrice` | Exécutrice | +4 dégâts contre une cible sous 40 % de ses PV. |
| 4 | 12 | `elfe.assassin.r4.a.executrice.coup_fatal` | Coup fatal | Le seuil d’exécution passe à 50 % des PV. |
| 4 | 12 | `elfe.assassin.r4.a.executrice.ouverture` | Ouverture | La cible subit +3 dégâts sur la prochaine attaque physique reçue. |
| 3 | 7 | `elfe.assassin.r3.a.repli` | Repli | Après une attaque arrière réussie, l’Elfe gagne 1 PM à son prochain tour. |
| 4 | 12 | `elfe.assassin.r4.a.repli.allonge_elfique` | Allonge elfique | +1 portée. |
| 4 | 12 | `elfe.assassin.r4.a.repli.pas_leger` | Pas léger | Le bonus de mobilité passe à +2 PM au prochain tour. |
| 5 | 18 | `elfe.assassin.r5.a.assassinat` | Assassinat | +8 dégâts si la cible est dans le dos ou sous 35 % de ses PV. |
| 5 | 18 | `elfe.assassin.r5.a.lame_fantome` | Lame fantôme | Portée totale de 3 cases et +3 dégâts. |
| 2 | 3 | `elfe.assassin.r2.b.lame_venimeuse` | Lame venimeuse | Applique Poison : 2 dégâts pendant 2 tours. |
| 3 | 7 | `elfe.assassin.r3.b.empoisonneuse` | Empoisonneuse | Le Poison inflige +1 dégât par tour. |
| 4 | 12 | `elfe.assassin.r4.b.empoisonneuse.toxines_persistantes` | Toxines persistantes | Le Poison dure 1 tour supplémentaire. |
| 4 | 12 | `elfe.assassin.r4.b.empoisonneuse.double_dose` | Double dose | Le Poison inflige 3 dégâts pendant 2 tours. |
| 3 | 7 | `elfe.assassin.r3.b.saboteuse` | Saboteuse | La cible perd 1 PM pendant son prochain tour. |
| 4 | 12 | `elfe.assassin.r4.b.saboteuse.tendon_tranche` | Tendon tranché | La perte passe à −2 PM pour le prochain tour. |
| 4 | 12 | `elfe.assassin.r4.b.saboteuse.affaiblissement` | Affaiblissement | La cible inflige −2 dégâts pendant son prochain tour. |
| 5 | 18 | `elfe.assassin.r5.b.venin_mortel` | Venin mortel | Poison : 3 dégâts pendant 3 tours. |
| 5 | 18 | `elfe.assassin.r5.b.sabotage` | Sabotage | −2 PM et +3 dégâts reçus sur les 2 prochaines attaques. |

Comparaison dépôt : seuls les deux R2 existent (`elf_assassin_backstab`, `elf_assassin_venomous_blade`). Les 16 choix R3–R5 sont absents.

### Elfe — Mage — Boule de feu de l’Elfe

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `elfe.mage.r1.base` | Boule de feu de l’Elfe | Explosion de feu de zone · Valeurs de base à normaliser avant équilibrage final. |
| 2 | 3 | `elfe.mage.r2.a.cur_incandescent` | Cœur incandescent | +3 dégâts sur la cellule centrale. |
| 3 | 7 | `elfe.mage.r3.a.detonation` | Détonation | +3 dégâts supplémentaires au centre. |
| 4 | 12 | `elfe.mage.r4.a.detonation.noyau_ardent` | Noyau ardent | +4 dégâts supplémentaires au centre. |
| 4 | 12 | `elfe.mage.r4.a.detonation.portee_arcanique` | Portée arcanique | +2 portée. |
| 3 | 7 | `elfe.mage.r3.a.explosion_elargie` | Explosion élargie | La zone gagne 1 cellule sur ses extrémités cardinales. |
| 4 | 12 | `elfe.mage.r4.a.explosion_elargie.grande_explosion` | Grande explosion | La zone gagne encore 1 cellule cardinale. |
| 4 | 12 | `elfe.mage.r4.a.explosion_elargie.eclats_brulants` | Éclats brûlants | +2 dégâts à toutes les cibles touchées. |
| 5 | 18 | `elfe.mage.r5.a.comete_elfique` | Comète elfique | +8 dégâts au centre et +2 portée. |
| 5 | 18 | `elfe.mage.r5.a.nova_elfique` | Nova elfique | +3 dégâts à toutes les cibles et zone agrandie. |
| 2 | 3 | `elfe.mage.r2.b.braises_persistantes` | Braises persistantes | Le terrain enflammé dure 1 tour supplémentaire. |
| 3 | 7 | `elfe.mage.r3.b.incendiaire` | Incendiaire | Applique Brûlure : 2 dégâts pendant 2 tours. |
| 4 | 12 | `elfe.mage.r4.b.incendiaire.braises_longues` | Braises longues | La Brûlure dure 1 tour supplémentaire. |
| 4 | 12 | `elfe.mage.r4.b.incendiaire.feu_mordant` | Feu mordant | La Brûlure inflige +1 dégât par tour. |
| 3 | 7 | `elfe.mage.r3.b.souffle_ardent` | Souffle ardent | Repousse les ennemis touchés de 1 case. |
| 4 | 12 | `elfe.mage.r4.b.souffle_ardent.souffle_puissant` | Souffle puissant | +1 case de poussée. |
| 4 | 12 | `elfe.mage.r4.b.souffle_ardent.fracas_ardent` | Fracas ardent | Une collision inflige 4 dégâts supplémentaires. |
| 5 | 18 | `elfe.mage.r5.b.incendie_sauvage` | Incendie sauvage | Brûlure : 3 dégâts pendant 3 tours et terrain +1 tour. |
| 5 | 18 | `elfe.mage.r5.b.onde_explosive` | Onde explosive | Poussée de 2 cases, 6 dégâts de collision et terrain +1 tour. |

Comparaison dépôt : seuls Cœur incandescent et Braises persistantes existent. Le dépôt crée du terrain `feu` d'une durée forcée à 1 tour, tandis que la preview parle d'ajouter un tour à un terrain enflammé existant. La base chiffrée est indéterminée dans la preview.

### Elfe — Soigneur — Soin sylvestre

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `elfe.soigneur.r1.base` | Soin sylvestre | 2 PA · Portée 5 · Rend 7 PV · Soi-même ou allié. |
| 2 | 3 | `elfe.soigneur.r2.a.seve_abondante` | Sève abondante | +3 soins immédiats. |
| 3 | 7 | `elfe.soigneur.r3.a.sauveteuse` | Sauveteuse | +5 soins si la cible possède moins de 50 % de ses PV. |
| 4 | 12 | `elfe.soigneur.r4.a.sauveteuse.miracle_mineur` | Miracle mineur | +5 soins supplémentaires sous 35 % des PV. |
| 4 | 12 | `elfe.soigneur.r4.a.sauveteuse.racines_lointaines` | Racines lointaines | +2 portée. |
| 3 | 7 | `elfe.soigneur.r3.a.regeneratrice` | Régénératrice | Rend 2 PV à la fin des 2 prochains tours. |
| 4 | 12 | `elfe.soigneur.r4.a.regeneratrice.seve_longue` | Sève longue | La régénération dure 1 tour supplémentaire. |
| 4 | 12 | `elfe.soigneur.r4.a.regeneratrice.seve_riche` | Sève riche | La régénération rend +1 PV par tour. |
| 5 | 18 | `elfe.soigneur.r5.a.miracle_sylvestre` | Miracle sylvestre | +10 soins sous 35 % des PV et retire un effet de dégâts sur la durée. |
| 5 | 18 | `elfe.soigneur.r5.a.floraison` | Floraison | Les alliés adjacents à la cible reçoivent 50 % du soin principal. |
| 2 | 3 | `elfe.soigneur.r2.b.ecorce_protectrice` | Écorce protectrice | Ajoute 3 points de bouclier. |
| 3 | 7 | `elfe.soigneur.r3.b.bastion_naturel` | Bastion naturel | Ajoute 3 points de bouclier supplémentaires. |
| 4 | 12 | `elfe.soigneur.r4.b.bastion_naturel.ecorce_epaisse` | Écorce épaisse | Ajoute encore 3 points de bouclier. |
| 4 | 12 | `elfe.soigneur.r4.b.bastion_naturel.protection_partagee` | Protection partagée | L’Elfe reçoit 3 points de bouclier lorsqu’elle protège un allié. |
| 3 | 7 | `elfe.soigneur.r3.b.garde_mobile` | Garde mobile | La cible gagne 1 PM pendant son prochain tour. |
| 4 | 12 | `elfe.soigneur.r4.b.garde_mobile.elan_sylvestre` | Élan sylvestre | Le bonus passe à +2 PM pour le prochain tour. |
| 4 | 12 | `elfe.soigneur.r4.b.garde_mobile.purification` | Purification | Retire un Poison, Saignement, Brûlure ou ralentissement. |
| 5 | 18 | `elfe.soigneur.r5.b.ecorce_vivante` | Écorce vivante | Ajoute 8 points de bouclier et l’Elfe en reçoit 4. |
| 5 | 18 | `elfe.soigneur.r5.b.elan_protecteur` | Élan protecteur | La cible gagne +2 PM et 6 points de bouclier. |

Comparaison dépôt : seuls Sève abondante et Écorce protectrice existent. Les règles de cumul/remplacement des boucliers, de rafraîchissement de régénération et d'arrondi de Floraison ne sont pas définies dans la preview.

### Mage — Pyromancie — Boule de feu

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `mage.pyromancie.r1.base` | Boule de feu | Explosion de feu de zone · Valeurs de base à normaliser avant équilibrage final. |
| 2 | 3 | `mage.pyromancie.r2.a.conflagration` | Conflagration | +2 dégâts à toutes les cibles touchées. |
| 3 | 7 | `mage.pyromancie.r3.a.noyau_instable` | Noyau instable | +4 dégâts sur la cellule centrale. |
| 4 | 12 | `mage.pyromancie.r4.a.noyau_instable.detonation_intense` | Détonation intense | +4 dégâts supplémentaires au centre. |
| 4 | 12 | `mage.pyromancie.r4.a.noyau_instable.projection_lointaine` | Projection lointaine | +2 portée. |
| 3 | 7 | `mage.pyromancie.r3.a.maitre_des_explosions` | Maître des explosions | La zone gagne 1 cellule sur ses extrémités cardinales. |
| 4 | 12 | `mage.pyromancie.r4.a.maitre_des_explosions.superficie_accrue` | Superficie accrue | La zone gagne encore 1 cellule cardinale. |
| 4 | 12 | `mage.pyromancie.r4.a.maitre_des_explosions.chaleur_extreme` | Chaleur extrême | +2 dégâts à toutes les cibles. |
| 5 | 18 | `mage.pyromancie.r5.a.supernova` | Supernova | +6 dégâts au centre, +3 dégâts de zone et zone agrandie. |
| 5 | 18 | `mage.pyromancie.r5.a.bombardement` | Bombardement | +4 portée et +4 dégâts à toutes les cibles. |
| 2 | 3 | `mage.pyromancie.r2.b.brasier_durable` | Brasier durable | Le terrain enflammé dure 1 tour supplémentaire. |
| 3 | 7 | `mage.pyromancie.r3.b.incendiaire` | Incendiaire | Applique Brûlure : 2 dégâts pendant 2 tours. |
| 4 | 12 | `mage.pyromancie.r4.b.incendiaire.feu_devorant` | Feu dévorant | La Brûlure inflige +1 dégât par tour. |
| 4 | 12 | `mage.pyromancie.r4.b.incendiaire.braises_eternelles` | Braises éternelles | La Brûlure dure 1 tour supplémentaire. |
| 3 | 7 | `mage.pyromancie.r3.b.sol_ardent` | Sol ardent | Les ennemis qui commencent leur tour sur le feu subissent +2 dégâts. |
| 4 | 12 | `mage.pyromancie.r4.b.sol_ardent.terrain_persistant` | Terrain persistant | Le terrain dure 1 tour supplémentaire. |
| 4 | 12 | `mage.pyromancie.r4.b.sol_ardent.fournaise` | Fournaise | Les dégâts supplémentaires du terrain passent à +4. |
| 5 | 18 | `mage.pyromancie.r5.b.enfer` | Enfer | Brûlure : 3 dégâts pendant 3 tours et terrain +2 tours. |
| 5 | 18 | `mage.pyromancie.r5.b.mer_de_flammes` | Mer de flammes | Zone de terrain agrandie, durée +2 tours et +3 dégâts au début du tour. |

Comparaison dépôt : seule la base existe, sous `discipline_id = mage_fire`. La preview ne permet pas de valider les 400 dégâts, la portée 14, la zone ou la lave sérialisés dans la ressource actuelle.

### Mage — Cryomancie — Mur de glace

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `mage.cryomancie.r1.base` | Mur de glace | Portée 6 · Crée une zone de glace · Aucun dégât direct de base. |
| 2 | 3 | `mage.cryomancie.r2.a.mur_etendu` | Mur étendu | Ajoute 1 cellule à chaque extrémité du mur. |
| 3 | 7 | `mage.cryomancie.r3.a.glace_tenace` | Glace tenace | La glace dure 1 tour supplémentaire. |
| 4 | 12 | `mage.cryomancie.r4.a.glace_tenace.mur_durable` | Mur durable | La glace dure encore 1 tour supplémentaire. |
| 4 | 12 | `mage.cryomancie.r4.a.glace_tenace.projection_glaciale` | Projection glaciale | +2 portée. |
| 3 | 7 | `mage.cryomancie.r3.a.cristallomancie` | Cristallomancie | Les alliés présents sur la glace reçoivent 3 boucliers. |
| 4 | 12 | `mage.cryomancie.r4.a.cristallomancie.glace_miroir` | Glace miroir | Le bouclier accordé passe à 6. |
| 4 | 12 | `mage.cryomancie.r4.a.cristallomancie.passage_sur` | Passage sûr | Les alliés présents sur la glace gagnent 1 PM au prochain tour. |
| 5 | 18 | `mage.cryomancie.r5.a.forteresse_gelee` | Forteresse gelée | Ajoute 4 cellules au total et +2 tours de durée. |
| 5 | 18 | `mage.cryomancie.r5.a.sanctuaire_de_glace` | Sanctuaire de glace | Les alliés sur la glace reçoivent 8 boucliers et +1 PM. |
| 2 | 3 | `mage.cryomancie.r2.b.gel_mordant` | Gel mordant | Inflige 3 dégâts aux ennemis présents lors de la création. |
| 3 | 7 | `mage.cryomancie.r3.b.geolier_du_froid` | Geôlier du froid | Les ennemis touchés perdent 1 PM au prochain tour. |
| 4 | 12 | `mage.cryomancie.r4.b.geolier_du_froid.gel_profond` | Gel profond | La perte passe à −2 PM. |
| 4 | 12 | `mage.cryomancie.r4.b.geolier_du_froid.froid_tranchant` | Froid tranchant | +2 dégâts lors de la création. |
| 3 | 7 | `mage.cryomancie.r3.b.cristallisation` | Cristallisation | Les ennemis touchés subissent +2 dégâts sur la prochaine attaque reçue. |
| 4 | 12 | `mage.cryomancie.r4.b.cristallisation.fragilite_glacee` | Fragilité glacée | Le bonus s’applique aux 2 prochaines attaques. |
| 4 | 12 | `mage.cryomancie.r4.b.cristallisation.point_de_rupture` | Point de rupture | Le bonus de dégâts reçus passe à +4. |
| 5 | 18 | `mage.cryomancie.r5.b.hiver_brutal` | Hiver brutal | 7 dégâts lors de la création et −2 PM. |
| 5 | 18 | `mage.cryomancie.r5.b.prison_cristalline` | Prison cristalline | 5 dégâts et +4 dégâts reçus sur les 2 prochaines attaques. |

Comparaison dépôt : seule la racine existe, sous `mage_ice`. Le dépôt fixe une croix de taille 3 et une durée de terrain issue de la ressource glace; la preview ne donne pas la forme de base ni toutes les règles de déclenchement.

### Mage — Foudromancie — Tempête orageuse

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `mage.foudromancie.r1.base` | Tempête orageuse | 3 PA · Portée 5 · Zone 3×3 · 7 dégâts de foudre. |
| 2 | 3 | `mage.foudromancie.r2.a.surcharge` | Surcharge | +2 dégâts à toutes les cibles. |
| 3 | 7 | `mage.foudromancie.r3.a.cur_de_lorage` | Cœur de l’orage | +4 dégâts sur la cellule centrale. |
| 4 | 12 | `mage.foudromancie.r4.a.cur_de_lorage.impact_central` | Impact central | +3 dégâts supplémentaires au centre. |
| 4 | 12 | `mage.foudromancie.r4.a.cur_de_lorage.orage_lointain` | Orage lointain | +2 portée. |
| 3 | 7 | `mage.foudromancie.r3.a.front_orageux` | Front orageux | La zone gagne 1 cellule sur ses extrémités cardinales. |
| 4 | 12 | `mage.foudromancie.r4.a.front_orageux.supercellule_mineure` | Supercellule mineure | La zone gagne encore 1 cellule cardinale. |
| 4 | 12 | `mage.foudromancie.r4.a.front_orageux.haute_tension` | Haute tension | +2 dégâts à toutes les cibles. |
| 5 | 18 | `mage.foudromancie.r5.a.cur_de_tonnerre` | Cœur de tonnerre | +8 dégâts au centre et +3 dégâts à toutes les cibles. |
| 5 | 18 | `mage.foudromancie.r5.a.supercellule` | Supercellule | Zone agrandie, +2 portée et +3 dégâts de zone. |
| 2 | 3 | `mage.foudromancie.r2.b.champ_statique` | Champ statique | Les ennemis touchés perdent 1 PM au prochain tour. |
| 3 | 7 | `mage.foudromancie.r3.b.paralysie` | Paralysie | La perte de PM s’applique pendant 2 tours. |
| 4 | 12 | `mage.foudromancie.r4.b.paralysie.entrave_majeure` | Entrave majeure | La perte passe à −2 PM pour le prochain tour. |
| 4 | 12 | `mage.foudromancie.r4.b.paralysie.electricite_residuelle` | Électricité résiduelle | Inflige 2 dégâts à la fin du prochain tour. |
| 3 | 7 | `mage.foudromancie.r3.b.conductivite` | Conductivité | Chaque cible subit +3 dégâts sur la prochaine attaque reçue. |
| 4 | 12 | `mage.foudromancie.r4.b.conductivite.charge_persistante` | Charge persistante | Le bonus s’applique aux 2 prochaines attaques. |
| 4 | 12 | `mage.foudromancie.r4.b.conductivite.arc_secondaire` | Arc secondaire | La première attaque bonus inflige aussi 3 dégâts à un ennemi adjacent. |
| 5 | 18 | `mage.foudromancie.r5.b.paralysie_complete` | Paralysie complète | −2 PM au prochain tour et 3 dégâts différés. |
| 5 | 18 | `mage.foudromancie.r5.b.orage_conducteur` | Orage conducteur | +4 dégâts reçus sur les 2 prochaines attaques et arc secondaire de 3 dégâts. |

Comparaison dépôt : la base `mage_thunderstorm` correspond aux valeurs R1. Les 18 choix sont absents.

### Mage — Géomancie — Onde sismique

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `mage.geomancie.r1.base` | Onde sismique | 2 PA · Portée 3 en ligne · 6 dégâts de terre · Pousse de 1 case. |
| 2 | 3 | `mage.geomancie.r2.a.onde_renforcee` | Onde renforcée | +2 dégâts à toutes les cibles de la ligne. |
| 3 | 7 | `mage.geomancie.r3.a.fracture` | Fracture | Les cibles subissent +2 dégâts sur les 2 prochaines attaques. |
| 4 | 12 | `mage.geomancie.r4.a.fracture.breche_profonde` | Brèche profonde | Le bonus de dégâts reçus passe à +4. |
| 4 | 12 | `mage.geomancie.r4.a.fracture.fracture_durable` | Fracture durable | Le bonus s’applique aux 3 prochaines attaques. |
| 3 | 7 | `mage.geomancie.r3.a.faille_prolongee` | Faille prolongée | +2 portée. |
| 4 | 12 | `mage.geomancie.r4.a.faille_prolongee.portee_tellurique` | Portée tellurique | +2 portée supplémentaire. |
| 4 | 12 | `mage.geomancie.r4.a.faille_prolongee.secousse_puissante` | Secousse puissante | +2 dégâts supplémentaires. |
| 5 | 18 | `mage.geomancie.r5.a.cataclysme` | Cataclysme | +5 dégâts de ligne et +4 dégâts reçus sur les 2 prochaines attaques. |
| 5 | 18 | `mage.geomancie.r5.a.faille_majeure` | Faille majeure | +4 portée totale supplémentaire et +3 dégâts. |
| 2 | 3 | `mage.geomancie.r2.b.recul_tectonique` | Recul tectonique | +1 case de poussée. |
| 3 | 7 | `mage.geomancie.r3.b.fracasseur` | Fracasseur | Une collision inflige 4 dégâts supplémentaires. |
| 4 | 12 | `mage.geomancie.r4.b.fracasseur.ecrasement` | Écrasement | +4 dégâts de collision supplémentaires. |
| 4 | 12 | `mage.geomancie.r4.b.fracasseur.projection` | Projection | +1 case de poussée. |
| 3 | 7 | `mage.geomancie.r3.b.eboulement` | Éboulement | Les cibles touchées perdent 1 PM au prochain tour. |
| 4 | 12 | `mage.geomancie.r4.b.eboulement.terrain_instable` | Terrain instable | La perte passe à −2 PM. |
| 4 | 12 | `mage.geomancie.r4.b.eboulement.secousse` | Secousse | +2 dégâts directs. |
| 5 | 18 | `mage.geomancie.r5.b.impact_tectonique` | Impact tectonique | Poussée totale de 3 cases et 8 dégâts de collision. |
| 5 | 18 | `mage.geomancie.r5.b.glissement_de_terrain` | Glissement de terrain | Poussée de 2 cases, −2 PM et +3 dégâts. |

Comparaison dépôt : la base `mage_seismic_wave` correspond aux valeurs R1. Les 18 choix sont absents.

### Guerrier — Brutalité — Frappe lourde

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `guerrier.brutalite.r1.base` | Frappe lourde | 2 PA · Portée 1 · 8 dégâts physiques. |
| 2 | 3 | `guerrier.brutalite.r2.a.coup_brutal` | Coup brutal | +3 dégâts directs. |
| 3 | 7 | `guerrier.brutalite.r3.a.executeur` | Exécuteur | +4 dégâts contre une cible sous 40 % de ses PV. |
| 4 | 12 | `guerrier.brutalite.r4.a.executeur.coup_fatal` | Coup fatal | Le seuil d’exécution passe à 50 % des PV. |
| 4 | 12 | `guerrier.brutalite.r4.a.executeur.allonge_martiale` | Allonge martiale | +1 portée. |
| 3 | 7 | `guerrier.brutalite.r3.a.brise_armure` | Brise-armure | La cible subit +2 dégâts physiques sur les 2 prochaines attaques. |
| 4 | 12 | `guerrier.brutalite.r4.a.brise_armure.armure_fendue` | Armure fendue | Le bonus de dégâts reçus passe à +4. |
| 4 | 12 | `guerrier.brutalite.r4.a.brise_armure.frappe_repoussante` | Frappe repoussante | Repousse la cible de 1 case. |
| 5 | 18 | `guerrier.brutalite.r5.a.decapitation` | Décapitation | +8 dégâts contre une cible sous 35 % de ses PV. |
| 5 | 18 | `guerrier.brutalite.r5.a.armure_pulverisee` | Armure pulvérisée | +4 dégâts physiques reçus sur les 3 prochaines attaques. |
| 2 | 3 | `guerrier.brutalite.r2.b.entaille_profonde` | Entaille profonde | Applique Saignement : 2 dégâts pendant 2 tours. |
| 3 | 7 | `guerrier.brutalite.r3.b.boucher` | Boucher | Le Saignement inflige +1 dégât par tour. |
| 4 | 12 | `guerrier.brutalite.r4.b.boucher.hemorragie` | Hémorragie | Le Saignement inflige encore +1 dégât par tour. |
| 4 | 12 | `guerrier.brutalite.r4.b.boucher.coup_appuye` | Coup appuyé | +2 dégâts directs. |
| 3 | 7 | `guerrier.brutalite.r3.b.plaie_ouverte` | Plaie ouverte | Le Saignement dure 1 tour supplémentaire. |
| 4 | 12 | `guerrier.brutalite.r4.b.plaie_ouverte.plaie_beante` | Plaie béante | Le Saignement dure encore 1 tour supplémentaire. |
| 4 | 12 | `guerrier.brutalite.r4.b.plaie_ouverte.tendon_sectionne` | Tendon sectionné | La cible perd 1 PM au prochain tour. |
| 5 | 18 | `guerrier.brutalite.r5.b.hemorragie_brutale` | Hémorragie brutale | Saignement : 3 dégâts pendant 3 tours. |
| 5 | 18 | `guerrier.brutalite.r5.b.plaie_incapacitante` | Plaie incapacitante | Saignement : 2 dégâts pendant 4 tours et −1 PM. |

### Guerrier — Assaut — Charge

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `guerrier.assaut.r1.base` | Charge | 2 PA · Portée 3 en ligne · Se déplace au contact et inflige 5 dégâts. |
| 2 | 3 | `guerrier.assaut.r2.a.elan_prolonge` | Élan prolongé | +1 portée. |
| 3 | 7 | `guerrier.assaut.r3.a.intercepteur` | Intercepteur | La Charge peut cibler une case libre et servir uniquement de déplacement. |
| 4 | 12 | `guerrier.assaut.r4.a.intercepteur.course_longue` | Course longue | +1 portée supplémentaire. |
| 4 | 12 | `guerrier.assaut.r4.a.intercepteur.repositionnement` | Repositionnement | Le Guerrier gagne 1 PM à son prochain tour. |
| 3 | 7 | `guerrier.assaut.r3.a.armure_delan` | Armure d’élan | Après une Charge réussie, le Guerrier gagne 3 boucliers. |
| 4 | 12 | `guerrier.assaut.r4.a.armure_delan.avant_garde` | Avant-garde | Le bouclier gagné passe à 6. |
| 4 | 12 | `guerrier.assaut.r4.a.armure_delan.protection_mobile` | Protection mobile | Un allié adjacent au point d’arrivée reçoit 3 boucliers. |
| 5 | 18 | `guerrier.assaut.r5.a.charge_tactique` | Charge tactique | Peut cibler une case libre, +2 portée et +1 PM au prochain tour. |
| 5 | 18 | `guerrier.assaut.r5.a.avant_garde_supreme` | Avant-garde suprême | +2 portée et 7 boucliers après la Charge. |
| 2 | 3 | `guerrier.assaut.r2.b.impact_puissant` | Impact puissant | +3 dégâts à la cible atteinte. |
| 3 | 7 | `guerrier.assaut.r3.b.belier` | Bélier | Repousse la cible de 1 case. |
| 4 | 12 | `guerrier.assaut.r4.b.belier.projection` | Projection | +1 case de poussée. |
| 4 | 12 | `guerrier.assaut.r4.b.belier.impact_lourd` | Impact lourd | +2 dégâts directs. |
| 3 | 7 | `guerrier.assaut.r3.b.percuteur` | Percuteur | Une collision inflige 4 dégâts supplémentaires. |
| 4 | 12 | `guerrier.assaut.r4.b.percuteur.collision_brutale` | Collision brutale | +4 dégâts de collision supplémentaires. |
| 4 | 12 | `guerrier.assaut.r4.b.percuteur.plaie_dimpact` | Plaie d’impact | Applique Saignement : 2 dégâts pendant 2 tours. |
| 5 | 18 | `guerrier.assaut.r5.b.belier_de_guerre` | Bélier de guerre | Poussée totale de 3 cases et +3 dégâts directs. |
| 5 | 18 | `guerrier.assaut.r5.b.impact_devastateur` | Impact dévastateur | +6 dégâts directs et 8 dégâts de collision. |

### Guerrier — Furie — Tourbillon

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `guerrier.furie.r1.base` | Tourbillon | 3 PA · Frappe tous les ennemis adjacents pour 5 dégâts. |
| 2 | 3 | `guerrier.furie.r2.a.lames_lourdes` | Lames lourdes | +2 dégâts à toutes les cibles. |
| 3 | 7 | `guerrier.furie.r3.a.ravageur` | Ravageur | +2 dégâts supplémentaires à toutes les cibles. |
| 4 | 12 | `guerrier.furie.r4.a.ravageur.tourbillon_renforce` | Tourbillon renforcé | +2 dégâts supplémentaires. |
| 4 | 12 | `guerrier.furie.r4.a.ravageur.cercle_elargi` | Cercle élargi | Ajoute les cases situées à 2 cases cardinales du Guerrier. |
| 3 | 7 | `guerrier.furie.r3.a.faucheur` | Faucheur | Applique Saignement : 2 dégâts pendant 2 tours. |
| 4 | 12 | `guerrier.furie.r4.a.faucheur.lames_dentelees` | Lames dentelées | Le Saignement inflige +1 dégât par tour. |
| 4 | 12 | `guerrier.furie.r4.a.faucheur.moisson_longue` | Moisson longue | Le Saignement dure 1 tour supplémentaire. |
| 5 | 18 | `guerrier.furie.r5.a.tempete_dacier` | Tempête d’acier | +5 dégâts à toutes les cibles et zone élargie. |
| 5 | 18 | `guerrier.furie.r5.a.moissonneur` | Moissonneur | Saignement : 3 dégâts pendant 3 tours. |
| 2 | 3 | `guerrier.furie.r2.b.cercle_de_force` | Cercle de force | Repousse chaque ennemi touché de 1 case. |
| 3 | 7 | `guerrier.furie.r3.b.controleur` | Contrôleur | Les ennemis touchés perdent 1 PM au prochain tour. |
| 4 | 12 | `guerrier.furie.r4.b.controleur.fauchage` | Fauchage | La perte passe à −2 PM. |
| 4 | 12 | `guerrier.furie.r4.b.controleur.balayage_lourd` | Balayage lourd | +2 dégâts directs. |
| 3 | 7 | `guerrier.furie.r3.b.projection_circulaire` | Projection circulaire | +1 case de poussée. |
| 4 | 12 | `guerrier.furie.r4.b.projection_circulaire.onde_circulaire` | Onde circulaire | +1 case de poussée. |
| 4 | 12 | `guerrier.furie.r4.b.projection_circulaire.fracas_circulaire` | Fracas circulaire | Une collision inflige 4 dégâts supplémentaires. |
| 5 | 18 | `guerrier.furie.r5.b.balayage_total` | Balayage total | −2 PM et +3 dégâts à toutes les cibles. |
| 5 | 18 | `guerrier.furie.r5.b.onde_de_choc` | Onde de choc | Poussée totale de 3 cases et 6 dégâts de collision. |

### Guerrier — Rempart — Garde

| R | XP | Identifiant preview | Libellé | Description exacte |
|---:|---:|---|---|---|
| 1 | 0 | `guerrier.rempart.r1.base` | Garde | 2 PA · Portée 1 · Donne 6 boucliers à soi-même ou à un allié. |
| 2 | 3 | `guerrier.rempart.r2.a.bouclier_renforce` | Bouclier renforcé | +3 points de bouclier. |
| 3 | 7 | `guerrier.rempart.r3.a.bastion` | Bastion | Ajoute 4 boucliers supplémentaires. |
| 4 | 12 | `guerrier.rempart.r4.a.bastion.fortification` | Fortification | Ajoute encore 3 boucliers. |
| 4 | 12 | `guerrier.rempart.r4.a.bastion.vigilance` | Vigilance | +2 portée. |
| 3 | 7 | `guerrier.rempart.r3.a.protection_partagee` | Protection partagée | Le Guerrier reçoit 3 boucliers lorsqu’il protège un allié. |
| 4 | 12 | `guerrier.rempart.r4.a.protection_partagee.serment` | Serment | Le bouclier reçu par le Guerrier passe à 6. |
| 4 | 12 | `guerrier.rempart.r4.a.protection_partagee.soutien_durable` | Soutien durable | L’allié protégé récupère 2 PV pendant 2 tours. |
| 5 | 18 | `guerrier.rempart.r5.a.forteresse_vivante` | Forteresse vivante | Ajoute 10 boucliers à la cible. |
| 5 | 18 | `guerrier.rempart.r5.a.serment_du_protecteur` | Serment du protecteur | Le Guerrier et l’allié ciblé reçoivent chacun 7 boucliers. |
| 2 | 3 | `guerrier.rempart.r2.b.garde_mobile` | Garde mobile | La cible gagne 1 PM pendant son prochain tour. |
| 3 | 7 | `guerrier.rempart.r3.b.ordre_dassaut` | Ordre d’assaut | La prochaine attaque de la cible inflige +2 dégâts. |
| 4 | 12 | `guerrier.rempart.r4.b.ordre_dassaut.commandement` | Commandement | Le bonus de la prochaine attaque passe à +4 dégâts. |
| 4 | 12 | `guerrier.rempart.r4.b.ordre_dassaut.marche_forcee` | Marche forcée | Le bonus de mobilité passe à +2 PM. |
| 3 | 7 | `guerrier.rempart.r3.b.purification_martiale` | Purification martiale | Retire un Poison, Saignement, Brûlure ou ralentissement. |
| 4 | 12 | `guerrier.rempart.r4.b.purification_martiale.nettoyage_complet` | Nettoyage complet | Retire jusqu’à 2 effets négatifs simples. |
| 4 | 12 | `guerrier.rempart.r4.b.purification_martiale.garde_purifiante` | Garde purifiante | Ajoute aussi 3 boucliers. |
| 5 | 18 | `guerrier.rempart.r5.b.ordre_de_guerre` | Ordre de guerre | +2 PM et +4 dégâts sur la prochaine attaque. |
| 5 | 18 | `guerrier.rempart.r5.b.protection_absolue` | Protection absolue | Ajoute 6 boucliers et retire tous les effets négatifs simples. |

Comparaison dépôt pour les quatre arbres Guerrier : aucun de ces quatre sorts, disciplines ou 72 choix n'est présent. La ressource Guerrier actuelle équipe Bourrade, Marque de guerre, Exécution de guerre et Piétinement, avec seulement Briseur, Bourreau et Saccageur.

## Audit du dépôt réel

### Équipe, sorts et disciplines équipés

| Personnage | `unit_id` | Sorts équipés, dans l'ordre | `discipline_id` | Résultat |
|---|---|---|---|---|
| Elfe | `elf` | `elf_precise_shot`, `elf_sneak_strike`, `elf_fireball`, `elf_sylvan_heal` | `archer`, `assassin`, `mage`, `healer` | 4 sorts, 4 disciplines distinctes |
| Mage | `mage` | `mage_fireball`, `mage_ice_wall`, `mage_thunderstorm`, `mage_seismic_wave` | `mage_fire`, `mage_ice`, `mage_lightning`, `mage_earth` | 4 sorts, 4 disciplines distinctes |
| Guerrier | `warrior` | `warrior_shove`, `warrior_war_mark`, `warrior_execution`, `warrior_stomp` | `warrior_breaker`, `warrior_executioner`, `warrior_executioner`, `warrior_ravager` | 4 sorts, seulement 3 disciplines distinctes |

Le trio de production est fixé dans `GameManager.PRODUCTION_HERO_DATA_PATHS` dans l'ordre Elfe, Mage, Guerrier. `active_spell_slots` vaut 4 par défaut et les trois ressources exposent exactement 4 sorts.

### Ressources d'arbres présentes

| Personnage | Discipline dépôt | Ressource | Rangs | Seuils | Choix | Diagnostic resolver |
|---|---|---|---|---|---:|---|
| Elfe | `archer` | `res://data/characters/elf/disciplines/archer.tres` | R1–R5 | 0/3/7/12/18 | 18 | valide |
| Elfe | `assassin` | `res://data/characters/elf/disciplines/assassin.tres` | R1–R2 | 0/3 | 2 | valide mais incomplet |
| Elfe | `mage` | `res://data/characters/elf/disciplines/mage.tres` | R1–R2 | 0/3 | 2 | valide mais incomplet |
| Elfe | `healer` | `res://data/characters/elf/disciplines/healer.tres` | R1–R2 | 0/3 | 2 | valide mais incomplet |
| Mage | `mage_fire` | `res://data/characters/mage/disciplines/fire.tres` | R1 | 0 | 0 | valide mais progression non définie |
| Mage | `mage_ice` | `res://data/characters/mage/disciplines/ice.tres` | R1 | 0 | 0 | valide mais progression non définie |
| Mage | `mage_lightning` | `res://data/characters/mage/disciplines/lightning.tres` | R1 | 0 | 0 | valide mais progression non définie |
| Mage | `mage_earth` | `res://data/characters/mage/disciplines/earth.tres` | R1 | 0 | 0 | valide mais progression non définie |
| Guerrier | `warrior_breaker` | `res://data/characters/warrior/disciplines/breaker.tres` | R1–R2 | 0/3 | 1 | **invalide**, exclusion inconnue `warrior_breaker_long_hook` |
| Guerrier | `warrior_executioner` | `res://data/characters/warrior/disciplines/executioner.tres` | R1–R3 | 0/3/7 | 4 | valide, mais partagé par 2 sorts |
| Guerrier | `warrior_ravager` | `res://data/characters/warrior/disciplines/ravager.tres` | R1–R2 | 0/3 | 2 | valide mais incomplet |

Total dépôt : 11 disciplines, 31 choix, 34 ressources de modificateurs. Cible candidate : 12 disciplines, 216 choix.

### Choix et modificateurs réellement présents

`—` signifie qu'aucun prérequis ou aucune exclusion explicite n'est sérialisé. L'exclusivité d'un choix par rang reste appliquée par le resolver.

| Discipline | R | `upgrade_id` | Effet réel | Prérequis | Exclusions |
|---|---:|---|---|---|---|
| Archer | 2 | `elf_archer_eagle_eye` | +3 dégâts à distance ≥ 4 | — | — |
| Archer | 2 | `elf_archer_repel_arrow` | poussée +1 | — | — |
| Archer | 3 | `elf_archer_long_range` | portée +2 | `elf_archer_eagle_eye` | — |
| Archer | 3 | `elf_archer_piercing_shot` | statut brèche physique +2, 1 charge | `elf_archer_eagle_eye` | — |
| Archer | 3 | `elf_archer_hindering_arrow` | cible −1 PM au prochain tour | `elf_archer_repel_arrow` | — |
| Archer | 3 | `elf_archer_impact_bolt` | collision +4 dégâts | `elf_archer_repel_arrow` | — |
| Archer | 4 | `elf_archer_perfect_sight` | +3 dégâts à distance ≥ 6 | `elf_archer_long_range` | — |
| Archer | 4 | `elf_archer_stabilization` | +2 dégâts | `elf_archer_long_range` | — |
| Archer | 4 | `elf_archer_barbed_tip` | Saignement 2 × 2 tours | `elf_archer_piercing_shot` | — |
| Archer | 4 | `elf_archer_open_breach` | brèche physique +2, 2 charges | `elf_archer_piercing_shot` | — |
| Archer | 4 | `elf_archer_pin_arrow` | cible −2 PM au prochain tour | `elf_archer_hindering_arrow` | — |
| Archer | 4 | `elf_archer_tactical_retreat` | lanceur +1 PM au prochain tour | `elf_archer_hindering_arrow` | — |
| Archer | 4 | `elf_archer_siege_bolt` | poussée +1 | `elf_archer_impact_bolt` | — |
| Archer | 4 | `elf_archer_shatter` | collision +4 dégâts | `elf_archer_impact_bolt` | — |
| Archer | 5 | `elf_archer_perfect_shot` | portée +1 et +6 dégâts à distance ≥ 6 | `elf_archer_eagle_eye` | — |
| Archer | 5 | `elf_archer_transpiercing_bolt` | cible secondaire alignée à 50 % | `elf_archer_eagle_eye` | — |
| Archer | 5 | `elf_archer_siege_arrow` | poussée totale 3, collision totale 8 | `elf_archer_repel_arrow` | — |
| Archer | 5 | `elf_archer_stopping_arrow` | −2 PM et collision +4 | `elf_archer_repel_arrow` | — |
| Assassin | 2 | `elf_assassin_backstab` | +4 dégâts depuis la case arrière | — | — |
| Assassin | 2 | `elf_assassin_venomous_blade` | Poison 2 × 2 tours | — | — |
| Mage Elfe | 2 | `elf_mage_incandescent_core` | centre +3 dégâts | — | — |
| Mage Elfe | 2 | `elf_mage_persistent_embers` | pose `feu`, durée forcée 1 | — | — |
| Soigneur | 2 | `elf_healer_abundant_sap` | soin +3 | — | — |
| Soigneur | 2 | `elf_healer_protective_bark` | bouclier 3 | — | — |
| Briseur | 2 | `warrior_breaker_driving_shove` | poussée +1 sur Bourrade | — | `warrior_breaker_long_hook` absent |
| Bourreau | 2 | `warrior_executioner_distant_mark` | portée +1 sur Marque | — | `warrior_executioner_cruel_mark` |
| Bourreau | 2 | `warrior_executioner_cruel_mark` | +3 dégâts sur Marque | — | `warrior_executioner_distant_mark` |
| Bourreau | 3 | `warrior_executioner_final_sentence` | +6 dégâts sur Exécution | — | `warrior_executioner_crippling_execution` |
| Bourreau | 3 | `warrior_executioner_crippling_execution` | cible −1 PM après Exécution | — | `warrior_executioner_final_sentence` |
| Saccageur | 2 | `warrior_ravager_violent_stomp` | poussée +1 sur Piétinement | — | `warrior_ravager_earthen_stomp` |
| Saccageur | 2 | `warrior_ravager_earthen_stomp` | +3 dégâts sur Piétinement | — | `warrior_ravager_violent_stomp` |

### Icônes et assets réellement présents

- Les 11 `DisciplineData.icon` sont nuls.
- Les 31 `SkillUpgradeData.icon` sont nuls.
- Trois sorts seulement sérialisent une icône directement : les deux Boules de feu et Tempête orageuse.
- Le catalogue UI fournit des badges/racines pour les 4 disciplines Elfe et les 4 disciplines Mage; aucun badge/racine Guerrier.
- Le catalogue mappe les 24 choix Elfe actuels vers des icônes sémantiques; aucun choix Guerrier n'est mappé.
- `elf_archer_visual_map.tres` couvre uniquement la racine et les 18 choix Archer.
- Les nœuds non mappés tombent sur l'icône générique `upgrade.svg`.
- `SkillTreeScreen` appelle `SkillTreeGraphView.rebuild` sans lui transmettre `character_id`; le graphe conserve donc son défaut `elf`. Cela rend la résolution des badges Mage/Guerrier incorrecte, même si une icône de base peut retomber sur l'icône de sort.

### Compatibilité sort ↔ discipline dans l'UI

`SkillTreeScreen._base_spell_for_discipline()` associe un sort à une discipline par index, et non par `spell.discipline_id`.

- Elfe : 4 disciplines et 4 sorts dans le même ordre; l'association fonctionne.
- Mage : 4 disciplines et 4 sorts dans le même ordre; l'association fonctionne.
- Guerrier : 3 disciplines pour 4 sorts. Briseur pointe Bourrade, Bourreau pointe Marque, mais Saccageur pointe **Exécution de guerre** au lieu de Piétinement. Piétinement n'a aucun onglet dédié.

Ce défaut ne peut pas être corrigé uniquement avec de nouvelles données : l'UI doit résoudre le sort par identifiant de discipline et refuser/diagnostiquer les doublons.

## Contrats transversaux

| Contrat | État | Preuve / écart |
|---|---|---|
| Équipe fixe Elfe, Mage, Guerrier | CONFORME | `GameManager.PRODUCTION_HERO_DATA_PATHS` contient exactement ces trois ressources dans cet ordre. |
| Quatre sorts exactement par héros | CONFORME | Les trois `UnitData` en exposent 4 et le loadout crée 4 slots. |
| Quatre `discipline_id` distincts par héros | NON CONFORME | Guerrier : `warrior_executioner` est utilisé par Marque et Exécution; 3 IDs seulement. |
| Douze arbres | NON CONFORME | 11 ressources de discipline actuelles; seulement 8 correspondent aux sorts Elfe/Mage de la candidate. |
| Rangs R1–R5 | NON CONFORME | Seul Archer va jusqu'à R5; trois arbres Elfe s'arrêtent à R2; Mage à R1; Guerrier à R2/R3. |
| Seuils 0/3/7/12/18 | PARTIEL | Exact sur Archer; 0/3 sur les tranches R2; 0/3/7 sur Bourreau; rangs suivants absents. |
| 1 XP par utilisation réussie du sort | CONFORME | `CharacterProgressionService.grant_cast_xp()` crédite exactement 1 XP au `discipline_id`, une fois par cast et non par cible. |
| Ordre de résolution des choix | CONFORME | héros dans l'ordre du run, disciplines dans l'ordre `UnitData`, rangs en attente croissants; un rang ultérieur est refusé si un rang antérieur attend. |
| Exclusions définitives | CONFORME au niveau moteur | `SkillTreeResolver` vérifie exclusions dans les deux directions et `DisciplineProgressState` ne permet qu'un choix par rang. Briseur est toutefois invalide. |
| Application effective des `SpellModifier` | CONFORME pour le contenu existant testé | Synchronisation après sélection; filtrage par `target_spell_id`; ordre de hooks coûts → cibles → dégâts → terrain → mouvement → fin de cast; ressource Spell non mutée. |
| Évolutions sélectionnées pendant la run | CONFORME | Les IDs sélectionnés et modificateurs restent dans `CharacterRunState` entre salles; une nouvelle run recrée l'état. |
| Persistance d'un choix entre salles | CONFORME et testée | Tests Archer, Mage Elfe et lifecycle. |
| Absence de mécanique d'énergie | CONFORME | `data/energy/energy_type.gd`, Foi et Rage sont absents; aucun coût/stock d'énergie dans la progression. Les occurrences `energy` restantes sont des propriétés de lumière, commentaires ou tests. |
| Absence de Ferveur | PARTIEL textuel | Pas de mécanique. Une description d'ennemi conserve « Draine PA/Ferveur » dans `run_hurleur_gobelin.tres`. |
| Absence d'Éveil | CONFORME mécaniquement | Aucune mécanique. Le verbe « s’éveille » subsiste uniquement dans les sous-titres de la cinématique. |
| Absence de coups signature | CONFORME mécaniquement | Aucune capacité ou ressource de progression correspondante; occurrences génériques dans commentaires/VFX seulement. |
| Absence des anciennes huit capacités Guerrier | NON CONFORME au sens littéral | L'ancien kit à 8 était Bourrade, Crochet, Coup d'épaule, Onde de choc, Marque de guerre, Exécution de guerre, Piétinement, Sol corrompu. Quatre ont été supprimées, mais Bourrade, Marque, Exécution et Piétinement restent équipées. |

### Runtime data-driven

- `CharacterRunState` possède l'identité, les disciplines, les progressions et le `SpellLoadoutState`; il synchronise les modificateurs actifs vers l'unité.
- `DisciplineProgressState` conserve XP, rang, rangs en attente et choix sélectionnés. Les rangs doivent être contigus pour avancer.
- `SkillTreeResolver` valide discipline, rangs, seuils, IDs, prérequis, exclusions et cycles avant toute sélection.
- `SpellModifier.applies_to()` cible d'abord `target_spell_id`, puis l'ancien fallback par nom; un filtre vide s'applique à tous les sorts.
- `SpellCaster` réunit d'abord les modificateurs natifs du sort, puis ceux de progression, les déduplique et exécute leurs hooks dans un ordre stable.

Le socle demandé existe donc et fonctionne. Le déficit est principalement du contenu, plus deux défauts d'intégration : arbre Briseur invalide et association UI par index.

## Audit de l'interface

### Structure générale

| Sujet | Preview candidate | UI réelle | Écart |
|---|---|---|---|
| Vue globale | longue page avec 3 personnages et 4 `<details>` ouverts chacun | modal d'un personnage, un arbre actif | structure différente |
| Branches | A/B côte à côte, tous les nœuds visibles | graphe d'une discipline, spécialisation Archer dédiée ou layout générique | proche conceptuellement, non isomorphe |
| Navigation des sorts | ancres personnage puis accordéons de discipline | liste verticale de disciplines | correcte pour Elfe/Mage, seulement 3 entrées Guerrier |
| Détail | contenu dans chaque carte | panneau de détail séparé | ajout runtime non défini par la preview |
| Sélection | preview descriptive | écran d'arbre consultatif; choix confirmé après combat dans `ProgressionChoiceScreen` | compatible avec le runtime, non défini dans la preview |

### Révélation et états

- La preview montre l'intégralité de R1 à R5, sans état de progression.
- Le runtime révèle jusqu'au rang courant + 1 (`reveal_depth = 1`). Le rang suivant masque le nom, conserve actuellement l'icône (`show_next_rank_icons = true`) et les rangs plus lointains deviennent des `RankGate` génériques.
- États runtime : `SELECTED`, `AVAILABLE`, `LOCKED_BY_XP`, `LOCKED_BY_BRANCH`, `FUTURE`.
- Libellés runtime : Acquis, Disponible après le combat, Bloqué par l'XP, Branche inaccessible, Futur compatible.
- `LOCKED_BY_BRANCH` utilise l'iconographie « excluded », mais il n'existe pas d'état `EXCLUDED` séparé.
- Les connexions représentent sélection, disponibilité, incompatibilité et porte de rang. La preview n'en spécifie ni couleur d'état ni épaisseur.
- Le panneau de détail expose sort, description, prérequis, incompatibilités et raison du verrouillage. La preview ne spécifie pas ce composant.

Conclusion visuelle : il est impossible de déclarer la conformité des états attendus, car la preview candidate n'en définit aucun.

### Clavier, souris et manette

- Souris : survol et clic gauche inspectent un nœud; molette via `ScrollContainer`; glisser avec bouton milieu pour parcourir; boutons Fermer et Centrer.
- Clavier : focus spatial entre nœuds, focus haut/bas entre disciplines, `ui_cancel` et touche physique K ferment l'écran.
- Manette : la navigation s'appuie sur les actions UI et les voisins de focus, donc elle est théoriquement disponible si l'InputMap est correctement mappée.
- Aucun test automatisé actuel ne couvre l'arbre au clavier, à la souris ou à la manette. Le comportement manette est donc non prouvé.
- `ProgressionChoiceScreen` crée des boutons focusables, mais ne pose pas de focus initial ni de voisins explicites; son accessibilité manette/clavier est incomplètement démontrée.

### 720p, 1080p et 1440p

| Résolution | Profil runtime | Contrôle statique | Validation automatisée actuelle |
|---|---|---|---|
| 1280×720 | compact | marges 8 px, navigation 206 px, détail 286 px, graphe min. 840 px avec scroll horizontal/vertical | absente |
| 1920×1080 | large | cadre plafonné à 1700×940, navigation 252 px, détail 360 px | absente |
| 2560×1440 | large | même plafond 1700×940 centré | absente |

Le code possède des profils explicites et du scroll, mais aucune preuve automatisée ou capture actuelle ne valide absence de chevauchement, clipping, focus hors écran ou lisibilité à ces trois résolutions. L'ancien audit UI mentionne des validations sur une base qui ne contenait pas encore les arbres Guerrier; il est désormais obsolète et ne remplace pas un test présent dans la suite.

## Écarts de conception impossibles à résoudre fidèlement

1. Le fichier demandé manque; la candidate peut être obsolète ou différente.
2. Le JSON annoncé comme autorité des identifiants stables manque.
3. Les IDs candidate (`elfe.archer.r2.a...`) et runtime (`elf_archer_...`) sont incompatibles; aucune règle de migration n'indique lequel doit survivre.
4. Valeurs R1 des deux Boules de feu : PA, portée, dégâts, forme exacte, terrain et durée non définis.
5. Aucune iconographie ni chemin d'asset pour les 12 racines et 216 choix.
6. Aucun état visuel, animation, focus, survol, sélection, verrouillage ou exclusion défini dans la preview.
7. Cumul, remplacement et rafraîchissement des boucliers, DoT, HoT et vulnérabilités généralement non définis.
8. Arrondis de 50 % pour Trait transperçant et Floraison non définis.
9. « Zone agrandie », « terrain agrandi », « effets négatifs simples » et plusieurs formulations de durée n'ont pas de définition canonique complète.
10. Charge : chemin, obstacles, case d'arrivée, occupation et comportement du ciblage libre non définis.
11. Timing des effets « alliés/ennemis présents sur la glace » non défini.
12. Déclenchement exact d'une collision contre obstacle, bord ou unité non défini globalement.

## Fichiers à créer, migrer ou supprimer

### Fichiers de migration certains

Ces fichiers existants devront nécessairement être modifiés si la candidate est confirmée :

- `res://data/units/alliés/elfe.tres`
- `res://data/units/alliés/mage.tres`
- `res://data/units/alliés/Guerrier.tres`
- `res://data/characters/elf/disciplines/assassin.tres`
- `res://data/characters/elf/disciplines/mage.tres`
- `res://data/characters/elf/disciplines/healer.tres`
- `res://data/characters/mage/disciplines/fire.tres`
- `res://data/characters/mage/disciplines/ice.tres`
- `res://data/characters/mage/disciplines/lightning.tres`
- `res://data/characters/mage/disciplines/earth.tres`
- `res://ui/progression/screens/skill_tree_screen.gd`
- `res://ui/progression/components/skill_tree_graph_view.gd`
- `res://data/ui/skill_tree_icon_catalog_refined.tres`
- `res://ui/progression/skin/elf_archer_visual_map.tres` ou son remplacement générique multi-arbres
- `res://docs/reference/skill_tree_node_icon_mapping.json`

Les ressources R1/R2 et nœuds Elfe existants devront être migrés si les IDs preview deviennent canoniques. Les 13 scripts de `core/spell_mods` déjà capables de porter les effets conservables peuvent être réutilisés, mais de nouveaux types seront requis pour les mécaniques absentes.

### Créations dont le chemin peut être fixé sans inventer le design

- `res://data/characters/elf/disciplines/assassin_rank_3.tres`
- `res://data/characters/elf/disciplines/assassin_rank_4.tres`
- `res://data/characters/elf/disciplines/assassin_rank_5.tres`
- `res://data/characters/elf/disciplines/mage_rank_3.tres`
- `res://data/characters/elf/disciplines/mage_rank_4.tres`
- `res://data/characters/elf/disciplines/mage_rank_5.tres`
- `res://data/characters/elf/disciplines/healer_rank_3.tres`
- `res://data/characters/elf/disciplines/healer_rank_4.tres`
- `res://data/characters/elf/disciplines/healer_rank_5.tres`

### Créations impossibles à nommer fidèlement avant décision d'IDs

Les 192 choix manquants, leurs modificateurs, les rangs Mage/Guerrier, les quatre sorts Guerrier et les quatre disciplines Guerrier ont un contenu connu dans la candidate, mais leur **chemin exact** dépend du choix non résolu entre IDs français pointés et convention runtime anglaise soulignée. Inventer maintenant des noms de fichiers violerait la consigne. Le manifeste les énumère par identifiant preview avec `planned_path: null` et un motif explicite.

### Suppressions

Aucune suppression ne peut être prescrite avec certitude avant confirmation de la candidate et de la stratégie de sauvegarde/migration. Si elle est confirmée, les ressources suivantes sont obsolètes en tant que kit équipé, mais peuvent nécessiter une migration de sauvegarde ou une réutilisation d'effets avant suppression :

- `res://data/characters/warrior/disciplines/breaker.tres` et ses rangs;
- `res://data/characters/warrior/disciplines/executioner.tres` et ses rangs;
- `res://data/characters/warrior/disciplines/ravager.tres` et ses rangs;
- `res://data/characters/warrior/upgrades/*.tres`;
- `res://data/characters/warrior/modifiers/*.tres`;
- `res://data/spells/Guerrier/bourrade.tres`;
- `res://data/spells/Guerrier/marque_de_guerre.tres`;
- `res://data/spells/Guerrier/execution_de_guerre.tres`;
- `res://data/spells/Guerrier/pietinement.tres`.

Statut : **candidats de suppression, pas ordre de suppression**.

## Tests à créer avant migration

1. `test/unit/test_skill_tree_preview_contract.gd` — charge un manifeste canonique et valide 12 arbres, 5 rangs, 18 choix, seuils et IDs.
2. `test/unit/test_fixed_trio_skill_tree_matrix.gd` — 3 héros × 4 sorts × 4 disciplines distinctes, association par `discipline_id` et non par index.
3. `test/unit/test_all_skill_tree_resources_validate.gd` — exécute `SkillTreeResolver.validate_discipline()` sur les 12 ressources et exige zéro diagnostic.
4. `test/unit/test_skill_tree_branch_exclusivity.gd` — 16 configurations finales par arbre, branches définitives, prérequis R3/R4/R5.
5. `test/unit/test_all_skill_tree_modifier_integration.gd` — un cas réel par choix, ciblage stable, ordre des hooks et absence de mutation des ressources Spell.
6. `test/unit/test_skill_tree_status_stacking_contract.gd` — rafraîchissement/cumul/charges pour DoT, HoT, boucliers, vulnérabilités et PM.
7. `test/unit/test_warrior_four_discipline_contract.gd` — Frappe lourde, Charge, Tourbillon, Garde et aucun des huit anciens sorts équipé.
8. `test/unit/test_skill_tree_run_persistence.gd` — sélection persistante entre chaque salle et remise à zéro à la nouvelle run.
9. `test/unit/test_skill_tree_screen_contract.gd` — quatre onglets par héros, bon sort racine, 5 rangs, états et détail.
10. `test/unit/test_skill_tree_screen_responsive.gd` — 1280×720, 1920×1080, 2560×1440; rectangles sans chevauchement et focus visible.
11. `test/unit/test_skill_tree_input_navigation.gd` — souris, clavier et manette, focus initial/restauré, scroll et fermeture.
12. `test/unit/test_no_legacy_progression_symbols.gd` — absence de mécanique énergie/Ferveur/Éveil/signature et absence des huit anciennes capacités équipées.
13. `test/unit/test_skill_tree_icon_coverage.gd` — icône de racine et de choix pour les 228 présentations, sans fallback générique involontaire.

## Ordre d'implémentation recommandé

1. Restaurer le fichier au chemin demandé ou confirmer formellement que la candidate est l'autorité.
2. Fournir le JSON joint annoncé, choisir les IDs canoniques et publier une table de migration des IDs actuels.
3. Trancher toutes les ambiguïtés listées, en priorité les deux Boules de feu, Charge, statuts, cumul et arrondis.
4. Écrire les tests de contrat et le validateur des 12 disciplines avant de modifier les ressources.
5. Remplacer le kit Guerrier et garantir quatre sorts/quatre disciplines distinctes.
6. Compléter les trois arbres Elfe partiels, puis les quatre arbres Mage.
7. Implémenter et tester les nouveaux `SpellModifier` par familles mécaniques.
8. Corriger l'association UI sort/discipline et transmettre le vrai `character_id` au graphe.
9. Étendre le catalogue d'icônes et le mapping visuel aux 12 arbres.
10. Valider les 16 configurations de chaque arbre, la persistance de run, les entrées et les trois résolutions.
11. Migrer ou supprimer les ressources legacy seulement après validation des sauvegardes et références.

## Validation exécutée

### Parse et chargement

- Scan initial Godot 4.7.1 : terminé (`first_scan_filesystem DONE`).
- Aucun parse error de ressource de progression relevé.
- L'environnement sandbox ne peut pas écrire dans les répertoires Godot sous AppData; le plugin GUT émet des erreurs d'update/cache sans rapport avec les ressources. Ces erreurs environnementales sont conservées dans le constat et non masquées.
- Les tests ciblés chargent effectivement les trois `UnitData`, les 11 disciplines, les choix et modificateurs existants.

### Suite de progression existante

Commande GUT ciblée sur 14 scripts :

- scripts : 14;
- tests : 166;
- assertions : 1 748;
- succès : 165 tests, 1 747 assertions;
- échec : `test_fixed_trio_mage_contract.gd::test_basic_attack_policy_is_explicit_for_the_fixed_party`, ligne 94, car `res://data/units/alliés/Gardien.tres` existe encore;
- les tests Archer, tranches R2 Elfe, Mage élémentaire, resolver, modificateurs, file de choix, lifecycle et persistance passent.

### Audit grep legacy

- `data/energy/energy_type.gd`, Foi et Rage : absents.
- `frappe_lourde.tres`, `brise_garde.tres`, Crochet, Coup d'épaule, Onde de choc et Sol corrompu : absents comme ressources équipables actuelles.
- Bourrade, Marque de guerre, Exécution de guerre et Piétinement : toujours présents et équipés.
- `Ferveur` : une occurrence de description ennemi sans mécanique.
- `Éveil` : aucune mécanique; occurrence narrative « s’éveille » dans la cinématique.
- `signature` : commentaires/outils seulement, aucune capacité contractuelle.

### État Git

- Aucun fichier de gameplay, scène ou script n'a été modifié.
- Aucun fichier n'a été stagé, commité ou poussé.
- `git diff --check` est exécuté après génération des deux livrables; son résultat final est reporté dans le manifeste.

## Verdict final

`SKILL_TREES_BLOCKED_BY_PREVIEW_GAPS`
