# Base de reprise — Catabase, référence Dofus et production VFX

Date : 5 septembre 2026. Cette note consolide les conversations retrouvées, les audits locaux et le code courant. Elle sert de point d’entrée pour poursuivre le projet ; elle ne certifie ni le rendu actuel ni une release.

## 1. État de référence et portée

| Élément | Observation de cette reprise |
|---|---|
| Dépôt | C:/Users/paolo/Documents/dungeon-draft-v-2 |
| Branche | main |
| HEAD examiné | `13cb5872a9fa68ea3d3e9c9855defad4a9923915` |
| Dernier commit | 4 septembre 2026 — feat: harmoniser l'interface de la run Odyssée |
| État initial | Sortie de `git status --porcelain=v1` vide |
| Moteur local | `4.7.1.stable.official.a13da4feb`, obtenu par `--version` |
| Vérifications réalisées | Lecture des conversations, rapports, ressources et code ; historique et deltas Git |
| Non exécuté ici | Import, GUT, partie, capture du runtime courant, profiling, vérification de la CI distante |

Les données et branchements ci-dessous sont **OBSERVÉS STATIQUEMENT**. Les résultats de tests des anciens rapports restent **HISTORIQUES**. Présence d’un fichier, raccordement, test réussi et validation artistique sont des preuves différentes.

## 2. Direction retenue

**Catabase d’Achille est le centre du travail actuel.** La run du trio conserve son rôle de régression pour les systèmes partagés. L’ambition plus large d’anthologie de catabases ne commande pas l’ajout immédiat de héros ou de biomes.

Le contrat du slice repose sur trois piliers :

1. **Intentions lisibles** : comprendre les conséquences critiques et leur contre-jeu avant résolution.
2. **Évolution par l’action** : les usages d’Achille font évoluer ses capacités pendant les combats.
3. **Mémoire mythologique factuelle** : le résultat raconte les faits de la tentative sans inventer d’exploit.

Source : [vision du slice](../design/catabase_achille_vertical_slice_vision.md). La durée de 18–25 minutes est une cible, pas une durée humaine mesurée ici.

La décision utilisateur la plus récente retrouvée ouvre la production interne de VFX 2D : palettes, spritesheets, flipbooks et compositions réutilisables. La conversation **« Créer animations spritesheet »** nomme cet axe `DD-VFX-001` et propose la mission `DD-VFX-FORGE-01`. Cette décision avance les VFX dans les priorités par rapport à l’audit v4.0 du 30 août. Le cadrage conservé est une consommation immédiate par les actions réelles d’Achille.

Cette reprise prépare ce travail ; elle n’exécute pas le long prompt d’implémentation contenu dans cette ancienne conversation.

## 3. Dofus et notre direction artistique

La référence principale est la **grammaire de présentation et d’interaction de Dofus 3** : ancrages stables, hiérarchie, sélection persistante, états distincts, explication des indisponibilités et détails révélés progressivement. Waven reste une référence secondaire pour le rythme des capacités et les VFX dans les conversations retrouvées.

| Principe transférable | Application à Catabase |
|---|---|
| Plateau prioritaire | Protéger les cellules utiles ; inspection et journal contextuels ou repliables |
| Signaux concordants | Acteur, phase, bouton, grille et texte annoncent le même état |
| Icône = identité ; cadre = état | Préserver la silhouette du sort sous les badges et voiles |
| Intention → aperçu → engagement → conséquence | Relier capacité, coût, cible, impact et restitution du contrôle |
| Verrou explicable | Montrer la cause et la condition de reprise près de l’action |
| Information stable et progressive | Tooltip ancré, sélection identifiable, résultat puis détails facultatifs |
| Densité maîtrisée | Présentation adaptée aux quatre actions et au contenu réel de la run |

Notre identité visuelle présente dans les ressources est **mythologique, peinte en 2,5D, avec bronze, cendre et mémoire**. Le HUD actuel utilise des surfaces très sombres légèrement violacées, des bordures bronze/or, des textes crème, Cinzel pour l’emphase et Atkinson Hyperlegible pour la lecture et les chiffres. Cadres ornementaux et illustrations peintes d’Achille sont déjà présents dans les ressources.

Sources : [skin Achille](../../data/ui/hud_visual_skin_achilles_v1.tres), [thème hors combat](../../ui/theme/premium_ui.gd), [vision artistique](../design/catabase_achille_vertical_slice_vision.md).

Les cotes proposées dans les études Dofus sont des recommandations datées. Deux spécifications emploient notamment des dimensions et positions de badges différentes. Les reporter mécaniquement dans le thème de septembre créerait des incohérences. Retenir leurs critères de lisibilité et mesurer les composants actuels avant de modifier leur géométrie.

### Frontières des preuves Dofus

- Les passes du 30 août couvrent HUD, inventaire, équipement, catalogue, caractéristiques, Zaapi, combat et résultat, avec des états encore non observés.
- Le Zaapi et l’épinglage de tooltips ont été observés dans des passes ultérieures : les absences de la première passe sont dépassées.
- Les comparaisons Dungeon Draft utilisent des captures du **23 août**, antérieures aux commits HUD du 2 septembre et à l’harmonisation du 4 septembre.
- La borne nominale d’apparition du tooltip `(0,16] ms` appartient au protocole de capture ; elle ne mesure pas la latence interne exacte de Dofus.
- L’inventaire des fichiers installés renseigne les familles nominales et l’organisation des fichiers. Il ne prouve ni le shader utilisé à l’écran ni l’architecture interne du jeu.
- La reprise Dofus du 5 septembre est documentaire, sans nouvelle capture. Les compléments du 3 septembre y restent à contrôler avant consolidation finale.

## 4. État présent du projet

| Domaine | État présent au HEAD examiné | Limite à conserver |
|---|---|---|
| Run | Nom public Catabase, seed 2401, trois salles ordonnées, début forcé en salle I, cinématique V4 référencée | Chemins techniques `odyssey` toujours utilisés |
| Achille | 110 PV, 6 PA, 3 PM, quatre emplacements, attaque générique désactivée | Rôle sérialisé « Hoplite de Catabase », à rapprocher de l’ambition antérieure d’un Achille plus large que le hoplite |
| Capacités | Frappe de lance, Percée, Balayage, Garde d’airain ; `once_per_activation = true` dans les quatre ressources | Kit épée-bouclier/arc envisagé dans les anciens audits encore distinct |
| Progression | Quatre disciplines ; chacune possède un rang 2 à 3 XP et deux choix exclusifs ; huit illustrations dédiées | Choix surtout sur dégâts, portée, poussée, bouclier ou PM ; deux builds transformants restent à éprouver |
| Salle I | Rejeton chétif des Enfers et Trait d’ombre dédié | Paris en ouverture appartient à l’ancien état |
| Salle II | Deux escarmoucheurs et un garde selon le contrat ; arène grecque à obstacles | Références et identifiants `room_05_volcano` toujours présents dans la ressource |
| Salle III | Champion et Ombre de Paris ; finale grecque 13×13 selon le contrat | La combinaison n’est pas un boss à plusieurs phases |
| Menaces | Traits différés du Rejeton et de Paris : 18 dégâts, portée 3–7, télégraphe et contre-jeu documenté | Pas de preuve ici d’un système d’intentions exactes généralisé à tous les ennemis |
| Personnage | Profil Meshy V3, rendu VIEWPORT_3D, 24 os attendus, vingt noms de clips requis, quatre orientations | `equipment_enabled = false`, `weapon_profile = null` ; mort par fondu prévu |
| HUD et menus | HUD Achille remanié le 2 septembre ; inventaire, récompenses, évolution, résultats, pause et hub harmonisés le 4 septembre | Présence dans le code vérifiée ; qualité perçue et comportement à recapturer |
| Économie | Deux potions et un parchemin au départ ; récompenses d’équipement activées, pool `first_run_equipment_reward` | Équipement dans l’inventaire et arme affichée sur le modèle 3D sont deux fonctions différentes |
| Résultat | Service de chronique factuelle et écran de résultat présents | Mémoire immédiate selon le contrat, sans Archive persistante certifiée |

Sources : [run](../../data/runs/odyssey.tres), [Achille](../../data/units/allies/achilles.tres), [économie](../../data/runs/economy/odyssey_economy_profile.tres), [disciplines](../../data/characters/achilles/disciplines/), [profil visuel](../../data/visuals/achilles/achilles_meshy_profile_v3.tres), [sorts ennemis](../../data/spells/enemies/catabase/), [bilan du slice et mise à jour du 2 septembre](../design/catabase_achille_vertical_slice_implementation_2026-08-28.md).

## 5. État VFX à reprendre

La fondation existe : profils, séquences, modules, runtime, services, laboratoires procédural et flipbook, domaine VFX du Studio. `VFXManager.play_profile()` est présent comme point d’entrée additionnel.

Le trajet automatique inspecté reste cependant `Spell.vfx_scene` → `VFXManager.play_spell_vfx()`. `Spell` ne possède pas de propriété canonique `vfx_profile`, et les quatre ressources de capacités d’Achille inspectées ne déclarent pas de `vfx_scene`. La présence du lecteur de profils ne prouve donc pas à elle seule le raccordement de la Forge à ces capacités.

Sources : [Spell](../../data/spell.gd), [VFXManager](../../core/vfx_manager.gd), [capacités Achille](../../data/spells/achilles/), [intégration historique de la fondation](../tools/vfx/vfx_flipbook_foundation_main_integration_report.md).

L’audit **« Auditer le système VFX »**, réalisé les 29–30 août sur un candidat basé sur `423a52d`, conclut `VFX_FOUNDATION_RELIABILITY_GATE_FAILED`, malgré 76/76 tests fonctionnels et 2 902/2 902 assertions : pollution d’import et diagnostics résiduels empêchaient la validation stricte. Ce résultat ne certifie ni ne condamne automatiquement `13cb587`.

Depuis `423a52d`, les services de brouillon, snapshot et document VFX ainsi que le compositeur ont changé ; la fixture suivie `data/runs/__g6_closure_e2e/source_run.tres` impliquée dans l’erreur d’import a été supprimée. Rejouer le diagnostic courant et comparer les corrections existantes avant de réappliquer l’ancien candidat. Les atlas synthétiques restent des fixtures techniques tant qu’une validation artistique spécifique n’existe pas.

## 6. Énoncés anciens à requalifier

| Ancien énoncé | Requalification pour la reprise |
|---|---|
| Le trio commande la production | Le trio est la référence historique ; Achille/Catabase est la priorité retrouvée |
| Achille est un POC 2D à une direction | Dépassé par le profil Meshy V3 ; fallback 2D encore prévu |
| Les quatre arbres ont un seul rang | Dépassé : rang 2, 3 XP, deux choix par discipline |
| Aucun télégraphe ennemi | Contredit par le contrat Catabase et les ressources du Rejeton/Paris |
| Une utilisation par combat | Contredit par les quatre `once_per_activation = true` |
| Aucune récompense d’équipement | Contredit par l’économie actuelle |
| Les écarts HUD mesurés en août sont actuels | Comparaison historique à refaire sur les écrans de septembre |
| Les VFX attendent nécessairement les deux kits d’armes | Priorité modifiée par le lancement utilisateur de l’axe VFX 2D |
| Un ancien PASS valide le HEAD actuel | Nouvelle exécution et provenance nécessaires |
| L’échec VFX d’août prouve la même panne aujourd’hui | Le périmètre a changé ; vérifier à nouveau avant correction |

La documentation partagée conserve des couches historiques contradictoires : [CURRENT_STATE](CURRENT_STATE.md), [KNOWN_ISSUES](KNOWN_ISSUES.md), [BALANCE_BASELINE](BALANCE_BASELINE.md) et [contrat HUD du 23 août](../audits/hud_reference_audit_2026-08-23/TARGET_HUD_CONTRACT.md). Cette note les signale sans réécrire les anciennes preuves ni inventer un nouvel équilibrage validé.

## 7. Suite recommandée et usage des outils

1. **Établir une preuve actuelle courte.** Import, tests ciblés Catabase/HUD/VFX et captures du même état Git : repos, sélection, cible invalide, résolution, tour adverse, évolution, inventaire et résultat. Réutiliser les runners existants.
2. **Fermer les défauts qui bloquent les VFX.** Reproduire les problèmes d’import, d’ownership ou de nettoyage encore présents ; séparer résultat GUT, erreurs moteur et observation graphique.
3. **Livrer une première tranche de Forge consommée en combat.** Cadrage retrouvé : Garde d’airain et une frappe de lance ou Balayage ; source/recette → palette → atlas/manifeste → profil → événement de capacité → impact → nettoyage. Les six recettes de laboratoire du brief restent au service de cette tranche.
4. **Vérifier le rendu dans les trois salles.** Taille réelle, fonds clairs/sombres, pivot, origine, direction, impact, dissipation et restitution du contrôle. Le VFX ne déplace pas l’autorité du gameplay.
5. **Reprendre les chantiers de fond.** Cohérence des armes et des contacts, profondeur des builds, variété tactique et partie humaine complète. Leur importance demeure ; cette reprise ne les déclare pas réglés.

Cet ordre est une recommandation fondée sur la dernière décision retrouvée. Aucun élargissement du scope ni implémentation de la Forge n’est réalisé par ce document.

Les outils disponibles peuvent servir concrètement à :

- croiser les tâches et fichiers pour retrouver les décisions, puis les confronter au code courant ;
- exécuter les commandes et runners Godot existants pour vérifier des parcours reproductibles ;
- préparer des opérations ciblées avec les outils Godot et Blender exposés dans la session ; leur présence dans la liste ne prouve pas une connexion active à un éditeur, à tester avant usage ;
- explorer des sources et textures par génération d’images, puis contrôler dimensions, alpha, pivots et atlas par une fabrication reproductible ;
- inspecter des images et comparer des captures à l’échelle du jeu.

Le contrôle natif des applications Windows n’est pas activé dans l’interface CUA de cette session : ne pas promettre un pilotage interactif de Godot ou Dofus sur cette seule base. La version Godot locale a été confirmée par commande ; les autres connexions n’ont pas été testées ici.

Le gain recherché est de terminer une chaîne visible et jouable avec ses preuves. Les nouvelles capacités de l’assistant ne remplacent pas la revue artistique et le playtest humain.

## 8. Provenance

### Conversations consultées

| Titre exact | Identifiant | Apport |
|---|---|---|
| Auditer UX visuelle de DOFUS | 01a0528b-b41c-7413-ada7-0ad690bdfa81 | Corpus Dofus, limites et études dérivées |
| Audit de projet | 6a7372b1-9f4c-83eb-8bf9-afc9191ec940 | Audit v4.0, priorité Achille, snapshot historique 423a52d |
| Analyser les animations | 6a93eac2-ead4-83eb-b27c-0758bbe89de1 | Dofus primaire pour le combat, Waven secondaire |
| Créer animations spritesheet | 6a9adca9-655c-83eb-8466-7fbc540be9ca | Lancement VFX 2D et brief de Forge |
| Impact sur notre jeu | 6a9be4fb-86c8-83eb-bc10-135efc1d4d25 | Attente de livraison complète et vérifiée avec les nouveaux outils |
| Auditer le système VFX | 01a04ccd-3b35-7003-8751-475a1029244e | Audit et candidat historique en échec strict |

Les pièces jointes non exposées ne sont pas réputées lues intégralement ; la synthèse utilise les messages accessibles et les rapports locaux effectivement consultés.

### Livrables extérieurs au dépôt

- [Étude Dofus → HUD](C:/Users/paolo/Documents/Codex/2026-08-30/mission-audit-visuel-et-ux-de/outputs/dofus-dd-reproduction-study-2026-08-30/rapport_etude_reproduction_hud.md).
- [Spécification HUD dérivée](C:/Users/paolo/Documents/Codex/2026-08-30/mission-audit-visuel-et-ux-de/outputs/dofus-dd-reproduction-study-2026-08-30/specification_hud_dungeon_draft.md).
- [Spécification d’iconographie](C:/Users/paolo/Documents/Codex/2026-08-30/mission-audit-visuel-et-ux-de/outputs/dofus-dd-reproduction-study-2026-08-30/specification_iconographie_detaillee.md).
- [Couverture cumulative Dofus](C:/Users/paolo/Documents/Codex/2026-08-30/mission-audit-visuel-et-ux-de/outputs/dofus-dd-reproduction-study-2026-08-30/couverture_cumulative.md).
- [Reprise Dofus du 5 septembre](C:/Users/paolo/Documents/Codex/2026-08-30/mission-audit-visuel-et-ux-de/outputs/reprise-audit-2026-09-05.md).
- [Audit VFX de fiabilité](C:/Users/paolo/Documents/Codex/2026-08-29/files-pasted-by-the-user-mission-2/outputs/vfx_foundation_reliability_gate_v1/VFX_FOUNDATION_RELIABILITY_GATE_V1_REPORT.md).

Ces liens externes sont propres à ce poste. Les faits de reprise et les références de code utiles à la suite sont conservés dans ce fichier versionnable.

