# Menus, haltes et ergonomie de Catabase — 8 septembre 2026

Cette passe conserve la version réunie dans `f99049a` et le Sanctuaire créé à la
maison. Elle raccorde les interfaces à la progression réelle de Catabase et
protège les sauvegardes pendant les transitions.

## Comportement livré

- L’accueil adapte son placement à la fenêtre. La reprise reçoit le focus quand
  une sauvegarde existe. Le premier clic pendant l’introduction la termine sans
  déclencher un bouton invisible. Les animations réduites ouvrent directement le menu.
- La sélection agrandit les commandes d’aperçu, les onglets et l’accès aux
  maîtrises. Le sixième héros reste accessible par défilement et au clavier.
  Les deux apparences de Catabase demandent confirmation avant remplacement ;
  le trio et l’essai philosophique conservent leur parcours indépendant.
- La confirmation de remplacement protège le fichier existant jusqu’à
  l’enregistrement d’une nouvelle entrée valide. Un consentement annulé ou
  devenu périmé ne permet pas de remplacer une autre sauvegarde.
- Le Sanctuaire s’ouvre depuis l’accueil, la sélection et une halte. Pendant une
  halte, ses objets, services et oboles sont ceux de la run. Avant le départ,
  ses habitants expliquent leurs services sans attribuer de monnaie ni de bonus
  fictifs. Revenir à la halte ne la consomme pas ; reprendre le chemin la termine.
- Les panneaux gardent leurs actions importantes visibles. Échap ferme d’abord
  le panneau ouvert, puis revient à son écran d’origine. Le StartHub historique
  dispose aussi d’une sortie vers le menu.
- Sur la carte, dans l’arbre et dans les haltes, les boutons d’engagement,
  d’achat de technique et de départ restent hors du défilement des descriptions.
- L’inventaire conserve les actions d’équipement visibles, donne plus de place
  au texte et aux icônes, et réagit au survol, au focus et au clic sans déplacer
  les zones cliquables. Les cartes de sorts fonctionnent aussi au clavier et
  restent au-dessus des commandes de combat. Le titre des récompenses garde sa
  largeur et chaque choix reste accessible par le défilement au clavier.
- Revenir au menu enregistre la progression. Un combat interrompu reprend à son
  entrée enregistrée. Abandonner supprime réellement la reprise après confirmation.
- Si l’écriture échoue, l’aventure reste ouverte et propose de réessayer. Une
  transaction déjà appliquée n’est pas exécutée deux fois. Après réessai, une
  entrée en combat lance le combat et une entrée de destination ouvre la halte.

## Vérification

Godot **4.7.1 stable**. Les suites ont été exécutées par groupes, avec des
sauvegardes isolées ; les sauvegardes du joueur sont contrôlées inchangées.

| Contrôle | Résultat |
| --- | --- |
| Fiabilité, HUD persistant et pause | 41 tests ciblés validés par groupes |
| Sélection, lancement et cinématique | 48 tests ciblés validés par groupes |
| Session du Sanctuaire | 4 tests, 16 assertions |
| Assets, thème réversible et inventaire | 23 tests, 917 assertions |
| Intégration de progression | 301 contrôles réussis |
| Parcours réel des menus, confirmation, cinématique et réessai | 612 contrôles, 10 captures |
| Sanctuaire, déplacements, services, inventaire, retour à la halte | 273 contrôles, 27 captures |
| Parcours UI complet avant les dernières finitions visuelles | 364 contrôles et 25 captures à chacune des trois résolutions |
| Régression finale : HUD, fiche de sort au clavier, pause, carte, récompenses et inventaire | 200 contrôles et 12 captures à chacune des trois résolutions, aucun échec, sorties moteur à 0 |

Les captures couvrent **1200 × 896**, **1280 × 720** et **1920 × 1080**.
Les menus et le Sanctuaire ont été vérifiés avec le rendu par défaut
**D3D12 / Forward+**. Leurs journaux finaux ne comportent aucune erreur de script
ni ressource manquante. Une passe antérieure utilisait aussi OpenGL Compatibility.
La régression finale emploie également D3D12 / Forward+ et ne présente aucune
erreur de script. Les neuf captures finales de récompenses, d’inventaire et de
fiche de sort ont été inspectées aux trois résolutions.

Les probes utilisent les scènes et les signaux d’interface de production.
Certaines victoires intermédiaires, découvertes et dotations d’objets sont des
fixtures explicites pour atteindre les écrans tardifs. Ils ne prouvent pas
l’équilibrage ni la durée d’une descente complète jouée manuellement.

## Reproduction

Depuis la racine du projet, avec le binaire Godot 4.7.1 disponible sous `godot` :

```text
godot --headless --path . --editor --recovery-mode --import --quit
godot --path . res://tests/expedition/MenuNavigationProbe.tscn
godot --path . res://tools/sanctuary_concepts/VerifySanctuaryRuntime.tscn -- --capture
godot --headless --path . res://tests/expedition/session_integration_test.tscn
godot --path . --rendering-method gl_compatibility res://tests/expedition/CatabaseMeshyUIProbe.tscn -- resolution=1280x720
godot --path . --audio-driver Dummy --position -3000,-3000 --resolution 1280x720 res://tests/expedition/CatabaseMeshyUIProbe.tscn -- resolution=1280x720 ergonomics_only=true
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -- -gconfig= -gexit -gtest res://test/unit/test_reliability_expedition_lifecycle.gd
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -- -gconfig= -gexit -gtest res://test/unit/test_selection_replacement_guard.gd
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -- -gconfig= -gexit -gtest res://test/unit/test_catabase_meshy_art.gd -gtest res://test/unit/test_inventory_equipment_system.gd
```

`-gconfig=` évite de charger les anciens répertoires de tests de la configuration
globale. Changer `resolution=` pour les deux autres formats. Les commandes
exactes exécutées sur le poste, résultats et empreintes sont conservés localement
dans `artifacts/project_audit/2026-09-08/reliability_validation.json`,
`menu_navigation/report.json`, `sanctuary/implementation_receipt.json` et
`artifacts/meshy_ui/`. Ces journaux et captures restent hors du dépôt.
La passe finale utilise les journaux `root-targeted-<résolution>.log` et les
rapports `<résolution>/ergonomics/report.json`. Chaque exécution graphique finale
est aussi bornée à 120 secondes par le lanceur externe.

## Limites constatées

Des avertissements d’accès au magasin de certificats et au cache des shaders
apparaissent dans l’environnement restreint. Des ressources GPU et objets restent
également signalés à la fermeture des probes graphiques ; leur origine n’a pas été
établie pendant cette passe. Ce bilan ne certifie pas l’absence de fuite mémoire.

La suite historique complète n’a pas été déclarée verte. Les nouveaux monstres,
leurs modifications de combat et les expériences de maps créés en parallèle
restent hors du périmètre de ces commits et de ce bilan. Les haltes peintes et
les sources d’assets existantes sont conservées.

Une tentative supplémentaire du probe UI complet s’est arrêtée après la capture
de l’arbre des éléments, avant le second combat. Aucun journal ne permet de
l’attribuer aux changements de combat parallèles. L’attente d’une image rendue
était sans limite explicite ; le probe demande désormais une image et borne
cette attente à 1,5 seconde. Les dernières corrections de survol, de carte de
sort et de récompenses ont passé la vérification ciblée distincte aux trois
résolutions. Cette passe ne répète pas les arbres tardifs ni le combat à six sorts.
